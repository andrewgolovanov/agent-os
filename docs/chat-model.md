# Codex task model

The root Agent OS task coordinates architecture, monitoring, and cross-project work. Ordinary implementation should happen in the registered project path so repository instructions and project-scoped tooling apply.

## Durable membership

- A durable Codex task is registered only by exact `thread_id`.
- One Codex task has at most one current `active` or `idle` outcome membership;
  archived memberships preserve earlier outcome history.
- Title, creation time, branch, and semantic similarity never replace the thread ID.
- Independent tasks and forks are peer relationships; an outcome has no required primary task.
- Spawned subagent threads are not registered.
- Disposable questions do not create Task Board membership.

## Starting project work

1. Find or create one Task Board outcome.
2. Open a separate Codex task in the registered project path and include the exact Task Board ID or a stable Slack, GitHub, or Figma source in the first meaningful prompt.
3. Task Bridge attaches the exact `session_id` only when there is one exact match. Without one, the agent presents candidates and requires an explicit `claim` before substantive mutations.
4. After material changes, checkpoint a verified summary, one next action, and `active`, `review`, or `waiting`. Only explicit user decisions set `done` or `cancelled`.

The hook measures linked Codex turns, changes membership between `active` and `idle`, and activates a newly started outcome. `Stop` ends one agent response, not the whole outcome; the checkpoint records lifecycle after implementation.

Opening a registered project path does not select an outcome because several outcomes may exist in one project. The reliable flow is:

1. Mention the exact outcome ID or stable source URL in the project task so Task Bridge can claim and start it.
2. If the prompt has no exact identity, use the suggested `claim TASK_ID`; a similar title never links work automatically.
3. Let the agent checkpoint material progress; the user supplies only domain decisions such as wait, resume, ready for review, close, or cancel.
4. If the user explicitly changes outcomes in the same chat, use `reassign` with
   the exact target ID before substantive work. The open turn follows the new
   outcome; completed time stays with the previous one.
5. If work began before Task Bridge was installed, import only proven session and turn timestamps, then continue in a fresh hooked task.

Codex membership and Task Board lifecycle are independent. Membership says whether a turn is running now (`active` or `idle`); lifecycle describes the overall result (`inbox`, `planned`, `active`, `waiting`, `review`, `done`, or `cancelled`).

## Ownership gate

A direct user message in a routed Codex task transfers that task to user ownership. Monitoring may continue to update Task Board, but it must not write to, wake, stop, or reroute the task without another explicit user request.

## Handoff

A self-contained handoff includes:

- Task Board ID and goal;
- exact project and repository paths;
- current verified summary and next action;
- exact external identities and URLs;
- permissions and explicit prohibitions;
- validation already completed and validation still required.

If a registered path or stable thread ID is unknown, create `routing_pending` rather than inventing membership.
