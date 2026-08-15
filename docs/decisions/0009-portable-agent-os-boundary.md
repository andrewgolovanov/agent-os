# 0009 — Portable Agent OS source and private home

Date: 2026-08-15

Status: accepted

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
- Keep real registry, outcomes, reports, runtime, source pointers, and project
  checkouts outside the release candidate.
- Consolidate the Agent OS macOS app and both Codex plugins into the monorepo while
  preserving previous standalone directories as local recoverable backups.
- Keep the first remote private and require path, provider-identity, client
  context, credential, nested-repository, clean-home, app, and plugin gates
  before commit or push.
- License the product under MIT.

## Consequences

- Agent OS remains useful without the native app or provider integrations.
- Initialization and activation must be preview-first and preserve existing
  state.
- Plugin and app code may read source and home independently but may not escape
  either configured root.
- The source repository cannot be treated as a backup for personal tasks or
  project repositories.
- Public visibility requires a second-user installation pilot after the private
  release is proven.
