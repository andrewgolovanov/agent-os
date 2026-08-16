# Extending Agent OS

## Principle

An extension starts with observed pain, not directory symmetry. A new layer must reduce repeated work or risk and must have one clear data owner.

## Choose the smallest mechanism

| Signal | Add |
| --- | --- |
| One durable rule is needed | a rule in the owning document or `AGENTS.md` |
| The rule applies to one project | the registered repository `AGENTS.md` |
| One workflow has repeated at least twice | a focused skill |
| Exact commands repeat or an operation is fragile | a validated script or tool |
| A compact handoff must survive chats | a Task Board outcome in private `AGENT_OS_HOME/work/` |
| Many outcomes need exact search and correlation | the structured Task Board |
| One external event repeatedly triggers the same work | automation after authority, retry, and idempotency boundaries are defined |

## New documentation

Before creating a document, answer:

1. Which question does it own exclusively?
2. Who reads it and under which trigger?
3. Which existing document stops owning this information?
4. How can the claim be checked for staleness?

If these questions have no clear answers, extend the existing owning document. Repository documentation and examples are written in English; private user-authored task and project content may use the user's preferred language.

## New skill

Repository-scoped skills live in `.agents/skills/<skill-name>/`. Each skill:

- solves one job;
- has `SKILL.md` with `name` and a precise `description`;
- uses imperative steps and explicit inputs and outputs;
- has no independent README, changelog, or duplicate general documentation;
- adds `scripts/`, `references/`, or `assets/` only when required;
- passes `quick_validate.py` from the system `skill-creator`.

This location follows the [official Codex skills documentation](https://learn.chatgpt.com/docs/build-skills), which defines `.agents/skills` as repository scope.

Package a workflow in a plugin when it must work without a source checkout or ship with a connector or MCP server. Otherwise a repository-scoped skill remains simpler and more transparent.

## Plugin branding

`apps/agent-os/Resources/AppIcon.svg` is the canonical Agent OS mark. The unified plugin stores an archived copy at `assets/agent-os-icon.svg` because an installed plugin archive cannot reference files outside itself. `interface.composerIcon`, `interface.logo`, and `interface.logoDark` point to the bundled copy, while `interface.websiteURL` points to the public repository. `node test/plugin_packages_test.mjs` verifies both the icon and repository link.

## Bundled runtime

`plugins/agent-os/runtime` is generated package payload, not a second source of truth. `tools/sync-plugin-runtime` owns a narrow allowlist of canonical runtime files. After changing any of them:

1. update the plugin cachebuster only with the system `plugin-creator` helper;
2. run `tools/sync-plugin-runtime --apply`;
3. run `tools/sync-plugin-runtime --check`;
4. run plugin package tests and Swift package and release tests.

The native packager copies the same payload to `Contents/Resources/AgentOSRuntime`. Do not add product documentation, tests, private state, Git metadata, or project source to the runtime. A new bundled file must be required for clean-home bootstrap, onboarding, or canonical MCP or app operations and must have an isolated test.

## New tool

A tool requires:

- a narrow operation and stable input contract;
- `--help` or clear usage;
- validation before every write;
- preview or dry-run behavior for potentially dangerous changes;
- atomic structured-state writes where applicable;
- clear exit codes;
- tests against a temporary fixture or safe target.

Do not create placeholder tools without a working scenario.

## New integration or automation

Before enabling an integration, define:

- the external source of truth;
- minimum permissions;
- read and write authority;
- an idempotency key or de-duplication identity;
- retry and partial-failure semantics;
- what is stored locally and what must never be stored;
- human approval points;
- disable and recovery procedures.

The first pilot should be read-only or draft-only. Automatic external writes are enabled separately.
