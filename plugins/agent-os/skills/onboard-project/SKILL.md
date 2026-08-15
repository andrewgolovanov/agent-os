---
name: onboard-project
description: Safely register an existing local Git repository in Agent OS without moving it. Use when the user asks to onboard, connect, add, or register a project from any folder on the computer.
---

# Onboard an Agent OS project

Use the Agent OS MCP server as the only project-registry interface.

1. Call `agent_os_list_projects` and reuse an existing registration for the same repository.
2. Call `agent_os_onboard_project` with the repository's absolute path and `apply: false`.
3. Report the verified Git root, remote, branch, HEAD, worktree state, proposed key, selected layout, files to create, and the unchanged repository path.
4. Apply only after the user approves that exact preview. Call the same tool with the reviewed arguments and `apply: true`.
5. Call `agent_os_list_projects` again and report the final key and working directory.

Never move, clone, fetch, pull, commit, push, change remotes, or edit the registry directly during onboarding. Keep unknown optional facts as `unknown`; do not invent publication targets or external integrations.
