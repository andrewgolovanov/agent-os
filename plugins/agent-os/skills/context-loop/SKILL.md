---
name: context-loop
description: Keep a long-running Codex task coherent in one thread and resumable across sessions by storing its goal, plan, current state, decisions, evidence, blockers, and next action under `.context-loop/`. Use when the user invokes `$context-loop`, asks Codex to keep working autonomously on a multi-step task, wants context preserved through compaction or restarts, asks to resume a durable task, or when hook context contains `[context-loop]`.
---

# Context Loop

Persist task context in the target repository instead of relying on chat history. Work on only one active Context Loop task at a time, checkpoint after every meaningful slice, and finish only from verified evidence.

Replace `<skill-dir>` in commands with the absolute directory containing this file.

## Route the request

- **Start**: the user provides a new goal or asks for a durable/autonomous task.
- **Status**: the user asks what is active, done, blocked, or next.
- **Resume**: the user asks to continue the active task or names an existing slug.
- **Pause**: the user asks to stop, wait, detach, or work outside the loop.
- **Complete**: acceptance criteria are satisfied and verified.

For any non-trivial Context Loop turn, orient from disk before acting:

```bash
node <skill-dir>/scripts/status.mjs --json
```

Read project instructions such as `AGENTS.md` after orientation. Do not treat the stored plan as permission to ignore newer user instructions. Capture changed intent in a checkpoint immediately.

## Check setup

Before the first start or resume in a project, run:

```bash
node <skill-dir>/scripts/doctor.mjs --json
```

Hooks are optional for manual checkpointing and required for automatic same-thread continuation. If hook setup is missing, ask one short question before changing project config:

```text
Context Loop needs project-local Codex hooks for automatic continuation. Install them now?
```

After approval, preview and install:

```bash
node <skill-dir>/scripts/install-hooks.mjs --dry-run
node <skill-dir>/scripts/install-hooks.mjs
```

Do not edit global Codex config. Tell the user to enable the active Codex hooks feature or review hooks with `/hooks` only when `doctor` reports that requirement. A static check cannot prove that the current thread loaded and trusted newly installed hooks; start a fresh thread after setup when automatic continuation does not activate.

Read [references/hooks.md](references/hooks.md) only when installing, repairing, or debugging hooks.

## Start a task

Initialize from the user's concrete goal. Generate a short English slug, even when the request is in another language:

```bash
node <skill-dir>/scripts/init.mjs \
  --slug "<short-english-slug>" \
  --goal "<user goal>" \
  --next "Inspect the repository and define an evidence-based plan"
```

Inspect the repository before decomposing implementation. Add a small ordered plan with observable acceptance criteria:

```bash
node <skill-dir>/scripts/add-task.mjs --title "<task>" --acceptance "<observable result>"
node <skill-dir>/scripts/set-task.mjs --id T001 --status in_progress
```

Do not ask the user to design the whole plan. Ask only questions whose answers materially change the implementation and cannot be discovered safely.

## Work loop

Repeat until completed or genuinely blocked:

1. Read current status and the relevant repository evidence.
2. Select one bounded task and mark it `in_progress`.
3. Implement within the user's scope.
4. Verify in proportion to risk.
5. Checkpoint the outcome, evidence, next action, and any decision or blocker.
6. Mark the task `done` only when its acceptance criterion is supported by evidence.

Use one deterministic checkpoint command rather than hand-editing generated state:

```bash
node <skill-dir>/scripts/checkpoint.mjs \
  --summary "<what changed and why>" \
  --next "<single next action>" \
  --task-id T001 \
  --task-status done \
  --evidence "<test, command, or inspected artifact>"
```

Optional checkpoint fields are `--decision`, `--blocker`, and `--clear-blockers`.

Checkpoint after meaningful progress, before risky operations, after verification, when the user changes direction, and before yielding. Do not log secrets, raw credentials, or large tool outputs. Keep `state.md` compact; use `log.md` for chronology and `decisions.md` for rationale.

If a new request is unrelated to the active task, pause the loop before switching scope. If it extends the task, update the plan and checkpoint the changed intent.

Read [references/state-model.md](references/state-model.md) when repairing state or resolving a conflict between artifacts.

## Pause, resume, and complete

Pause instead of pretending progress is possible:

```bash
node <skill-dir>/scripts/pause.mjs --reason "<why work is paused>"
```

Resume the active or named task and reset its continuation budget:

```bash
node <skill-dir>/scripts/resume.mjs
node <skill-dir>/scripts/resume.mjs --slug "<slug>"
```

Completion is evidence-gated. Run completion only after all plan items are done:

```bash
node <skill-dir>/scripts/complete.mjs \
  --summary "<delivered outcome>" \
  --evidence "<final verification>"
```

If incomplete plan items intentionally remain, explain why and use `--force` only with explicit user approval.

## Hook continuation rules

When hook context contains `[context-loop]`, obey its exact task path and re-orient from `status.mjs --json`. A Stop hook may continue the same thread while the task is active and `auto_continue` is enabled.

Before allowing a turn to end, do one of:

- checkpoint and continue the next actionable slice;
- complete the task from verified evidence;
- pause with a concrete blocker or user-requested stop.

The hook cycle limit is a safety boundary, not task completion. When it pauses the loop, report the current state and wait for `$context-loop resume`.
