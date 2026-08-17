---
name: agent-os
description: Use when listing, creating, or updating canonical Agent OS Task Board outcomes through the Agent OS MCP tools.
---

# Agent OS

Use the Agent OS MCP server as the only Agent OS task-state interface.

1. Call `agent_os_list_projects` when project identity or working directory matters.
2. Call `agent_os_list_tasks` before choosing an existing outcome.
3. Mutate only an exact task ID supplied by the user or returned by the list call.
4. Use one `agent_os_update_task` call for one coherent lifecycle change.
5. Use `agent_os_create_task` only when no exact canonical outcome already owns the requested result.
6. Use `agent_os_attach_source` for an exact external identity. For a Slack thread, pass the exact root permalink and optionally the root-message text as `title`; Task Board stores only its normalized 96-character display title, while the permalink remains correlation authority.
7. Use `agent_os_label_task` for a display-only Slack channel label. Keep its stable key namespaced by channel ID, such as `slack:C123`, and its current name human-readable, such as `#client-checks`; never place an unregistered channel name in `projects`.
8. When a done outcome has pending external follow-up, update `completionFollowUp` separately after the user confirms that the completion message was sent or is not required.
9. Never edit `task.json`, `board.json`, `STATUS.md`, or `events.jsonl` directly.
10. Never pass or infer Agent OS source or private-home roots. The plugin bootstraps and constrains them automatically; project repository paths remain explicit onboarding inputs.
11. Report the canonical task ID, resulting status, next action, completion follow-up state, and event-count delta after a mutation.

If exact identity is unavailable or ambiguous, stop without mutating state.
