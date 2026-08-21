# Changelog

## 2026-08-21

- Fixed the native Focus list moving down by 16 points on its first hover after
  navigation. The first section now owns the initial spacing, each task row owns
  its hover state, and hover feedback no longer applies a broad row animation or
  invalidates the full mixed-row list.
- Published `v0.7.1` from
  `27b1bdf370e27764b26c851ed2bf5e7f72dc94cb` in successful workflow run
  `32512791540`. The public archive SHA-256 is
  `9b3d660aea1bcdbfd793144afc21534f0fcc76e539afba15fe425a412760ceb1`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  23-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks. A fresh
  anonymous tag clone also initialized and validated against an empty private
  home.
- Published `v0.7.0` from
  `66fb08f77d7d6497f85fc7d4c1ebcb67e781284c` in successful workflow run
  `32508847564`. The public archive SHA-256 is
  `0eb48199f6a29e6ceae12d2c304a3c2464983038493ec1904a8c06c70a5e2eea`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  23-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks. A fresh
  anonymous tag clone also initialized and validated against an empty private
  home.
- Restored completed-only unmapped Slack labels to the native sidebar after
  `v0.7.0` made historical channel filters unreachable. The task labels and
  Task Board records were never deleted; the sidebar now keeps those channels
  visible with a zero unfinished count and hides only labels mapped to a
  registered project.
- Replaced the project-row pin glyph with a compact hover star immediately to
  the left of the trailing task count. The count keeps its original right-edge
  alignment, while pinned projects retain a visible filled star and the same
  context-menu action.
- Reduced project-sidebar noise by keeping pinned projects visible and showing
  unpinned projects only while they own unfinished outcomes. Completed-only and
  zero-work projects remain registered and available in Done history; assigning
  new unfinished work restores the regular sidebar row automatically.
- Fixed native project synchronization failing with App Server status `127`
  when a GUI launch selected a Node-based `~/.local/bin/codex` wrapper but did
  not inherit the shell path containing `node`. The app now prefers the
  self-contained executable bundled with Codex or ChatGPT and supplies explicit
  user, Homebrew, and system paths for standalone CLI fallback.
- Added deterministic Slack channel reconciliation to automatic Codex project
  synchronization. A stable channel label is linked only when its normalized
  name has exactly one registered project owner, the channel has no other
  owner, and every labeled outcome is unassigned or already belongs only to
  that project. Only unfinished unassigned outcomes are attributed; completed
  and conflicting history is never rewritten.
- Added sync-report counts and app notices for linked channels and newly
  attributed unfinished tasks.
- Added app-local ordered project pins to the native sidebar. A hover button or
  context-menu action moves a project into or out of a `Pinned` section while
  unpinned projects remain alphabetical. Stable project keys are stored only
  in macOS `UserDefaults`, so pinning cannot change the registry, Task Board
  routing, Slack mappings, or plugin behavior. Agent OS still does not read
  private Codex desktop state; project icons and colors remain deferred.
- Added app-coordinated Codex plugin updates for packaged installations. The
  native app now detects when its already installed plugin is older than the
  signed bundled runtime, offers an explicit Settings action, and supports a
  separate automatic-update opt-in after app updates. The runtime re-pins only
  the official Git marketplace from one stable release tag to the app's exact
  tag, verifies the installed full version, restores the previous tag after a
  failed install, never downgrades a newer plugin, and leaves the private
  registry and task-event history intact. Isolated fake-Codex coverage exercises
  planning, successful replacement, rollback, untrusted-marketplace refusal,
  missing-metadata fallback, bounded command timeout, and downgrade refusal.
- Verified the packaged flow locally against the real Codex CLI. An initial
  stalled GitHub marketplace clone failed back to the prior `v0.4.3` plugin;
  the retry re-pinned the marketplace to `v0.6.0` at
  `da78a9124cad93ee0a365b7d6b8e9eeb5256c239` and installed
  `0.6.0+codex.20260821154421`. The private home inode and file count stayed
  stable, and neither registry configuration nor task event history changed.
- Published `v0.6.0` from
  `da78a9124cad93ee0a365b7d6b8e9eeb5256c239` in successful workflow run
  `32499730792`. The public archive SHA-256 is
  `0ffd4465fd988c5db10f17d3d1e32fec6de2a76cb03325f55fd7996061284bf3`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  23-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks. A fresh
  anonymous tag clone also initialized and validated against an empty private
  home.
- Changed automatic Codex project synchronization so an existing local folder
  is a valid project without Git. App launch and the task-start hook now create
  local-only entries with `repositories: []`; a later committed Git root and
  later origin enrich the same project without changing its key or Task Board
  attribution.
- Added stable path-derived suffixes for same-name projects, nested local-path
  deduplication, and fail-closed overlap handling. Duplicate origins and
  transient worktrees without durable checkouts remain excluded.
- Updated the CLI to prefer repeatable `--directory` inputs while retaining
  `--repository` as a compatibility alias, and added explicit created,
  enriched, refreshed, preserved, and skipped synchronization counts.
- Allowed the native app and registry validator to load projects with no
  repositories, and added Ruby and Swift regression coverage for the complete
  local-only-to-repository lifecycle.
- Published `v0.5.0` from
  `5e6d0f16dd880e15ca681e6fa1e713acbf00facb` in successful workflow run
  `32495953322`. The public archive SHA-256 is
  `244ad1c6d445a9dacf3dc6a0036a407ed37d91d4e743095cf283d39f329754cb`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  23-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks. A fresh
  anonymous tag clone also initialized and validated against an empty private
  home.
- Added automatic registration of deterministic active Codex repositories.
  The macOS app pages public non-archived `thread/list` metadata on launch, and
  the plugin hook synchronizes the current task `cwd` before Task Bridge
  routing. The shared runtime deduplicates nested paths and origins, normalizes
  transient worktrees to durable checkouts, skips unsafe candidates, and never
  reads thread bodies or creates historical tasks.
- Added `agent-os sync-codex-projects` with preview and apply modes plus focused
  Ruby coverage for eligible roots, duplicate origins, transient worktrees,
  conflicts, and registry-only behavior. Manual onboarding and reviewed Slack
  channel mapping remain preview-first.
- Extended Slack monitor state with independently validated per-channel cursors
  and an `advance-channel --complete` command so a rate-limited dynamic channel
  pass can resume without advancing the global cursor.
- Updated the Slack monitor template, runbook, canonical Scheduled prompt, and
  setup skill to discover every visible public/private channel dynamically,
  retain only bot/app roots mentioning the exact current user, and process
  those complete threads through the same actionable rules as human mentions.
  Nonmatching ambient messages and raw thread bodies remain unpersisted.

## 2026-08-19

- Published `v0.4.3` from
  `d196e5ddef4c467e5614c84668756037af117da0` in successful workflow run
  `32300042057`. The public archive SHA-256 is
  `96e8bd3ce6c9eaff5f2040d674b27eca2d8abdac307e6ced581cdd6f22b848f5`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  22-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks. A fresh
  anonymous tag clone also initialized and validated against an empty private
  home.
- Made Agent OS MCP task-targeting mutations tolerant of `taskId`, `task_id`,
  and `id` request fields while retaining `taskId` as canonical. Conflicting
  aliases now fail before any Task Board mutation, with focused regression
  coverage for schema exposure, normalization, and conflict rejection.
- Published `v0.4.2` from
  `17e1c450d9ba4516f643f0b64c9ad910de9b8feb` in successful workflow run
  `32298222853`. The public archive SHA-256 is
  `4287aa33d901e7e6f6eadf1895083e516a2e73fa8fe924812b60c8c17e90ce21`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  22-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks.
- Added explicit `tools/task-bridge reassign` support for switching one Codex
  task between exact Task Board outcomes. The previous membership is archived,
  only the unfinished turn follows the target, and completed activity remains
  on its original outcome.
- Changed exact conflicting prompts to pause outcome timing until the agent
  explicitly reassigns the target or confirms the current outcome, preventing
  silent time attribution to a stale membership.
- Allowed one thread ID to remain as archived history across outcomes while
  enforcing at most one current `active` or `idle` membership, and kept those
  archived memberships visible in the native inspector.
- Added Task Board and Task Bridge regression coverage for exact-switch
  prompts, already-started turn reassignment, completed-time preservation,
  historical re-claim, and single-current-owner validation.

## 2026-08-18

- Published `v0.4.1` from
  `e847fd9465d5b9e9128f1eb7f16b3a2048e662f5` in successful workflow run
  `32080926193`. The public archive SHA-256 is
  `bd6ea00291e0d83692dde73a99f9b14f1195226f326df7a90154ca4d42e75ad3`;
  its checksum, exact app/runtime/plugin version, Apple Silicon/macOS metadata,
  22-file runtime, strict bundle signature, stable appcast URL and length, and
  Sparkle Ed25519 signature passed independent post-publication checks.
- Grouped the native Focus list by each outcome's last update using
  local-calendar Today, Yesterday, This Week, Last Week, and Earlier sections;
  periods with no matching outcomes remain hidden, and the lightweight text
  headings scroll with the list without a sticky backing surface.
- Reworked the native Focus list into a readable table rhythm with 14-point
  semibold titles, 13-point action text, added line spacing, a 6-point content
  flow, and a bounded reading measure derived from the shadcn Typeset model.
- Moved project context above each Focus task title while keeping lifecycle
  status as the only trailing signal; increased row padding and full-width
  semantic separators keep dense outcomes scannable at wide window sizes.
- Published `v0.4.0` from
  `f6417fcaac6c9176d3bebdd43394a30782d3adc5` in successful workflow run
  `32075412237`. The public archive, checksum, exact app/runtime/plugin version,
  Apple Silicon/macOS metadata, 22-file runtime, strict bundle signature,
  stable appcast URL and length, and Sparkle Ed25519 signature passed
  independent post-publication checks.
- Added a persistent Light/Dark appearance switch to the native app toolbar,
  following the shadcn theme-provider and sun/moon toggle model while retaining
  Dark as the existing-user default.
- Mapped the official shadcn default Neutral light tokens into the same SwiftUI
  semantic roles already used by Dark, including canvas, card, sidebar, muted,
  accent, border, input, ring, and foreground colors. Status colors and the
  AppKit-backed titlebar divider now adapt for readable contrast in both modes.
- Preserved `--force-light-appearance` and added `--force-dark-appearance` for
  deterministic contrast QA without overwriting the saved user preference.

## 2026-08-17

- Added preview-first Slack channel reconciliation to project onboarding.
  Conservative name normalization produces suggestions only; exact selected
  channel IDs require a second preview before apply stores a project mapping or
  assigns unfinished outcomes that currently have no project. Existing project
  attribution, exact sources, card labels, and separate outcomes are preserved.
- Kept Slack channel labels visible on Board cards while removing explicitly
  mapped channels from the duplicate top-level Labels sidebar. Unmapped
  Slack-only work remains filterable for users without repositories.
- Hid persistent vertical scroll indicators inside Board lifecycle columns
  while preserving independent scrolling and fixed column headers.
- Widened the resizable task inspector from `360 / 420 / 520` points to
  `420 / 520 / 680` points so long titles, pull-request metadata, and outcome
  text wrap less aggressively when desktop space is available.
- Published `v0.3.2` from
  `91b209ae02af854ccb52dee28037bc876298da73` in successful workflow run
  `32059910788`. The public archive, checksum, exact app/runtime/plugin version,
  Apple Silicon/macOS metadata, strict bundle signature, appcast URL and length,
  and Sparkle Ed25519 signature passed independent post-publication checks.
- Added concise versioned GitHub release notes with `✨ Features` and `🐛 Fixes`
  sections. Future release tags fail validation without those sections, and the
  generated Full Changelog now starts at the previous published release rather
  than an unpublished intermediate tag.
- Replaced the generic native `Slack thread` source-card heading with an
  optional normalized 96-character excerpt from the Slack root message while
  preserving the exact permalink as correlation identity and retaining the
  generic heading for legacy sources.
- Added idempotent CLI and MCP source-title attachment and refresh, search by
  stored title, backward-compatible Swift decoding, and explicit privacy rules:
  no replies, full Slack messages, author metadata, or runtime-state text are
  retained.
- Added display-only Task Board labels for Slack-only work. Named channels use
  stable `slack:<channel_id>` keys and current `#channel-name` labels without
  becoming registered projects, repository routes, or Codex handoff targets.
- Added idempotent Task Board CLI and Agent OS MCP label mutations, generated
  index/status output, and Ruby/MCP coverage including channel rename behavior.
- Added native app label display across Focus, Board, Done, and the task
  inspector, plus search and a separate sidebar filter for unfinished outcomes,
  while preserving registered-project requirements for repository actions.
- Documented a zero-repository Scheduled setup: use the active Agent OS home as
  a non-version-controlled local project instead of creating a fake Git
  repository.
- Verified the release path with a bounded connected-Slack read and an isolated
  zero-project home: the new MCP created an unassigned outcome, attached its
  exact Slack source, added the stable channel label, and left routing empty.
- Isolated Sparkle appcast generation to the current release archive so stale
  local artifacts cannot inherit the new tag URL or enter the published feed.

## 2026-08-16

- Published `v0.3.0` from
  `e9cdf0ab0434a7ad99b36c8b5d1cbe6023d9026a` in successful workflow run
  `31946760759`. The clean tag checkout passed 62 Ruby tests/520 assertions,
  22 Swift tests, plugin validation, runtime synchronization, and publication
  audit before packaging. The public zip, checksum, latest appcast,
  Apple Silicon/macOS metadata, strict bundle signature, embedded runtime, and
  Sparkle Ed25519 signature passed independent post-publication checks.
- Added semantic hover and pointer feedback to selectable Focus rows, matching
  the existing Board interaction language without turning the compact list into
  a second card grid.
- Removed the obsolete source-local `work/README.md` and its structural
  validation dependency. Agent instructions now route durable work through the
  canonical Task Board documentation and private `AGENT_OS_HOME/work` outcome
  records instead of implying that mutable task state belongs in the source
  checkout.
- Standardized repository README files, product documentation, agent
  instructions, examples, and decision records on English. Current documents
  now qualify every private state path with `AGENT_OS_HOME`, while historical
  architecture remains only in explicitly superseded decision records. The
  repository validator rejects Cyrillic text in maintained Markdown to prevent
  accidental language drift.
- Replaced the two-layout project model with one registry-only topology.
  Onboarding records `root + repositories` for projects in any local folder and
  never creates `AGENT_OS_HOME/projects`, project wrappers, or metadata inside
  product repositories.
- Added a preview-first, one-way MCP/CLI registry upgrade for obsolete
  `layout`/`wrapper` entries. Any old managed folder is retained in a private
  recovery backup; repository files and Git state remain unchanged.
- Removed project-wrapper templates and the public path for creating or
  switching back to wrapper layout.
- Fixed two recurrent Swift 6 executor crashes in the native app. Task Board
  filesystem events now enter actor-isolated refresh logic from the main queue,
  while the LaunchServices Codex-open completion uses a nonisolated Sendable
  continuation bridge. Background-queue regression tests cover both paths, and
  live Task Board mutation no longer terminates the running app.
- Replaced the textless capsule status badges in Done rows with
  fixed 24-point circular markers, keeping the existing semantic colors and SF
  Symbols without the stretched empty horizontal padding.
- Added a native Done workflow for durable completed and cancelled outcomes,
  including project/completion-period/lifecycle/follow-up filters, exact-linked
  time and pending-follow-up summaries, and the existing detail inspector with
  source, pull-request, Codex, and exact-linked time context.
  Slack-backed done outcomes now carry separate pending/sent/not-required
  completion follow-up state and a copyable completion update without automatic
  external messaging.
- Kept broader generated Project Time reporting in the CLI/private ledger while
  consolidating task-owned time into Done. The app has no separate Time page and
  never adds overlapping project-wide and exact-linked measurements.
- Made each Board column independently vertically scrollable inside the
  horizontal workflow canvas so lower cards remain reachable while column
  headers stay visible. Added the tested `agent-os://done` destination, retained
  `agent-os://history` and `agent-os://time` as Done compatibility aliases, and
  added completion decoding and completion-period coverage.
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
  obsolete project metadata are staged and validated without copying project
  repositories; the previous home remains intact for rollback.
- Added an explicit `activate --replace` gate so an existing valid active-home
  pointer can be changed only after a visible preview and deliberate apply.
- Added `bootstrap --replace-source` as the explicit preview-first transition
  from a selected development checkout to a chosen packaged runtime while
  preserving the existing automatic-bootstrap safety boundary.
- Added identity-checked MCP/CLI project relinking after a user moves a
  registered repository; only private registry metadata changes.
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
  only private Agent OS registry metadata.
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
