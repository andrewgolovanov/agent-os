---
name: onboard-project
description: Safely register or relink an existing local Git repository in Agent OS without moving it. Use when the user asks to connect, register, onboard, rename, or repair the path of a project from any folder; verify topology first and never move repositories or change remotes as part of onboarding.
---

# Onboard Project

Create or repair one registered project while preserving all existing repositories and external state.

## Inputs

Obtain or derive only from verified local evidence:

- lowercase kebab-case project key;
- display name and useful aliases;
- absolute existing Git root from any local folder;
- absolute paths to existing repositories;
- repository role, source of truth, primary branch, and publication target when known;
- optional Slack channel IDs returned as safe suggestions by the onboarding preview.

Use `unknown` for missing optional facts. Stop the affected mutation if an unknown fact changes repository topology or publication destination; continue independent safe work.

## Workflow

1. Prefer the installed MCP workflow: list current projects, then call `agent_os_onboard_project` with `apply: false`. From a source checkout, the equivalent preview is `bin/agent-os onboard-project --repository /absolute/repository --json`.
2. Review the returned repository root, remote, current branch, `HEAD`, worktree state, proposed key, exact files, unchanged repository path, and any conservative Slack channel suggestions. A suggestion is not selected automatically.
3. When the user wants a suggested channel linked, run a second `apply: false` preview with the exact returned `slackChannelIds`, or repeat `--slack-channel CHANNEL_ID` in the CLI. Report the selected mappings and every open unassigned outcome that would gain the project; channel labels remain on those cards.
4. Apply only after the user approves that exact selected preview. Use the same MCP arguments with `apply: true`, or add `--apply` to that reviewed CLI command.
5. If an already registered repository was moved separately by the user, preview
   `agent_os_relink_project` (or `bin/agent-os relink-project`) instead of
   onboarding a duplicate. Verify the same Git root and origin identity, then
   apply only the reviewed private metadata change.
6. If the registry contains obsolete `layout` or `wrapper` fields, preview
   `agent_os_upgrade_project_registry`. Apply the one-way migration only after
   reviewing every new root and recovery-backup path.
7. List projects again and read the registered project root `AGENTS.md` before substantive work.
8. Run `ruby tools/validate-agent-os` only when working from a full Agent OS source checkout; packaged runtime users validate the resulting MCP response and registry listing.

## Registry entry

Use this shape and omit empty optional collections only when the schema permits:

```yaml
project-key:
  display_name: Project Name
  status: active
  aliases: []
  root: /absolute/path/to/repository
  slack_channels:
    - id: CEXAMPLE
      name: "#project-name-int"
  repositories:
    - id: repository-id
      path: /absolute/path/to/repository
      role: primary
      source_of_truth: unknown
      primary_branch: unknown
```

The registry is the only Agent OS metadata owner. `slack_channels` contains only
reviewed stable channel IDs and their current display names. Applying a selected
mapping assigns only unfinished outcomes that are still unassigned; it never
replaces another project's attribution, merges outcomes by title, or removes the
channel label from a task card. A single-repository project's
`root` equals its registered Git root. Relink preserves that equality after a
separate user-controlled move. Multi-repository entries list every repository
in the same registry; Agent OS does not create a project container folder.

## Boundaries

- Do not move, delete, clone, fetch, pull, commit, push, or modify remotes as part of onboarding.
- Do not invent source-of-truth, provider project, Slack channel, task tracker, or Codex project IDs. Channel-name matching may produce a preview suggestion only; stable IDs and explicit approval own the mapping.
- Do not overwrite existing project or repository instructions without a targeted merge.
- Do not store credentials, raw conversations, or provider logs.
- Keep external integrations read-only unless the user separately authorizes a write action.
