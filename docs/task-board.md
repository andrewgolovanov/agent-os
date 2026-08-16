# Task Board

Task Board connects one real outcome to any number of external threads, Codex tasks, PRs, designs, and deployment sources. Its files live only under private `AGENT_OS_HOME`; the product checkout contains implementation and this contract, never user task data.

## Storage

```text
AGENT_OS_HOME/work/
├── BOARD.md
├── board.json
└── items/<task-id>/
    ├── task.json
    ├── STATUS.md
    └── events.jsonl
```

- `BOARD.md` is the generated human-readable dashboard.
- `task.json` is the canonical structured snapshot.
- `STATUS.md` is the generated human-readable handoff.
- `events.jsonl` is append-only material history.
- `board.json` is the atomically rebuilt compact index.

`BOARD.md` shows unfinished totals, lifecycle sections, current summary, next action, blocker, linked Codex state, and accumulated time. Every Task Board write, including activity hooks, regenerates it. While a turn runs, the dashboard shows an active-turn count; final duration is added after `Stop`.

All structured writes go through `tools/task-board`. File locking and atomic replacement prevent concurrent writers from corrupting the index.

## When to create an outcome

Create an outcome before the first meaningful mutation, multi-step investigation, review, release, deployment, or explicit request to continue later. Do not create one for a short explanation, FYI, or one-time lookup with no next action.

One outcome represents one coherent result. Multiple Slack roots or Codex tasks do not require separate outcomes.

## Commands

```bash
tools/task-board list
tools/task-board summary
tools/task-board show TASK_ID
tools/task-board find --source URL_OR_ID

tools/task-board create \
  --title "Outcome-oriented title" \
  --project example-site \
  --kind delivery \
  --goal "Stable desired result" \
  --next-action "One concrete next step"

tools/task-board source TASK_ID \
  --kind slack_threads \
  --value "https://slack.example/thread/ROOT_ID"

tools/task-board codex TASK_ID \
  --thread-id THREAD_ID \
  --role implementation \
  --origin new

tools/task-board activity-start TASK_ID \
  --session-id THREAD_ID \
  --turn-id TURN_ID

tools/task-board activity-stop TASK_ID \
  --session-id THREAD_ID \
  --turn-id TURN_ID

tools/task-board routing-update TASK_ID \
  --route-id ROUTE_ID \
  --state routed \
  --attempt \
  --codex-thread-id THREAD_ID

tools/task-board completion TASK_ID \
  --follow-up-status pending|sent|not_required

tools/task-board validate
```

Tests use `--root PATH` or `AGENT_OS_TASK_ROOT` to isolate private state.

`tools/task-board summary` includes every unfinished outcome: `inbox`, `planned`, `active`, `waiting`, and `review`. It excludes `done` and `cancelled`. The same summary is stored in private `AGENT_OS_HOME/work/board.json`; `--project KEY` limits it to one project.

`--project` may be omitted for a new Slack or DM signal whose owner is unknown. The outcome stays unassigned in `inbox` until attribution is verified, and no route is created for it.

## Natural-language lifecycle control

Users do not need to invoke the CLI manually. In a Codex task, identify the outcome or ID and state what changed:

- “Pause legal work until tomorrow” leaves lifecycle `active`; `Stop` changes only Codex membership to `idle` and stops its timer.
- “Wait for Dana's final cookie copy” sets `waiting` and records the reason in `waiting_on`.
- “Resume legal; the answer arrived” returns the outcome to `active` and clears `waiting_on`.
- “Privacy and Terms are implemented; next verify mobile” updates `summary` and `next_action` without completing the outcome.
- “Legal is ready for my review” sets `review`.
- “Legal is accepted and checks passed; close it” sets `done`.
- “Cancel the slider outcome; it is no longer needed” sets `cancelled`.

Use `waiting` only for a real external dependency. A break, end of day, or absence of a running Codex turn is not a blocker and does not change an `active` outcome. `done` means a verified or explicitly accepted final result, not the end of one agent response.

Moving to `done` records `completion.completed_at`. If the outcome has a Slack source, `completion.follow_up_status` starts as `pending`; without Slack it starts as `not_required`. Follow-up is not lifecycle state: sending a message does not reopen the outcome, and `done` does not claim the message was sent. After a manual reply use `completion ... sent`; when no reply is needed use `not_required`. This contract does not authorize automatic external writes.

## Identity and correlation

Correlation starts with stable external identity:

- Slack permalink -> `slack:<channel_id>:<root_ts>`;
- GitHub PR -> `github:<owner>/<repo>#<number>`;
- Figma file -> `figma:<file_key>`;
- Codex membership -> exact `thread_id` and `codex://threads/<id>`.

Only exact identity permits verified continuity. Semantic similarity alone never authorizes automatic merging. One canonical GitHub PR cannot belong to two outcomes.

## Codex membership and routing

Independent Codex tasks are peer memberships; an outcome has no required primary task. Subagent threads are not registered.

When no suitable registered project task or Codex thread exists, Task Board stores `routing_pending`. This is separate from Slack event processing: the Slack event is not replayed, while routing may be retried safely.

In a registered project task, [Task Bridge](task-bridge.md) may create membership only for one exact task or source match. The project path limits candidates but never chooses the outcome. With only semantic similarity, the agent must explicitly `claim` a candidate or create a new coherent outcome.

## Activity evidence

Outcome time is counted only after exact Codex `thread_id` membership. The installed Agent OS Task Bridge hooks call `tools/codex-activity-hook`: `UserPromptSubmit` performs safe correlation or claim and opens an exact `turn_id`; material `PostToolUse` requires a checkpoint; `Stop` closes the turn and changes membership from `active` to `idle`. Repeated delivery is idempotent.

This is Codex execution time, not human time tracking and not a copy of the UI “Working for…” label. Time between turns is excluded. An exact `Stop` wins; a crash-orphaned turn is capped by the configured idle timeout. Chats outside registered project paths are ignored.

After hook changes, inspect and trust them through `/hooks`, then start a fresh Codex task because an already-open task does not receive new hook configuration. See [Task Bridge](task-bridge.md) for the exact flow.

Task Board activity intentionally excludes unlinked project tasks. [Project Time](project-time.md) generates the all-thread project total. Do not add these metrics because linked turns appear in both.

The native app hides `done` and `cancelled` outcomes from the working Board but keeps completed outcomes in Done. Done opens the same canonical inspector with sources, PR context, Codex memberships, activity evidence, and follow-up status. Deleting or archiving a Codex task never deletes its outcome; cleanup of durable completed outcomes must be a separate explicit user action.
