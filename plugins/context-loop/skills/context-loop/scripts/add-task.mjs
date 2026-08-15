#!/usr/bin/env node
import { fail, loadWorkspace, nowIso, parseArgs, requireString, resolveProjectRoot, saveWorkspace } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  if (workspace.state.status === "completed") throw new Error("Cannot add tasks to a completed task. Resume it first if reopening is intentional.");
  const nextNumber = workspace.plan.tasks.reduce((max, task) => Math.max(max, Number(task.id.slice(1)) || 0), 0) + 1;
  const task = {
    id: `T${String(nextNumber).padStart(3, "0")}`,
    title: requireString(args, "title"),
    acceptance: requireString(args, "acceptance"),
    status: "pending",
    evidence: [],
    blocker: null,
    created_at: nowIso(),
    updated_at: nowIso(),
  };
  workspace.plan.tasks.push(task);
  saveWorkspace(workspace);
  process.stdout.write(`Added ${task.id}: ${task.title}\n`);
} catch (error) {
  fail(error);
}
