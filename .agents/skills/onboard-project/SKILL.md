---
name: onboard-project
description: Safely add or repair a wrapper or direct-repository project in an Agent OS installation. Use when the user asks to connect, register, onboard, rename, or document a project or existing repository under `projects/` and `config/projects.yaml`; verify topology first and never move repositories or change remotes as part of onboarding.
---

# Onboard Project

Create or repair one registered project while preserving all existing repositories and external state.

## Inputs

Obtain or derive only from verified local evidence:

- lowercase kebab-case project key;
- display name and useful aliases;
- layout: `wrapper` or `direct-repository`;
- absolute project root, normally `projects/<key>`;
- absolute paths to existing repositories;
- repository role, source of truth, primary branch, and publication target when known;
- optional external source URLs or IDs when explicitly provided.

Use `unknown` for missing optional facts. Stop the affected mutation if an unknown fact changes repository topology or publication destination; continue independent safe work.

## Workflow

1. Read root `AGENTS.md`, `config/projects.yaml`, `projects/README.md`, and `templates/project/`.
2. Check whether the requested key or alias already exists. Repair the existing record instead of creating a duplicate.
3. For each repository path, verify:
   - the resolved path and repository root;
   - `git remote -v`;
   - current branch and `HEAD`;
   - worktree status;
   - the closest repository `AGENTS.md`, when present.
4. Select `direct-repository` only when exactly one verified Git root already equals `projects/<key>/`; otherwise use `wrapper`. Never move a repository to force either layout.
5. Present a compact plan containing the selected layout, exact files to create or update, verified facts, unknown facts, and unchanged repositories.
6. For `wrapper`, create `projects/<key>/` from `templates/project/`, replacing all template values. For `direct-repository`, preserve its files and add one exact root `.gitignore` rule so the Agent OS repository cannot track it as a gitlink.
7. Add exactly one matching entry to `config/projects.yaml`. Keep this file the canonical structured registry.
8. For `wrapper`, describe project-only behavior in its `AGENTS.md` and durable context in `docs/PROJECT.md`. For `direct-repository`, use existing repository instructions and do not inject workspace metadata.
9. Do not create project tools until a deterministic workflow has repeated. Remove template-only rows or prose that would misrepresent current state.
10. Run `ruby tools/validate-agent-os` from the Agent OS source root.
11. Report created files, exact verified repository identities, unknowns, validation, and any user-only setup needed in the Codex UI.

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

For `wrapper`, mirror the project key and repository list in `projects/<key>/project.yaml`. For `direct-repository`, omit `project.yaml`; the registry is the only Agent OS metadata owner and the validator requires its single repository path to equal `wrapper`.

## Boundaries

- Do not move, delete, clone, fetch, pull, commit, push, or modify remotes as part of onboarding.
- Do not invent source-of-truth, provider project, Slack channel, task tracker, or Codex project IDs.
- Do not overwrite existing project or repository instructions without a targeted merge.
- Do not store credentials, raw conversations, or provider logs.
- Keep external integrations read-only unless the user separately authorizes a write action.
