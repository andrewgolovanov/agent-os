# State Model

Context Loop stores one project-level active pointer and any number of task workspaces:

```text
.context-loop/
  active.json
  tasks/<slug>/
    state.md
    plan.md
    decisions.md
    log.md
    .runtime/
      state.json
      plan.json
      events.jsonl
      sessions/<session-id>.jsonl
```

## Authority

- `.runtime/state.json` is authoritative for lifecycle status, next action, blockers, and continuation settings.
- `.runtime/plan.json` is authoritative for task ids and statuses.
- `state.md` and `plan.md` are deterministic human-readable projections of those JSON files.
- `log.md` and `decisions.md` are append-only evidence and rationale.
- `active.json` selects the task loaded by commands that omit `--slug`.

If generated Markdown conflicts with runtime JSON, rerun any state-changing command or `status.mjs`; do not make JSON match an unverified Markdown edit.

## Lifecycle

Allowed states are `active`, `paused`, and `completed`. Only `active` tasks can be continued by the Stop hook. `pause.mjs` and `complete.mjs` disable automatic continuation before the assistant yields.

Allowed plan states are `pending`, `in_progress`, `done`, and `blocked`. At most one task may be `in_progress`; `set-task.mjs` moves any previous in-progress task back to `pending`.

## Recovery

To recover after compaction or a new session:

1. Run `status.mjs --json`.
2. Read `state.md`, `plan.md`, and only the latest relevant entries in `log.md` and `decisions.md`.
3. Inspect current repository evidence because files may have changed outside the loop.
4. Resume from the stored next action or revise it with a checkpoint.

Never store secrets or full transcripts in the human-facing artifacts. Hook session logs store bounded final assistant messages for diagnostics and must not be treated as the source of truth.
