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
| Private home, timezone, project keys, aliases, roots, repository paths, and stable Slack channel mappings | `AGENT_OS_HOME/config/projects.yaml` |
| System model and boundaries | `docs/architecture.md` |
| Verified current readiness | `docs/state.md` |
| Architectural rationale | `docs/decisions/` |
| Project-specific rules and exceptions | registered project-root `AGENTS.md` |
| Durable project knowledge | documentation in the registered project root or repository |
| Current goal, state, next action, sources, Codex memberships, and linked-turn time | `AGENT_OS_HOME/work/items/<task-id>/task.json` |
| All-thread project Codex time and monthly rollups | generated `AGENT_OS_HOME/work/reports/project-time/<project>.json` |
| Human-readable task handoff | generated `AGENT_OS_HOME/work/items/<task-id>/STATUS.md` |
| Exact Slack events, watched roots, and cursors | `AGENT_OS_HOME/.runtime/dispatcher/` |
| Exact Codex hook turn, candidate, and checkpoint state | `AGENT_OS_HOME/.runtime/task-bridge/` |
| Slack connection and recurring execution | connected Slack integration and Codex Scheduled |
| Selected executable runtime | `AGENT_OS_HOME/source-path`; packaged runtime by default, explicit valid development checkout when selected |
| Reusable Task Bridge event commands | installed Agent OS plugin hook bundle |
| Repeatable procedures | `.agents/skills/<skill>/SKILL.md` or installed plugin skills |
| Project code | the corresponding local project root |
| Optional Git history and CI | the corresponding project repository |
| Issues, PRs, provider state, and conversations | the corresponding external system |

## Project registry

Every project exists only as an entry in private `AGENT_OS_HOME/config/projects.yaml`. `root` defines the working project root, `repositories` optionally stores verified Git roots and roles, and optional `slack_channels` records stable channel IDs that belong to the project. A local project is valid with `repositories: []` for its entire lifetime. When Git is initialized later at the same root, Agent OS enriches that project entry instead of replacing its key, Task Board attribution, Slack mappings, or history. A repository may live in any user-selected folder.

Automatic Codex synchronization is a narrow registry-only path. The macOS app
pages through public App Server metadata for active, non-archived tasks and
passes only unique `cwd` values to the shared runtime. The plugin hook passes
the current task `cwd` before Task Bridge routing. The runtime registers
deterministic existing local project directories, deduplicates nested paths,
uses stable path-derived suffixes for same-name projects, normalizes Git
working directories to their repository roots, and prefers a durable checkout
over transient Codex worktrees. Existing local-only entries are enriched when
a committed Git root appears at the exact project root and refreshed when a
previously unknown origin becomes available. Missing paths, ambiguous overlaps,
duplicate origins, and worktree-only candidates are skipped. The private Agent
OS home and its internal paths remain operational state and are never registered
as projects. After project registration, the same operation may link a Task
Board Slack channel label only when its normalized name resolves to exactly one
registered project, no other project owns the stable channel ID, and every
labeled outcome is unassigned or already belongs only to that project. It may
attribute unfinished unassigned outcomes, but never rewrites completed or
conflicting attribution. This does not read Slack, import Slack history, or
create outcomes. Synchronization never reads Codex thread bodies or changes
repository files or Git state.

Manual project onboarding accepts an existing absolute Git root, verifies its identity, and previews the registry change. A conservative channel-name comparison may suggest existing unfinished Slack-only work, but it never selects a channel automatically. After a second preview with exact reviewed channel IDs, apply records those mappings and may assign only unfinished outcomes that currently have no project; existing attribution and card labels are preserved. Onboarding never creates `AGENT_OS_HOME/projects`, writes Agent OS metadata into the product repository, moves source code, or merges outcomes by similar text. Existing repository `AGENTS.md`, READMEs, and documentation continue to own project-local rules and context.

A multi-repository project uses the same model: one registry entry contains multiple `repositories`, and `root` points to the primary repository. It does not need an Agent OS-owned container.

If a user moves a repository, identity-checked relink updates only `root` and the corresponding repository path in the private registry. Legacy `layout` and `wrapper` fields are accepted only by the one-way `upgrade-project-registry` migration. The migration removes those fields and moves any former managed directory to private `AGENT_OS_HOME/.runtime/legacy-project-backups/`. Agent OS never creates new wrapper directories.

## Security and authority

- Discovery and reads are allowed only inside the selected Agent OS installation and registered paths.
- Automatic Codex synchronization may mutate only the private project registry
  for deterministic local project roots, verified same-root repository
  enrichment, and a stable Slack channel mapping with exactly one
  non-conflicting project identity. It may attribute only unfinished unassigned
  outcomes. Manual and ambiguous Task Board reconciliation remain
  preview-first and never overwrite existing attribution.
- External provider tools are read-only by default.
- Commits, pushes, PRs, deployments, messages, and external task mutations require explicit user intent.
- Agent OS does not store secrets, full conversations, or complete build logs.
- Potentially destructive tools require an exact target, validation, and preview or dry-run behavior.

## Continuity layer

Task Board stores structured outcomes, stable source identities, optional short source-display titles, display-only work labels, Codex memberships, and retryable `routing_pending` records. File locking, atomic replacement, and a generated index provide local reliability without SQLite. A Slack source title is a normalized 96-character excerpt from the root message and never replaces its exact permalink identity. A Slack channel label remains presentation metadata on the task card even when its reviewed channel ID is mapped to a registered project. The mapping supplies exact project attribution; it does not replace the label or source identity. Runtime Slack state is separate from durable task correlation: it retains no message text, and a seen event is not replayed merely because Codex routing temporarily failed.

The user-level Task Bridge handles chats inside registered project paths and already-linked Codex tasks. It creates membership automatically only for one exact task or source match, totals `UserPromptSubmit` to `Stop` turns, and requires a durable checkpoint after material changes. A project path limits the candidate set but never selects an outcome; title and semantic similarity only suggest candidates. One session has at most one current outcome membership. Explicit reassignment archives the previous membership and moves only an unfinished turn to the exact target, preserving every completed interval on its original outcome.

Project Time independently accounts for every Codex turn inside a registered project, whether or not it is linked to an outcome. Its project ledger does not alter outcome lifecycle and must not be added to Task Board time because linked turns already appear in the project total. Historical paths and exact exclusions belong to the project registry, and generated reports aggregate completed intervals by month in the Agent OS timezone.

Slack Monitor is one Agent OS-wide read-only heartbeat. It collects direct mentions, incoming DMs and group DMs, and active watched roots. Search enables bot results, while a dynamic inventory of all visible public/private channels supplies the fallback for Block Kit-only app mentions that Slack search may omit. That fallback reads only each channel's bounded new-root window, discards human roots and bot/app roots without an exact current-user mention, and expands matching threads through the same unresolved-actionability rules as human mentions. Project channels still provide attribution rather than scan permission; no channel allowlist is configured. An actionable signal from a named channel may attach a `slack:<channel_id>` label with the current `#channel-name`; DMs never use participant names as labels. It may retain only the normalized short root-message title in the private Task Board source record; replies, full messages, authors, and discarded ambient roots are never persisted. Per-channel cursors retain resumable scan progress, while the global cursor advances only after every source and the complete dynamic inventory succeed. Its short prompt references canonical `AGENT_OS_HOME/config/monitors.yaml` and the installed `docs/slack-monitor.md`; policy is not copied into the automation.

Optional integration setup keeps owners separate. The Agent OS CLI manages private monitor configuration, the plugin bundle supplies hook commands, the connected Slack integration owns provider access, and Codex Scheduled owns recurring execution. The setup skill coordinates these steps without storing credentials or emulating a missing product API.

Packaged bootstrap also preserves ownership. Versioned plugin and app bundles contain a read-only runtime payload, `AGENT_OS_HOME` owns mutable state and the selected runtime pointer, and project repositories remain independent Git roots. The first component to run performs idempotent bootstrap; the app and task-start hook then invoke the same runtime-owned deterministic project synchronization, and the other component reuses the same private home.

The macOS app is a replaceable presentation and action layer over these owners. It has no separate task database and mutates state only through deterministic Agent OS tools. It creates and names an idle Codex task through the stable App Server `stdio` API, records exact membership, copies the prepared prompt, and opens the public `codex://threads/<id>` handoff. Turn start stays in Codex so two App Server clients do not compete for one task.

The app owns a deliberately narrow project-presentation preference: an ordered
list of pinned stable project keys in macOS `UserDefaults`. It affects only the
native sidebar and is not part of `projects.yaml`, Task Board state, project
routing, Slack reconciliation, or the plugin runtime. Missing project keys stay
dormant in the preference so a temporarily unavailable project can recover its
pin. Thread pins are not treated as project pins, and private Codex desktop
storage is not read. Unpinned projects remain alphabetical with folder glyphs;
project icon and color mirroring waits for supported App Server metadata.

Slack notifications open the native Board through `agent-os://board`. The deep link selects and refreshes the view; it carries no task content and creates no second storage path.

The update plane has no separate database. Development core and plugin updates
accept only version-tag fast-forwards through preview-first CLI behavior. The
packaged app consumes an Ed25519-signed archive from the appcast of one GitHub
Release, then uses its bundled runtime manifest as the authority for the
matching plugin version and `vN.N.N` marketplace tag. It can replace only an
already installed plugin from the official stable-tagged Git marketplace; the
operation verifies the resulting version and restores the previous tag on
failure. Automatic app and plugin installation are separate user opt-ins,
newer plugins are not downgraded, and updates never target private home data.

## Intentionally deferred

- a verified cross-version and second-Mac update pilot;
- Slack, GitHub, or other provider writes;
- Daily Chores and Trackline integrations;
- broader project discovery from private Codex desktop state or thread bodies.

A new layer is added only after repeated real work establishes its need. Continuity comes before telemetry or broader automation.
