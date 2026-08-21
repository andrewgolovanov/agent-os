# 0021 — Auto-register active Codex repositories

Date: 2026-08-21

Status: accepted

## Context

Manual onboarding left valid repositories absent from Agent OS until the user
remembered to register them. A later Slack signal could contain an exact pull
request or repository link, yet remain unassigned because the corresponding
Git root was unknown. Codex exposes active task working directories through the
public App Server, but it does not expose a public project-list API. Codex task
history also contains missing folders, non-Git paths, transient worktrees, and
duplicate checkouts.

## Decision

- On app launch, page public App Server `thread/list` with `archived: false`
  and use only unique `cwd` metadata. Never call `thread/read` for discovery or
  import historical task content.
- Before Task Bridge handles a new task, run the same synchronization for the
  current hook `cwd`.
- Normalize candidates to real Git roots, collapse nested paths and equivalent
  normalized origins, and prefer a durable checkout over `.codex/worktrees`.
- Automatically add only deterministic new registry entries. Preserve existing
  entries and skip missing paths, non-Git folders, unborn repositories,
  ambiguous keys, or worktree-only candidates.
- Keep manual onboarding preview-first for skipped repositories,
  multi-repository projects, relinking, and Slack channel reconciliation.
- Never move or modify a repository, create a Task Board outcome, map a Slack
  channel, or migrate old Slack/Codex tasks during synchronization.

## Consequences

- First-run users see eligible repositories already available in Agent OS.
- A repository first opened later is registered before Task Bridge routing.
- Exact future Slack repository or pull-request evidence can resolve against
  the registry without importing historical work.
- The private project registry gains a narrow automatic mutation path; every
  ambiguous case still fails closed and remains available for manual review.
