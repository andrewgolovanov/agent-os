# Agent OS repository instructions

## Purpose

This repository is the portable Agent OS source. Keep user project code and mutable operational state in the selected private `AGENT_OS_HOME`; only Agent OS core, app/plugin components, reusable workflows, templates, tests, and product documentation belong in the source candidate.

## Always

- Treat private `AGENT_OS_HOME/config/projects.yaml` as the canonical registry for project keys, aliases, project layouts, wrapper paths, and repository paths.
- Resolve a project through the registry before substantive project work.
- Read the registered project root `AGENTS.md` before working on that project. For a wrapper, then obey any more specific repository `AGENTS.md`; for a direct repository, that first file is already repository-scoped.
- Before Git-sensitive conclusions or mutations, verify the exact path, repository root, remotes, branch, HEAD, and worktree status.
- Preserve unrelated changes. Never move project repositories, change remotes, publish, deploy, or write to external services without explicit user intent.
- Record durable current state through `tools/task-board`; do not rely on chat history as the only copy of an important decision or next step.

## Route by task

| Task | Read first |
| --- | --- |
| Agent OS architecture or documentation | `docs/README.md`, then the owning document |
| Add or change a registered project | `.agents/skills/onboard-project/SKILL.md`, then `templates/project/` only for wrapper layout |
| Work on a registered project | `config/projects.yaml`, then the registered project root `AGENTS.md` |
| Start or resume durable work | `work/README.md`, `docs/task-board.md`, and the matching `work/items/<task-id>/STATUS.md` |
| Task correlation, Codex activity, or checkpoints | `config/task-bridge.yaml`, then `docs/task-bridge.md` |
| Slack monitor or review intake | `config/monitors.yaml`, then `docs/slack-monitor.md` or `docs/review-intake.md` |
| Create or change a skill | `docs/extending.md` and the skill's `SKILL.md` |

## Working contract

1. Discover and verify facts before editing structured records.
2. Keep one canonical owner for each fact; documentation may explain a fact but must not silently fork it.
3. Prefer a small reversible change. Use preview or dry-run behavior for tools that can mutate state.
4. Validate the affected layer and report exactly what was and was not verified.
5. For material Agent OS changes, update the owning doc, `docs/state.md`, and `docs/changelog.md`; add a decision record when rationale must survive.

## Documentation maintenance

- Treat documentation as part of the implementation, not as later cleanup. In the same change, update every relevant document whose claim became inaccurate because user-visible behavior, setup, commands, paths, naming, architecture, security boundaries, validation, or release behavior changed.
- Keep agent-facing commands, required checks, routing, and ownership rules in the nearest applicable `AGENTS.md`. Keep human installation, usage, and contribution guidance in the nearest relevant README. Keep deeper product facts in the owning document under `docs/`.
- Update only affected documents; do not mechanically touch every `AGENTS.md` or README. Before handoff, search for removed or renamed commands, paths, and product names, and run every validation command that was added or changed.

## Validation

Run `ruby tools/validate-agent-os` after structural or registry changes. Run `tools/task-board validate` after task-state tooling changes and `tools/slack-state validate` after dispatcher-state changes. Run repository-specific checks from the registered repository and its closest `AGENTS.md`.
