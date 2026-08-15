# Agent OS for macOS

Agent OS for macOS is the optional native cockpit for the Agent OS control
plane. It renders the canonical Task Board, performs lifecycle changes through
existing Agent OS tools, and creates or opens exact Codex tasks in their
registered project directory.

The app intentionally owns no task database. Durable state remains in:

- `config/projects.yaml` for project identity and repository paths;
- `work/items/*/task.json` through `tools/task-board` for outcomes;
- Codex App Server and `codex://threads/<id>` for execution state and handoff.

`Open new Codex task` creates a named task in the registered project, records its exact membership, copies a prepared continuation prompt, and opens that task in Codex. The app deliberately does not start a background turn: paste and send the prepared prompt when you are ready to begin work.

## Run

```bash
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME=$HOME/.agent-os \
./script/build_and_run.sh --verify
```

The private home defaults to `~/.agent-os`. The source checkout is read from
`AGENT_OS_SOURCE_ROOT` or from `~/.agent-os/source-path`, which `agent-os init`
creates. A non-default home selected by `agent-os activate` is discovered from
the user config pointer. `WORKSPACE_CONSOLE_ROOT` remains a deprecated
compatibility alias for older one-directory installations.

For reproducible appearance QA without changing the system setting:

```bash
open -n "dist/Agent OS.app" --args --force-light-appearance
open -n "dist/Agent OS.app" --args --force-dark-appearance
```

The companion plugin is maintained once at `../../plugins/agent-os`.

## Updates

The app uses Sparkle 2.9.5 with the stable latest GitHub Release appcast. It
checks app updates automatically once per day and notifies by default. Users can
enable automatic download/install in Settings. The same Settings pane checks
the source checkout and Codex plugin through preview-first `agent-os update`;
automatic tagged core/plugin updates are a separate opt-in.

Every app archive is signed by the Agent OS Ed25519 update key and verified
before extraction. Only the public key is present in source. Developer ID and
notarization remain intentionally absent, so the installation guide's
Gatekeeper boundary still applies.

## Package

```bash
./script/package_release.sh
```

This produces an ad-hoc signed zip, SHA-256 checksum, and signed-archive Sparkle
appcast under `dist/release`. There is no Developer ID or notarization workflow.
A downloaded copy requires the user to approve its first launch through
**System Settings → Privacy & Security → Open Anyway**. Full installation,
update, and checksum steps are in `../../docs/installation.md`.
