# Changelog

## 2026-08-15

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
