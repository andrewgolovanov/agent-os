# Workflows

## Synchronize Codex projects

1. On first app launch, page through public Codex App Server `thread/list` with
   `archived: false` and collect only unique `cwd` metadata.
2. Normalize each directory to a real Git root. Collapse nested paths and
   equivalent origins, and replace transient Codex worktrees with a durable
   checkout when one exists.
3. Automatically register only deterministic roots whose project key is not
   owned by another repository. Preserve existing entries and skip every
   unavailable, non-Git, unborn, ambiguous, or worktree-only candidate.
4. At `UserPromptSubmit`, apply the same idempotent operation to the current
   task `cwd` before Task Bridge resolves the project.
5. Never read thread bodies, create outcomes, migrate Slack history, map
   channels, move repositories, or change Git state during synchronization.

## Onboard a project manually

1. Invoke `$onboard-project` from the existing repository.
2. Provide a project key, display name, and absolute paths for its repositories.
3. Verify each repository root, remotes, branch, HEAD, and dirty state.
4. Register the existing Git root from any folder as project `root`.
5. Review the registry mutation preview and any conservative Slack channel suggestions. Suggestions are display-only until exact channel IDs are selected.
6. When a suggested channel really belongs to the project, preview again with those exact channel IDs. Confirm that only unfinished outcomes with no current project would be assigned.
7. After approval, update private `AGENT_OS_HOME/config/projects.yaml` and the selected Task Board attribution only through Agent OS MCP or CLI operations. Existing project attribution and Slack labels remain unchanged.
8. Run `ruby tools/validate-agent-os` and `tools/task-board validate` against the selected private home.
9. Report verified and unknown facts separately.

Onboarding does not authorize clone, move, remote changes, commits, publication, or semantic outcome merging. It writes no wrapper or Agent OS metadata into the product repository. Re-running onboarding for an existing project may use the same preview-first flow to add reviewed channel mappings and reconcile still-unassigned unfinished work.

If the registry still has legacy `layout` or `wrapper` fields, preview `agent_os_upgrade_project_registry`. Apply performs a one-way migration to `root + repositories` and preserves the former managed directory in a private recovery backup. New onboarding never creates those directories.

## Relink a moved repository

1. Confirm that the physical move already happened under explicit user intent.
2. Verify the new Git root, origin, branch, HEAD, and dirty state.
3. Invoke `agent_os_relink_project` with the existing project key and new absolute path; include repository ID for a multi-repository project.
4. Review the preview and verify that only private registry metadata changes.
5. Apply the same relink after approval and validate registry and Task Board state.

Relink never moves a repository or changes Git files, remotes, branches, or history.

## Start project work

1. Resolve the project name or alias through private `AGENT_OS_HOME/config/projects.yaml`.
2. Read `AGENTS.md` at the registered project root.
3. For a multi-repository project, read the nearest repository `AGENTS.md` before editing it.
4. Verify Git identity and dirty state.
5. For durable work, include the exact Task Board ID or a stable source URL in the first project-task prompt. Task Bridge attaches `session_id` only for one exact match.
6. Without an exact match, explicitly claim a suggested outcome through `tools/task-bridge claim` or create one through `tools/task-board`; never guess by title or branch.
7. Perform and validate work in the project repository. Task Bridge measures exact Codex turns, not human pauses.
8. After material changes, checkpoint a verified summary, next action, and lifecycle status. `done` remains an explicit user decision.

## Durable outcome lifecycle

```text
inbox -> planned -> active -> review -> done
                       \-> waiting -> active
```

- `inbox`: discovered but not triaged.
- `planned`: scope and next action are confirmed.
- `active`: one current next action exists.
- `waiting`: an external blocker and resume condition are recorded.
- `review`: implementation or analysis awaits verification or merge.
- `done`: result and validation are recorded with no required work left.
- `cancelled`: the outcome was intentionally stopped with a recorded reason.

Change lifecycle only through `tools/task-board`. Private `task.json` is the structured source, `STATUS.md` is generated handoff, and `events.jsonl` is append-only material history.

## Slack intake

1. One Agent OS heartbeat resolves the current Slack user through the connected integration.
2. Active watched roots are read before global mention and DM search.
3. Human direct mentions are searched across accessible public and private channels; DMs and group DMs are read separately.
4. Visible public/private channels are discovered dynamically. Only their new
   root-message window is read, and only bot/app roots containing an exact
   current-user mention are expanded and processed like human mention threads.
5. Exact event identity is checked through `tools/slack-state`.
6. Correlation uses stable Task Board sources and verified registry attribution, not similar text.
7. A registered stable Slack channel mapping provides project attribution. Without one, an unknown-project named-channel signal may become an unassigned inbox outcome with a display-only `#channel-name` label keyed by the stable Slack channel ID.
8. Channel labels remain visible on task cards after attribution. They support scanning and filtering but never become project keys, repository paths, source identity, or routing authority. DMs do not persist participant names as labels.
9. A channel cursor advances only after that channel page is complete; the global cursor advances only after every configured source and the full dynamic channel inventory are complete.
10. Nonmatching ambient messages are discarded immediately and never persisted or analyzed as tasks. External messages, code or Git mutations, deployments, and management of user-owned Codex tasks are prohibited.

See `docs/slack-monitor.md` for the canonical sequence and circuit breaker.

## Change Agent OS

1. Identify the owner of the changed knowledge through `docs/architecture.md`.
2. Make the smallest change without duplicating facts.
3. Update the owning document, `docs/state.md`, and `docs/changelog.md`.
4. Add a decision record when the rationale is non-obvious.
5. Run Agent OS validation.

## Create a skill

1. Gather at least two real examples of the repeated procedure.
2. Define one job and precise trigger phrases.
3. Default to an instruction-only skill in `.agents/skills/<name>/`.
4. Add a script only for a deterministic or fragile operation.
5. Run the skill validator and one realistic dry run.

See `docs/extending.md` for the full criteria.
