---
name: onboard-project
description: Safely register or relink an existing local Git repository in Agent OS without moving it. Use when the user asks to onboard, connect, add, register, or repair the path of a project from any folder on the computer.
---

# Onboard an Agent OS project

Use the Agent OS MCP server as the only project-registry interface.

1. Call `agent_os_list_projects` and reuse an existing registration for the same repository.
2. For an unregistered repository, call `agent_os_onboard_project` with the repository's absolute path and `apply: false`. Agent OS stores its verified root and repository metadata in the private registry and works from any local folder.
3. Review any `suggested_channels` returned by the preview. A normalized channel name is suggestion evidence only. If the user wants one linked, call `agent_os_onboard_project` again with `apply: false` and the exact suggested IDs in `slackChannelIds`; report every selected mapping and open unassigned outcome in `task_assignments`.
4. Apply only after the user approves that exact selected preview. Call the same tool with the reviewed `slackChannelIds` and `apply: true`. Existing card labels remain; only project attribution and registry mapping change.
5. For an already registered repository that the user moved, call `agent_os_relink_project` with its existing key, new absolute path, and `apply: false`. Include `repositoryId` when the project registers multiple repositories.
6. If the registry contains obsolete `layout` or `wrapper` fields, preview `agent_os_upgrade_project_registry`. This is a one-way migration; report every resulting root and private recovery-backup path.
7. Report the verified Git root, remote, branch, HEAD, worktree state, project key, files to change, and whether the repository path stays in place or was already moved by the user.
8. Call `agent_os_list_projects` again and report the final key, mapped Slack channel IDs, and working directory.

Never move, clone, fetch, pull, commit, push, change remotes, or edit the registry directly during onboarding or relinking. The relink tool only updates Agent OS metadata after a physical move has already happened. Keep unknown optional facts as `unknown`; do not invent publication targets or external integrations. Never select a Slack suggestion without explicit user approval, replace a non-empty project attribution, merge outcomes by similar names, or remove channel labels from task cards.
