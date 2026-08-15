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
| Provider context | exact source URLs | open only; no ambient write |

The app never edits Task Board JSON or Markdown directly and owns no database.
All task mutations use the source checkout's executable with an argument array.

## Source and home

- `AGENT_OS_SOURCE_ROOT` points to reusable executables.
- `AGENT_OS_HOME` points to private registry, tasks, and runtime.
- If the source variable is absent, the app reads `AGENT_OS_HOME/source-path`.
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
- selected outcome inspector with goal, summary, next action, blocker, sources,
  Codex memberships, and tracked outcome time;
- create outcome and validated lifecycle changes;
- bounded menu-bar counts and quick actions.
- unified update settings: tagged core/plugin updates plus Sparkle app updates,
  both automatic-install options disabled until the user opts in.

There is no team administration, agent runtime, container manager, hosted
database, transcript store, or provider write integration in the MVP.

## Verification

```bash
cd apps/agent-os
swift build
swift test
AGENT_OS_SOURCE_ROOT=/absolute/path/to/agent-os \
AGENT_OS_HOME="$HOME/.agent-os" \
./script/build_and_run.sh --verify
```

The companion MCP clean-home test lives in `test/agent_os_mcp_test.rb`.
Release packaging additionally verifies nested code signatures, SHA-256, and
the Sparkle Ed25519 archive signature.
