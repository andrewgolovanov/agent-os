# 0014 — One Agent OS Codex plugin

Date: 2026-08-15

Status: accepted

## Context

Agent OS and Context Loop were published as two cards in the same marketplace,
even though Context Loop is a focused repository-backed workflow with no MCP
server, hosted service, or independent product state. Users had to install and
update two packages carrying the same brand and could reasonably interpret them
as separate products.

The plugin manifests also used the general `homepage` and `repository` fields,
while the current Codex details interface reads `interface.websiteURL` for its
visible Website row.

## Decision

- Ship one marketplace package, `agent-os@agent-os`.
- Bundle Context Loop at `plugins/agent-os/skills/context-loop` and keep its
  `$context-loop` trigger, scripts, references, and `.context-loop/` state model.
- Keep Context Loop continuation hooks project-local and opt-in. They do not
  become Agent OS plugin-global hooks.
- Keep Task Bridge as the plugin-global hook bundle because it serves canonical
  Agent OS task correlation rather than Context Loop continuation.
- Set `interface.websiteURL` to the public Agent OS repository and validate it
  as package metadata.
- Remove the standalone Context Loop marketplace entry. Existing users install
  the consolidated Agent OS snapshot before removing `context-loop@agent-os`.

## Consequences

- Users install, update, and identify one Agent OS plugin while retaining the
  explicit `$context-loop` workflow.
- Existing repository `.context-loop/` directories need no migration because
  only the skill's package location changes.
- Removing the old plugin registration removes only a redundant Codex snapshot;
  project state and project-local hooks remain untouched.
- A fresh Codex task is required after installation or update before the merged
  skill and corrected Website link can appear.
