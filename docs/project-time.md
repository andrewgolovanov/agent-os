# Project Time

Project Time answers a different question from Task Board: how much active Codex execution time was spent across all tasks in a project, whether or not every task was linked to an outcome.

## Source and scope

Canonical project paths live in private `AGENT_OS_HOME/config/projects.yaml`. A moved repository may also define:

```yaml
activity:
  historical_paths:
    - /previous/exact/project/path
  include_thread_ids: []
  exclude_threads:
    - id: exact-codex-thread-id
      reason: Why this thread is not client project work.
```

- Current project `root` and repository paths are included automatically.
- `historical_paths` is only for exact previous checkout paths after a physical move.
- `include_thread_ids` narrowly includes a proven project task that started from another working directory.
- `exclude_threads` removes false attribution, such as system maintenance accidentally started from a project path.

## Measurement

The accounting unit is one exact Codex turn:

```text
task_started / hook start
  -> active Codex execution
task_complete | turn_aborted | hook stop
```

Only completed intervals count. Time between messages, Slack, meetings, manual browser QA, and work outside Codex are excluded. The report is therefore a reproducible minimum of Codex execution time, not proof of every billable human hour.

A turn that crosses a month boundary is split between months in `agent_os.timezone`. Exact `thread_id + turn_id` prevents double counting after repeated session events, compaction, or refresh.

Monthly `thread_count` is the number of tasks with active time in that month. One long task may appear in two months, while the overall count is deduplicated by thread ID.

## Files and commands

```text
AGENT_OS_HOME/work/reports/project-time/<project>.json  canonical generated ledger
AGENT_OS_HOME/work/reports/project-time/<project>.md    human-readable monthly report
```

```bash
tools/project-time refresh --project example-site
tools/project-time show --project example-site
tools/project-time show --project example-site --json
tools/project-time validate --project example-site
```

`refresh` rereads local Codex session histories, applies configured scope and exclusions, and atomically rebuilds both files. The installed Agent OS Task Bridge hook updates the same ledger at each new turn and `Stop`, even before a task has an exact Task Board outcome.

The generated ledger remains a private CLI report for all project tasks. The native app intentionally has no separate Time page: Done shows outcome-level activity attached to visible completed outcomes. The app does not recalculate session history, create another time database, or combine overlapping project-wide and task-linked totals.

## Relationship to Task Board

- Task Board time answers how much Codex execution is linked to one outcome.
- Project Time answers how much Codex execution occurred across all project tasks.
- These totals must not be added because linked turns already appear in the project total.
- A project report does not create outcomes, change lifecycle, or write to a product repository.

For an external report, use the monthly table from generated Markdown and add separately verified manual time only when required by the engagement.
