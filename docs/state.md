# Current state

Verified: 2026-08-17

## Product source

- The reusable source is public at
  `https://github.com/andrewgolovanov/agent-os` on `main`.
- The public repository describes Agent OS explicitly as an open-source,
  local-first task board and macOS control plane for OpenAI Codex, and classifies
  it with discoverability topics covering Codex, MCP, AI agents, macOS,
  developer tools, and local-first workflows.
- The initial public commit is
  `7947b27249fd757b44f946b3fa9d6d66f08cfd26`.
- The accepted native-app redesign and release-candidate assets are committed as
  `e98dc8118585e22d6f6ba2c070a6c146347d1103`; that commit was fast-forwarded to
  public `main` and verified against `origin/main` after push.
- Agent OS stage 1 is implemented as one monorepo containing the Ruby control
  plane, native Agent OS app source, and one Agent OS plugin with the optional
  Context Loop workflow bundled as a skill.
- MIT licensing is present.
- The first public release, `v0.1.0`, is published from commit
  `0d816b4724dc0ef14a2f49f7f0c451e5a1684f8f` at
  `https://github.com/andrewgolovanov/agent-os/releases/tag/v0.1.0`.
- The current public release, `v0.3.0`, is published from commit
  `e9cdf0ab0434a7ad99b36c8b5d1cbe6023d9026a` at
  `https://github.com/andrewgolovanov/agent-os/releases/tag/v0.3.0`.
- Documentation maintenance is part of the repository completion contract:
  affected agent instructions, human README guidance, and owning product docs
  are updated in the same change; public repository Markdown is written in
  English; and stale renamed identifiers are searched before handoff.
- The obsolete source-local `work/README.md` has been removed. Durable outcome
  state and generated reports have exactly one owner under the selected private
  `AGENT_OS_HOME/work`; the public source checkout contains only the Task Board
  contract and implementation.
- The `v0.2.0` release adds a complete opt-in integration path without
  changing provider state: preview-first Slack monitor configuration,
  plugin-bundled Task Bridge hooks, a Codex setup skill, Scheduled task prompt,
  recovery instructions, and optional doctor checks.
- The Agent OS plugin details link their Website field and source metadata to
  the public `andrewgolovanov/agent-os` repository through the Codex-specific
  `interface.websiteURL` contract.
- The `v0.2.0` release removes the manual source-checkout requirement
  for packaged users: the Agent OS plugin contains an allowlisted minimal
  runtime, and the app packager embeds that exact payload.
- Either packaged component bootstraps the shared private home idempotently; a
  valid explicitly selected development checkout remains authoritative.
- MCP and CLI onboarding can preview and register an existing Git repository
  from any absolute location without moving, cloning, renaming, or modifying it.
- Project onboarding now has one registry-only topology: every project records
  `root + repositories` and creates no generated folder under
  `AGENT_OS_HOME/projects`, including multi-repository registrations.
- MCP and CLI one-way registry upgrade remove obsolete `layout` and `wrapper`
  fields while preserving any old managed folder in a private recovery backup
  and leaving repository files and Git state unchanged.
- MCP and CLI relinking can verify a moved repository by its registered origin
  and update only private registry paths.
- Leaving an explicitly selected development checkout now requires the separate
  preview-first `bootstrap --replace-source` action; automatic packaged
  bootstrap continues to preserve valid development selection.

## Private instance boundary

- The current development installation has been migrated from the legacy
  one-directory topology to a separate private home; the source checkout is now
  retained only for Agent OS development.
- New installations default to a separate `~/.agent-os` private home.
- Real configs, Task Board state, reports, runtime state, source pointers, and
  registered project paths are ignored by the source repository. Project code
  remains in its existing repository location.
- The verified local project repositories now live independently of the Agent
  OS source checkout and resolve through absolute paths in the private registry.
- Packaged bootstrap preserves existing files, creates no project entries, and
  enables no monitor or provider integration. Project onboarding remains a
  separate preview-first operation.

## Verified implementation

- `agent-os doctor` passes for the current instance and for a fresh temporary
  home.
- The full Agent OS validator passes against both homes.
- The current Ruby suite passes 65 tests and 539 assertions, including active
  private-home resolution, safe home migration, monitor-path rewriting,
  identity-checked repository relinking, completion follow-up, and Project Time
  reporting contracts.
- Agent OS app builds and its 22 Swift tests pass; bundle launch verification
  succeeds with both the active home and a fresh empty private home.
- Task Board and the Agent OS MCP now support idempotent display-only Slack
  channel labels keyed by `slack:<channel_id>`. The native app presents and
  filters those labels separately from registered projects, so label-only
  outcomes never enable repository routing or Codex project handoff.
- Optional integration guidance now supports a user with no repositories by
  using the active Agent OS home as a non-version-controlled local Scheduled
  project. A bounded connected-Slack smoke verified one named-channel outcome
  with no registered projects; a real product-owned Scheduled execution remains
  unverified.
- The two recurrent native crash signatures are covered at their executor
  boundaries: Task Board filesystem events enter the main-actor watcher on the
  main queue, and the LaunchServices Codex-open callback is a nonisolated
  Sendable continuation bridge. A live canonical Task Board update left the
  rebuilt app running and produced no diagnostic report beyond the recorded
  pre-fix baseline.
- Real-window accessibility and screenshot QA verified that Board lifecycle
  columns scroll vertically and independently inside the horizontal workflow
  canvas, keeping their headers fixed while lower cards remain reachable.
- The native Done view retains all `done` and `cancelled` outcomes with the
  canonical inspector, source and pull-request context, project/completion-
  period/lifecycle/follow-up filters, and a visible summary of exact-linked task
  time. Slack-backed done outcomes
  expose explicit `pending`, `sent`, and `not_required` follow-up states and a
  copyable completion update; no external message is sent automatically.
- Broader generated Project Time ledgers remain available through the CLI and
  private reports. They are intentionally not mixed into Done's exact-linked
  outcome total or exposed as a competing primary navigation page.
- Status-only rows in Done use fixed 24-point circular markers; full
  lifecycle badges continue to retain their text and capsule geometry where
  the label is part of the interface.
- The app now maps the official shadcn default Neutral dark tokens directly into
  SwiftUI: `#0a0a0a` canvas, `#171717` sidebar/cards, `#262626` interactive
  accents, 10% borders, 15% input borders, and `#a3a3a3` secondary text. Large
  gray column fills and AppKit's default sidebar selection were removed. The
  native controls follow the dashboard-01 48/36/32-point toolbar/default/compact
  sizing and the shadcn radius scale. Status badges retain text and distinct
  icons while Active is green, Waiting amber, Review blue, Planned violet,
  Inbox neutral, Done emerald, and Cancelled red. Focus rows also expose the
  registered project display name in a compact folder badge and use the shared
  semantic hover surface with pointer feedback for task selection.
- The task detail is no longer a permanent empty third column or animated
  inspector sheet. Real-window accessibility and screenshot QA verified a
  closed-at-launch, open-on-selection, resizable native split with explicit
  close and restored full-width Board behavior. Its open state now dims and
  disables the Focus or Board pane with a translucent backdrop that closes the
  detail on click while leaving the inspector, toolbar, and project sidebar
  unobscured.
- Development and release bundles register `agent-os://`; the tested
  `agent-os://board`, `agent-os://focus`, and `agent-os://done` destinations
  select, refresh, and foreground the corresponding native view without
  carrying task data outside the canonical private home. `agent-os://history`
  and `agent-os://time` remain compatibility aliases for Done.
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
- The Agent OS MCP clean-home test proves that tools execute from the bundled
  runtime while task and registry data remain under the private home; separate
  CLI tests cover packaged-runtime upgrade and development-source preservation.
- The unified monorepo Agent OS plugin is installed and enabled from the
  `agent-os` marketplace; its bundled Context Loop skill passes the isolated
  lifecycle/hook smoke test. The obsolete standalone Context Loop snapshot has
  been removed.
- The installed Agent OS MCP snapshot is byte-identical to source and
  discovers the active private home without injected environment variables.
- Agent OS exposes the canonical native-app mark for its plugin card,
  dark-mode card, and composer; package validation keeps the archive-local SVG
  byte-identical to the app icon source.
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
- Versioned Git marketplace installation is the packaged-user path; the legacy
  preview-first `install-plugin` command remains available for development
  checkouts. The macOS packager produces an ad-hoc signed app zip, SHA-256
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
- The Ed25519 private key has an independently verified encrypted
  password-manager recovery copy. The temporary export used for that backup was
  validated, overwritten, and removed.
- All 126 initial publication candidates passed a dedicated Gitleaks 8.30.1
  scan with full redaction, manual filename/content review, `git diff --check`,
  and the built-in publication audit before commit.
- A fresh anonymous HTTPS clone of the redesign commit passed initialization
  into a separate private home, `doctor`, the complete validator, 37 Ruby
  tests/222 assertions, both plugin package checks, 15 Swift tests, and the
  publication audit.
- The tag-triggered GitHub Release workflow completed successfully for
  `v0.1.0`: clean-home validation, publication audit, Swift tests, signed
  packaging, and GitHub publication all passed in run `31905346346`.
- The release workflow now initializes a clean temporary private home, runs the
  complete Agent OS validator and publication audit before Swift packaging, and
  refuses publication unless the packaged executable is Apple Silicon
  (`arm64`).
- The Swift package declares tools version 6.1, matching the Apple Silicon
  `macos-15` release runner; it also builds and tests with local Swift 6.2.
- The static AppKit menu-bar image is main-actor isolated, preserving strict
  Swift 6 concurrency checks on the release runner.
- Task Bridge turn-state calls use explicit positional hashes and pass the same
  suite on the bundled Ruby 2.6 and Homebrew Ruby 4.0, covering the Ruby 3+
  keyword-argument boundary exercised by the release runner.
- The public `v0.1.0` zip, checksum, and appcast were downloaded independently
  after publication. The checksum, strict bundle signature, version `0.1.0`,
  macOS 14 minimum, Apple Silicon executable, appcast archive length and URL,
  stable `latest` feed, and Ed25519 archive signature all passed verification.
- The tag-triggered GitHub Release workflow completed successfully for
  `v0.2.0`: clean-home validation, publication audit, Swift tests, signed
  packaging, and GitHub publication all passed in run `31909930801`.
- The public `v0.2.0` zip, checksum, and appcast were downloaded independently
  after publication. The checksum, strict bundle signature, version `0.2.0`,
  macOS 14 minimum, Apple Silicon executable, appcast archive length and URL,
  stable `latest` feed, embedded 25-file runtime manifest, and Ed25519 archive
  signature all passed verification.
- A fresh anonymous HTTPS clone of `v0.2.0` initialized a separate private home
  and passed 46 Ruby tests/328 assertions, structural validation, exact runtime
  synchronization, both plugin package checks, and the publication audit.
- The tag-triggered GitHub Release workflow completed successfully for
  `v0.2.1`: clean-home validation, publication audit, 17 Swift tests, signed
  packaging, and GitHub publication all passed in run `31913614945`.
- The public `v0.2.1` zip, checksum, and appcast were downloaded independently
  after publication. The checksum, strict bundle signature, version `0.2.1`,
  macOS 14 minimum, Apple Silicon executable, appcast archive length and URL,
  exact 29-file embedded runtime tree, and Sparkle Ed25519 archive signature all
  passed verification.
- A fresh anonymous HTTPS clone of `v0.2.1` at
  `d7607144fcf21fa4781ee9beabff9f3c0c9786d3` initialized a separate private
  home and passed 54 Ruby tests/420 assertions, structural validation, exact
  runtime synchronization, the plugin package and Context Loop checks, Task
  Board and Slack-state validation, and the publication audit.
- The tag-triggered GitHub Release workflow completed successfully for
  `v0.3.0`: the clean tag checkout passed 62 Ruby tests/520 assertions,
  22 Swift tests, plugin package validation, runtime synchronization, and the
  publication audit before packaging in run `31946760759`.
- The public `v0.3.0` zip, checksum, and latest appcast were downloaded
  independently after publication. The checksum, strict bundle signature,
  version `0.3.0`, macOS 14 minimum, Apple Silicon executable, embedded runtime
  version, appcast archive length and URL, stable latest feed, and Sparkle
  Ed25519 archive signature all passed verification.

## Not configured

- A real second-Mac install and cross-version Sparkle update from `v0.2.1` to
  `v0.3.0`.
- End-user hook trust remains a per-install Codex choice; the release source
  cannot pre-approve it for another user.
- A product-owned Codex Scheduled task for a clean user; the local CLI
  intentionally cannot inspect or create that state. The connected-Slack and
  zero-repository label path is verified, but its first Scheduled execution is
  still a separate live gate.
- Automated secret scanning on future pull requests and tags; the initial
  candidate received a one-off dedicated scan.
- A release support policy.

Unknown values must remain unknown until verified. Private instance facts belong
in ignored local state, not in this product document.
