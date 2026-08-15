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
| Project identity and paths | private `config/projects.yaml` | read and present |
| Outcome lifecycle | private Task Board via `tools/task-board` | invoke validated actions |
| Task index | generated private `work/board.json` | refresh/read model |
| Codex tasks | Codex App Server | create/name exact idle task and hand off |
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
- The private home defaults to `~/.agent-os`.
- `WORKSPACE_CONSOLE_ROOT` remains only as a deprecated compatibility alias for older
  one-directory installations.

## Codex handoff

The app creates and names an idle task through stable App Server `stdio`, records
the exact membership through `tools/task-board`, copies the prepared first
prompt, and opens the public `codex://threads/<id>` handoff. It does not start a
competing background turn from a second App Server client.

## UI scope

- regular SwiftUI window with Focus and Board views;
- project/outcome filtering and search;
- the official shadcn default Neutral dark tokens mapped into SwiftUI semantic
  roles: `#0a0a0a` background, `#171717` card/sidebar, `#262626`
  muted/accent, 10% borders, 15% input borders, and `#a3a3a3` muted text;
- dashboard-01 geometry for the native equivalents: a 48-point toolbar rhythm,
  36-point default controls, 32-point compact controls, 16-point icons, a
  4-point spacing grid, and the documented shadcn radius scale;
- a native resizable task-detail split that stays closed by default, opens only
  from task selection without a sheet transition, and closes through its button
  or Escape without retaining stale selection; while it is open, a translucent
  backdrop dims and disables the Focus or Board pane and closes the detail when
  clicked without covering the inspector, toolbar, or project sidebar;
- selected outcome details with goal, summary, next action, blocker, sources,
  Codex memberships, and tracked outcome time in the header;
- registered project display names directly in Focus rows for mixed-project
  scanning without opening task details;
- tracked outcome time at the top of every Board card for immediate scanning;
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
  external-link affordances, privacy-safe Slack permalink context, and optional
  live GitHub pull-request title/state/review metadata; PR rows are promoted
  below the task header and excluded from the lower supporting-source list;
- the supplied canonical Agent OS `A` glyph, preserved as editable paths without
  geometric distortion, optically centered inside a padded rounded black app
  tile on a transparent canvas, and generated as a multi-resolution `.icns`
  copied into development and release bundles, plus an 18-point background-free
  template version of the same path geometry for the menu-bar extra;
- create outcome and validated lifecycle changes;
- bounded menu-bar counts and quick actions.
- unified update settings: Sparkle owns packaged app/runtime updates, while
  Codex owns versioned marketplace snapshots of the companion plugin; automatic
  app installation remains disabled until the user opts in.

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

Authenticated `gh` is optional and is discovered from the process `PATH` plus
the standard Apple Silicon and Intel Homebrew locations. Without it, PR rows
remain usable links with repository and PR-number context.
