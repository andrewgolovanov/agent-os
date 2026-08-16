# Review intake

Review intake remains read-only until a separate user request authorizes a mutation. Slack may provide context, but GitHub must confirm the canonical PR, author, state, and head SHA.

## User is the reviewer

1. Find or create a `kind=review` outcome.
2. Attach the canonical PR and Slack review root.
3. Prepare a separate analysis-only Codex handoff in the registered project path.
4. Include the repository, head SHA, PR URL, Task Board ID, and exact Slack root.
5. Save findings locally; do not publish a review or change code automatically.

## User is the author

1. Find the original delivery or research outcome by canonical PR.
2. Attach the review root and classify verified feedback.
3. Actionable changes return the outcome to `active`; approval normally leaves it in `review` until merge.
4. A verified merge may complete the outcome when no required follow-up remains.
5. Do not write automatically to a user-owned implementation task; update the Task Board snapshot.

When roles conflict, author behavior is safer. Ambiguity requires a user decision rather than a guess.
