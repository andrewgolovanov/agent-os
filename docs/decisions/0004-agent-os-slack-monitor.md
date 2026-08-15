# 0004 — One Agent OS Slack monitor

Date: 2026-08-09

Status: accepted

## Context

Project-specific monitoring required a new heartbeat and channel list for every onboarded project. It also missed DMs and mentions in channels not yet registered. The user explicitly authorized read-only intake of DMs and group DMs.

## Decision

Use one `agent-os-slack-monitor` for the whole Slack identity:

- exact direct mentions in all accessible public/private channels;
- incoming direct and group DMs;
- active exact-root watches already linked to Task Board outcomes;
- project channels only for attribution, not ambient full-channel scanning.

Run on the private schedule selected by the user. Reuse an existing heartbeat record during migration when that preserves task/runtime continuity; the user-facing name and canonical monitor key are `Agent OS Slack Monitor` / `agent-os-slack-monitor`.

## Rationale

One personal dispatcher scales without creating per-project automations. Mention/DM intake captures explicit personal responsibility; watched roots preserve continuity. Avoiding ambient scanning reduces noise and unnecessary access to unrelated conversations.

## Consequences

- Project onboarding adds registry mapping only when attribution/routing is useful.
- Unknown-project signals may create an unassigned inbox task.
- DMs are read-only evidence and follow the same no-raw-content runtime schema.
- Three daily runs trade minute-level latency for a predictable workday cadence.
