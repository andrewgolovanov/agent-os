# 0001: Minimal local-first core

- Status: superseded by 0016
- Date: 2026-08-09

## Context

Agent OS was starting from scratch. The reference harness included a Task Board CLI, Slack dispatcher, activity hooks, and automations, but the new installation had not yet proven a real project workflow.

## Historical decision

Start with six independent layers: a small root router, canonical project registry, project wrappers, durable documentation, Markdown task snapshots, and repository-scoped skills. Do not implement integrations, database-backed task state, or automations before a real pilot.

Decision 0016 later replaced the interim wrapper topology with one registry-only `root + repositories` contract. Wrapper is no longer a supported project type; legacy records are accepted only by the one-way migration.

## Consequences

- The initial structure supported multiple projects and specialized skills.
- The first project could be onboarded without changing architectural boundaries.
- Task management began as transparent manual Markdown state.
- New subsystems required evidence from a repeated scenario and a separate decision.

This record remains only as historical rationale.
