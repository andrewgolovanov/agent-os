#!/usr/bin/env node
import path from "node:path";
import { fail, loadWorkspace, parseArgs, renderPlan, renderState, resolveProjectRoot } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  renderState(workspace);
  renderPlan(workspace);
  const result = {
    slug: workspace.slug,
    folder: path.relative(projectRoot, workspace.taskDir),
    state: workspace.state,
    plan: workspace.plan,
  };
  if (args.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    const done = workspace.plan.tasks.filter((task) => task.status === "done").length;
    process.stdout.write(`Task: ${workspace.state.title} (${workspace.slug})\nStatus: ${workspace.state.status}\nProgress: ${done}/${workspace.plan.tasks.length}\nCurrent: ${workspace.state.current_task ?? "none"}\nNext: ${workspace.state.next_action}\nFolder: ${result.folder}\n`);
  }
} catch (error) {
  fail(error);
}
