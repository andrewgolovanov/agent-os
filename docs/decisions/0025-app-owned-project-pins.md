# 0025 — App-owned project pins

Date: 2026-08-21

Status: accepted

Supersedes: the project-pin ownership portion of 0024

## Context

The Codex desktop sidebar supports project pinning, but the supported Codex App
Server contract exposes thread pin state rather than stable project-presentation
metadata. Reading private Codex desktop files would create an unsupported and
fragile dependency. Waiting for a future API also leaves frequently used Agent
OS projects difficult to keep visible in a long sidebar.

The user chose a narrow Agent OS-owned fallback for pins while explicitly
deferring project icons and colors.

## Decision

- Store an ordered list of stable project keys in macOS `UserDefaults` through
  SwiftUI `AppStorage`.
- Present the matching projects in a `Pinned` section above `Projects`. A new
  pin appends to that order; unpinning removes it; pinning it again appends it.
- Allow pin and unpin from a star immediately left of the invariant trailing
  task count and from the project context menu. Show the empty star on hover;
  keep the filled star visible for a pinned project.
- Keep every pinned project visible. Keep unpinned projects in the
  registry-provided alphabetical order only while at least one unfinished
  outcome is assigned to them.
- Treat inactive-project hiding as presentation only. Keep the canonical
  registry and completed history intact, and restore an unpinned project row
  automatically when new unfinished work references its stable key.
- Ignore missing keys while rendering but retain them in the preference so a
  temporarily unavailable project can recover its pin.
- Treat pins as presentation only. They never modify `projects.yaml`, Task Board
  state, project routing, Slack reconciliation, or plugin behavior.
- Do not infer project pins from Codex thread pins or read private Codex desktop
  state. Continue using the folder glyph; icons and colors remain deferred.

## Consequences

- Frequently used projects stay visible without waiting for a new Codex API.
- The regular project section remains focused on actionable work without
  deleting zero-work or completed-only registrations. Those projects remain
  available through Done history and return when actionable work resumes.
- Pin order is local to this macOS user and app installation; it does not sync
  through the Agent OS plugin or private project registry.
- If Codex later exposes supported project pin metadata, Agent OS will need an
  explicit migration or precedence rule instead of silently replacing local
  choices.
