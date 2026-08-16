# Done workflow and completion time

- Status: accepted
- Date: 2026-08-16

## Context

The unfinished Board is optimized for deciding what to do next. Mixing a large
completed archive into those lifecycle columns makes current work harder to
scan, while a generic history page that only reports aggregate time loses the
operational context needed to review a delivery, reopen its PR or source thread,
and confirm that completion was communicated.

The reference workflow reviewed for this decision treats completion as an
explicit gate: agent work can reach a completed state, but approval and the
transition to done remain visible user decisions. Agent OS needs the same
clarity without adopting a second subtask engine or external task database.

## Decision

1. Board contains unfinished lifecycle states only.
2. Done is a separate operational journal for `done` and `cancelled` outcomes.
   It reuses the canonical task and inspector, retaining goal, state, next
   action, time, PRs, source links, and Codex memberships.
3. Done owns the operational time surface. Project and completion-period filters
   summarize only exact-linked activity for the visible completed outcomes; no
   separate Time page competes with the completion journal.
4. Generated Project Time remains a CLI/private-report workflow for broader
   analytics across project chats. It is not mixed into Done because the two
   measurements overlap.
5. Completion communication is not a lifecycle state. A done outcome stores a
   `completed_at` timestamp and `pending`, `sent`, or `not_required` follow-up.
   Slack-backed outcomes default to `pending`.
6. Agent OS may prepare and copy a completion update, but it does not send an
   external message without a future explicit preview-and-confirm action.
7. Removing or archiving a Codex task never deletes the durable outcome.

## Consequences

- Current work stays compact while every completed delivery remains auditable.
- Users can find the exact Slack thread or PR needed for completion follow-up.
- Exact-linked time remains visible beside the completed work it belongs to;
  broader project reporting stays available without duplicating navigation or
  inviting users to add overlapping totals.
- Completed records can grow over time; any future retention or purge feature
  must be explicit and separate from Codex task deletion.
