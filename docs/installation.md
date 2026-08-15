# Install Agent OS

Agent OS has two user-facing packages: the Codex plugin and the native macOS
app. Each package contains the same minimal runtime and can initialize the
shared private home independently. A normal installation does not require a
manual repository checkout.

## Requirements

- macOS or Linux with Ruby for the packaged control plane;
- Node.js for the Codex MCP server;
- Codex desktop or CLI with plugin support;
- Apple Silicon (`arm64`) with macOS 14 or newer for the first downloadable
  native app release; an Intel or universal binary is not included yet;
- Swift 6.2 only when building the native app from source.

## 1. Install the Codex plugin

Add the public Git marketplace at the release tag you want to install, then add
the Agent OS plugin from that marketplace:

```bash
codex plugin marketplace add andrewgolovanov/agent-os --ref v0.2.0
codex plugin add agent-os@agent-os
```

For a later release, replace `v0.2.0` with the latest published `vN.N.N` tag
shown on the [Agent OS Releases page](https://github.com/andrewgolovanov/agent-os/releases).
Codex downloads and manages the plugin snapshot; the user does not clone or
maintain the Agent OS repository.

Start a fresh Codex task. Plugin startup creates `~/.agent-os` when it does not
exist, copies no project code, and records the packaged runtime selected for
that plugin version. An existing valid development checkout selected through
`AGENT_OS_SOURCE_ROOT` or the private source pointer remains authoritative and
is never replaced by packaged bootstrap.

The plugin ships Task Board MCP tools, project onboarding, skills, and the Task
Bridge hook bundle. Review the exact hook commands with `/hooks`; approve them
only if they resolve to the installed `agent-os@agent-os` plugin. A running task
cannot hot-reload a newly installed or updated plugin.

## 2. Onboard a project from any folder

Open an existing Git repository from any location on the computer and ask:

```text
Onboard this repository into Agent OS safely.
```

The onboarding skill resolves the Git root, remote, branch, and current HEAD,
previews the exact private registry and wrapper changes, and waits for approval
before applying them. It never moves, clones, renames, commits, pushes, or
writes files inside the project repository. Once registered, Agent OS and Codex
can open that project through its absolute path; no common `projects/` parent
folder is required.

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

- Codex updates Agent OS by installing a newer versioned marketplace snapshot;
  start a fresh task afterward.
- The native app checks the latest signed Sparkle appcast once per day and
  notifies before installation by default. Automatic installation is opt-in.
- A valid explicitly selected development checkout remains separate and keeps
  the preview-first tagged Git update flow. Packaged bootstrap never resets or
  overwrites it.

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

To create the distributable zip and checksum:

```bash
./script/package_release.sh
```

The script bundles Sparkle, ad-hoc signs the complete app and its updater
helpers, signs the update archive with the Agent OS Ed25519 key, and verifies
the archive signature before returning. It creates:

- `dist/release/AgentOS-0.2.0-macOS.zip`;
- `dist/release/AgentOS-0.2.0-macOS.zip.sha256`;
- `dist/release/appcast.xml`.

This is not a Developer ID signature and the app is not notarized. Only install
an archive downloaded from the expected Agent OS GitHub release and compare its
checksum before opening it. The current public package and checksum are attached
to [Agent OS v0.2.0](https://github.com/andrewgolovanov/agent-os/releases/tag/v0.2.0):

```bash
shasum -a 256 -c AgentOS-0.2.0-macOS.zip.sha256
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
that the first-release binary is `arm64`, signs its Sparkle archive, verifies
the signature, and publishes the zip, checksum, and appcast. It requires one
non-Apple repository secret:

```text
AGENT_OS_SPARKLE_PRIVATE_KEY
```

The corresponding private key must also have an offline backup before the
first release. Never commit it. Local release builds use the Keychain account
`agent-os`; CI passes the same exported base64 seed through the secret.


## Verify

```bash
tools/sync-plugin-runtime --check
./bin/agent-os validate
./bin/agent-os audit-publication
```
