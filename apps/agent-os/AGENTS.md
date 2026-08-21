# Agent OS macOS app instructions

## Product boundary

- Build a thin native macOS cockpit over the canonical Agent OS registry and Task Board.
- Never introduce a second task database or write `task.json`, `board.json`, `STATUS.md`, or `events.jsonl` directly.
- Perform task mutations through the registered Agent OS `tools/task-board` executable with argument arrays.
- Use Codex App Server over local `stdio` only. Do not depend on experimental WebSocket transport or private desktop APIs.
- Use the public `codex://threads/<id>` handoff for exact task navigation.
- Keep project pins as an ordered app-local presentation preference in `UserDefaults`; they must never alter the project registry, Task Board routing, Slack mappings, or plugin behavior.
- Slack remains a read-only source in the MVP.

## Structure

- Keep SwiftUI scenes in `Sources/AgentOS/App` and views in `Views`.
- Keep value models in `Models`, app-wide observable state in `Stores`, process clients in `Services`, and small glue in `Support`.
- Keep the companion Codex plugin package under `../../plugins/agent-os`.
- Package the synchronized minimal runtime from `../../plugins/agent-os/runtime` into `Contents/Resources/AgentOSRuntime`; first launch must initialize private state without requiring a source checkout.

## Validation

- Run `swift build` and `swift test` after Swift changes.
- Run `../../tools/sync-plugin-runtime --check` before bundle or release verification.
- Run `./script/build_and_run.sh --verify` for bundle launch verification.
- Run `./script/package_release.sh` to verify the ad-hoc signed package,
  checksum, Sparkle appcast, and Ed25519 archive signature.
- Validate the plugin with the plugin-creator validator before handoff.
