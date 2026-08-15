# Changelog

## 2026-08-15

- Approved Agent OS as the portable product form of the local control plane:
  in-place source, external private state, one monorepo, private-first release,
  and MIT licensing.
- Added separate `AGENT_OS_SOURCE_ROOT` and `AGENT_OS_HOME` contracts with
  compatibility for the previous one-directory installation.
- Added preview-first `agent-os init`, read-only `doctor`, full `validate`, and
  a publication boundary audit.
- Added sanitized configuration templates; initialization creates an empty
  registry and does not enable monitors, hooks, provider access, or write
  authority.
- Excluded real config, tasks, reports, runtime, project checkouts, and local
  source pointers from Git candidates.
- Consolidated the Agent OS macOS app and both Codex plugins into the monorepo without
  removing or changing the standalone source directories.
- Updated the Agent OS app and its MCP server to use distinct source and home
  roots and removed developer-specific default paths.
- Aligned app and MCP task-ID validation with the canonical Task Board contract.
- Added clean-home CLI and MCP tests, plugin package validation, and Context Loop
  smoke coverage.
- Verified the current instance and a fresh temporary home with 37 Ruby tests,
  222 assertions, Swift build/tests, app bundle launch, MCP isolation, and both
  plugin packages.
- Preserved the previous private operational documentation in an ignored local
  backup before beginning product-document sanitization.
- Sanitized the product documentation until the built-in publication audit
  reported zero known private-state boundary findings.
- Added preview-first active-home selection for app/plugin discovery, installed
  both plugins from the monorepo `agent-os` marketplace, and removed the old
  personal marketplace registration without deleting its source directory.
- Unified public naming across the Swift package, macOS bundle, Codex plugin,
  MCP tools, Ruby namespace, paths, templates, and documentation under Agent OS.
- Added preview-first Codex plugin installation plus ad-hoc signed macOS
  packaging, SHA-256 checksums, and an explicit user-approved Gatekeeper flow.
- Added release-tag-based `agent-os update`: preview by default, clean
  fast-forward only, no reset of local changes, and version-aware Codex plugin
  refresh.
- Integrated Sparkle 2.9.5 into Agent OS for daily update checks, manual check,
  and user-controlled automatic installation; added the same Settings surface
  for core/plugin update opt-in.
- Added a dedicated Agent OS Ed25519 update key, pre-extraction archive
  verification, generated appcast, nested framework signing, and a tag-triggered
  GitHub Release workflow without Developer ID or notarization.

Earlier private installation history is intentionally not part of the shareable
product changelog.
