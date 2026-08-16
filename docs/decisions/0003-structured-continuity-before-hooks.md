# 0003: Structured continuity before activity hooks

- Status: accepted; activity deferral superseded by 0005
- Date: 2026-08-09

## Context

The first read-only intake pilot showed that plain Markdown folders were insufficient for reliable correlation among replies, Codex tasks, and future PRs. The reference harness used a Task Board, exact-event ledger, watched roots, routing queue, and activity hooks.

## Decision

Implement a structured Task Board and separate Slack runtime state first:

- one coherent outcome has a stable task ID;
- exact external identities attach to the outcome;
- Codex tasks are peer memberships;
- Slack event de-duplication is separate from durable task correlation;
- failed Codex routing becomes `routing_pending` rather than replaying the Slack event;
- the automation prompt stays short and refers to a local runbook.

Activity hooks, time evidence, Daily Chores, and automatic Codex task management were initially deferred.

## Rationale

Hooks measure activity but do not repair lost task identity. Installing them first would have added global noise and privacy surface before a verified consumer existed. Structured continuity was already required by monitor workflows and could be tested locally without external write permission.

## Consequences

- Private task state moved from status folders to a locked structured Task Board.
- Monitor runtime stores only identifiers and dispositions under ignored `AGENT_OS_HOME/.runtime/dispatcher/`.
- The next pilot had to verify the complete Slack-to-task-to-Codex-to-review cycle.
- Decision 0005 later enabled exact linked activity after that consumer was proven.
