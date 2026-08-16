# 0002: Support direct repositories under projects

- Status: superseded by 0016
- Date: 2026-08-09

## Context

The first real pilot had been placed manually at `projects/<key>` as a complete Git repository. The original architecture supported only wrappers, which would have required another repository move or Agent OS metadata inside product source.

## Historical decision

Support two explicit project layouts:

- `wrapper` for Agent OS-owned context pointing to one or more external repositories;
- `direct-repository` for one existing Git root that also served as the registered project root.

The direct root initially lived under `projects/<key>`. Decisions 0013 and the identity-checked relink later allowed that repository to remain in any absolute user-selected folder. Direct layout stored structured Agent OS metadata only in `AGENT_OS_HOME/config/projects.yaml` and excluded the exact embedded repository from Agent OS Git history.

## Historical consequences

- Direct repositories kept independent remotes, history, instructions, and dirty worktrees.
- Agent OS avoided accidental embedded-repository gitlinks.
- Multi-repository projects still depended on wrapper layout.
- Moving between layouts required a separate explicit operation.

## Supersession

Decision 0016 replaces both layouts with one registry-only `root + repositories` model. This record remains only as historical rationale for keeping repositories in user-selected locations.
