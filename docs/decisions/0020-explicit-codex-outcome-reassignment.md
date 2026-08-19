# 0020 — Explicit Codex outcome reassignment

Date: 2026-08-19

Status: accepted

Amends: `0005-linked-codex-activity.md` and
`0006-exact-task-bridge.md`

## Context

The original exact-membership model permanently assigned one Codex
`session_id` to one Task Board outcome. Real project work showed that a user may
deliberately continue the same chat with a different outcome. Task Bridge then
ignored even an exact target ID, started every new turn on the old outcome, and
rejected a target claim. The timer was internally consistent but attributed
valid execution time to the wrong outcome.

Automatic semantic switching remains unsafe: a prompt may mention another
outcome only for comparison or context.

## Decision

- A Codex task has at most one current membership with status `active` or
  `idle`.
- The same exact thread ID may remain on earlier outcomes with status
  `archived` as historical evidence.
- An exact conflicting target in a prompt pauses outcome activity and requires
  an explicit `reassign`, or an explicit claim of the existing outcome.
- `reassign` archives the previous membership, attaches the exact target, and
  moves the current unfinished turn with its original start timestamp.
- Completed turns and accumulated outcome time never move automatically.
- A chat with only historical memberships must explicitly claim one current
  outcome before substantive work.

## Rationale

This preserves exact identity and auditability without forcing a new Codex task
for every intentional outcome transition. Moving only an unfinished turn is
safe because it has not contributed duration yet. Keeping completed intervals
in place prevents retroactive guesses and preserves existing Task Board totals.

## Consequences

- Task Board global validation enforces one current owner rather than global
  uniqueness across archived history.
- Task Bridge prompt, stop, checkpoint, context, and stale-turn logic resolve
  only the current membership.
- The native inspector displays archived Codex memberships so a reassigned chat
  remains discoverable from every outcome it previously served.
- Hook changes still require plugin update, `/hooks` review, and a fresh Codex
  task before runtime verification.
