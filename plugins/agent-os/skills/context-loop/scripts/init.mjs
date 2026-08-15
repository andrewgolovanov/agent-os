#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import {
  LOOP_DIR,
  SCHEMA_VERSION,
  activateWorkspace,
  asBoolean,
  asPositiveInteger,
  atomicWrite,
  defaultSlug,
  fail,
  nowIso,
  parseArgs,
  renderPlan,
  renderState,
  requireString,
  resolveProjectRoot,
  slugify,
  titleFromSlug,
  writeJson,
} from "./lib/common.mjs";

try {
  const args = parseArgs();
  const goal = requireString(args, "goal");
  const projectRoot = resolveProjectRoot(args, { allowMissing: true });
  const rawSlug = typeof args.slug === "string" ? args.slug : slugify(goal) || defaultSlug();
  const slug = slugify(rawSlug);
  if (!slug || slug !== rawSlug) throw new Error("--slug must use lowercase English letters, digits, and hyphens only.");
  const taskDir = path.join(projectRoot, LOOP_DIR, "tasks", slug);
  if (fs.existsSync(taskDir)) throw new Error(`Task already exists: ${slug}`);

  const createdAt = nowIso();
  const workspace = {
    projectRoot,
    slug,
    taskDir,
    runtimeDir: path.join(taskDir, ".runtime"),
  };
  fs.mkdirSync(path.join(workspace.runtimeDir, "sessions"), { recursive: true });

  workspace.state = {
    schema_version: SCHEMA_VERSION,
    slug,
    title: typeof args.title === "string" ? args.title.trim() : titleFromSlug(slug),
    goal,
    status: "active",
    current_task: null,
    next_action: typeof args.next === "string" ? args.next.trim() : "Inspect the project and define the plan.",
    latest_summary: "Task initialized. No implementation checkpoint yet.",
    blockers: [],
    auto_continue: asBoolean(args["auto-continue"], true),
    cycle_limit: asPositiveInteger(args["cycle-limit"], 20),
    stop_cycles: {},
    checkpoints: 0,
    created_at: createdAt,
    updated_at: createdAt,
    last_checkpoint_at: null,
    pause_reason: null,
    completion: null,
  };
  workspace.plan = {
    schema_version: SCHEMA_VERSION,
    slug,
    tasks: [],
    created_at: createdAt,
    updated_at: createdAt,
  };
  workspace.statePath = path.join(workspace.runtimeDir, "state.json");
  workspace.planPath = path.join(workspace.runtimeDir, "plan.json");

  writeJson(workspace.statePath, workspace.state);
  writeJson(workspace.planPath, workspace.plan);
  renderState(workspace);
  renderPlan(workspace);
  atomicWrite(path.join(taskDir, "log.md"), `# Execution Log\n\nTask created at ${createdAt}.\n`);
  atomicWrite(path.join(taskDir, "decisions.md"), "# Decisions\n\nRecord durable choices and rationale here through checkpoint commands.\n");
  const loopGitignore = path.join(projectRoot, LOOP_DIR, ".gitignore");
  if (!fs.existsSync(loopGitignore)) {
    atomicWrite(loopGitignore, "tasks/*/.runtime/sessions/\n");
  }
  activateWorkspace(workspace);

  process.stdout.write(`Context Loop task created.\n\nSlug: ${slug}\nFolder: ${path.relative(projectRoot, taskDir)}\nGoal: ${goal}\n`);
} catch (error) {
  fail(error);
}
