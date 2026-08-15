# Current state

Verified: 2026-08-15

## Product source

- The reusable source is public at
  `https://github.com/andrewgolovanov/agent-os` on `main`.
- The initial public commit is
  `7947b27249fd757b44f946b3fa9d6d66f08cfd26`; local `main` and `origin/main`
  were verified at the same SHA after push.
- Agent OS stage 1 is implemented as one monorepo containing the Ruby control
  plane, native Agent OS app source, Agent OS plugin, and optional
  Context Loop plugin.
- MIT licensing is present.
- No GitHub Release or version tag has been published.

## Private instance boundary

- The current installation remains usable as a legacy one-directory source and
  home.
- New installations default to a separate `~/.agent-os` private home.
- Real configs, Task Board state, reports, runtime state, source pointers, and
  local project checkouts are ignored by the source repository.
- The installer is preview-first, does not overwrite existing files, creates no
  project entries, and enables no monitor or provider integration.

## Verified implementation

- `agent-os doctor` passes for the current instance and for a fresh temporary
  home.
- The full Agent OS validator passes against both homes.
- The current and clean-home Ruby suites pass 37 tests and 222 assertions.
- Agent OS app builds and its six Swift tests pass; bundle launch verification
  succeeds with both the active home and a fresh empty private home.
- The Agent OS MCP clean-home test proves that tools execute from the
  source root while task and registry data remain under the private home.
- Both monorepo plugin packages are installed and enabled from the `agent-os`
  marketplace; Context Loop passes its isolated lifecycle/hook smoke test. The
  old installed plugin snapshot has been removed.
- The installed Agent OS MCP snapshot is byte-identical to source and
  discovers the active private home without injected environment variables.
- The official plugin validator is currently unavailable in the local Python
  runtimes because `PyYAML` is absent. No dependency was installed implicitly.
- The built-in publication audit reports zero known private-state boundary
  findings for the current candidate.
- Preview-first `install-plugin` works against the local marketplace. The macOS
  packager produces an ad-hoc signed `AgentOS-0.1.0-macOS.zip`, SHA-256
  checksum, and Sparkle appcast for user-approved Gatekeeper installation.
- The packaged app passes strict `codesign` bundle verification. `spctl`
  rejects it at the expected trust-policy boundary because there is no Developer
  ID; this is the condition covered by the documented `Open Anyway` flow.
- Preview-first `agent-os update` discovers semantic release tags and only
  fast-forwards a clean checkout; dirty-checkout preservation and successful
  tagged update are covered by isolated Git tests.
- The native app embeds Sparkle 2.9.5, exposes manual and daily checks, and keeps
  automatic app and core/plugin installation as separate user opt-ins.
- The dedicated Agent OS Ed25519 key exists in the local Keychain account
  `agent-os`; only its public key is in source. The generated 0.1.0 archive
  signature was independently verified with CryptoKit.
- All 126 initial publication candidates passed a dedicated Gitleaks 8.30.1
  scan with full redaction, manual filename/content review, `git diff --check`,
  and the built-in publication audit before commit.
- A fresh anonymous HTTPS clone of the pushed SHA passed initialization into a
  separate private home, `doctor`, the complete validator, publication audit,
  and a clean Swift dependency resolution/build with all six tests passing.
- The tag-triggered GitHub Release workflow is present but has not run.

## Not configured

- A published GitHub Release and real cross-version Sparkle update.
- An offline backup of the Agent OS Ed25519 private key and the repository secret
  `AGENT_OS_SPARKLE_PRIVATE_KEY`.
- Fresh Codex task pickup of the newly installed monorepo plugin (the current
  already-open task cannot reload plugin capabilities in place).
- Automated secret scanning on future pull requests and tags; the initial
  candidate received a one-off dedicated scan.
- A release support policy.

Unknown values must remain unknown until verified. Private instance facts belong
in ignored local state, not in this product document.
