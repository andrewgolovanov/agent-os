# Architecture

## Goal

Agent OS reduces the cost of switching between projects and preserves working context without becoming an unreliable copy of external systems or project repositories.

## Layers

```text
Human entry point      README.md or installed app/plugin
Agent routing          packaged skills + registered project AGENTS.md
Structured facts       AGENT_OS_HOME/config/projects.yaml
Durable documentation docs/
Project context        registered project and repository roots
Reusable workflows     installed plugin skills or .agents/skills/<skill>/
Deterministic helpers  selected packaged/development runtime
Durable task state     AGENT_OS_HOME/work/items/<task-id>/
Project time reports   AGENT_OS_HOME/work/reports/project-time/
Ephemeral cursors      AGENT_OS_HOME/.runtime/dispatcher/
Ephemeral task hooks   AGENT_OS_HOME/.runtime/task-bridge/
Optional operator UI   installed Agent OS.app
```

Each layer has one purpose. The root `AGENTS.md` routes work without duplicating architecture. Skills describe executable procedures without becoming encyclopedias. Private `AGENT_OS_HOME/work/` stores current task snapshots and material events, not full chat transcripts.

## Data ownership

| Data | Canonical owner |
| --- | --- |
| Private home, timezone, project keys, aliases, roots, and repository paths | `AGENT_OS_HOME/config/projects.yaml` |
| System model and boundaries | `docs/architecture.md` |
| Verified current readiness | `docs/state.md` |
| Architectural rationale | `docs/decisions/` |
| Project-specific rules and exceptions | registered repository `AGENTS.md` |
| Durable project knowledge | documentation in the registered repository |
| Current goal, state, next action, sources, Codex memberships, and linked-turn time | `AGENT_OS_HOME/work/items/<task-id>/task.json` |
| All-thread project Codex time and monthly rollups | generated `AGENT_OS_HOME/work/reports/project-time/<project>.json` |
| Human-readable task handoff | generated `AGENT_OS_HOME/work/items/<task-id>/STATUS.md` |
| Exact Slack events, watched roots, and cursors | `AGENT_OS_HOME/.runtime/dispatcher/` |
| Exact Codex hook turn, candidate, and checkpoint state | `AGENT_OS_HOME/.runtime/task-bridge/` |
| Slack connection and recurring execution | connected Slack integration and Codex Scheduled |
| Selected executable runtime | `AGENT_OS_HOME/source-path`; packaged runtime by default, explicit valid development checkout when selected |
| Reusable Task Bridge event commands | installed Agent OS plugin hook bundle |
| Repeatable procedures | `.agents/skills/<skill>/SKILL.md` or installed plugin skills |
| Project code, Git history, and CI | the corresponding project repository |
| Issues, PRs, provider state, and conversations | the corresponding external system |

## Project registry

Every project exists only as an entry in private `AGENT_OS_HOME/config/projects.yaml`. `root` defines the working project root, while `repositories` stores verified Git roots and roles. For a normal single-repository project, `root` is the Git root. A repository may live in any user-selected folder.

Project onboarding accepts an existing absolute Git root, verifies its identity, previews the change, and writes only private registry metadata. It does not create `AGENT_OS_HOME/projects`, write Agent OS metadata into the product repository, or move source code. Existing repository `AGENTS.md`, READMEs, and documentation continue to own project-local rules and context.

A multi-repository project uses the same model: one registry entry contains multiple `repositories`, and `root` points to the primary repository. It does not need an Agent OS-owned container.

If a user moves a repository, identity-checked relink updates only `root` and the corresponding repository path in the private registry. Legacy `layout` and `wrapper` fields are accepted only by the one-way `upgrade-project-registry` migration. The migration removes those fields and moves any former managed directory to private `AGENT_OS_HOME/.runtime/legacy-project-backups/`. Agent OS never creates new wrapper directories.

## Security and authority

- Discovery and reads are allowed only inside the selected Agent OS installation and registered paths.
- Project onboarding does not move, clone, or modify repositories.
- External provider tools are read-only by default.
- Commits, pushes, PRs, deployments, messages, and external task mutations require explicit user intent.
- Agent OS does not store secrets, full conversations, or complete build logs.
- Potentially destructive tools require an exact target, validation, and preview or dry-run behavior.

## Continuity layer

Task Board stores structured outcomes, stable source identities, optional short source-display titles, display-only work labels, Codex memberships, and retryable `routing_pending` records. File locking, atomic replacement, and a generated index provide local reliability without SQLite. A Slack source title is a normalized 96-character excerpt from the root message and never replaces its exact permalink identity. A label such as a Slack channel name helps a non-code user group work but is not project identity, source identity, or routing authority. Runtime Slack state is separate from durable task correlation: it retains no message text, and a seen event is not replayed merely because Codex routing temporarily failed.

The user-level Task Bridge handles chats inside registered project paths and already-linked Codex tasks. It creates membership automatically only for one exact task or source match, totals `UserPromptSubmit` to `Stop` turns, and requires a durable checkpoint after material changes. A project path limits the candidate set but never selects an outcome; title and semantic similarity only suggest candidates.

Project Time independently accounts for every Codex turn inside a registered project, whether or not it is linked to an outcome. Its project ledger does not alter outcome lifecycle and must not be added to Task Board time because linked turns already appear in the project total. Historical paths and exact exclusions belong to the project registry, and generated reports aggregate completed intervals by month in the Agent OS timezone.

Slack Monitor is one Agent OS-wide read-only heartbeat. It collects direct mentions, incoming DMs and group DMs, and active watched roots. Project channels provide attribution rather than ambient full-channel scanning. An actionable signal from a named channel may attach a `slack:<channel_id>` label with the current `#channel-name`; DMs never use participant names as labels. It may retain only the normalized short root-message title in the private Task Board source record; replies, full messages, authors, cursors, and dispositions keep their existing owners and privacy boundaries. Its short prompt references canonical `AGENT_OS_HOME/config/monitors.yaml` and the installed `docs/slack-monitor.md`; policy is not copied into the automation. The cursor advances only after a complete scan.

Optional integration setup keeps owners separate. The Agent OS CLI manages private monitor configuration, the plugin bundle supplies hook commands, the connected Slack integration owns provider access, and Codex Scheduled owns recurring execution. The setup skill coordinates these steps without storing credentials or emulating a missing product API.

Packaged bootstrap also preserves ownership. Versioned plugin and app bundles contain a read-only runtime payload, `AGENT_OS_HOME` owns mutable state and the selected runtime pointer, and project repositories remain independent Git roots. The first component to run performs idempotent bootstrap; the other reuses the same private home.

The macOS app is a replaceable presentation and action layer over these owners. It has no separate task database and mutates state only through deterministic Agent OS tools. It creates and names an idle Codex task through the stable App Server `stdio` API, records exact membership, copies the prepared prompt, and opens the public `codex://threads/<id>` handoff. Turn start stays in Codex so two App Server clients do not compete for one task.

Slack notifications open the native Board through `agent-os://board`. The deep link selects and refreshes the view; it carries no task content and creates no second storage path.

The update plane has no separate database. Core and plugin updates accept only version-tag fast-forwards through preview-first CLI behavior. The app consumes an Ed25519-signed archive from the appcast of one GitHub Release. Automatic installation is a separate user opt-in, and updates never target private home data.

## Intentionally deferred

- a verified cross-version and second-Mac update pilot;
- Slack, GitHub, or other provider writes;
- Daily Chores and Trackline integrations;
- mutating project or repository auto-discovery.

A new layer is added only after repeated real work establishes its need. Continuity comes before telemetry or broader automation.
