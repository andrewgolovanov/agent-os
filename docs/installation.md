# Install Agent OS

Agent OS has three separately installable layers. The core is required; the
Codex plugin and native macOS app are optional views over the same private data.

## Requirements

- macOS or Linux with Ruby 3.x for the core;
- Node.js for the Codex MCP server;
- Codex CLI for plugin installation and Codex handoff;
- Apple Silicon (`arm64`) with macOS 14 or newer for the first downloadable
  native app release; an Intel or universal binary is not included yet;
- Swift 6.2 for building the native app from source.

## 1. Core

Clone the repository, then initialize a private home. Both mutations are
preview-only until `--apply` is present.

```bash
git clone https://github.com/andrewgolovanov/agent-os.git
cd agent-os
./bin/agent-os init
./bin/agent-os init --apply
./bin/agent-os activate
./bin/agent-os activate --apply
./bin/agent-os doctor
```

Reusable source stays in the checkout. Private project paths, task records, and
runtime state live in `~/.agent-os` by default.

## 2. Codex plugin

```bash
./bin/agent-os install-plugin
./bin/agent-os install-plugin --apply
```

This registers the checkout as the `agent-os` marketplace and installs
`agent-os@agent-os`. Start a fresh Codex task after installation or an update;
running tasks do not reload plugin capabilities in place.

The plugin also ships the Task Bridge hook bundle. Review its exact commands in
Codex with `/hooks`, approve them only if they resolve to the installed Agent OS
plugin, and then start a fresh project task. Optional Slack intake and recurring
execution are configured separately; follow [Optional integrations](optional-integrations.md).

For a read-only status that includes these optional layers:

```bash
./bin/agent-os doctor --integrations
```

## Updates

Agent OS updates only from versioned Git tags, never from an arbitrary latest
commit on `main`:

```bash
./bin/agent-os update
./bin/agent-os update --apply
```

The first command is read-only and prints the plan. `--apply` requires a clean
checkout and performs only a fast-forward to the newest `vN.N.N` release. It
refuses local changes and diverged history. If that release changes the Codex
plugin manifest version, the installed plugin snapshot is refreshed and a new
Codex task is required.

The macOS app performs the same core/plugin check at startup. In **Agent OS →
Settings → Updates**, a user can opt into automatic tagged core/plugin updates.
This option is disabled by default.

## 3. macOS app

For a local source build:

```bash
cd apps/agent-os
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME="$HOME/.agent-os" \
./script/build_and_run.sh --verify
```

The bundle is created at `apps/agent-os/dist/Agent OS.app`. It can be copied to
`/Applications` or `~/Applications` for local use.

To create the distributable zip and checksum:

```bash
./script/package_release.sh
```

The script bundles Sparkle, ad-hoc signs the complete app and its updater
helpers, signs the update archive with the Agent OS Ed25519 key, and verifies
the archive signature before returning. It creates:

- `dist/release/AgentOS-0.1.0-macOS.zip`;
- `dist/release/AgentOS-0.1.0-macOS.zip.sha256`;
- `dist/release/appcast.xml`.

This is not a Developer ID signature and the app is not notarized. Only install
an archive downloaded from the expected Agent OS GitHub release and compare its
checksum before opening it. The current public package and checksum are attached
to [Agent OS v0.1.0](https://github.com/andrewgolovanov/agent-os/releases/tag/v0.1.0):

```bash
shasum -a 256 -c AgentOS-0.1.0-macOS.zip.sha256
```

### First launch on macOS

1. Unzip the archive and move `Agent OS.app` to `/Applications` or
   `~/Applications`.
2. Try to open it once. macOS should block the launch because Apple cannot
   verify the developer.
3. Open **System Settings → Privacy & Security**, scroll to **Security**, and
   click **Open Anyway** for Agent OS.
4. Confirm **Open** and authenticate when macOS asks.

macOS saves that app as an exception, so later launches work normally. Apple
notes that **Open Anyway** is available for about an hour after the blocked
launch. Do not disable Gatekeeper globally and do not use this override for an
archive whose source or checksum you cannot verify. See
[Apple's current instructions](https://support.apple.com/guide/mac-help/mh40616/mac).

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
./bin/agent-os validate
./bin/agent-os audit-publication
```
