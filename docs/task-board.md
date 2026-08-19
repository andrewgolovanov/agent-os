# Task Board

Task Board connects one real outcome to any number of external threads, Codex tasks, PRs, designs, and deployment sources. Its files live only under private `AGENT_OS_HOME`; the product checkout contains implementation and this contract, never user task data.

An outcome may also carry display-only labels. A Slack channel label groups non-code work without pretending that the channel is a registered project or repository routing target. When a reviewed stable channel ID is mapped to a project, the label remains visible on cards while the app omits it from the separate top-level Labels section.

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
  --value "https://slack.example/thread/ROOT_ID" \
  --title "Please verify the client launch checklist"

tools/task-board label TASK_ID \
  --key "slack:C123" \
  --name "#client-checks" \
  --kind slack_channel

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

Slack channel labels use stable `slack:<channel_id>` keys and the current human-readable `#channel-name`. Reprocessing the same key is idempotent; a channel rename refreshes the display name. Labels never authorize project routing, repository access, Codex task creation, or source correlation. A separately reviewed `projects.yaml` channel mapping can attribute unfinished unassigned outcomes during preview-first onboarding, but it does not remove their labels or overwrite existing project attribution. Direct messages remain unlabelled unless a separate non-personal work label is explicitly available; participant names are not persisted as labels.

A Slack source may carry one optional display title derived from its root message. Task Board removes Slack link and formatting markup, collapses whitespace, and limits the result to 96 characters. Reprocessing the same exact source may refresh that title without changing `added_at` or source identity. The title is private presentation metadata, not a transcript, correlation key, project label, or routing signal. Existing sources without a title remain valid and the native app falls back to `Slack thread`.

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
- Codex membership -> exact `thread_id` and `codex://threads/<id>`; one
  `active` or `idle` membership is current, while archived memberships preserve
  prior outcome history.

Only exact identity permits verified continuity. Semantic similarity, including a matching source title, never authorizes automatic merging. One canonical GitHub PR cannot belong to two outcomes.

Labels are presentation and filtering metadata, not identity. Two similarly named channels remain distinct because their label keys contain different channel IDs, while Slack source correlation continues to use the exact thread identity. Channel-name normalization may suggest a project mapping during onboarding, but only an exact reviewed channel ID can be stored or applied.

## Codex membership and routing

Independent Codex tasks are peer memberships; an outcome has no required primary task. Subagent threads are not registered.

When no suitable registered project task or Codex thread exists, Task Board stores `routing_pending`. This is separate from Slack event processing: the Slack event is not replayed, while routing may be retried safely.

In a registered project task, [Task Bridge](task-bridge.md) may create membership only for one exact task or source match. The project path limits candidates but never chooses the outcome. With only semantic similarity, the agent must explicitly `claim` a candidate or create a new coherent outcome.

If the user explicitly switches an already linked Codex task to another exact
outcome, Task Bridge uses `reassign`: the previous membership becomes
`archived`, the target becomes the only current membership, and the open turn
moves to the target without moving any completed activity. Referencing another
outcome does not trigger this mutation automatically.

## Activity evidence

Outcome time is counted only after exact Codex `thread_id` membership. The installed Agent OS Task Bridge hooks call `tools/codex-activity-hook`: `UserPromptSubmit` performs safe correlation or claim and opens an exact `turn_id`; material `PostToolUse` requires a checkpoint; `Stop` closes the turn and changes membership from `active` to `idle`. Repeated delivery is idempotent.

The same Codex `thread_id` may appear as archived history on multiple outcomes,
but validation permits only one current `active` or `idle` membership. An
explicit reassignment can move an unfinished turn because it has not contributed
duration yet; completed turns and totals never move automatically.

This is Codex execution time, not human time tracking and not a copy of the UI “Working for…” label. Time between turns is excluded. An exact `Stop` wins; a crash-orphaned turn is capped by the configured idle timeout. Chats outside registered project paths are ignored.

After hook changes, inspect and trust them through `/hooks`, then start a fresh Codex task because an already-open task does not receive new hook configuration. See [Task Bridge](task-bridge.md) for the exact flow.

Task Board activity intentionally excludes unlinked project tasks. [Project Time](project-time.md) generates the all-thread project total. Do not add these metrics because linked turns appear in both.

The native app hides `done` and `cancelled` outcomes from the working Board but keeps completed outcomes in Done. Done opens the same canonical inspector with sources, PR context, Codex memberships, activity evidence, and follow-up status. Deleting or archiving a Codex task never deletes its outcome; cleanup of durable completed outcomes must be a separate explicit user action.
