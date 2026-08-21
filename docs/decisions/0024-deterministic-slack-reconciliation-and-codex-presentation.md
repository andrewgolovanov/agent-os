# 0024 — Deterministic Slack reconciliation and Codex-owned presentation

Date: 2026-08-21

Status: accepted

Amended: 2026-08-21 after `v0.7.0` feedback restored completed-only unmapped
labels to the sidebar

Supersedes: the blanket automatic channel-mapping exclusion in 0021

Partially superseded by: 0025 for app-owned project pins

## Context

Automatic Codex project registration can create a real project after Slack-only
work already produced a display label. Preview-only reconciliation leaves that
stable channel ID unmapped, so future Slack work still routes to the label even
when the corresponding project is now known. The native sidebar also needs to
keep historical Slack-only work reachable when no registered project owns its
channel.

The Codex desktop UI separately supports project presentation such as pinning,
order, icons, and colors. Agent OS should mirror Codex rather than own a second
configuration, but the supported [Codex App Server
contract](https://learn.chatgpt.com/docs/app-server) currently exposes thread
pin state and no stable project-presentation contract.

## Decision

- After deterministic project registration, inspect only existing Task Board
  Slack labels keyed by their stable channel ID. Do not read Slack or import
  Slack history for reconciliation.
- Normalize the label's channel name and link it only when exactly one
  registered project owns that identity, no other project owns the channel ID,
  and every labeled outcome is unassigned or already attributed only to that
  project.
- The mapping may attribute only unfinished unassigned outcomes. Completed,
  cancelled, and already attributed outcomes are never rewritten. Labels stay
  on cards and sources retain their exact identity.
- Any ambiguous identity, conflicting mapping, or conflicting outcome
  attribution fails closed and remains available to the existing preview-first
  manual onboarding flow.
- The top-level Labels sidebar lists every unmapped stable channel label across
  outcome lifecycles. Its number remains an unfinished-work count, so a
  completed-only channel stays navigable with zero. Only an exact registered
  project-channel mapping removes the duplicate top-level label.
- Do not add Agent OS-owned pin, order, icon, or color controls. Do not infer a
  project pin from a thread pin or read private Codex desktop storage. Continue
  alphabetical project presentation with folder glyphs until a supported Codex
  API exposes stable project presentation metadata.

## Consequences

- A newly registered project can absorb the exact safe subset of prior Slack
  routing metadata and receive future channel work without a manual onboarding
  pass.
- Historical outcomes remain audit-stable, while redundant sidebar labels
  disappear when they no longer represent unfinished unmapped work.
- Codex remains the future owner of project presentation. Agent OS gains no
  competing preferences and can adopt supported metadata later without a
  migration from locally invented state.
