#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { appendEvent, appendLine, appendLog, findLoopRoot, loadWorkspace, saveWorkspace } from "./lib/common.mjs";

const scriptsDir = path.dirname(fileURLToPath(import.meta.url));

function readPayload() {
  const input = fs.readFileSync(0, "utf8").trim();
  return input ? JSON.parse(input) : {};
}

function bounded(value, limit) {
  const text = String(value ?? "");
  return text.length > limit ? `${text.slice(0, limit)}\n[truncated]` : text;
}

function inline(value, limit = 500) {
  return bounded(value, limit).replace(/\s+/gu, " ").trim();
}

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

try {
  const payload = readPayload();
  const eventName = payload.hook_event_name || payload.hookEventName || payload.event_name;
  const start = typeof payload.cwd === "string" ? payload.cwd : process.cwd();
  const projectRoot = findLoopRoot(start);
  if (!projectRoot || !eventName) process.exit(0);

  const workspace = loadWorkspace(projectRoot);
  const state = workspace.state;
  if (state.status !== "active") process.exit(0);

  const sessionId = typeof payload.session_id === "string" && payload.session_id ? payload.session_id : "unknown";
  const event = {
    type: "hook",
    event: eventName,
    session_id: sessionId,
    turn_id: payload.turn_id ?? null,
  };
  appendEvent(workspace, event);

  const sessionRecord = {
    at: new Date().toISOString(),
    event: eventName,
    turn_id: payload.turn_id ?? null,
    prompt: eventName === "UserPromptSubmit" ? bounded(payload.prompt, 4000) : undefined,
    last_assistant_message: eventName === "Stop" ? bounded(payload.last_assistant_message, 12000) : undefined,
  };
  appendLine(path.join(workspace.runtimeDir, "sessions", `${sessionId.replace(/[^a-zA-Z0-9._-]/gu, "_")}.jsonl`), JSON.stringify(sessionRecord));

  if (eventName === "SessionStart" || eventName === "UserPromptSubmit") {
    const current = state.current_task ?? "none";
    const context = `[context-loop] active=${workspace.slug} status=active goal="${inline(state.goal)}" current=${current} next="${inline(state.next_action)}". Run node ${JSON.stringify(path.join(scriptsDir, "status.mjs"))} --json before substantial work; checkpoint new intent and verified progress.`;
    emit({
      hookSpecificOutput: {
        hookEventName: eventName,
        additionalContext: context,
      },
    });
    process.exit(0);
  }

  if (eventName !== "Stop" || !state.auto_continue) process.exit(0);

  const cycles = Number(state.stop_cycles?.[sessionId] ?? 0) + 1;
  state.stop_cycles = { ...(state.stop_cycles ?? {}), [sessionId]: cycles };
  if (cycles > Number(state.cycle_limit ?? 20)) {
    state.status = "paused";
    state.auto_continue = false;
    state.pause_reason = `Automatic continuation reached the ${state.cycle_limit ?? 20}-cycle safety limit.`;
    appendLog(workspace, "Safety pause", [`- Reason: ${state.pause_reason}`, `- Next: ${state.next_action}`]);
    saveWorkspace(workspace);
    process.exit(0);
  }

  saveWorkspace(workspace);
  const reason = `[context-loop] Continue task ${workspace.slug} in this same thread (cycle ${cycles}/${state.cycle_limit}). First run: node ${JSON.stringify(path.join(scriptsDir, "status.mjs"))} --json. Work on the stored next action or next pending plan item, verify the slice, and checkpoint it with checkpoint.mjs before stopping. If the whole goal is verified, run complete.mjs. If user input or an external change is truly required, run pause.mjs with the blocker. Do not claim completion without evidence.`;
  emit({ decision: "block", reason });
} catch {
  // Hooks must fail open so an invalid or stale workspace cannot trap the host session.
  process.exit(0);
}
