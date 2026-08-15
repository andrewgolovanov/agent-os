#!/usr/bin/env node
import { activateWorkspace, appendEvent, appendLog, asBoolean, asPositiveInteger, fail, loadWorkspace, parseArgs, resolveProjectRoot, saveWorkspace } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  workspace.state.status = "active";
  workspace.state.auto_continue = asBoolean(args["auto-continue"], true);
  workspace.state.cycle_limit = asPositiveInteger(args["cycle-limit"], workspace.state.cycle_limit || 20);
  workspace.state.stop_cycles = {};
  workspace.state.pause_reason = null;
  workspace.state.completion = null;
  activateWorkspace(workspace);
  appendLog(workspace, "Resumed", [`- Next: ${workspace.state.next_action}`]);
  appendEvent(workspace, { type: "resumed", auto_continue: workspace.state.auto_continue });
  saveWorkspace(workspace);
  process.stdout.write(`Resumed ${workspace.slug}. Next: ${workspace.state.next_action}\n`);
} catch (error) {
  fail(error);
}
