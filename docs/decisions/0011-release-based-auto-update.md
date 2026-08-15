# 0011 — Release-based Agent OS updates

Date: 2026-08-15

Status: accepted

## Context

Agent OS ships as one source checkout, a cached Codex plugin, and an optional
macOS app. Pulling every commit from `main` would expose users to unreleased
changes, while silently replacing an executable from an unsigned checksum feed
would be unsafe. The app is intentionally distributed without Apple Developer
ID or notarization.

## Decision

- Treat semantic `vN.N.N` Git tags and their GitHub Releases as the only
  automatic update units. Never auto-execute arbitrary `main` commits.
- Keep `agent-os update` preview-only by default. `--apply` may fetch one release
  tag and fast-forward a clean checkout to it; it refuses dirty or diverged
  source trees and never resets user changes.
- Refresh `agent-os@agent-os` after the source update only when its manifest
  version changed. A fresh Codex task is still required to load the new plugin.
- Let the native app check core/plugin status at startup. Automatic core/plugin
  installation is off until the user enables it in Agent OS Settings.
- Use Sparkle 2.9.5 for native app updates. Check once per day by default, notify
  by default, and let each user opt into automatic download and installation.
- Sign every update archive with the dedicated Agent OS Ed25519 key and verify
  it before extraction. Commit only the public key. Keep the private key in the
  release operator's Keychain account `agent-os` and the GitHub Actions secret
  `AGENT_OS_SPARKLE_PRIVATE_KEY`.
- Publish the app zip, SHA-256 checksum, and generated `appcast.xml` together in
  the same GitHub Release. The stable feed is the latest-release asset URL.
- Continue ad-hoc code signing and the explicit macOS Open Anyway first-launch
  flow. Do not introduce Apple Developer ID or notarization credentials.

## Consequences

- One release updates the core, Codex plugin source, and macOS app without
  creating a second hosted task database.
- Core/plugin auto-update remains reversible through Git history and never
  overwrites a customized checkout.
- Compromise of a download URL or checksum alone cannot produce an accepted app
  update without the Agent OS Ed25519 private key.
- Losing the Ed25519 private key is serious because there is no Developer ID
  fallback for rotating trust. The key must be backed up before the first public
  release.
- Gatekeeper still cannot verify the publisher. The first downloaded build
  requires user approval, and a future macOS version may request approval again
  after an update; this must be tested on a second Mac for each release process.
- The updater cannot consume a private GitHub Release anonymously. End-to-end
  public feed verification begins only when the repository/releases are public
  or another authenticated feed is deliberately introduced.
