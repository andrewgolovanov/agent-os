# 0013 — Bundle the minimal runtime with app and plugin

Date: 2026-08-15

Status: accepted

## Context

The original portable setup required every user to clone the complete Agent OS
repository, initialize a private home, activate that checkout, install the
plugin from the local marketplace, and separately install the app. This made a
source-development topology part of the normal product experience and suggested
that project repositories also had to live under one Agent OS `projects/`
directory.

The app and plugin already operate on the same small deterministic subset of
Agent OS: configuration templates, project wrappers, Task Board tools, runtime
correlation helpers, and the CLI. The rest of the public repository is useful
for development, tests, and documentation but is not required at runtime.

## Decision

- Package one generated, allowlisted minimal runtime inside the Agent OS plugin.
- Copy that exact generated runtime into the macOS app bundle during development
  and release packaging; do not maintain a second app-specific payload.
- Let either component perform the same idempotent bootstrap into the active
  private `AGENT_OS_HOME`, defaulting to `~/.agent-os`.
- Prefer an explicitly selected valid development checkout. Otherwise use the
  newest packaged runtime and record it through the private `source-path`.
- Require an explicit preview-first `--replace-source` action to leave a valid
  development checkout; routine app/plugin bootstrap must not make that choice
  implicitly.
- Add preview-first MCP and CLI project onboarding that accepts an existing Git
  repository in any absolute location and never moves or modifies it.
- Add identity-checked relinking for the private registry after a user has
  deliberately moved a registered repository.
- Keep the public source checkout as the contributor and advanced-development
  surface, not as a normal installation prerequisite.
- Generate the payload only through `tools/sync-plugin-runtime`; its manifest,
  hashes, executable bits, package tests, app tests, and release validation must
  prevent source/package drift.

## Consequences

- A normal user installs the versioned Codex plugin and the matching macOS app;
  no manual `git clone`, activation command, or source environment variable is
  required.
- Codex owns the installed plugin snapshot, the app owns its bundle resources,
  and the private home remains the sole owner of mutable Agent OS state.
- Projects may remain anywhere on the computer. Agent OS records an absolute
  routing path and creates only private wrapper metadata when needed.
- Plugin and app package size increases by the minimal allowlisted runtime, but
  product source, tests, documentation, Git history, and private data remain
  excluded.
- Marketplace and app releases must stay version-aligned. Updating a plugin
  still requires a fresh Codex task; updating the app still follows the signed
  Sparkle boundary.
- Existing development installations remain valid and are not silently replaced
  or reset by packaged bootstrap.
- A contributor can detach private state from a development checkout without
  editing pointer files manually, while retaining a visible preview and an
  explicit packaged-runtime target.

## Relationship to prior decisions

This decision replaces the normal-user checkout assumption in
`0009-portable-agent-os-boundary.md` and `0011-release-based-auto-update.md`.
Their source/home separation, privacy boundary, versioned release policy,
preview-first Git update behavior for development checkouts, and signed app
update requirements remain accepted.
