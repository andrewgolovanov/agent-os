# 0008 — Native Agent OS app over the existing control plane

Date: 2026-08-14

Status: accepted

## Context

Agent OS already owns structured projects, outcomes, exact source identity,
Codex membership, linked-turn time, project-level time, and read-only Slack
intake. Its primary human dashboard is generated Markdown. With many concurrent
active and review outcomes, the state remains reliable but orientation and task
launch require too much navigation and memory.

The reviewed AgentOS example combines a board with a separate agent runtime,
containers, permissions, files, triggers, schedules, goals, inbox, activity, and
cost management. Rebuilding that whole control plane would duplicate Codex and
create a large maintenance and security surface.

Current official Codex contracts offer a smaller boundary: plugins can package
skills and MCP tools, while Codex App Server is intended for rich clients and
provides thread and event APIs.

## Decision

- Build toward a thin native macOS Agent OS app, not a standalone second
  service.
- Keep `config/projects.yaml`, Task Board, Project Time, Task Bridge, and Slack
  Monitor as the canonical control plane.
- Give the native app no independent task database. All mutations go through
  existing deterministic Agent OS tools.
- Use a regular SwiftUI main window with a native sidebar/detail model; keep the
  menu bar surface limited to counts and quick actions.
- Use a skills-plus-MCP Codex plugin as the agent-facing adapter. Do not require
  custom plugin UI for the native cockpit.
- Evaluate Codex App Server over local `stdio` using only its stable documented
  surface. Do not make experimental WebSocket transport, private deep links, or
  UI automation core dependencies.
- Keep Slack/provider integration read-only in the MVP.
- Require product-spec approval and a bounded integration spike before app or
  plugin scaffolding.

## Consequences

- The native UI is replaceable if Codex later ships an adequate task board; the
  durable state remains usable without it.
- The project avoids containers, hosted databases, queues, transcript copies,
  secret vaults, and another automation engine.
- Exact one-click handoff into the official Codex desktop task is a validation
  gate, not an assumed capability.
- The first app may expose less live-agent detail than the reference AgentOS,
  because it intentionally delegates execution, goals, schedules, and approvals
  to Codex.
- New task fields such as priority, rank, assignee, due date, and capacity stay
  out of scope until real use proves they are necessary.
