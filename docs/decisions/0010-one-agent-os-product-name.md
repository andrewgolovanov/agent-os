# 0010 — One Agent OS product name and two optional clients

Date: 2026-08-15

Status: accepted
Amended: 2026-08-15 — ad-hoc signed distribution approved

## Context

The reusable setup was already called Agent OS, while the native app, Codex
plugin, MCP server, Swift package, and internal Ruby namespace still exposed the
older Workspace Console or Workspace names. A second user would see several
apparently different products and would not have one reproducible installation
path.

## Decision

- Use `Agent OS` for the product, macOS display name, and Codex plugin.
- Use `agent-os` for repository paths, marketplace/plugin IDs, CLI names, and
  service identifiers; use `AgentOS` for Swift and Ruby symbols.
- Ship one required core plus two optional clients: `agent-os@agent-os` for
  Codex and `Agent OS.app` for macOS. Both operate on the same private home and
  own no second task database.
- Keep old `WORKSPACE_*` inputs only as explicitly deprecated migration aliases.
  New documentation, templates, output, and examples use `AGENT_OS_*`.
- Do not require Apple Developer ID or notarization. Package the complete app
  with an ad-hoc signature, publish a SHA-256 checksum, and document the normal
  macOS `Open Anyway` user-consent flow.

## Consequences

- A new user sees one product name across the repository, Codex, and macOS.
- Plugin installation and local app packaging are reproducible from the source
  checkout without storing credentials in Git.
- macOS cannot verify the publisher identity or Apple malware review. Users must
  trust the release source, verify its checksum, and explicitly approve the
  first launch; the project must state this limitation plainly.
