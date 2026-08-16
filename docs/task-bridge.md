# Task Bridge

Task Bridge connects work in a registered project path to one canonical Task Board outcome. It starts outcome activity with the first exact working turn and persists a verified summary and next action before the response ends.

## Data flow

```text
project Codex task
  -> UserPromptSubmit
  -> project-time start for every registered project task
  -> registered cwd + exact task/source identity
  -> one Task Board membership
  -> activity-start
  -> material-change marker
  -> checkpoint
  -> Stop / activity-stop
  -> project-time stop and monthly rollup
```

The canonical outcome remains only in `AGENT_OS_HOME/work/items/<task-id>/task.json`. Agent OS creates no task copies, configuration, or runtime files in the product repository.

Project-level time is stored separately under `AGENT_OS_HOME/work/reports/project-time/`. It includes exact-linked and unlinked project tasks. Task Bridge state and lifecycle do not depend on this report.

## Automatic correlation

Task Bridge resolves a project by the longest exact registered path in `AGENT_OS_HOME/config/projects.yaml`. Automatic claim is allowed only for one exact match:

- the prompt contains a Task Board ID;
- a Slack permalink matches the canonical channel and root timestamp;
- a GitHub PR matches owner, repository, and number;
- a Figma URL matches exactly or contains the same file key and `node-id`.

Titles and similar text only produce candidates. Semantic similarity never attaches a Codex task automatically. With zero or multiple exact matches, the hook returns instructions and candidates without changing the outcome.

## Lifecycle and time

- The first exact claim attaches `session_id`, moves `inbox`, `planned`, or `review` to `active`, and opens the exact `turn_id`.
- Each later `UserPromptSubmit` in a linked task opens a new turn; repeated events are idempotent.
- `Stop` closes that turn and changes only Codex membership to `idle`. The checkpoint controls whether the outcome remains `active`, `waiting`, or `review`.
- An exact `Stop` timestamp wins. A new turn in the same session closes the previous unfinished turn, and `idle_timeout_minutes` caps it; the default is 30 minutes. Global reconcile runs only when explicitly requested and does not interfere with a parallel active task.
- The system counts Codex execution, not human time between messages.
- `done` and `cancelled` are never automatic; the user confirms them through the normal Task Board flow.

After a material file mutation such as `apply_patch`, `Edit`, or `Write`, `Stop` requires a checkpoint with a verified `summary`, one concrete `next_action`, and `active`, `waiting`, or `review`. This prevents work from disappearing from the Board merely because one response ended.

## Runtime state and privacy

Exact hook state lives in ignored private runtime storage:

```text
AGENT_OS_HOME/.runtime/task-bridge/sessions/<session-id>/turns/<turn-id>.json
```

Runtime state stores IDs, timestamps, candidate IDs, claim reason, material and checkpoint flags, and a SHA-256 prompt digest. It never stores raw prompts, source content, or tool payloads. Durable summary and task state change only through the Task Board API.

## Policy

Private `AGENT_OS_HOME/config/task-bridge.yaml` defines defaults and rare project overrides:

- `enabled`: whether the registered project participates;
- `auto_claim`: `exact_sources` or `disabled`;
- `require_checkpoint`: whether material mutation blocks `Stop` without a checkpoint;
- `max_candidates`: safe candidate-list size;
- `idle_timeout_minutes`: fallback cap for orphaned turns.

## Manual commands

The agent normally invokes these commands from hook context:

```bash
tools/task-bridge claim TASK_ID \
  --session-id SESSION_ID \
  --turn-id TURN_ID

tools/task-bridge checkpoint TASK_ID \
  --session-id SESSION_ID \
  --turn-id TURN_ID \
  --summary "Verified current state" \
  --next-action "One concrete next step" \
  --status review

tools/task-bridge context --session-id SESSION_ID --turn-id TURN_ID
tools/task-bridge reconcile --session-id SESSION_ID
```

If the exact outcome does not exist, create it through `tools/task-board` before `claim`. Import old turns only from exact Codex timestamps; guessed time is prohibited.

A legacy task that sequentially handled several outcomes cannot become durable membership automatically. Attach only proven historical activity, mark its membership `archived`, and continue future work in a fresh project task. Otherwise one old thread ID would permanently mix time from unrelated outcomes.

## Codex setup

The unified Agent OS plugin supplies the standard hook bundle for `UserPromptSubmit`, material `PostToolUse`, and `Stop`. The installer does not edit a separate user-level `hooks.json`, avoiding a divergent command copy. After installing or updating the bundle, inspect and trust it through `/hooks`, then start a new project task because an already-open task cannot receive hook configuration retroactively.

`agent-os doctor --integrations` verifies bundle files and historical runtime evidence. It cannot prove trust or hook pickup in the current task.

Task Bridge does not use `AGENTS.override.md` because that file would replace rather than extend a project `AGENTS.md`. The hook supplies project-specific task context dynamically through `additionalContext`.
