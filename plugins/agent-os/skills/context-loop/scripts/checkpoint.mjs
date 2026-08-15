#!/usr/bin/env node
import {
  appendDecision,
  appendEvent,
  appendLog,
  asList,
  fail,
  loadWorkspace,
  nowIso,
  parseArgs,
  requireString,
  resolveProjectRoot,
  saveWorkspace,
  setTaskStatus,
} from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  const summary = requireString(args, "summary");
  const nextAction = requireString(args, "next");
  const evidence = asList(args.evidence);
  const blockers = asList(args.blocker);
  const checkpointAt = nowIso();

  if (args["clear-blockers"]) workspace.state.blockers = [];
  if (blockers.length) workspace.state.blockers = [...new Set([...(workspace.state.blockers ?? []), ...blockers])];
  if (typeof args["task-id"] === "string" || typeof args["task-status"] === "string") {
    if (typeof args["task-id"] !== "string" || typeof args["task-status"] !== "string") {
      throw new Error("Use --task-id and --task-status together.");
    }
    setTaskStatus(workspace, args["task-id"], args["task-status"], {
      evidence,
      blocker: blockers[0],
    });
  }

  workspace.state.latest_summary = summary;
  workspace.state.next_action = nextAction;
  workspace.state.last_checkpoint_at = checkpointAt;
  workspace.state.checkpoints += 1;
  if (workspace.state.status !== "completed") workspace.state.status = blockers.length ? "paused" : "active";
  if (blockers.length) {
    workspace.state.pause_reason = blockers.join("; ");
    workspace.state.auto_continue = false;
  }
  if (typeof args.decision === "string") appendDecision(workspace, args.decision);

  appendLog(workspace, `Checkpoint ${workspace.state.checkpoints}`, [
    `- Summary: ${summary}`,
    `- Next: ${nextAction}`,
    ...(evidence.length ? [`- Evidence: ${evidence.join("; ")}`] : []),
    ...(blockers.length ? [`- Blockers: ${blockers.join("; ")}`] : []),
  ]);
  appendEvent(workspace, { type: "checkpoint", summary, next_action: nextAction });
  saveWorkspace(workspace);
  process.stdout.write(`Checkpoint ${workspace.state.checkpoints} saved for ${workspace.slug}.\n`);
} catch (error) {
  fail(error);
}
