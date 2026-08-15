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
- layout derived by Agent OS as `wrapper` or `direct-repository`;
- absolute existing Git root from any local folder;
- absolute paths to existing repositories;
- repository role, source of truth, primary branch, and publication target when known;
- optional external source URLs or IDs when explicitly provided.

Use `unknown` for missing optional facts. Stop the affected mutation if an unknown fact changes repository topology or publication destination; continue independent safe work.

## Workflow

1. Prefer the installed MCP workflow: list current projects, then call `agent_os_onboard_project` with `apply: false`. From a source checkout, the equivalent preview is `bin/agent-os onboard-project --repository /absolute/repository --json`.
2. Review the returned repository root, remote, current branch, `HEAD`, worktree state, proposed key, selected layout, exact files, and unchanged repository path.
3. Apply only after the user approves that exact preview. Use the same MCP arguments with `apply: true`, or add `--apply` to the reviewed CLI command.
4. If an already registered repository was moved separately by the user, preview
   `agent_os_relink_project` (or `bin/agent-os relink-project`) instead of
   onboarding a duplicate. Verify the same Git root and origin identity, then
   apply only the reviewed private metadata change.
5. List projects again and read the registered project root `AGENTS.md` before substantive work.
6. Run `ruby tools/validate-agent-os` only when working from a full Agent OS source checkout; packaged runtime users validate the resulting MCP response and registry listing.

## Registry entry

Use this shape and omit empty optional collections only when the schema permits:

```yaml
project-key:
  display_name: Project Name
  status: active
  layout: wrapper
  aliases: []
  wrapper: /absolute/agent-os-home/projects/project-key
  repositories:
    - id: repository-id
      path: /absolute/path/to/repository
      role: primary
      source_of_truth: unknown
      primary_branch: unknown
```

For `wrapper`, mirror the project key and repository list in
`AGENT_OS_HOME/projects/<key>/project.yaml`. For `direct-repository`, omit
`project.yaml`; the registry is the only Agent OS metadata owner and the
validator requires its single repository path to equal `wrapper`. Relink may
preserve that equality in an external absolute folder after a separate move.

## Boundaries

- Do not move, delete, clone, fetch, pull, commit, push, or modify remotes as part of onboarding.
- Do not invent source-of-truth, provider project, Slack channel, task tracker, or Codex project IDs.
- Do not overwrite existing project or repository instructions without a targeted merge.
- Do not store credentials, raw conversations, or provider logs.
- Keep external integrations read-only unless the user separately authorizes a write action.
