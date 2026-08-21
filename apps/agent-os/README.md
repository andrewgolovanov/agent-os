# Agent OS for macOS

Agent OS for macOS is the optional native cockpit for the Agent OS control
plane. It renders the canonical Task Board, performs lifecycle changes through
existing Agent OS tools, and creates or opens exact Codex tasks in their
registered project directory.

The app intentionally owns no task database. Durable state remains in:

- `AGENT_OS_HOME/config/projects.yaml` for project identity and repository paths;
- private `AGENT_OS_HOME/work/items/*/task.json` through `tools/task-board` for outcomes;
- Codex App Server and `codex://threads/<id>` for execution state and handoff.

Slack monitor notifications use `agent-os://board` to launch the app directly
on the shared Board. `agent-os://focus` opens the Focus view, while
`agent-os://done` opens completed outcomes. The older `agent-os://history` and
`agent-os://time` links remain compatibility aliases for Done. Every
destination refreshes canonical private state; none imports or duplicates task
data.

Board keeps unfinished outcomes in independently scrollable lifecycle columns
while hiding their persistent vertical scroll indicators.
Focus uses a compact reading hierarchy rather than card geometry: 14-point
semibold titles, 13-point action text with added leading, a 6-point content
flow, and a bounded text measure keep long mixed-project work readable. Outcomes
are grouped by their last update into local-calendar Today, Yesterday, This
Week, Last Week, and Earlier sections; empty sections are omitted and lightweight
headings scroll with the list without a separate backing surface. Project and
label context sits above each task title, while status remains the only trailing
signal. Semantic separators span the full row width instead of inheriting the
variable native list inset.
Unassigned outcomes may carry display-only Slack channel labels. The app shows
those labels in Focus, Board, Done, and the inspector. Unmapped channels remain
available as a separate sidebar filter; a channel explicitly mapped to a
registered project stays visible on task cards but is omitted from that
top-level section to avoid duplicating the project. Labels never enable `Open
new Codex task` on their own.
Done is the operational completion journal: it retains `done` and `cancelled`
outcomes with their complete inspector, sources, pull-request state, linked
Codex activity, and completion follow-up state. Its project, completion-period,
lifecycle, and follow-up filters drive one exact-linked time summary for the
visible completed outcomes. A completed outcome with a Slack source starts as
`Pending`; the user can copy a prepared completion update and explicitly mark it
`Sent` or `Not required`. Agent OS does not send external messages automatically
and does not mix broader project-wide time into this task-owned total.

`Open new Codex task` creates a named task in the registered project, records its exact membership, copies a prepared continuation prompt, and opens that task in Codex. The app deliberately does not start a background turn: paste and send the prepared prompt when you are ready to begin work.

When Task Bridge explicitly reassigns an existing Codex task to another
outcome, the inspector retains the previous membership with its `archived`
status. Completed activity stays on that outcome, while the target displays the
same Codex task as its current membership.

The resizable task inspector opens at a wider desktop-friendly width so long
titles, pull-request metadata, goals, and current-state text wrap less
aggressively while the Board remains visible.

Task Board filesystem notifications are delivered on the main actor before the
SwiftUI store is refreshed. The LaunchServices completion used for Codex
handoff is a nonisolated Sendable bridge that only resumes the awaiting
continuation. These queue boundaries keep file refreshes and Codex opens safe
under Swift 6 strict concurrency.

## Install

Download the app zip and checksum from the matching Agent OS GitHub Release.
The release bundle contains the minimal Agent OS runtime and initializes the
shared private home at `~/.agent-os` on first launch. A source checkout and
`AGENT_OS_SOURCE_ROOT` are not required for normal use.

The app also pages through public active Codex task metadata on launch and
passes only unique working directories to the shared runtime. Deterministic
local roots are registered automatically before the project snapshot is loaded,
including folders without Git. A repository discovered later at the same root
enriches the existing project; thread bodies and historical tasks are never
imported. A compact notice reports changed projects without blocking the Board
on skipped or ambiguous paths.

Follow the checksum and Gatekeeper instructions in
`../../docs/installation.md`. Install the Codex plugin from the same release to
add MCP tools, project onboarding, skills, and Task Bridge hooks.

## Run from source

```bash
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME=$HOME/.agent-os \
./script/build_and_run.sh --verify
```

The private home defaults to `~/.agent-os`. Development builds honor
`AGENT_OS_SOURCE_ROOT`; otherwise the app bootstraps the synchronized runtime
bundled at `Contents/Resources/AgentOSRuntime`. A non-default home selected by
`agent-os activate` is discovered from the user config pointer.
`WORKSPACE_CONSOLE_ROOT` remains a deprecated compatibility alias for older
one-directory installations.

The app uses its minimal dark appearance by default. The sun/moon button in the
main toolbar switches between the official shadcn Neutral light and dark
semantic palettes and stores the choice for future launches. For isolated
contrast regression QA, either appearance can still be forced without changing
the saved preference:

```bash
open -n "dist/Agent OS.app" --args --force-light-appearance
open -n "dist/Agent OS.app" --args --force-dark-appearance
```

The companion plugin is maintained once at `../../plugins/agent-os`.

Source rows use the canonical Task Board source kind instead of presenting raw
hostnames. Slack permalinks show their workspace, channel, and message date;
Figma and deployment links show their provider context. If the GitHub CLI is
installed and authenticated, pull-request rows also resolve the current title,
repository, branches, merge/open/draft/closed state, and review decision. The
app keeps a local fallback label when `gh` is unavailable and never mutates the
pull request. Pull requests are promoted directly below the task header for
quick access and are not repeated in the supporting Sources section.

Task details open in the resizable right-hand inspector. While it is visible,
the Focus or Board content is dimmed and does not accept task interactions;
clicking that backdrop, pressing Escape, or using the close button dismisses the
inspector and clears its selection.

The project sidebar continues through the titlebar behind the native hide/show
button and traffic lights, while the main toolbar keeps the darker content
canvas. Its default and maximum width is the compact 240-point layout; hiding
and restoring the sidebar preserves that split and its divider.

The application icon preserves the supplied canonical Agent OS `A` path
geometry without redrawing or distortion. The glyph is optically centered with
deliberate inner spacing on a rounded `#111111` tile, while the transparent
1024-point canvas supplies the outer macOS icon margin. The editable source is
`Resources/AppIcon.svg`; rebuild the committed macOS icon asset with:

```bash
./script/generate_app_icon.sh
```

The menu-bar extra uses a separate 18-point template rendering of the same
glyph paths from `Sources/AgentOS/Support/AgentOSBrandIcon.swift`. It omits the
tile so macOS can tint the mark correctly for either menu-bar appearance.

## Updates

The app uses Sparkle 2.9.5 with the stable latest GitHub Release appcast. It
checks app updates automatically once per day and notifies by default. Users can
enable automatic download/install in Settings. Packaged plugin updates are
installed as newer Codex marketplace snapshots; development checkouts keep the
preview-first `agent-os update` path.

Every app archive is signed by the Agent OS Ed25519 update key and verified
before extraction. Only the public key is present in source. Developer ID and
notarization remain intentionally absent, so the installation guide's
Gatekeeper boundary still applies.

## Package

```bash
./script/package_release.sh
```

The current downloadable release targets Apple Silicon (`arm64`) on macOS 14 or
newer. It does not include an Intel or universal binary.

This produces an ad-hoc signed zip, SHA-256 checksum, and signed-archive Sparkle
appcast under `dist/release`. There is no Developer ID or notarization workflow.
A downloaded copy requires the user to approve its first launch through
**System Settings → Privacy & Security → Open Anyway**. Full installation,
update, and checksum steps are in `../../docs/installation.md`.
