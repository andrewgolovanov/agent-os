# 0019 — Map reviewed Slack channels to registered projects

Date: 2026-08-17

Status: accepted

## Context

Display-only Slack labels make repository-free work visible, but a channel can
later turn out to belong to an existing or newly onboarded project. Showing both
the registered project and its channels as peer sidebar destinations creates
duplicates. Leaving earlier channel outcomes unassigned also fragments one
project board after its repository is registered.

Channel names are conventions rather than identities. Similar names can belong
to different clients, environments, or workspaces, and outcome titles are not a
safe merge key. Stable Slack channel IDs can own an explicit mapping after a
human reviews the suggestion.

## Decision

Allow each private project registry entry to own optional `slack_channels`
records containing a stable channel ID and its current display name.
Onboarding may conservatively normalize conventional channel and repository
affixes to suggest a possible match, but it never selects or applies a channel
from name similarity alone.

The user must provide exact reviewed channel IDs and inspect a second preview.
Apply stores only those selected mappings and assigns only unfinished outcomes
whose project list is empty and whose stable Slack label key matches. It never
overwrites existing project attribution, changes labels, merges outcomes, or
uses similar task text as evidence. Re-running the same apply is idempotent and
can reconcile an already registered project.

Mapped Slack labels remain visible on outcome cards and details so the source
channel is immediately recognizable. The native app omits only those mapped
labels from the separate top-level Labels sidebar, while unmapped Slack-only
work remains filterable there.

## Consequences

- Project-specific channels no longer duplicate their registered project in the
  sidebar after explicit mapping.
- Slack-only work can join a newly onboarded repository board through one
  reviewed preview-first operation.
- Existing project attribution and exact Slack source identity remain safe.
- Managers without repositories retain the Slack-only Labels workflow defined
  by decision 0017.
