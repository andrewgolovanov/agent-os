import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { isAbsolute, join, relative, resolve } from "node:path";
import { createInterface } from "node:readline";
import { ensureAgentOSRuntime } from "./bootstrap.mjs";

const serverVersion = "0.5.0";
const { homeRoot, sourceRoot } = ensureAgentOSRuntime();
if (homeRoot === "/") throw new Error("Refusing to use the filesystem root as AGENT_OS_HOME");
if (sourceRoot === "/") throw new Error("Refusing to use the filesystem root as AGENT_OS_SOURCE_ROOT");
const taskRoot = realpathSync(join(homeRoot, "work"));
const taskBoardBin = realpathSync(join(sourceRoot, "tools", "task-board"));
const agentOSBin = realpathSync(join(sourceRoot, "bin", "agent-os"));
const registryPath = realpathSync(join(homeRoot, "config", "projects.yaml"));

function assertInsideRoot(root, candidate, label) {
  const resolved = resolve(candidate);
  const pathFromRoot = relative(root, resolved);
  if (pathFromRoot === "" || (!pathFromRoot.startsWith("..") && !isAbsolute(pathFromRoot))) {
    return resolved;
  }
  throw new Error(`Path escapes configured ${label} root`);
}

assertInsideRoot(homeRoot, taskRoot, "Agent OS home");
assertInsideRoot(homeRoot, registryPath, "Agent OS home");
assertInsideRoot(sourceRoot, taskBoardBin, "Agent OS source");
assertInsideRoot(sourceRoot, agentOSBin, "Agent OS source");
if (!statSync(taskRoot).isDirectory()) throw new Error("Task root is not a directory");
if (!statSync(taskBoardBin).isFile()) throw new Error("Task Board executable is missing");

function assertTaskId(taskId) {
  if (typeof taskId !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(taskId)) {
    throw new Error("Invalid task ID");
  }
  return taskId;
}

function resolveTaskId(args) {
  const provided = [
    ["taskId", args.taskId],
    ["task_id", args.task_id],
    ["id", args.id],
  ].filter(([, value]) => value !== undefined);
  if (provided.length === 0) {
    throw new Error("One of taskId, task_id, or id is required");
  }

  const validated = provided.map(([name, value]) => [name, assertTaskId(value)]);
  if (new Set(validated.map(([, value]) => value)).size > 1) {
    throw new Error(`Conflicting task ID fields: ${validated.map(([name]) => name).join(", ")}`);
  }
  return validated[0][1];
}

function taskFile(taskId, filename) {
  return assertInsideRoot(homeRoot, join(taskRoot, "items", assertTaskId(taskId), filename), "Agent OS home");
}

function run(executable, args, cwd = homeRoot) {
  const result = spawnSync(executable, args, {
    cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `${executable} exited ${result.status}`);
  }
  return result.stdout.trim();
}

function runTaskBoard(args) {
  return run(taskBoardBin, [...args, "--root", taskRoot]);
}

function runAgentOS(args) {
  return run(agentOSBin, args, sourceRoot);
}

function eventCount(taskId) {
  const path = taskFile(taskId, "events.jsonl");
  if (!existsSync(path)) return 0;
  return readFileSync(path, "utf8").split("\n").filter(Boolean).length;
}

function listProjects() {
  const script = String.raw`
    data = YAML.safe_load(File.read(ARGV.fetch(0)), permitted_classes: [], permitted_symbols: [], aliases: false)
    projects = data.fetch("projects").map do |key, value|
      {
        key: key,
        display_name: value.fetch("display_name"),
        status: value.fetch("status"),
        root: value.fetch("root"),
        slack_channels: Array(value["slack_channels"]).map { |channel| channel.slice("id", "name") },
        repositories: value.fetch("repositories").map { |repository| repository.slice("id", "path", "role", "source_of_truth", "primary_branch") }
      }
    end
    puts JSON.generate(projects)
  `;
  return JSON.parse(run("/usr/bin/ruby", ["-ryaml", "-rjson", "-e", script, registryPath]));
}

function textResult(value, isError = false) {
  const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
  return {
    content: [{ type: "text", text }],
    ...(typeof value === "object" && value !== null ? { structuredContent: value } : {}),
    ...(isError ? { isError: true } : {}),
  };
}

const taskIdProperties = {
  taskId: { type: "string", description: "Exact canonical task ID (preferred field)." },
  task_id: { type: "string", description: "Compatibility alias for taskId." },
  id: { type: "string", description: "Compatibility alias for taskId." },
};

const tools = [
  {
    name: "agent_os_list_projects",
    title: "List Agent OS projects",
    description: "List registered project keys and exact repository paths.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_list_tasks",
    title: "List Agent OS outcomes",
    description: "List canonical Task Board outcomes from the configured root.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_onboard_project",
    title: "Onboard an Agent OS project",
    description: "Preview or register an existing local Git repository and explicitly selected Slack channel reconciliation without moving it or changing Git state.",
    inputSchema: {
      type: "object",
      required: ["repositoryPath"],
      properties: {
        repositoryPath: { type: "string", description: "Absolute path to a Git repository or a directory inside it." },
        key: { type: "string", description: "Optional lowercase kebab-case project key." },
        displayName: { type: "string", description: "Optional human-readable project name." },
        slackChannelIds: {
          type: "array",
          items: { type: "string", minLength: 1 },
          uniqueItems: true,
          description: "Exact Slack channel IDs selected from a reviewed onboarding preview.",
        },
        apply: { type: "boolean", description: "False previews; true applies the reviewed project and selected Slack reconciliation." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_upgrade_project_registry",
    title: "Upgrade the Agent OS project registry",
    description: "Preview or remove obsolete layout metadata. Managed legacy project folders are preserved in a private recovery backup.",
    inputSchema: {
      type: "object",
      properties: {
        apply: { type: "boolean", description: "False previews; true applies the reviewed one-way registry migration." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_relink_project",
    title: "Relink an Agent OS project",
    description: "Preview or update registry metadata after an already registered Git repository was moved locally. The tool never moves repository files or changes Git state.",
    inputSchema: {
      type: "object",
      required: ["key", "repositoryPath"],
      properties: {
        key: { type: "string", description: "Existing lowercase kebab-case project key." },
        repositoryPath: { type: "string", description: "Absolute new path to the same Git repository." },
        repositoryId: { type: "string", description: "Repository id when the project registers multiple repositories." },
        apply: { type: "boolean", description: "False previews; true applies only the reviewed registry path changes." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_create_task",
    title: "Create an Agent OS outcome",
    description: "Create one canonical outcome through tools/task-board.",
    inputSchema: {
      type: "object",
      required: ["title", "goal", "nextAction"],
      properties: {
        title: { type: "string", minLength: 1 },
        project: { type: "string", minLength: 1 },
        goal: { type: "string", minLength: 1 },
        nextAction: { type: "string", minLength: 1 },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
  {
    name: "agent_os_label_task",
    title: "Label an Agent OS outcome",
    description: "Add or refresh one display-only label. Provide taskId (preferred), task_id, or id for the exact outcome.",
    inputSchema: {
      type: "object",
      required: ["key", "name", "kind"],
      properties: {
        ...taskIdProperties,
        key: { type: "string", minLength: 1, description: "Stable namespaced label key, for example slack:C123." },
        name: { type: "string", minLength: 1, description: "Current user-facing label, for example #client-checks." },
        kind: { type: "string", enum: ["slack_channel"] },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_attach_source",
    title: "Attach an Agent OS source",
    description: "Attach one stable external source to an exact outcome using taskId (preferred), task_id, or id. A Slack root-message title is optional display metadata and never becomes source identity.",
    inputSchema: {
      type: "object",
      required: ["kind", "value"],
      properties: {
        ...taskIdProperties,
        kind: {
          type: "string",
          enum: ["slack_threads", "pull_requests", "figma", "deployments", "other"],
        },
        value: { type: "string", minLength: 1, description: "Exact provider URL or stable identifier." },
        title: {
          type: "string",
          minLength: 1,
          description: "Optional Slack root-message text; Task Board normalizes and limits it to a 96-character display title.",
        },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "agent_os_update_task",
    title: "Update an Agent OS outcome",
    description: "Apply one validated Task Board update using taskId (preferred), task_id, or id for the exact outcome.",
    inputSchema: {
      type: "object",
      properties: {
        ...taskIdProperties,
        status: {
          type: "string",
          enum: ["inbox", "planned", "active", "waiting", "review", "done", "cancelled"],
        },
        summary: { type: "string", minLength: 1 },
        nextAction: { type: "string", minLength: 1 },
        waitingOn: { type: "string", minLength: 1 },
        clearWaiting: { type: "boolean" },
        completionFollowUp: {
          type: "string",
          enum: ["pending", "sent", "not_required"],
          description: "Completion communication state for a done outcome.",
        },
      },
      minProperties: 2,
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
];

function callTool(name, args = {}) {
  try {
    if (name === "agent_os_list_projects") {
      return textResult({ projects: listProjects() });
    }

    if (name === "agent_os_list_tasks") {
      const tasks = JSON.parse(runTaskBoard(["list", "--json"]));
      return textResult({
        tasks: tasks.map((task) => ({
          id: task.id,
          title: task.title,
          projects: task.projects,
          labels: task.labels || [],
          status: task.status,
          summary: task.summary,
          nextAction: task.next_action,
          waitingOn: task.waiting_on,
          eventCount: eventCount(task.id),
        })),
      });
    }

    if (name === "agent_os_onboard_project") {
      const command = [
        "onboard-project",
        "--source", sourceRoot,
        "--home", homeRoot,
        "--repository", args.repositoryPath,
        "--json",
      ];
      if (args.key) command.push("--key", args.key);
      if (args.displayName) command.push("--display-name", args.displayName);
      for (const channelId of args.slackChannelIds || []) command.push("--slack-channel", channelId);
      if (args.apply === true) command.push("--apply");
      return textResult(JSON.parse(runAgentOS(command)));
    }

    if (name === "agent_os_upgrade_project_registry") {
      const command = [
        "upgrade-project-registry",
        "--source", sourceRoot,
        "--home", homeRoot,
        "--json",
      ];
      if (args.apply === true) command.push("--apply");
      return textResult(JSON.parse(runAgentOS(command)));
    }

    if (name === "agent_os_relink_project") {
      const command = [
        "relink-project",
        "--source", sourceRoot,
        "--home", homeRoot,
        "--key", args.key,
        "--repository", args.repositoryPath,
        "--json",
      ];
      if (args.repositoryId) command.push("--repository-id", args.repositoryId);
      if (args.apply === true) command.push("--apply");
      return textResult(JSON.parse(runAgentOS(command)));
    }

    if (name === "agent_os_create_task") {
      const command = [
        "create",
        "--title", args.title,
        "--kind", "delivery",
        "--status", "planned",
        "--goal", args.goal,
        "--summary", "Created through Agent OS MCP.",
        "--next-action", args.nextAction,
      ];
      if (args.project) command.push("--project", args.project);
      const task = JSON.parse(runTaskBoard(command));
      return textResult({ task: { id: task.id, status: task.status, nextAction: task.next_action } });
    }

    if (name === "agent_os_label_task") {
      const taskId = resolveTaskId(args);
      taskFile(taskId, "task.json");
      const beforeEventCount = eventCount(taskId);
      const task = JSON.parse(runTaskBoard([
        "label", taskId,
        "--key", args.key,
        "--name", args.name,
        "--kind", args.kind,
      ]));
      const afterEventCount = eventCount(taskId);
      return textResult({
        task: {
          id: task.id,
          status: task.status,
          labels: task.labels || [],
        },
        beforeEventCount,
        afterEventCount,
        eventDelta: afterEventCount - beforeEventCount,
      });
    }

    if (name === "agent_os_attach_source") {
      const taskId = resolveTaskId(args);
      taskFile(taskId, "task.json");
      const command = [
        "source", taskId,
        "--kind", args.kind,
        "--value", args.value,
      ];
      if (args.title) command.push("--title", args.title);
      const beforeEventCount = eventCount(taskId);
      const task = JSON.parse(runTaskBoard(command));
      const afterEventCount = eventCount(taskId);
      return textResult({
        task: {
          id: task.id,
          status: task.status,
          sources: task.sources[args.kind],
        },
        beforeEventCount,
        afterEventCount,
        eventDelta: afterEventCount - beforeEventCount,
      });
    }

    if (name === "agent_os_update_task") {
      const taskId = resolveTaskId(args);
      taskFile(taskId, "task.json");
      if (args.waitingOn && args.clearWaiting) {
        throw new Error("waitingOn and clearWaiting are mutually exclusive");
      }
      const lifecycleFields = [args.status, args.summary, args.nextAction, args.waitingOn, args.clearWaiting]
        .filter((value) => value !== undefined && value !== false);
      if (args.completionFollowUp && lifecycleFields.length > 0) {
        throw new Error("completionFollowUp must be updated separately from lifecycle fields");
      }
      if (args.completionFollowUp) {
        const beforeEventCount = eventCount(taskId);
        const task = JSON.parse(runTaskBoard([
          "completion", taskId,
          "--follow-up-status", args.completionFollowUp,
        ]));
        const afterEventCount = eventCount(taskId);
        return textResult({
          task: {
            id: task.id,
            status: task.status,
            completion: task.completion,
          },
          beforeEventCount,
          afterEventCount,
          eventDelta: afterEventCount - beforeEventCount,
        });
      }
      const command = ["update", taskId];
      if (args.status) command.push("--status", args.status);
      if (args.summary) command.push("--summary", args.summary);
      if (args.nextAction) command.push("--next-action", args.nextAction);
      if (args.waitingOn) command.push("--waiting-on", args.waitingOn);
      if (args.clearWaiting) command.push("--clear-waiting");
      if (command.length === 2) throw new Error("At least one update field is required");

      const beforeEventCount = eventCount(taskId);
      const task = JSON.parse(runTaskBoard(command));
      const afterEventCount = eventCount(taskId);
      return textResult({
        task: {
          id: task.id,
          status: task.status,
          summary: task.summary,
          nextAction: task.next_action,
          waitingOn: task.waiting_on,
        },
        beforeEventCount,
        afterEventCount,
        eventDelta: afterEventCount - beforeEventCount,
      });
    }

    throw new Error(`Unknown tool: ${name}`);
  } catch (error) {
    return textResult({ error: error.message }, true);
  }
}

function respond(id, result) {
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id, result })}\n`);
}

function respondError(id, code, message) {
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } })}\n`);
}

createInterface({ input: process.stdin }).on("line", (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    respondError(null, -32700, "Parse error");
    return;
  }
  if (!Object.hasOwn(message, "id")) return;

  switch (message.method) {
    case "initialize":
      respond(message.id, {
        protocolVersion: message.params?.protocolVersion || "2025-11-25",
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "agent-os", version: serverVersion },
      });
      break;
    case "ping":
      respond(message.id, {});
      break;
    case "tools/list":
      respond(message.id, { tools });
      break;
    case "tools/call":
      respond(message.id, callTool(message.params?.name, message.params?.arguments || {}));
      break;
    default:
      respondError(message.id, -32601, `Method not found: ${message.method}`);
  }
});
