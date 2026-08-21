# Agent OS macOS app

Status: local MVP implemented and consolidated into Agent OS

Product path: `apps/agent-os`

Plugin path: `plugins/agent-os`

## Purpose

Agent OS is an optional native macOS cockpit for durable outcomes. It
answers what needs attention, what the next action is, and which exact Codex task
or source belongs to the outcome.

It is intentionally replaceable. If Codex later provides an adequate task board,
the canonical Agent OS registry and Task Board remain usable without this app.

## Boundary

| Concern | Canonical owner | Console role |
| --- | --- | --- |
| Project identity and paths | private `AGENT_OS_HOME/config/projects.yaml` | invoke deterministic sync, then read and present |
| Outcome lifecycle | private Task Board via `tools/task-board` | invoke validated actions |
| Task index | generated private `AGENT_OS_HOME/work/board.json` | refresh/read model |
| Codex tasks | Codex App Server | list active task `cwd` metadata, create/name exact idle task, and hand off |
| Provider context | exact source URLs | contextual display and open only; optional read-only `gh` PR lookup |

The app never edits Task Board JSON or Markdown directly and owns no database.
All task mutations use the selected packaged or development runtime executable
with an argument array.

## Source and home

- Release builds bundle the synchronized runtime under
  `Contents/Resources/AgentOSRuntime` and bootstrap it on first launch.
- `AGENT_OS_SOURCE_ROOT` optionally selects a valid development checkout and
  takes precedence over packaged runtime.
- `AGENT_OS_HOME` points to private registry, tasks, and runtime.
- If the source variable is absent, the app initializes or upgrades the private
  runtime pointer from the bundle, then reads `AGENT_OS_HOME/source-path`.
- On each app launch, public App Server `thread/list` supplies active,
  non-archived `cwd` metadata. The shared runtime automatically registers only
  deterministic local project roots before the app loads its project snapshot;
  Git is optional, and a verified repository can enrich the same project later.
  Exact unique non-conflicting Slack channel labels may then be linked to the
  project, with attribution limited to unfinished unassigned outcomes. No
  thread body, Slack history, or historical task is imported.
- The App Server process prefers the self-contained Codex executable bundled
  with an installed Codex or ChatGPT app. Standalone CLI installations remain
  a fallback, with standard user, Homebrew, and system binary directories added
  explicitly because a macOS GUI launch does not inherit an interactive shell
  `PATH`.
- The app owns one narrow presentation preference: an ordered list of pinned
  project keys in macOS `UserDefaults`. Pinned projects appear in their own
  section above the otherwise alphabetical project list and can be toggled from
  the row or its context menu. Pinned projects remain visible without unfinished
  work; unpinned projects appear only while at least one unfinished outcome is
  assigned to them. Hiding is presentation-only: the registry and Done history
  retain every project, and new unfinished work restores its sidebar row. This
  preference never changes registry or task routing state. Codex thread pins are
  not interpreted as project pins, private desktop state is not read, and
  icon/color mirroring remains deferred until a supported App Server contract
  exists.
- The private home defaults to `~/.agent-os`.
- `WORKSPACE_CONSOLE_ROOT` remains only as a deprecated compatibility alias for older
  one-directory installations.

## Codex handoff

The app creates and names an idle task through stable App Server `stdio`, records
the exact membership through `tools/task-board`, copies the prepared first
prompt, and opens the public `codex://threads/<id>` handoff. It does not start a
competing background turn from a second App Server client.

AppKit and Dispatch callbacks have explicit Swift 6 executor boundaries. Task
Board filesystem events are delivered on the main actor queue before the
observable store is touched. The LaunchServices completion for Codex handoff is
created outside the main actor as a Sendable continuation bridge, so the system
may call it on its own queue without entering main-actor-isolated code.

## UI scope

- regular SwiftUI window with Focus, Board, and Done views;
- ordered app-local project pins above the alphabetical project list, plus
  project, unmapped Slack channel label, outcome filtering, and search; mapped
  channel labels remain visible on task cards without duplicating their project
  in the sidebar;
- independently vertically scrollable Board columns inside the horizontal
  workflow canvas, keeping every card reachable without moving column headers
  while hiding the persistent vertical scroll indicators;
- a Done view for durable `done` and `cancelled` outcomes, with project,
  completion-period, lifecycle, and completion-follow-up filters plus summary
  cards for visible outcomes, exact-linked time, and pending follow-up; grouped
  outcome rows reopen the same inspector so goal, summary, next action, source
  links, PR status, Codex memberships, and exact-linked time remain inspectable
  after completion;
- completion follow-up is separate from lifecycle. Done outcomes with Slack
  sources begin as `pending`; the inspector prepares a copyable completion
  update, but the user sends it and explicitly records `sent` or `not_required`;
- the official shadcn default Neutral light and dark tokens mapped into SwiftUI
  semantic roles. Dark retains its `#0a0a0a` background and `#171717`
  card/sidebar; Light uses a white canvas, `#fafafa` sidebar, `#f5f5f5`
  muted/accent surfaces, and `#e5e5e5` borders;
- a sun/moon button in the main toolbar switches Light and Dark immediately and
  stores the user preference across launches while retaining explicit force
  flags for isolated contrast QA;
- dashboard-01 geometry for the native equivalents: a 48-point toolbar rhythm,
  36-point default controls, 32-point compact controls, 16-point icons, a
  4-point spacing grid, and the documented shadcn radius scale;
- a native resizable task-detail split that stays closed by default, opens only
  from task selection without a sheet transition, and closes through its button
  or Escape without retaining stale selection; while it is open, a translucent
  backdrop dims and disables the Focus or Board pane and closes the detail when
  clicked without covering the inspector, toolbar, or project sidebar;
- a wider `420 / 520 / 680` point minimum, ideal, and maximum inspector range so
  long task and pull-request context remains readable while the split stays
  user-resizable;
- selected outcome details with goal, summary, next action, blocker, sources,
  Codex memberships, and tracked outcome time in the header;
- readable Focus rows with 14-point semibold titles, 13-point action text,
  added leading, a 6-point vertical flow, and a bounded text measure;
  local-calendar Today, Yesterday, This Week, Last Week, and Earlier sections
  group outcomes by their last update, omit empty periods, and use lightweight
  non-sticky headings without a separate backing surface; the first heading
  owns the stable top spacing so the initial layout cannot move when a row first
  receives hover state;
  registered project context sits above each task title while lifecycle status
  remains the only trailing signal; full-width semantic separators, the shared
  hover surface, and pointing-hand feedback make every selectable row clear,
  while hover state stays local to the affected row;
- display-only Slack channel labels on outcomes, with an unmapped Labels sidebar
  section across every lifecycle; completed-only channels remain navigable with
  a zero unfinished count, while mapped labels stay on cards without duplicating
  their project or enabling repository actions;
- tracked outcome time at the top of every Board card for immediate scanning;
- compact status-only markers in Done use a fixed 24-point circular
  surface instead of retaining the horizontal padding of a text badge;
- a full-height sidebar surface and divider through the titlebar, compact icons
  aligned to the first label line, and a document-style detail view with one
  clear hierarchy instead of nested detail cards; the sidebar is capped at the
  compact 240-point width, and the titlebar keeps the
  sidebar surface behind traffic lights and the native hide/show control while
  the main toolbar retains the canvas surface in both expanded and collapsed
  sidebar states;
- one shared 36-point project/lifecycle select and input geometry, with a single
  chevron, flat semantic popover, automatic edge placement, and correctly
  aligned single-line and multiline placeholders;
- interactive source rows with provider-specific labels, hover feedback,
  external-link affordances, a normalized short Slack root-message title with a
  generic fallback for legacy sources, privacy-safe permalink context, and
  optional live GitHub pull-request title/state/review metadata; PR rows are promoted
  below the task header and excluded from the lower supporting-source list;
- the supplied canonical Agent OS `A` glyph, preserved as editable paths without
  geometric distortion, optically centered inside a padded rounded black app
  tile on a transparent canvas, and generated as a multi-resolution `.icns`
  copied into development and release bundles, plus an 18-point background-free
  template version of the same path geometry for the menu-bar extra;
- create outcome and validated lifecycle changes;
- bounded menu-bar counts and quick actions.
- a compact notice after newly discovered Codex projects are registered or
  enriched; skipped paths do not block the existing Board from loading.
- unified update settings: Sparkle owns packaged app/runtime updates, while the
  app compares the installed companion plugin with its signed bundled release
  metadata and can ask Codex to re-pin the official marketplace to that exact
  stable tag. Plugin installation and automatic app installation remain
  separate user opt-ins; failed plugin replacement restores the previous tag,
  newer plugins are not downgraded, and private state remains out of scope.

There is no team administration, agent runtime, container manager, hosted
database, transcript store, or provider write integration in the MVP.

## Verification

```bash
cd apps/agent-os
swift build
swift test
../../tools/sync-plugin-runtime --check
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME="$HOME/.agent-os" \
./script/build_and_run.sh --verify
```

The companion MCP clean-home test lives in `test/agent_os_mcp_test.rb`.
Release packaging additionally verifies nested code signatures, SHA-256, and
the Sparkle Ed25519 archive signature.

Swift regression coverage writes a watched file from a detached task and
asserts main-actor delivery, then invokes the Codex-open completion from a
utility queue. Live verification additionally mutates the canonical Task Board
while the built app is running and confirms that the process remains alive
without producing a new macOS diagnostic report.

Authenticated `gh` is optional and is discovered from the process `PATH` plus
the standard Apple Silicon and Intel Homebrew locations. Without it, PR rows
remain usable links with repository and PR-number context.

Done does not archive or delete canonical outcomes when a Codex task is
removed from the Codex sidebar. Outcome retention remains a Task Board concern;
Codex membership is only one linked source of activity evidence.
