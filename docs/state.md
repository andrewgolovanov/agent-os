# Current state

Verified: 2026-08-15

## Product source

- The reusable source is public at
  `https://github.com/andrewgolovanov/agent-os` on `main`.
- The initial public commit is
  `7947b27249fd757b44f946b3fa9d6d66f08cfd26`.
- The accepted native-app redesign and release-candidate assets are committed as
  `e98dc8118585e22d6f6ba2c070a6c146347d1103`; that commit was fast-forwarded to
  public `main` and verified against `origin/main` after push.
- Agent OS stage 1 is implemented as one monorepo containing the Ruby control
  plane, native Agent OS app source, Agent OS plugin, and optional
  Context Loop plugin.
- MIT licensing is present.
- No GitHub Release or version tag has been published.
- Documentation maintenance is now part of the repository completion contract:
  affected agent instructions, human README guidance, and owning product docs
  are updated in the same change and stale renamed identifiers are searched
  before handoff.
- The current release candidate adds a complete opt-in integration path without
  changing provider state: preview-first Slack monitor configuration,
  plugin-bundled Task Bridge hooks, a Codex setup skill, Scheduled task prompt,
  recovery instructions, and optional doctor checks.

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
- The current and clean-home Ruby suites pass 39 tests and 256 assertions.
- Agent OS app builds and its 16 Swift tests pass; bundle launch verification
  succeeds with both the active home and a fresh empty private home.
- The app now maps the official shadcn default Neutral dark tokens directly into
  SwiftUI: `#0a0a0a` canvas, `#171717` sidebar/cards, `#262626` interactive
  accents, 10% borders, 15% input borders, and `#a3a3a3` secondary text. Large
  gray column fills and AppKit's default sidebar selection were removed. The
  native controls follow the dashboard-01 48/36/32-point toolbar/default/compact
  sizing and the shadcn radius scale. Status badges retain text and distinct
  icons while Active is green, Waiting amber, Review blue, Planned violet,
  Inbox neutral, Done emerald, and Cancelled red. Focus rows also expose the
  registered project display name in a compact folder badge.
- The task detail is no longer a permanent empty third column or animated
  inspector sheet. Real-window accessibility and screenshot QA verified a
  closed-at-launch, open-on-selection, resizable native split with explicit
  close and restored full-width Board behavior. Its open state now dims and
  disables the Focus or Board pane with a translucent backdrop that closes the
  detail on click while leaving the inspector, toolbar, and project sidebar
  unobscured.
- The sidebar color and AppKit-backed divider now continue through the titlebar
  and content while SwiftUI remains the state owner. The native sidebar toggle
  sits on that same surface; live-window QA verified hide and restore retain the
  sidebar/canvas titlebar split and divider. The split is capped at the accepted
  compact 240-point width instead of restoring the prior 288-point expansion.
  Compact icons align with the first line of two-line rows. Detail sections use
  a continuous document rhythm, tracked time is visible in the detail header and
  every Board card, and source rows expose link/hover affordances.
- The Agent OS application icon preserves the user-supplied canonical glyph
  paths without redrawing or aspect-ratio distortion. Its macOS composition
  adds a transparent outer margin, a rounded near-black tile, and deliberate
  inner spacing; the menu-bar extra renders the same paths as an enlarged
  18-point monochrome template without the tile.
- Lifecycle and project selection now share one 36-point SwiftUI control with
  the form inputs: balanced padding, one chevron, a flat token-owned popover,
  and automatic edge placement that remains visible near window boundaries.
  The title placeholder is vertically centered while multiline placeholders
  remain top aligned.
- Real-window QA verified Slack workspace/channel/date context, Figma file
  context, and authenticated read-only GitHub enrichment of PR title, branches,
  and a visible merged/open/draft/closed status. Pull requests now appear
  directly below the inspector header for quick access and are not duplicated
  in the lower Sources section. The local fallback remains available when `gh`
  is missing or unauthenticated.
- The canonical Agent OS `A` mark is stored as the supplied path geometry in a
  rounded, padded SVG app-icon composition and as a reproducibly generated
  multi-resolution ICNS asset. Both development and release packagers copy it
  into `Contents/Resources` and declare it through `CFBundleIconFile`.
- The Agent OS MCP clean-home test proves that tools execute from the
  source root while task and registry data remain under the private home.
- Both monorepo plugin packages are installed and enabled from the `agent-os`
  marketplace; Context Loop passes its isolated lifecycle/hook smoke test. The
  old installed plugin snapshot has been removed.
- The installed Agent OS MCP snapshot is byte-identical to source and
  discovers the active private home without injected environment variables.
- Two fresh non-interactive Codex tasks loaded the installed Agent OS skill and
  successfully invoked the real `agent_os_list_tasks` and
  `agent_os_list_projects` MCP tools. A separately vetted automation smoke also
  executed the plugin's Task Bridge hook bundle against an isolated clean home.
- The official plugin validator passes for `plugins/agent-os` in an isolated
  temporary Python environment, and the new `setup-agent-os` skill passes its
  dedicated validator. No project or global Python dependency was added.
- A fresh private home whose path contains spaces passed initialization,
  Slack-monitor preview/apply, optional doctor checks, the plugin hook runner,
  and the full Agent OS validation. The command preserves an identical monitor
  and refuses a differing entry unless `--replace` is explicitly supplied.
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
- The matching GitHub Actions secret `AGENT_OS_SPARKLE_PRIVATE_KEY` is configured
  for the public repository. Its value was transferred from Keychain through a
  validated temporary file that was overwritten and removed after upload.
- All 126 initial publication candidates passed a dedicated Gitleaks 8.30.1
  scan with full redaction, manual filename/content review, `git diff --check`,
  and the built-in publication audit before commit.
- A fresh anonymous HTTPS clone of the redesign commit passed initialization
  into a separate private home, `doctor`, the complete validator, 37 Ruby
  tests/222 assertions, both plugin package checks, 15 Swift tests, and the
  publication audit.
- The tag-triggered GitHub Release workflow is present but has not run.
- The release workflow now initializes a clean temporary private home, runs the
  complete Agent OS validator and publication audit before Swift packaging, and
  refuses the first release unless the packaged executable is Apple Silicon
  (`arm64`).

## Not configured

- A published GitHub Release and real cross-version Sparkle update.
- An offline backup of the Agent OS Ed25519 private key.
- End-user hook trust remains a per-install Codex choice; the release source
  cannot pre-approve it for another user.
- A connected Slack integration and Codex Scheduled task for a clean user; the
  local CLI intentionally cannot inspect or create either product-owned state.
- Automated secret scanning on future pull requests and tags; the initial
  candidate received a one-off dedicated scan.
- A release support policy.

Unknown values must remain unknown until verified. Private instance facts belong
in ignored local state, not in this product document.
