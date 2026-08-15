# 0007 — Separate project-level Codex time from outcome time

Date: 2026-08-13

Status: accepted

## Context

Task Board time is intentionally attached only to exact outcome memberships. Work in an existing registered project may predate Task Bridge and span many independent Codex threads, so summing current Task Board cards undercounts project work. Assigning every historical thread to a synthetic task would corrupt outcome semantics and could double-count turns already linked to real cards.

Path-only attribution also has known false positives: unrelated system maintenance may start while the cwd is a registered repository.

## Decision

- Keep outcome activity in Task Board unchanged.
- Add a separate project ledger generated from exact local Codex `task_started` and terminal events, deduplicated by `thread_id + turn_id`.
- Resolve project scope from current registry paths plus explicit historical paths; allow exact manual include and reasoned exclude lists.
- Update the project ledger from the user-level hook for every registered project chat, even when no Task Board outcome is claimed.
- Aggregate completed intervals by the Agent OS timezone and split turns that cross a month boundary.
- Generate both machine-readable JSON and a human-readable monthly report.

## Consequences

- Historical and future project threads can be reported without inventing tasks or modifying the project repository.
- Task totals and project totals remain separate views of the same turns and must never be added together.
- The report measures Codex execution only; meetings, Slack, manual testing and other human work need separate evidence if they are billable.
- Explicit exclusions are reviewable rather than hidden in heuristics.
