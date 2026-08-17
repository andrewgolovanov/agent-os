# 0018 — Keep Slack source titles short and display-only

Date: 2026-08-17

Status: accepted

## Context

Exact Slack permalinks are reliable correlation identities, but a native source
list containing many rows titled `Slack thread` is difficult to scan. Slack does
not provide a separate thread-topic field, so the only useful local heading is a
small excerpt from the root message.

Storing the full message or thread would expand Agent OS into a transcript store
and duplicate Slack. Using an excerpt as identity would also make correlation
unstable when message text changes.

## Decision

Allow a Slack source to carry one optional `title` derived only from its root
message. Task Board normalizes Slack link and formatting markup, collapses
whitespace, and caps the stored value at 96 characters. It never prepends author
metadata or combines replies. Reattaching the same exact source may refresh the
title idempotently while preserving its original `added_at` value.

The exact permalink-derived identity remains the only correlation authority.
Source titles are private display and search metadata; they never select a
project, create a label, authorize routing, or merge outcomes. Slack cursor and
seen-event state continue to store no message text. Existing sources without a
title remain valid and render with the generic `Slack thread` fallback.

## Consequences

- Source cards become immediately distinguishable without opening each thread.
- Agent OS retains one bounded excerpt rather than a message or thread copy.
- Root-message edits can refresh presentation without breaking continuity.
- Legacy Task Board data and third-party sources remain backward compatible.
