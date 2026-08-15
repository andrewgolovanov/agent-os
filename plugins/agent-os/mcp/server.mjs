import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";
import { createInterface } from "node:readline";

const serverVersion = "0.2.0";
const legacyRoot = process.env.WORKSPACE_CONSOLE_ROOT;
const activeHomePointer = process.env.AGENT_OS_HOME_POINTER
  || join(homedir(), ".config", "agent-os", "home");
const activeHome = existsSync(activeHomePointer)
  ? readFileSync(activeHomePointer, "utf8").trim()
  : "";
const configuredHome = process.env.AGENT_OS_HOME || legacyRoot || activeHome || join(homedir(), ".agent-os");

if (!isAbsolute(configuredHome)) {
  throw new Error("AGENT_OS_HOME must be an absolute path");
}

const homeRoot = realpathSync(configuredHome);
if (homeRoot === "/") throw new Error("Refusing to use the filesystem root as AGENT_OS_HOME");
const sourcePointerPath = join(homeRoot, "source-path");
const configuredSource = process.env.AGENT_OS_SOURCE_ROOT
  || process.env.WORKSPACE_CONSOLE_SOURCE_ROOT
  || legacyRoot
  || (existsSync(sourcePointerPath) ? readFileSync(sourcePointerPath, "utf8").trim() : "");
if (!configuredSource || !isAbsolute(configuredSource)) {
  throw new Error("AGENT_OS_SOURCE_ROOT must be absolute or AGENT_OS_HOME/source-path must exist");
}
const sourceRoot = realpathSync(configuredSource);
if (sourceRoot === "/") throw new Error("Refusing to use the filesystem root as AGENT_OS_SOURCE_ROOT");
const taskRoot = realpathSync(join(homeRoot, "work"));
const taskBoardBin = realpathSync(join(sourceRoot, "tools", "task-board"));
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
if (!statSync(taskRoot).isDirectory()) throw new Error("Task root is not a directory");
if (!statSync(taskBoardBin).isFile()) throw new Error("Task Board executable is missing");

function assertTaskId(taskId) {
  if (typeof taskId !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(taskId)) {
    throw new Error("Invalid task ID");
  }
  return taskId;
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
        wrapper: value.fetch("wrapper"),
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
    name: "agent_os_update_task",
    title: "Update an Agent OS outcome",
    description: "Apply one validated Task Board update by exact task ID.",
    inputSchema: {
      type: "object",
      required: ["taskId"],
      properties: {
        taskId: { type: "string", description: "Exact canonical task ID." },
        status: {
          type: "string",
          enum: ["inbox", "planned", "active", "waiting", "review", "done", "cancelled"],
        },
        summary: { type: "string", minLength: 1 },
        nextAction: { type: "string", minLength: 1 },
        waitingOn: { type: "string", minLength: 1 },
        clearWaiting: { type: "boolean" },
      },
      anyOf: [
        { required: ["status"] },
        { required: ["summary"] },
        { required: ["nextAction"] },
        { required: ["waitingOn"] },
        { required: ["clearWaiting"] },
      ],
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
          status: task.status,
          summary: task.summary,
          nextAction: task.next_action,
          waitingOn: task.waiting_on,
          eventCount: eventCount(task.id),
        })),
      });
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

    if (name === "agent_os_update_task") {
      const taskId = assertTaskId(args.taskId);
      taskFile(taskId, "task.json");
      if (args.waitingOn && args.clearWaiting) {
        throw new Error("waitingOn and clearWaiting are mutually exclusive");
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
