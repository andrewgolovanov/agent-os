# Changelog

## 2026-08-16

- Replaced Slack monitor links to the generated private `BOARD.md` file with a
  native `agent-os://board` destination, added tested Board/Focus deep-link
  handling to both development and release app bundles, and rewrote the
  canonical Slack runbook and Scheduled prompt in portable plugin-first terms.
- Clarified exact Slack-to-outcome correlation: stable event identities update
  an existing task when verified, otherwise an actionable ask creates an inbox
  outcome and optional `routing_pending` handoff in the shared private state
  read by the Agent OS app.

- Added preview-first migration from a legacy source-plus-home installation to
  a separate private `~/.agent-os`: config, Task Board, runtime evidence, and
  wrapper metadata are staged and validated without copying project
  repositories; the previous home remains intact for rollback.
- Added an explicit `activate --replace` gate so an existing valid active-home
  pointer can be changed only after a visible preview and deliberate apply.
- Added `bootstrap --replace-source` as the explicit preview-first transition
  from a selected development checkout to a chosen packaged runtime while
  preserving the existing automatic-bootstrap safety boundary.
- Added identity-checked MCP/CLI project relinking after a user moves a
  registered repository; only private registry and wrapper metadata change.
- Migrated the verified development installation to a separate private home,
  kept source repositories in independent user-selected folders, and removed
  the old assumption that project code belongs under the Agent OS checkout.
- Made optional integration diagnostics recognize Task Bridge hooks beside a
  packaged plugin runtime as well as inside a development checkout.
- Clarified that a direct project is defined by project-root and Git-root
  identity rather than by living under the Agent OS checkout; verified relinked
  direct projects remain supported in ordinary user-selected folders.
- Made every direct Ruby tool, including the full validator and Task Board CLI,
  resolve the selected active private home when no explicit home environment is
  provided; the source checkout remains only the legacy fallback.
- Bundled the canonical Slack monitor runbook and optional-integration guide in
  the packaged runtime, and made home migration rewrite monitor-owned registry,
  Task Board, runtime, dashboard, and runbook paths to the new owners without
  changing unrelated monitor entries.
- Published the compatible `v0.2.1` plugin and application release from
  `d7607144fcf21fa4781ee9beabff9f3c0c9786d3` in successful workflow run
  `31913614945`. The public zip, checksum, appcast, Apple Silicon/macOS
  metadata, strict bundle signature, exact embedded runtime, Sparkle Ed25519
  signature, and a fresh anonymous-clone validation passed independent checks.

## 2026-08-15

- Consolidated Context Loop into the Agent OS plugin as a bundled skill, removed
  the redundant marketplace package, preserved existing `.context-loop/` state
  and project-local hook behavior, and documented the one-time removal of an
  older standalone installation.
- Added the Codex-specific `interface.websiteURL` manifest field so the plugin
  details page links to the public repository instead of showing Website as
  unavailable; package tests now cover this UI metadata contract.
- Published `v0.2.0` from
  `ecab617fa23abdaefdea42a4c9d157e2b737ed9f`: the tag workflow completed
  clean-home validation, publication audit, Swift tests, signed packaging, and
  GitHub publication in run `31909930801`. The public zip, checksum, stable
  appcast, Apple Silicon/macOS metadata, strict bundle signature, embedded
  25-file runtime manifest, and Sparkle Ed25519 signature passed independent
  post-publication verification.
- Removed the manual repository checkout from the packaged installation path:
  the Codex plugin now contains an allowlisted minimal Agent OS runtime, the
  macOS app embeds the same generated payload, and either component can
  initialize the shared private home on first use.
- Added preview-first MCP and CLI onboarding for an existing Git repository in
  any folder, preserving its path, Git state, remotes, and files while writing
  only private Agent OS registry and wrapper metadata.
- Added runtime source/package hashes, executable-mode checks, isolated
  clean-home bootstrap coverage, app-bundle packaging checks, and documented
  the new app-plus-plugin installation and update boundary.
- Made the app's Updates screen recognize the embedded runtime as app-managed,
  removing the obsolete Git-checkout requirement from packaged installations
  while retaining preview-first tag updates for development checkouts.
- Clarified the public positioning as Agent OS for Codex: the repository
  description and topics now cover the Codex task board, MCP plugin, native
  macOS app, local-first workflow, and AI-agent use cases, while the README
  opens with a concise audience-facing tagline and problem statement.
- Linked both Codex plugin cards directly to the public Agent OS repository
  through their homepage and source metadata, with package coverage preventing
  the links from disappearing in later builds.
- Published the first public `v0.1.0` GitHub Release from
  `0d816b4724dc0ef14a2f49f7f0c451e5a1684f8f`; independently downloaded and
  verified its zip, checksum, stable appcast, Apple Silicon/macOS metadata,
  strict bundle signature, and Sparkle Ed25519 archive signature.
- Isolated the AppKit-backed menu-bar image provider to `MainActor`, satisfying
  Swift 6 strict concurrency without weakening checks for the rest of the app.
- Lowered the Agent OS package manifest requirement from Swift tools 6.2 to
  6.1; the package uses no 6.2-only manifest features and now builds on the
  Apple Silicon `macos-15` release runner.
- Made Task Bridge turn-state updates explicit about their positional hash so
  the release suite behaves identically on the bundled Ruby 2.6 and runner Ruby
  3 or newer.
- Created and verified an independent encrypted recovery copy of the Sparkle
  Ed25519 private key, then overwrote and removed the validated temporary export.
- Applied the canonical Agent OS app icon to the Agent OS and Context Loop
  plugin cards and composer metadata, with archive-local SVG copies and a
  byte-for-byte package test that prevents brand drift.
- Hardened the tag release workflow to initialize a clean temporary private
  home, run the complete Agent OS validator and publication audit, and reject a
  first-release executable that is not Apple Silicon (`arm64`).
- Documented that the first downloadable macOS application supports Apple
  Silicon on macOS 14 or newer and does not yet include an Intel or universal
  binary.
- Verified from fresh Codex tasks that the installed Agent OS skill and MCP
  tools load correctly, and exercised the vetted Task Bridge hook bundle
  against an isolated clean private home.
- Added preview-first `configure-slack-monitor` onboarding with a sanitized
  template, structured merge, explicit conflict/replace boundary, private file
  permissions, and clean-home coverage including paths with spaces.
- Bundled `UserPromptSubmit`, material `PostToolUse`, and `Stop` Task Bridge
  hooks in the Agent OS plugin, added the `setup-agent-os` skill, and refreshed
  the plugin cache-busting version without adding a second user hook file.
- Added one canonical optional-integration guide and Scheduled task prompt that
  keep local config, Slack access, hook trust, and Codex recurring execution in
  their respective authority domains. Extended `doctor --integrations` without
  treating unverifiable provider state as core failure.
- Approved Agent OS as the portable product form of the local control plane:
  in-place source, external private state, one monorepo, private-first release,
  and MIT licensing.
- Added separate `AGENT_OS_SOURCE_ROOT` and `AGENT_OS_HOME` contracts with
  compatibility for the previous one-directory installation.
- Added preview-first `agent-os init`, read-only `doctor`, full `validate`, and
  a publication boundary audit.
- Added sanitized configuration templates; initialization creates an empty
  registry and does not enable monitors, hooks, provider access, or write
  authority.
- Excluded real config, tasks, reports, runtime, project checkouts, and local
  source pointers from Git candidates.
- Consolidated the Agent OS macOS app and both Codex plugins into the monorepo without
  removing or changing the standalone source directories.
- Updated the Agent OS app and its MCP server to use distinct source and home
  roots and removed developer-specific default paths.
- Aligned app and MCP task-ID validation with the canonical Task Board contract.
- Added clean-home CLI and MCP tests, plugin package validation, and Context Loop
  smoke coverage.
- Verified the current instance and a fresh temporary home with 37 Ruby tests,
  222 assertions, Swift build/tests, app bundle launch, MCP isolation, and both
  plugin packages.
- Preserved the previous private operational documentation in an ignored local
  backup before beginning product-document sanitization.
- Sanitized the product documentation until the built-in publication audit
  reported zero known private-state boundary findings.
- Added preview-first active-home selection for app/plugin discovery, installed
  both plugins from the monorepo `agent-os` marketplace, and removed the old
  personal marketplace registration without deleting its source directory.
- Unified public naming across the Swift package, macOS bundle, Codex plugin,
  MCP tools, Ruby namespace, paths, templates, and documentation under Agent OS.
- Added preview-first Codex plugin installation plus ad-hoc signed macOS
  packaging, SHA-256 checksums, and an explicit user-approved Gatekeeper flow.
- Added release-tag-based `agent-os update`: preview by default, clean
  fast-forward only, no reset of local changes, and version-aware Codex plugin
  refresh.
- Integrated Sparkle 2.9.5 into Agent OS for daily update checks, manual check,
  and user-controlled automatic installation; added the same Settings surface
  for core/plugin update opt-in.
- Added a dedicated Agent OS Ed25519 update key, pre-extraction archive
  verification, generated appcast, nested framework signing, and a tag-triggered
  GitHub Release workflow without Developer ID or notarization.
- Passed all 126 initial candidates through Gitleaks 8.30.1, manual review, the
  built-in publication audit, and whitespace checks with no secret or private
  state findings.
- Published the initial MIT-licensed source to the public
  `andrewgolovanov/agent-os` repository at commit
  `7947b27249fd757b44f946b3fa9d6d66f08cfd26`.
- Verified the pushed source from a fresh anonymous HTTPS clone through private
  home initialization, doctor, complete Ruby/plugin validation, publication
  audit, and clean Swift build/tests.
- Configured `AGENT_OS_SPARKLE_PRIVATE_KEY` in GitHub Actions without exposing
  the private value in the repository or command output.
- Reworked the native app around the official shadcn default Neutral dark
  tokens rather than an elevated Zinc interpretation: `#0a0a0a` canvas,
  `#171717` cards/sidebar, `#262626` interactive accents, documented translucent
  border/input roles, and readable `#a3a3a3` muted text.
- Matched dashboard-01 geometry with 48-point toolbar rhythm, 36-point default
  controls, 32-point compact controls, 16-point icons, a 4-point spacing grid,
  and shadcn's radius scale. Replaced the system sidebar selection surface with
  token-owned 48-point rows and removed gray fills from Board columns.
- Reassigned workflow colors to semantic roles: Active green, Waiting amber,
  Review blue, Planned violet, Inbox neutral, Done emerald, and Cancelled red,
  while retaining status text and unique SF Symbols.
- Added compact registered project badges to Focus rows so mixed-project work
  remains attributable without opening the task inspector.
- Made documentation maintenance an explicit completion contract: affected
  agent commands stay current in the nearest `AGENTS.md`, human-facing behavior
  stays current in the relevant README, material changes update their owning
  docs/state/changelog, and stale renamed identifiers are searched before
  handoff without mechanically touching unrelated documentation.
- Replaced the permanent empty task-detail column and animated inspector with a
  stable resizable native split that starts closed, opens from task selection,
  clears selection on close, and also closes with Escape. The open inspector now
  places a translucent dismissible backdrop over Focus or Board so its boundary
  stays visually clear and an outside click closes it. Added color-role,
  board-order, tracked-time, and backdrop-token regression tests.
- Matched the toolbar to the dark content canvas and extended the sidebar color
  and divider continuously through the titlebar with a narrow AppKit bridge.
  Removed the conflicting full-width toolbar fill, made the titlebar transparent
  over explicit sidebar/canvas segments, and verified the native hide/show
  control preserves the split after collapsing and restoring the sidebar.
  Restored and capped the accepted compact sidebar width at 240 points so macOS
  cannot revive the unintended saved 288-point expansion.
  Aligned compact sidebar icons to the first line of their labels, flattened
  detail content into document sections, and moved tracked time into the header
  and every Board card.
- Replaced the mismatched system project and lifecycle menus with one shared
  36-point select: balanced padding, a single chevron, flat token-owned popover,
  automatic edge placement, and the same input border as the task form. Fixed
  the single-line title placeholder alignment while retaining top-aligned
  multiline fields.
- Replaced raw source hostnames with interactive provider-aware rows, Slack
  permalink context, Figma/deployment labels, hover/pointer feedback, and
  optional read-only GitHub CLI enrichment for PR title, branches, review
  decision, and open/draft/merged/closed state. Promoted PR rows directly below
  the task header and removed their duplicate appearance from supporting
  Sources.
- Added the selected minimal black-and-white Agent OS `A` app icon as an
  editable SVG, a reproducible multi-resolution ICNS asset, and bundle metadata
  for both development and release packaging.
- Refined the `A` into a smooth optically centered silhouette and replaced the
  menu-bar extra's generic system layout glyph with a dedicated monochrome
  template version of the Agent OS mark.
- Corrected child-process environment inheritance so GUI-launched CLI tools can
  resolve normal user configuration and Keychain-backed authentication.
- Added the public version keys to the development app bundle so Sparkle can
  initialize during real-window QA instead of rejecting an unversioned host.
- Added the canonical Agent OS icon before the project name in the public root
  README, fast-forwarded the accepted redesign commit
  `e98dc8118585e22d6f6ba2c070a6c146347d1103` to `main`, and verified that exact
  commit from a fresh anonymous HTTPS clone through isolated-home setup,
  doctor, Ruby/plugin/Swift checks, and the publication audit.
- Replaced the earlier hand-drawn icon geometry with the user-supplied canonical
  SVG, preserved its aspect ratio in deterministic ICNS generation, and rebuilt
  the 18-point menu-bar template from the same exact paths.
- Corrected the supplied glyph's macOS app-icon composition after Dock QA: kept
  its exact path geometry, restored a transparent outer margin and rounded
  near-black tile, and added balanced inner spacing without changing the
  background-free menu-bar mark.

Earlier private installation history is intentionally not part of the shareable
product changelog.
