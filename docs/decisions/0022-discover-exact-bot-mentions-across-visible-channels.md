# 0022 — Discover exact bot mentions across visible Slack channels

Date: 2026-08-21

Status: accepted

Supersedes: the no-ambient-read restriction in decision 0004 only for bounded
bot/app root-message mention discovery.

## Context

Slack search can include bot messages, but some app notifications put reviewer
mentions only in Block Kit. Those roots may not be returned by an exact mention
search even though a direct channel read renders the current user as a
reviewer. Configuring channel IDs would not be portable because every user and
workspace has different review channels.

## Decision

- Keep one Agent OS-wide monitor and resolve the exact current Slack user on
  every run.
- Enable bot results in normal direct-mention search.
- Dynamically enumerate every public and private channel visible to the user;
  do not configure an allowlist of channel IDs.
- Read only the bounded new root-message window for each channel. Discard human
  roots and bot/app roots whose rendered text or blocks do not resolve a
  mention to the exact current user ID.
- Process a matching bot/app thread with the same complete-thread,
  unresolved-actionability, exact-source, deduplication, attribution, and
  Unassigned fallback rules as a human direct mention.
- Persist only stable per-channel progress and existing minimal Task Board
  evidence. Never retain nonmatching ambient messages or raw thread bodies.
- Advance a channel cursor only after that channel is complete. Advance the
  global cursor only after every source and the full dynamic inventory finish;
  resume safely after rate limits or partial reads.

## Consequences

- Structured review apps can create or update the user's work without manual
  channel configuration.
- Bot posts without the exact personal mention remain noise and never become
  outcomes.
- The monitor performs more read calls and may span multiple scheduled runs in
  large workspaces, but per-channel cursors prevent gaps and repeated history
  scans.
- Decision 0004 continues to prohibit general ambient task analysis; this
  exception exists only to find exact personal mentions hidden from search.
