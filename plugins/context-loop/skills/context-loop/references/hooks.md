# Hooks

Context Loop uses project-local Codex hooks for three events:

- `SessionStart`: inject a compact pointer to the active task.
- `UserPromptSubmit`: inject the goal, current task, and next action so new intent is reconciled with durable state.
- `Stop`: save a bounded final assistant message and continue the same thread while the task is active.

`install-hooks.mjs` preserves unrelated JSON and hook entries, refuses invalid JSON, replaces stale Context Loop commands, and supports `--dry-run`. It writes only `.codex/hooks.json` in the target project.

Codex must load the hooks feature in its active configuration and command hooks must be reviewed and trusted. Use `/hooks` in Codex to review them. A hook installed after a thread started may require a fresh thread.

The Stop hook is bounded by `cycle_limit` (default 20). Reaching the limit changes the task to `paused` and disables continuation. Resume explicitly to reset the counter.

Hooks are a convenience, not the source of truth. Manual checkpoints and disk-backed state remain usable when hooks are unavailable.
