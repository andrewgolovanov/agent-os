import fs from "node:fs";
import path from "node:path";

export const SCHEMA_VERSION = 1;
export const LOOP_DIR = ".context-loop";

export function nowIso() {
  return new Date().toISOString();
}

export function parseArgs(argv = process.argv.slice(2)) {
  const args = { _: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      args._.push(token);
      continue;
    }
    const key = token.slice(2);
    const next = argv[index + 1];
    const value = next && !next.startsWith("--") ? argv[++index] : true;
    if (Object.hasOwn(args, key)) {
      args[key] = Array.isArray(args[key]) ? [...args[key], value] : [args[key], value];
    } else {
      args[key] = value;
    }
  }
  return args;
}

export function asList(value) {
  if (value === undefined || value === false) return [];
  return Array.isArray(value) ? value.map(String) : [String(value)];
}

export function requireString(args, key) {
  const value = args[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`Missing required --${key} value.`);
  }
  return value.trim();
}

export function asBoolean(value, fallback = false) {
  if (value === undefined) return fallback;
  if (value === true || value === "true" || value === "1") return true;
  if (value === false || value === "false" || value === "0") return false;
  throw new Error(`Expected a boolean value, received: ${value}`);
}

export function asPositiveInteger(value, fallback) {
  if (value === undefined) return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`Expected a positive integer, received: ${value}`);
  }
  return parsed;
}

export function slugify(value) {
  return String(value)
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]+/gu, "-")
    .replace(/^-+|-+$/gu, "")
    .replace(/-{2,}/gu, "-")
    .slice(0, 48);
}

export function titleFromSlug(slug) {
  return slug.split("-").filter(Boolean).map((part) => part[0].toUpperCase() + part.slice(1)).join(" ");
}

export function defaultSlug() {
  return `task-${nowIso().replace(/[-:TZ.]/gu, "").slice(0, 12)}`;
}

export function atomicWrite(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tempPath, content, "utf8");
  fs.renameSync(tempPath, filePath);
}

export function writeJson(filePath, value) {
  atomicWrite(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

export function readJson(filePath, fallback = undefined) {
  if (!fs.existsSync(filePath)) return fallback;
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

export function appendLine(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.appendFileSync(filePath, `${value}\n`, "utf8");
}

export function findLoopRoot(start = process.cwd()) {
  let current = path.resolve(start);
  while (true) {
    if (fs.existsSync(path.join(current, LOOP_DIR))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

export function resolveProjectRoot(args = {}, { allowMissing = false, start } = {}) {
  if (typeof args.root === "string") return path.resolve(args.root);
  const found = findLoopRoot(start ?? process.cwd());
  if (found) return found;
  if (allowMissing) return path.resolve(start ?? process.cwd());
  throw new Error(`No ${LOOP_DIR} workspace found. Run init.mjs from the project root.`);
}

export function resolveWorkspace(projectRoot, slug) {
  const requested = slug || readJson(path.join(projectRoot, LOOP_DIR, "active.json"), {})?.active_slug;
  if (!requested) throw new Error("No active Context Loop task. Pass --slug or run init.mjs.");
  const normalized = slugify(requested);
  if (!normalized || normalized !== requested) throw new Error(`Invalid task slug: ${requested}`);
  const taskDir = path.join(projectRoot, LOOP_DIR, "tasks", normalized);
  if (!fs.existsSync(taskDir)) throw new Error(`Context Loop task not found: ${normalized}`);
  return {
    projectRoot,
    slug: normalized,
    taskDir,
    runtimeDir: path.join(taskDir, ".runtime"),
  };
}

export function loadWorkspace(projectRoot, slug) {
  const workspace = resolveWorkspace(projectRoot, slug);
  const statePath = path.join(workspace.runtimeDir, "state.json");
  const planPath = path.join(workspace.runtimeDir, "plan.json");
  const state = readJson(statePath);
  const plan = readJson(planPath);
  if (!state || !plan) throw new Error(`Task ${workspace.slug} has incomplete runtime state.`);
  return { ...workspace, statePath, planPath, state, plan };
}

export function activateWorkspace(workspace) {
  writeJson(path.join(workspace.projectRoot, LOOP_DIR, "active.json"), {
    schema_version: SCHEMA_VERSION,
    active_slug: workspace.slug,
    updated_at: nowIso(),
  });
}

function cleanInline(value) {
  return String(value ?? "").replace(/\s+/gu, " ").trim();
}

export function renderState(workspace, state = workspace.state) {
  const blockers = state.blockers?.length ? state.blockers.map((item) => `- ${cleanInline(item)}`).join("\n") : "- None";
  const content = `# Task State: ${cleanInline(state.title)}

- **Slug:** \`${state.slug}\`
- **Status:** ${state.status}
- **Goal:** ${cleanInline(state.goal)}
- **Current task:** ${state.current_task ?? "None"}
- **Next action:** ${cleanInline(state.next_action) || "None"}
- **Last checkpoint:** ${state.last_checkpoint_at ?? "None"}
- **Automatic continuation:** ${state.auto_continue ? "enabled" : "disabled"}

## Latest summary

${state.latest_summary?.trim() || "No checkpoint yet."}

## Blockers

${blockers}
`;
  atomicWrite(path.join(workspace.taskDir, "state.md"), content);
}

export function renderPlan(workspace, plan = workspace.plan) {
  const lines = ["# Plan", "", `Updated: ${plan.updated_at}`, ""];
  if (plan.tasks.length === 0) {
    lines.push("No tasks yet.", "");
  } else {
    for (const task of plan.tasks) {
      const mark = task.status === "done" ? "x" : " ";
      lines.push(`- [${mark}] **${task.id}** [${task.status}] ${cleanInline(task.title)}`);
      lines.push(`  - Acceptance: ${cleanInline(task.acceptance)}`);
      if (task.evidence?.length) lines.push(`  - Evidence: ${task.evidence.map(cleanInline).join("; ")}`);
      if (task.blocker) lines.push(`  - Blocker: ${cleanInline(task.blocker)}`);
    }
    lines.push("");
  }
  atomicWrite(path.join(workspace.taskDir, "plan.md"), `${lines.join("\n")}\n`);
}

export function saveWorkspace(workspace) {
  workspace.state.updated_at = nowIso();
  workspace.plan.updated_at = workspace.state.updated_at;
  writeJson(workspace.statePath, workspace.state);
  writeJson(workspace.planPath, workspace.plan);
  renderState(workspace);
  renderPlan(workspace);
}

export function appendEvent(workspace, event) {
  appendLine(path.join(workspace.runtimeDir, "events.jsonl"), JSON.stringify({ at: nowIso(), ...event }));
}

export function appendLog(workspace, heading, bodyLines = []) {
  const lines = [`\n## ${nowIso()} — ${heading}`, "", ...bodyLines.map((line) => String(line)), ""];
  fs.appendFileSync(path.join(workspace.taskDir, "log.md"), lines.join("\n"), "utf8");
}

export function appendDecision(workspace, decision) {
  const lines = [`\n## ${nowIso()}`, "", String(decision).trim(), ""];
  fs.appendFileSync(path.join(workspace.taskDir, "decisions.md"), lines.join("\n"), "utf8");
}

export function selectTask(workspace, id) {
  const task = workspace.plan.tasks.find((item) => item.id === id);
  if (!task) throw new Error(`Unknown task id: ${id}`);
  return task;
}

export function setTaskStatus(workspace, id, status, { evidence = [], blocker } = {}) {
  const allowed = new Set(["pending", "in_progress", "done", "blocked"]);
  if (!allowed.has(status)) throw new Error(`Invalid task status: ${status}`);
  const task = selectTask(workspace, id);
  if (status === "in_progress") {
    for (const item of workspace.plan.tasks) {
      if (item.id !== id && item.status === "in_progress") item.status = "pending";
    }
  }
  task.status = status;
  task.updated_at = nowIso();
  if (evidence.length) task.evidence = [...(task.evidence ?? []), ...evidence];
  if (blocker !== undefined) task.blocker = blocker || null;
  workspace.state.current_task = status === "in_progress" ? id : workspace.state.current_task === id ? null : workspace.state.current_task;
  return task;
}

export function fail(error) {
  process.stderr.write(`context-loop: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
