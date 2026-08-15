# <img src="apps/agent-os/Resources/AppIcon.svg" alt="Agent OS icon" height="42" align="absbottom"> Agent OS

**A local-first Codex task board, MCP plugin, and native macOS app for managing
AI-agent work across multiple projects.**

Agent OS gives OpenAI Codex work a durable, cross-project control plane. It
combines a visual task board, project routing, exact Codex task correlation,
pull-request and source context, optional read-only intake, and installable
plugins in one portable setup.

## Why Agent OS?

Long-running Codex work becomes difficult to track when outcomes, project
routing, pull requests, source links, time, and follow-up tasks are spread
across separate chats. Agent OS keeps that operational context local and makes
it visible through a native macOS task board and MCP tools.

Agent OS does not replace your project repositories, GitHub, Slack, or Codex.
It gives those systems a small, deterministic continuity layer without copying
transcripts or introducing another hosted task database.

![Agent OS demo showing Focus, Board, task details, pull request status, and sources](docs/assets/agent-os-demo.gif)

## Installation

Requirements: macOS or Linux, Ruby, and Node.js. The first downloadable macOS
app release supports Apple Silicon (`arm64`) on macOS 14 or newer; an Intel or
universal binary is not included yet. Swift is needed only to build the optional
macOS app from source, and the Codex CLI is needed only for Codex handoff
features.

```bash
git clone https://github.com/andrewgolovanov/agent-os.git
cd agent-os
./bin/agent-os init
./bin/agent-os init --apply
./bin/agent-os activate --apply
./bin/agent-os doctor
./bin/agent-os install-plugin
./bin/agent-os install-plugin --apply
./bin/agent-os update
./bin/agent-os validate
```

`init` and `activate` are preview-only until `--apply` is supplied. Initialization creates private state in
`~/.agent-os` by default and never overwrites existing configuration. Choose a
different private home with `--home /absolute/path` or `AGENT_OS_HOME`;
`activate` records that selection for app and plugin processes.

After initialization, use the `onboard-project` skill to register an existing
repository. Create a durable outcome with:

```bash
./tools/task-board create \
  --title "Ship the verified change" \
  --project PROJECT_KEY \
  --goal "Describe the stable result" \
  --next-action "Describe one concrete next step"
```

## Source and private state

The checkout contains reusable product source:

```text
agent-os/
├── apps/agent-os/              optional native macOS app
├── bin/agent-os                setup, doctor, update, validate, publication audit
├── config/examples/            sanitized configuration templates
├── docs/                       architecture and runbooks
├── lib/ and tools/             deterministic control plane
├── plugins/                    Agent OS and optional Context Loop plugins
├── templates/                  project wrapper template
└── test/                       isolated and clean-home verification
```

Each user's private home owns `config/*.yaml`, `work/`, `.runtime/`, and local
project checkouts. Those paths are ignored when the checkout itself is also the
active home, so real tasks, provider identifiers, and repository paths cannot
enter a release candidate accidentally.

## Codex plugin

`install-plugin` previews its changes first. With `--apply`, it registers this
checkout as the `agent-os` marketplace and installs `agent-os@agent-os`. Start a
fresh Codex task afterward so Codex loads the new MCP tools and skill.

The plugin also contains the Task Bridge hooks and the `setup-agent-os` skill.
Review the hook commands with `/hooks`, start a fresh task, and ask `Set up
optional Agent OS integrations safely.` Slack and recurring monitoring remain
separate opt-ins; see [Optional integrations](docs/optional-integrations.md).

The local Slack monitor configuration is preview-first:

```bash
./bin/agent-os configure-slack-monitor --timezone Europe/Madrid
./bin/agent-os configure-slack-monitor --timezone Europe/Madrid --apply
./bin/agent-os doctor --integrations
```

`update` is also preview-first. `update --apply` accepts only a clean
fast-forward to the newest `vN.N.N` release tag, preserves the private home, and
refreshes the installed plugin when its manifest version changes. Dirty or
diverged checkouts are never reset.

## Optional macOS app

```bash
cd apps/agent-os
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME="$HOME/.agent-os" \
./script/build_and_run.sh --verify
```

The app owns no database. It reads the private registry and invokes the source
checkout's `tools/task-board` executable with argument arrays.

For a release artifact, run `./script/package_release.sh`. It creates an ad-hoc
signed zip, SHA-256 checksum, and Sparkle appcast without Developer ID or
notarization. The app checks releases automatically, notifies by default, and
offers opt-in automatic install. macOS will block the first launch until the
user explicitly approves the app in Privacy & Security; see the installation
guide for the exact flow and update trust boundary.

## Safety and publication

Integrations are opt-in and read-only by default. Initialization does not enable
hooks, schedules, Slack access, repository writes, commits, pushes, or deploys.
Plugin installation makes its hook bundle available, but Codex still requires
the user to review trust with `/hooks`; the Slack connection and Scheduled task
remain separately controlled product state.

Before publishing a candidate, run:

```bash
./bin/agent-os audit-publication
```

The audit is a release gate for known private paths, provider identities,
client-specific history, Codex task IDs, and obvious credential material. It
complements, but does not replace, a dedicated secret scanner and manual review.

See [installation](docs/installation.md), [the documentation map](docs/README.md), [Agent OS distribution](docs/agent-os.md),
and [the security policy](SECURITY.md).

## Contributing

Documentation is part of a complete change. Update the nearest `AGENTS.md` when
agent workflows, commands, paths, validation, or ownership rules change; update
the relevant README when installation, usage, or other user-facing behavior
changes. Material product changes must also update their owning document,
`docs/state.md`, and `docs/changelog.md`. Before handoff, search for stale
renamed or removed identifiers and run every documented validation command that
was changed. Only affected documents should be edited—there is no requirement
to touch every README or instruction file mechanically.

## License

MIT
