#!/usr/bin/env node
import { asList, fail, loadWorkspace, parseArgs, requireString, resolveProjectRoot, saveWorkspace, setTaskStatus } from "./lib/common.mjs";

try {
  const args = parseArgs();
  const projectRoot = resolveProjectRoot(args);
  const workspace = loadWorkspace(projectRoot, typeof args.slug === "string" ? args.slug : undefined);
  const id = requireString(args, "id");
  const status = requireString(args, "status");
  const task = setTaskStatus(workspace, id, status, {
    evidence: asList(args.evidence),
    blocker: typeof args.blocker === "string" ? args.blocker : undefined,
  });
  saveWorkspace(workspace);
  process.stdout.write(`${task.id} is now ${task.status}.\n`);
} catch (error) {
  fail(error);
}
