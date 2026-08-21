# 0023 — Projects do not require Git

Date: 2026-08-21

Status: accepted

Supersedes: the Git-only eligibility rules in 0021

## Context

Decision 0021 removed a manual onboarding step for active Codex repositories,
but it still treated a committed Git root as the project identity. A user can
start durable local work before `git init`, before the first commit, before a
remote exists, or without ever creating a repository. Excluding those folders
also prevents Task Bridge and future Slack routing from using the project even
though the native Board itself needs only a working directory.

## Decision

- A project is identified by an existing absolute local `root`; its
  `repositories` collection may be empty indefinitely.
- App-launch discovery and the task-start hook register deterministic `cwd`
  roots without requiring Git or reading task bodies.
- A committed Git repository discovered later at the exact project root is
  attached to the existing entry. Newly available branch or origin metadata is
  filled without replacing known identity or changing Git state.
- Same-name roots receive a deterministic path-derived project-key suffix.
- Nested paths collapse into a registered parent. A new parent that would
  overlap an existing child, nested repository attachment, and multi-repository
  topology remain manual reviewed cases.
- Missing folders are never removed automatically. Duplicate origins,
  ambiguous overlaps, and transient Codex worktrees without a durable checkout
  fail closed.
- The private Agent OS home is operational state, not a registrable project,
  even when a Scheduled task uses it as a technical working directory.
- No historical Codex or Slack content is imported and no Task Board outcome is
  created by project synchronization.

## Consequences

- A user receives an Agent OS project and Board routing as soon as work begins
  in a local folder, whether or not Git ever exists.
- Later repository setup enriches the same project key, preserving tasks,
  aliases, Slack mappings, and historical attribution.
- The project registry remains the only metadata owner, while Git and provider
  state stay optional external facts.
