# Slack Monitor runbook

This runbook belongs to one Agent OS-wide heartbeat monitor. It reads Slack
through the connected Slack integration, correlates new signals with the
canonical Task Board, and prepares a local handoff. A newly registered project
does not receive another automation: the project registry is used only for
attribution and routing.

## Configuration

A new installation previews the sanitized template before adding it to the
private home:

```bash
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00 \
  --apply
```

The command changes only private `AGENT_OS_HOME/config/monitors.yaml`; it neither connects
Slack nor creates a Codex Scheduled task. The complete sequence, canonical
prompt, and recovery procedure are in [optional integrations](optional-integrations.md).

1. Find `agent-os-slack-monitor` in private `AGENT_OS_HOME/config/monitors.yaml`.
2. Resolve the current Slack user profile again on every run and use its exact user ID for mention search.
3. Resolve project attribution through `AGENT_OS_HOME/config/projects.yaml`; never guess channel IDs or duplicate them in the Scheduled prompt.
4. Use `tools/task-board` for outcome state and `tools/slack-state` for the global cursor, per-channel cursors, seen ledger, and watched roots.

If the config, registry, or connected Slack integration is unavailable, record
a monitor failure. Never advance any cursor after a partial read.

## Authority

Allowed:

- read-only Slack observation;
- correlation with the local Task Board;
- creation or update of a local outcome snapshot;
- preparation of a `routing_pending` handoff;
- a compact recommendation to the user.

Without a separate user request, the monitor must not send Slack messages or
reactions, write an external tracker, edit code, commit, push, act on a pull
request, deploy, or manage a user-owned Codex task.

## Run sequence

1. Read the current Slack user profile. This is both the availability check and the source of the exact user ID and timezone.
2. Check the bounded set of open outcomes and `routing_pending` entries. When an
   open Slack source has no title, read only its exact root during this bounded
   pass and attach the short title. Do not scan surrounding history or backfill
   `done` and `cancelled` outcomes automatically.
3. Read active exact-root watches before general search because Slack search does not guarantee that every reply is returned.
4. Load the last successful cursor from `AGENT_OS_HOME/.runtime/dispatcher/slack-monitor.json` and apply the configured overlap. If the cursor is `null`, read only one configured interval plus overlap; do not backfill old history.
5. Search for exact `<@USER_ID>` mentions in all accessible public and private channels within the bounded window. Set `include_bots: true`; this catches searchable bot text but is not sufficient for Block Kit-only messages.
6. Dynamically list every public and private channel visible to the current user; do not use a configured channel allowlist. Page the complete inventory. For each channel, read only roots newer than its saved channel cursor, or the global bounded cursor when the channel is new.
7. In the dynamic channel pass, discard human-authored roots and bot/app roots that do not contain a mention resolving to the exact current user ID in their rendered text or blocks. A display-name string, `@channel`, `@here`, or user-group mention is not an exact user mention. Do not persist or semantically analyze discarded ambient messages.
8. For every matching bot/app root, read the thread to the end and apply the same unresolved-actionability rules as a human direct mention. Advance that channel with `tools/slack-state advance-channel --complete` only after its bounded pages and candidate threads were read completely. If rate limiting interrupts the inventory, preserve completed channel cursors, record a monitor failure, leave the global cursor unchanged, and resume remaining channels on the next run.
9. Search incoming direct messages and group direct messages separately. Deduplicate conversations and expand only candidates with a new unresolved ask; acknowledgements and FYI messages do not become outcomes.
10. For candidate roots and replies, read only enough thread or channel context to determine whether action remains. Registered project channels are attribution evidence only. Resolve the current channel display name only for an actionable named-channel signal that needs a Task Board label.
11. Identify each new message by `channel_id + thread_ts + message_ts` and check the exact-event ledger before processing it.
12. Correlate first by an exact Task Board source, then by registered channel mapping, explicit repository or pull-request links, and verified continuity. If the project is unknown, create one unassigned inbox outcome; never merge on similar wording alone. Attach the exact root permalink and root-message text through `agent_os_attach_source` or `tools/task-board source --title`; Task Board stores only a normalized 96-character display title. For a named Slack channel, upsert a display-only label with key `slack:<channel_id>`, current name `#channel-name`, and kind `slack_channel`.
13. Persist only disposition and stable identifiers through `tools/slack-state seen`. Do not save raw Slack message text, author names, or message summaries in runtime state. The short source title belongs only to the private Task Board source record and must come from the root message, never from replies or participant metadata.
14. After every source and the entire dynamic channel inventory complete successfully, record all seen events first, then advance watched-root cursors and the global cursor with the required `--complete` flag.
15. Before deciding whether to notify, run `tools/task-board summary --json`. Every user-facing `NOTIFY` must include the configured `notifications.agent_os_app` link and the current Agent OS-wide unfinished total. The app reads the same private Task Board state, so this link is the user-facing destination; do not link to internal generated files.

## Source-specific rules

### Mentions

- Search public and private channels for the exact current-user mention.
- Set `include_bots: true`, while retaining the dynamic channel pass because Slack search may omit Block Kit-only bot mentions.
- A mention inside a thread requires reading that thread to the end so an already resolved ask does not create an outcome.
- `@channel`, `@here`, and user-group mentions are not direct mentions of the current user.

### Bot and app mentions

- Discover visible public and private channels on every run; channel IDs are runtime identities and are never configured as an allowlist.
- Read only each channel's bounded new-root window. Filter by bot/app authorship first, then require a rendered mention that resolves to the exact current user ID.
- Once selected, process the complete thread exactly like a human mention: require a concrete unresolved ask, review, approval, blocker, or follow-up owned by the current user.
- A bot-authored FYI, automated status without the exact user mention, resolved review, or repeated event does not create an outcome.
- Advance one channel cursor only after its pages and matching threads are complete. Per-channel progress is resumable; the global cursor still requires the complete inventory.

### Direct and group direct messages

- Scan `im` and `mpim` separately because direct messages normally have no explicit mention.
- Keep only a conversation where the latest unresolved ask came from another person, or where new messages appeared after the user's last substantive response.
- Emoji-only messages, acknowledgements, and the user's own messages do not create outcomes.

### Attribution and task mutation

- Exact source identity has priority.
- Then use registered stable Slack channel ID mapping and explicit repository, pull-request, or project links.
- If a project is unregistered or ambiguous, keep the outcome unassigned and give it one concrete clarification next action.
- For an actionable named-channel signal, attach or refresh its Slack channel label even when no project is registered. The label remains on the outcome after reviewed project attribution. It supports display and filtering only; the separately registered stable channel mapping owns attribution.
- Do not derive labels from DM participant names, message text, or semantic guesses.
- Attach or refresh one short source title from the exact thread root. Do not concatenate replies, prepend an author, or use the title for correlation; Task Board normalizes Slack markup and truncates it to 96 characters.
- If an exact source already belongs to an outcome, update that outcome's current state, next action, blocker, sources, or lifecycle only when the new Slack context materially changes it.
- If no exact outcome exists and the ask is actionable, create one inbox outcome, attach its stable Slack source, and add a `routing_pending` handoff only when registered project routing is available.

Example:

```bash
tools/task-board source TASK_ID \
  --kind slack_threads \
  --value "https://slack.example/thread/ROOT_ID" \
  --title "Please verify the client launch checklist"

tools/slack-state seen \
  --channel CHANNEL_ID \
  --thread-ts ROOT_TIMESTAMP \
  --message-ts MESSAGE_TIMESTAMP \
  --permalink "https://slack.example/thread/ROOT_ID" \
  --disposition actionable \
  --project example-site \
  --task-id TASK_ID

tools/slack-state monitor-success --cursor CURSOR_TIMESTAMP --complete

tools/slack-state advance-channel \
  --channel CHANNEL_ID \
  --cursor CHANNEL_CURSOR_TIMESTAMP \
  --complete
```

## Watches

Each active root watch stores the exact channel and thread identity, the last
seen reply, reason, optional task ID, and expiry. Advance its cursor only after
the root has been read completely and all new events have been recorded.

Closed or done outcomes should gradually leave the bounded active scan; the
monitor does not need an infinite thread registry.

```bash
tools/slack-state close-watch --channel CHANNEL_ID --thread-ts ROOT_TIMESTAMP
```

## Circuit breaker and notifications

- The first outage may return `NOTIFY`.
- A repeated identical outage returns `DONT_NOTIFY` and leaves the cursor unchanged.
- Notify once when the integration recovers.
- An empty run, duplicate event, or unchanged state returns `DONT_NOTIFY`.
- A source-title-only backfill or refresh returns `DONT_NOTIFY`.
- A new actionable outcome, blocker, ambiguity, or material lifecycle change returns `NOTIFY`.
- Every `NOTIFY` includes the clickable Agent OS app link and the current total of unfinished outcomes. A quiet `DONT_NOTIFY` does not create a notification only because the unchanged total exists.

The monitor does not use Chrome, Slack Desktop, or Computer Use as a fallback.
Structured bot-mention discovery performs a bounded read of new roots across
dynamically visible channels, but it immediately discards nonmatching ambient
messages and never persists or treats them as task context.
