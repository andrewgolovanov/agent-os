#!/usr/bin/env node
import { appendEvent, appendLog, fail, loadWorkspace, nowIso, parseArgs, requireString, resolveProjectRoot, saveWorkspace } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  const reason = requireString(args, "reason");
  workspace.state.status = "paused";
  workspace.state.auto_continue = false;
  workspace.state.pause_reason = reason;
  workspace.state.last_checkpoint_at = nowIso();
  appendLog(workspace, "Paused", [`- Reason: ${reason}`, `- Next: ${workspace.state.next_action}`]);
  appendEvent(workspace, { type: "paused", reason });
  saveWorkspace(workspace);
  process.stdout.write(`Paused ${workspace.slug}: ${reason}\n`);
} catch (error) {
  fail(error);
}
