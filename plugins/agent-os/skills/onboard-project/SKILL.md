---
name: onboard-project
description: Safely register or relink an existing local Git repository in Agent OS without moving it. Use when the user asks to onboard, connect, add, register, or repair the path of a project from any folder on the computer.
---

# Onboard an Agent OS project

Use the Agent OS MCP server as the only project-registry interface.

1. Call `agent_os_list_projects` and reuse an existing registration for the same repository.
2. For an unregistered repository, call `agent_os_onboard_project` with the repository's absolute path and `apply: false`.
3. For an already registered repository that the user moved, call `agent_os_relink_project` with its existing key, new absolute path, and `apply: false`. Include `repositoryId` when the project registers multiple repositories.
4. Report the verified Git root, remote, branch, HEAD, worktree state, project key, selected layout, files to change, and whether the repository path stays in place or was already moved by the user.
5. Apply only after the user approves that exact preview. Call the same tool with the reviewed arguments and `apply: true`.
6. Call `agent_os_list_projects` again and report the final key and working directory.

Never move, clone, fetch, pull, commit, push, change remotes, or edit the registry directly during onboarding or relinking. The relink tool only updates Agent OS metadata after a physical move has already happened. Keep unknown optional facts as `unknown`; do not invent publication targets or external integrations.
