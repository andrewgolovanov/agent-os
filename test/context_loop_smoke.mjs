import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const sourceRoot = path.resolve(import.meta.dirname, "..");
const scriptsDirectory = path.join(
  sourceRoot,
  "plugins",
  "agent-os",
  "skills",
  "context-loop",
  "scripts",
);
const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "agent-os-context-loop-"));

function run(script, args = [], options = {}) {
  return execFileSync(process.execPath, [path.join(scriptsDirectory, script), ...args], {
    cwd: temporaryRoot,
    encoding: "utf8",
    ...options,
  });
}

try {
  run("init.mjs", [
    "--root", temporaryRoot,
    "--slug", "ship-feature",
    "--goal", "Ship a verified feature",
    "--next", "Create the execution plan",
    "--cycle-limit", "2",
  ]);
  run("add-task.mjs", ["--root", temporaryRoot, "--title", "Implement feature", "--acceptance", "Feature behavior exists"]);
  run("add-task.mjs", ["--root", temporaryRoot, "--title", "Verify feature", "--acceptance", "Automated verification passes"]);
  run("set-task.mjs", ["--root", temporaryRoot, "--id", "T001", "--status", "in_progress"]);
  run("checkpoint.mjs", [
    "--root", temporaryRoot,
    "--summary", "Feature implemented",
    "--next", "Verify the behavior",
    "--task-id", "T001",
    "--task-status", "done",
    "--evidence", "implementation inspected",
  ]);
  run("set-task.mjs", ["--root", temporaryRoot, "--id", "T002", "--status", "in_progress"]);
  run("checkpoint.mjs", [
    "--root", temporaryRoot,
    "--summary", "Feature verified",
    "--next", "Complete the durable task",
    "--task-id", "T002",
    "--task-status", "done",
    "--evidence", "smoke test passed",
    "--decision", "Keep repository-backed state",
  ]);

  const status = JSON.parse(run("status.mjs", ["--root", temporaryRoot, "--json"]));
  assert.equal(status.state.current_task, null);
  assert.deepEqual(status.plan.tasks.map((task) => task.status), ["done", "done"]);
  run("complete.mjs", ["--root", temporaryRoot, "--summary", "Feature shipped", "--evidence", "all smoke checks passed"]);

  fs.mkdirSync(path.join(temporaryRoot, ".codex"), { recursive: true });
  fs.writeFileSync(path.join(temporaryRoot, ".codex", "hooks.json"), JSON.stringify({
    hooks: { Stop: [{ hooks: [{ type: "command", command: "echo unrelated" }] }] },
    preserved: true,
  }, null, 2));
  run("install-hooks.mjs", ["--root", temporaryRoot]);
  const installed = JSON.parse(fs.readFileSync(path.join(temporaryRoot, ".codex", "hooks.json"), "utf8"));
  assert.equal(installed.preserved, true);
  assert(installed.hooks.Stop.some((entry) => entry.hooks.some((hook) => hook.command === "echo unrelated")));
  fs.writeFileSync(path.join(temporaryRoot, ".codex", "config.toml"), "[features]\nhooks = true\n");
  const doctor = JSON.parse(run("doctor.mjs", ["--root", temporaryRoot, "--json"]));
  assert.equal(doctor.ready, true);

  process.stdout.write("Context Loop smoke test passed.\n");
} finally {
  fs.rmSync(temporaryRoot, { recursive: true, force: true });
}
