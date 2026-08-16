# 0006 — Exact-source Task Bridge for project chats

Date: 2026-08-10

Status: accepted

Supersedes: unregistered-session ignore and explicit-only lifecycle portions of `0005-linked-codex-activity.md`

## Context

Exact-only activity accounting worked for a manually linked outcome, but direct work in another project chat was invisible: the second outcome never became active and accumulated no time. Requiring the user to return to the root Agent OS chat for every claim, status update and stop defeats the purpose of project-local work.

At the same time, choosing a task from project path or similar title is unsafe because one project can contain several active outcomes.

## Decision

- Add one Agent OS-owned Task Bridge for all registered projects; no task config is copied into product repositories.
- `UserPromptSubmit` scopes candidates by canonical project path and auto-claims only one exact Task Board ID or stable Slack/GitHub/Figma source match.
- Semantic similarity may rank candidates but may never mutate membership or lifecycle.
- Exact claim sets the outcome active and starts exact turn activity; `Stop` closes it. A later turn in the same session safely closes a lost predecessor with a configured idle cap; global reconcile remains explicit so parallel active chats are not truncated.
- Material project changes require a Task Board checkpoint with verified summary, next action and `active`/`waiting`/`review` status before Stop may complete.
- `done` and `cancelled` remain explicit user acceptance decisions.
- Exact runtime correlation lives under ignored `AGENT_OS_HOME/.runtime/task-bridge/` and stores a prompt hash, not raw prompt content.

## Rationale

Dynamic hook context reaches every registered project chat without overriding repository `AGENTS.md`. Exact source identity gives safe automation, while explicit claim is a bounded fallback for genuinely new or ambiguous outcomes. Central state avoids drift between per-project copies.

## Consequences

- Starting work with an exact task ID or source URL makes Board activity and time automatic.
- A prompt containing only a similar title may require one explicit claim command.
- Hook configuration must be trusted in `/hooks` and is guaranteed only for fresh chats.
- Imported historical time requires exact Codex turn timestamps; guessed human time is never added.
- A legacy chat that contains multiple unrelated outcomes is archived after scoped backfill and must not be reused as a durable membership.
