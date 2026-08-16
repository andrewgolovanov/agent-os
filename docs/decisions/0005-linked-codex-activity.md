# 0005: Linked Codex activity and unfinished totals

- Status: accepted
- Date: 2026-08-10
- Supersedes: activity deferral in `0003-structured-continuity-before-hooks.md`

## Context

The first real continuity cycle reached active implementation. A concrete consumer now existed: the user needed the total number of unfinished outcomes in monitor notifications and measurable Codex execution time for each outcome.

## Decision

- The generated Task Board index always contains `unfinished_total`; `done` and `cancelled` are excluded.
- Every Slack Monitor `NOTIFY` displays the Agent OS-wide unfinished total.
- Activity starts only after exact Codex `thread_id` membership.
- `UserPromptSubmit` opens a turn and `Stop` closes the same exact `turn_id`; repeated events do not duplicate time.
- Hooks synchronize only Codex membership `active` and `idle`; outcome lifecycle remains explicit.
- Unregistered Codex sessions are ignored. Hooks perform no semantic routing and never change outcome lifecycle automatically.

## Rationale

Codex hook payload exposes stable `session_id` and `turn_id` but not outcome duration. A bounded timer makes evidence reproducible, while exact membership prevents time from being assigned to a similar but unrelated outcome.

## Consequences

- The metric is agent execution time for completed turns, not a human timesheet or the Codex UI “Working for…” duration.
- A new hook requires inspection, trust, and a fresh task; historical time is never reconstructed by guessing.
- `review`, `waiting`, and `done` remain explicit domain decisions.
