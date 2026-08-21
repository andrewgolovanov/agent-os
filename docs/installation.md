# Install Agent OS

Agent OS has two user-facing packages: the Codex plugin and the native macOS
app. Each package contains the same minimal runtime and can initialize the
shared private home independently. A normal installation does not require a
manual repository checkout.

## Requirements

- macOS or Linux with Ruby for the packaged control plane;
- Node.js for the Codex MCP server;
- Codex desktop or CLI with plugin support;
- Apple Silicon (`arm64`) with macOS 14 or newer for the current downloadable
  native app; an Intel or universal binary is not included yet;
- Swift 6.2 only when building the native app from source.

## 1. Install the Codex plugin

Add the public Git marketplace at the release tag you want to install, then add
the Agent OS plugin from that marketplace:

```bash
codex plugin marketplace add andrewgolovanov/agent-os --ref v0.7.1
codex plugin add agent-os@agent-os
```

For a later release, replace `v0.7.1` with the latest published `vN.N.N` tag
shown on the [Agent OS Releases page](https://github.com/andrewgolovanov/agent-os/releases).
Codex downloads and manages the plugin snapshot; the user does not clone or
maintain the Agent OS repository.

Start a fresh Codex task. Plugin startup creates `~/.agent-os` when it does not
exist, copies no project code, records the packaged runtime selected for that
plugin version, and idempotently registers the current task's local project root
in the private project registry whether or not Git exists. An existing valid development checkout selected through
`AGENT_OS_SOURCE_ROOT` or the private source pointer remains authoritative and
is never replaced by packaged bootstrap.

The plugin ships Task Board MCP tools, project onboarding, the Context Loop
skill, setup skills, and the Task Bridge hook bundle. Review the exact hook
commands with `/hooks`; approve them only if they resolve to the installed
`agent-os@agent-os` plugin. A running task cannot hot-reload a newly installed
or updated plugin.

If an older installation still lists `context-loop@agent-os` separately,
install the newer Agent OS snapshot first, start a fresh task, and verify that
`$context-loop` is available from `agent-os@agent-os`. Then remove only the
obsolete plugin registration:

```bash
codex plugin remove context-loop@agent-os
```

This removes the redundant installed plugin snapshot; it does not delete any
project `.context-loop/` state.

The installed Agent OS plugin also carries the deterministic Slack monitor
runbook and its optional-integration guide. No documentation checkout is
required for that workflow.

## 2. Automatic project sync and manual onboarding

On first launch, the macOS app uses public Codex App Server `thread/list`
metadata for active, non-archived tasks. It passes only their `cwd` values to
the packaged runtime. Existing deterministic local roots are registered
automatically, including folders without Git; the app does not call
`thread/read`, import task text, or create Task Board outcomes. The runtime
deduplicates nested folders and normalized origins, uses stable suffixes for
same-name roots, prefers a durable checkout over a transient
`.codex/worktrees` path, and skips missing paths, ambiguous overlaps, duplicate
origins, and worktrees with no durable checkout.

The plugin applies the same idempotent operation to the current `cwd` on each
new Codex task before Task Bridge resolves project routing. When Git is added
later at the exact project root, the same operation attaches the verified
repository and fills a later origin without changing the project key, tasks, or
Slack mappings. Automatic sync may link a stable Slack channel only when its
normalized name has one exact non-conflicting registered project owner, and may
attribute only unfinished unassigned outcomes. It never reads Slack history,
moves a repository, or changes Git state.

Use manual onboarding for an ambiguous or multi-repository topology, relinking,
or ambiguous Slack channel reconciliation. A local-only project can also be
previewed explicitly with `agent-os sync-codex-projects --directory PATH` and
applied only after reviewing the same command with `--apply`.

Open an existing Git repository from any location on the computer and ask:

```text
Onboard this repository into Agent OS safely.
```

The onboarding skill resolves the Git root, remote, branch, and current HEAD,
previews the exact private registry change, and waits for approval before
applying it. It creates no folder under `~/.agent-os/projects` and writes no
Agent OS metadata inside the project repository. Onboarding never moves,
clones, renames, commits, or pushes the repository. Once registered, Agent OS
and Codex can open that project through its absolute path; no common
`projects/` parent folder is required.

### Move an already registered project

Agent OS does not move repositories. Move a project only when you deliberately
want to reorganize the computer, then open the repository from its new location
and ask:

```text
Relink this registered Agent OS project to its current folder safely.
```

The plugin checks the new Git root and origin against the registered identity,
previews the private registry change, and updates only those paths after
approval. Git history, remotes, branches, and project files remain untouched.

## 3. Install the macOS app

Download the app zip and matching `.sha256` file from the same GitHub Release.
The first downloadable package targets Apple Silicon (`arm64`) on macOS 14 or
newer.

```bash
shasum -a 256 -c AgentOS-VERSION-macOS.zip.sha256
```

Unzip the archive and move `Agent OS.app` to `/Applications` or
`~/Applications`. On first launch, the app initializes the same private home as
the plugin and selects its bundled runtime if a newer packaged runtime is
needed. Whichever component starts first can perform this bootstrap; repeated
launches are idempotent.

The app and plugin communicate only through local private Agent OS files. They
do not create a second hosted task database, and neither requires the source
repository after installation.

### First launch on macOS

1. Try to open Agent OS once. macOS should block the launch because Apple
   cannot verify the developer.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and
   click **Open Anyway** for Agent OS.
3. Confirm **Open** and authenticate when macOS asks.

macOS saves that app as an exception, so later launches work normally. Apple
notes that **Open Anyway** is available for about an hour after the blocked
launch. Do not disable Gatekeeper globally and do not use this override for an
archive whose source or checksum you cannot verify. See
[Apple's current instructions](https://support.apple.com/guide/mac-help/mh40616/mac).

## Updates

- The native app checks the latest signed Sparkle appcast once per day and
  notifies before installation by default. Automatic installation is opt-in.
- After the app/runtime advances, **Settings → Updates** compares the installed
  Agent OS Codex plugin with that same release. **Install Codex Plugin Update**
  re-pins only the official Git marketplace from its previous stable tag to the
  app's exact `vN.N.N` tag, reinstalls the plugin, and verifies its full version.
  Start a fresh Codex task afterward.
- **Update Codex plugin automatically after app updates** is a separate opt-in.
  It applies the same tagged flow on app launch. A failed install restores the
  previous marketplace tag; an unpinned, missing, local, or non-official
  marketplace requires manual handling, and a newer plugin is never downgraded.
- The updater does not pass or edit `AGENT_OS_HOME`; private registry and task
  event history are preserved. A normal app/plugin bootstrap may validate and
  re-render derived Task Board projections after installation.
- A valid explicitly selected development checkout remains separate and keeps
  the preview-first tagged Git update flow. Packaged bootstrap never resets or
  overwrites it.

When development is finished, use the CLI from the packaged runtime that should
become authoritative. The first command is preview-only:

```bash
/absolute/path/to/packaged/runtime/bin/agent-os bootstrap \
  --source /absolute/path/to/packaged/runtime \
  --home "$HOME/.agent-os" \
  --replace-source

/absolute/path/to/packaged/runtime/bin/agent-os bootstrap \
  --source /absolute/path/to/packaged/runtime \
  --home "$HOME/.agent-os" \
  --replace-source \
  --apply
```

`--replace-source` is deliberately explicit. Normal app/plugin bootstrap keeps
a valid development checkout selected and cannot perform this transition.

## Development source checkout

Only contributors and advanced local development need the full repository:

```bash
git clone https://github.com/andrewgolovanov/agent-os.git
cd agent-os
./bin/agent-os init --apply
./bin/agent-os activate --apply
./bin/agent-os doctor
```

For a local app build:

```bash
cd apps/agent-os
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME="$HOME/.agent-os" \
./script/build_and_run.sh --verify
```

The bundle is created at `apps/agent-os/dist/Agent OS.app` and includes the
synchronized minimal runtime from `plugins/agent-os/runtime`.

### Migrate an older one-directory development installation

If a development checkout is also the currently active private home, first
select the packaged runtime that should serve the migrated installation. Then
preview every copied and replaced path:

```bash
./bin/agent-os migrate-home \
  --from /absolute/path/to/legacy-agent-os \
  --home "$HOME/.agent-os" \
  --source /absolute/path/to/installed-or-packaged/runtime
```

The migration copies `config/`, `work/`, and `.runtime/` from the legacy home.
If the old registry
still references a legacy Agent OS-managed project folder, its contents are
copied only to `AGENT_OS_HOME/.runtime/legacy-project-backups/` and the registry
is upgraded to `root + repositories`. It never copies, moves, renames, or
rewrites project repositories.
It rejects symbolic links in copied private state, refuses an existing target,
validates the staged registry and Task Board JSON, and switches the active-home
pointer only after the staged home is complete. Apply the reviewed plan with
the same arguments plus `--apply`.

The previous home remains in place for rollback. To select it again, preview
and then apply an explicit replacement:

```bash
./bin/agent-os activate --home /absolute/path/to/legacy-agent-os --replace
./bin/agent-os activate --home /absolute/path/to/legacy-agent-os --replace --apply
```

To create the distributable zip and checksum:

```bash
./script/package_release.sh
```

Before pushing `vN.N.N`, add `docs/releases/vN.N.N.md` with concise
`## ✨ Features` and `## 🐛 Fixes` sections. The release workflow rejects a tag
without both sections, publishes that human-readable summary, and appends a
Full Changelog link starting from the previous published release. Unpublished
intermediate tags therefore do not shorten the public change summary.

The script bundles Sparkle, ad-hoc signs the complete app and its updater
helpers, signs the update archive with the Agent OS Ed25519 key, and verifies
the archive signature before returning. It creates:

- `dist/release/AgentOS-0.7.1-macOS.zip`;
- `dist/release/AgentOS-0.7.1-macOS.zip.sha256`;
- `dist/release/appcast.xml`.

This is not a Developer ID signature and the app is not notarized. Only install
an archive downloaded from the expected Agent OS GitHub release and compare its
checksum before opening it. The current public package and checksum are attached
to [Agent OS v0.7.1](https://github.com/andrewgolovanov/agent-os/releases/tag/v0.7.1):

```bash
shasum -a 256 -c AgentOS-0.7.1-macOS.zip.sha256
```

### App updates

Agent OS checks the latest GitHub Release appcast once per day and exposes
**Check for Updates…** in both the app and menu-bar menus. The default is to
notify before installation. A user can opt into automatic download and install
under **Settings → Updates**.

The app verifies each archive against the embedded Agent OS Ed25519 public key
before extraction. This key is independent of Apple Developer ID. Because the
app still has no Apple-trusted publisher identity, Open Anyway remains part of
the initial install and macOS may request renewed approval after a future
update. Do not promise a zero-prompt Gatekeeper experience without Developer ID.

The GitHub feed must be publicly readable. A private GitHub Release cannot be
checked anonymously by Sparkle; use manual archives until the release is public
or an authenticated feed is intentionally designed.

## Publishing a release

Pushing a `vN.N.N` tag runs `.github/workflows/release.yml`. The workflow runs
the full Agent OS validation against a clean temporary private home, the
publication audit, and the Swift tests. It then builds the ad-hoc app, asserts
that the release executable is `arm64`, signs its Sparkle archive, verifies
the signature, and publishes the zip, checksum, and appcast. It requires one
non-Apple repository secret:

```text
AGENT_OS_SPARKLE_PRIVATE_KEY
```

The corresponding private key must have an independently verified encrypted
recovery copy before publishing with that key. Never commit it. The current key
already has a verified recovery copy. Local release builds use the Keychain
account `agent-os`; CI passes the same exported base64 seed through the secret.


## Verify

```bash
tools/sync-plugin-runtime --check
./bin/agent-os validate
./bin/agent-os audit-publication
```
