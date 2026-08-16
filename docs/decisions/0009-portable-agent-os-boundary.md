# 0009 — Portable Agent OS source and private home

Date: 2026-08-15

Status: accepted; amended by decisions 0013 and 0014

## Context

The original local control plane stored reusable tools, developer-specific
project paths, durable tasks, runtime correlation, the macOS app, and plugin
snapshots across several uncommitted directories. That worked for one machine
but could not be shared without leaking private operational state or maintaining
duplicate plugin sources.

## Decision

- Use the current control-plane checkout as the in-place Agent OS source.
- Separate immutable product source from mutable private state through
  `AGENT_OS_SOURCE_ROOT` and `AGENT_OS_HOME`.
- Default new private homes to `~/.agent-os`; support a preview-first active-home
  pointer for app/plugin processes.
- Keep real registry, outcomes, reports, runtime, and source pointers outside
  the release candidate. Registered project repositories remain in their
  existing user-selected folders.
- Consolidate the Agent OS macOS app and the unified Codex plugin into the
  monorepo. Context Loop is a skill inside that plugin; obsolete standalone
  snapshots are migration history, not product packages.
- Require path, provider-identity, client-context, credential,
  nested-repository, clean-home, app, and plugin gates before publication.
- License the product under MIT.

## Consequences

- Agent OS remains useful without the native app or provider integrations.
- Initialization and activation must be preview-first and preserve existing
  state.
- Separating a legacy source-plus-home installation must copy only private
  state and obsolete project metadata, validate before activation, leave project
  repositories in place, and preserve the previous home for rollback.
- Plugin and app code may read source and home independently but may not escape
  either configured root.
- The source repository cannot be treated as a backup for personal tasks or
  project repositories.
- The initial privacy and publication gates have been satisfied. A second-user
  and second-Mac pilot remains a product-validation goal, not a visibility
  blocker for the already public source and releases.
