# 0017 — Separate work labels from registered projects

Date: 2026-08-17

Status: accepted

## Context

Slack intake can produce actionable client, review, and coordination work for a user who has no local code repository. Reusing the Slack channel name as a Task Board `project` would make the work visible, but it would also falsely imply a registered Git root and could leak into project routing, Codex handoff, and time reporting.

Channel names are readable but mutable and not unique enough to own correlation. Slack channel IDs and exact thread identities are stable provider identifiers.

## Decision

Keep `projects` limited to registered repository-backed project keys. Add display-only outcome labels with a stable namespaced key, current human-readable name, and explicit kind.

For Slack channel intake:

- key: `slack:<channel_id>`;
- name: current `#channel-name`;
- kind: `slack_channel`.

The exact Slack thread source continues to own correlation. Label upsert is idempotent by key and refreshes the name after a channel rename. Labels support display, search, and filtering only. They never authorize repository access, project routing, Codex task creation, or project time attribution. Direct-message participant names are not persisted as labels.

When no repository is registered, Codex Scheduled may use the active Agent OS home as a non-version-controlled local project. Agent OS does not create a fake Git repository for monitoring.

## Consequences

- Managers and client-facing users can use Slack Monitor and Task Board without local code repositories.
- Named-channel work remains recognizable while project and repository semantics stay precise.
- The native app exposes a separate Labels section and keeps repository actions disabled for label-only outcomes.
- A channel rename changes presentation but not the stable label key or Slack source identity.
- DMs remain unassigned unless an explicit non-personal work label is available.
