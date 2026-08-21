# Agent OS documentation

This directory explains how Agent OS is designed, how to operate it, and why its important decisions were made.

## Documentation map

| Document | Owns |
| --- | --- |
| [architecture.md](architecture.md) | layers, boundaries, and the source of truth for each data type |
| [workflows.md](workflows.md) | automatic project synchronization, manual onboarding, execution, and task handoff |
| [task-board.md](task-board.md) | structured outcomes, source identity, and Codex memberships |
| [task-bridge.md](task-bridge.md) | automatic project-task correlation, checkpoints, and time evidence |
| [project-time.md](project-time.md) | all-thread Codex time by project and month |
| [agent-os-app.md](agent-os-app.md) | native macOS app boundary, UX, and implementation notes |
| [installation.md](installation.md) | reproducible core, Codex plugin, and macOS app installation |
| [optional-integrations.md](optional-integrations.md) | opt-in Slack monitoring, Codex Scheduled, and plugin hooks |
| [agent-os.md](agent-os.md) | portable product boundary, local/private split, and publication gates |
| [slack-monitor.md](slack-monitor.md) | read-only Slack intake, cursors, and watched roots |
| [review-intake.md](review-intake.md) | safe PR review routing for reviewers and authors |
| [chat-model.md](chat-model.md) | Codex task topology, ownership, and handoff |
| [harness-comparison.md](harness-comparison.md) | reference gap analysis and accepted scope |
| [extending.md](extending.md) | criteria for new docs, skills, tools, and integrations |
| [state.md](state.md) | verified current state and known limitations |
| [roadmap.md](roadmap.md) | near-term outcomes rather than a feature wish list |
| [changelog.md](changelog.md) | dated material changes |
| [decisions/](decisions/README.md) | durable architectural decisions and rationale |

## Maintenance contract

A material Agent OS change updates:

1. the nearest `AGENTS.md` when agent commands, required checks, paths, routing, or ownership change;
2. the relevant README when installation, usage, contribution, or other user-visible behavior changes;
3. the owning document;
4. `state.md` when verified current state changes;
5. `roadmap.md` when the next outcome changes;
6. `changelog.md`;
7. a new decision record when the rationale is non-obvious or supersedes an earlier decision.

Update only documents whose claims changed. Before handoff, search for removed or renamed commands, paths, and product names, then run every affected documented validation command.

Repository documentation, READMEs, agent instructions, examples, and release notes are written in English. Private user-authored project and task content may use the user's preferred language.

Do not copy structured project facts from private `AGENT_OS_HOME/config/projects.yaml` into these documents. This directory describes the model and how to use the registry; the registry owns each installation's project data.
