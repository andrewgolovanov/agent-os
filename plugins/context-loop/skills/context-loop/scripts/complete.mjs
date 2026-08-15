#!/usr/bin/env node
import { appendEvent, appendLog, asList, fail, loadWorkspace, nowIso, parseArgs, requireString, resolveProjectRoot, saveWorkspace } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  const incomplete = workspace.plan.tasks.filter((task) => task.status !== "done");
  if (incomplete.length && !args.force) {
    throw new Error(`Cannot complete: ${incomplete.map((task) => task.id).join(", ")} are not done. Use --force only with explicit user approval.`);
  }
  const summary = requireString(args, "summary");
  const evidence = asList(args.evidence);
  if (!evidence.length) throw new Error("Completion requires at least one --evidence value.");
  const completedAt = nowIso();
  workspace.state.status = "completed";
  workspace.state.auto_continue = false;
  workspace.state.current_task = null;
  workspace.state.next_action = "None — task completed.";
  workspace.state.latest_summary = summary;
  workspace.state.last_checkpoint_at = completedAt;
  workspace.state.completion = { at: completedAt, summary, evidence };
  appendLog(workspace, "Completed", [`- Summary: ${summary}`, `- Evidence: ${evidence.join("; ")}`]);
  appendEvent(workspace, { type: "completed", summary, evidence });
  saveWorkspace(workspace);
  process.stdout.write(`Completed ${workspace.slug}.\n`);
} catch (error) {
  fail(error);
}
