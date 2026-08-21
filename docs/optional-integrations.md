# Optional integrations

Agent OS installs without provider access, schedules, or external write authority. Optional integrations are assembled from four independently owned pieces so a user can inspect, enable, repair, or remove each one without guessing.

| Piece | Canonical owner | Agent OS responsibility |
| --- | --- | --- |
| Slack connection and permissions | connected Slack integration in Codex | require the smallest read-only access and never store credentials |
| Monitor policy and local schedule intent | private `AGENT_OS_HOME/config/monitors.yaml` | preview and merge one sanitized monitor entry |
| Recurring execution | Codex Scheduled | create or update only after explicit user approval |
| Task Bridge events | installed Agent OS plugin hooks | ship the exact hook bundle; user reviews trust with `/hooks` |

The local CLI never claims it can inspect or change Codex Scheduled or a connected Slack account.

## Quick setup

Install the public plugin snapshot, review its hooks, and start a fresh Agent OS
task:

```bash
codex plugin marketplace add andrewgolovanov/agent-os --ref v0.7.1
codex plugin add agent-os@agent-os
```

In Codex, open `/hooks`, review the Agent OS command hooks, and trust them only if their command resolves to the installed `agent-os@agent-os` plugin. Start a fresh task after that review; an already running task cannot load a newly installed or changed hook bundle.

Then ask Codex: `Set up optional Agent OS integrations safely.` The `setup-agent-os` skill will preserve the sequence below and use the product automation capability when it is available.

## Configure the Slack monitor

The command is preview-only by default:

```bash
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00
```

After reviewing the exact target, schedule, and read-only authority:

```bash
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00 \
  --apply
```

This merges only `agent-os-slack-monitor` into the private `monitors.yaml`, creates no provider connection, and creates no Scheduled task. If that key already differs, the command stops. `--replace` is available only for a separately reviewed replacement of that exact entry.

Before scheduling, use a normal Codex task to verify one complete read-only pass against [the Slack monitor runbook](slack-monitor.md). A partial provider read must not advance the cursor. An unchanged second pass should produce `DONT_NOTIFY`.

## Scheduled task

Use these canonical values:

- name: `Agent OS Slack Monitor`;
- working directory: a registered project path when one exists, otherwise the
  active `AGENT_OS_HOME` opened as a non-version-controlled local project;
- schedule: the timezone, days, and local times in private
  `AGENT_OS_HOME/config/monitors.yaml`;
- prompt: the block below.

```text
Run the Agent OS Slack monitor once. Use the installed Agent OS plugin and its active private home. Read the active private home's config/monitors.yaml entry named agent-os-slack-monitor and the installed Slack monitor runbook before acting. Require that monitor to be enabled. Use only the connected Slack integration and only read-only Slack operations. Resolve the current Slack user each run; scan the configured bounded human mentions with bot search enabled, direct messages, group direct messages, and active watched roots. Dynamically list all public and private channels visible to that user, read only each channel's new root-message window, and retain only bot/app roots whose rendered text or blocks mention the exact current user ID; process those complete threads with the same unresolved-actionability rules as human mentions. Do not use a configured channel allowlist, persist nonmatching ambient messages, or treat display-name text and broad mentions as personal mentions. Attribute only through the registered project configuration. Store only stable identifiers, global and per-channel cursors, dispositions, and local Task Board changes through the installed Agent OS runtime. A Task Board Slack source may retain only the runbook-defined normalized short title from its root message; never store full raw message text, replies, or author metadata. Do not send Slack messages or reactions, write external tasks, edit repositories, run Git mutations, or deploy. Advance a channel cursor only after its bounded read completes, and never advance the global cursor after a partial inventory or source read. Return DONT_NOTIFY when nothing actionable changed; otherwise return the compact notification required by the runbook, including its Agent OS app link.
```

Codex Scheduled is the authority for whether this automation exists and is enabled. Inspect an existing task with the exact name before creating another one. If the current Codex surface cannot manage Scheduled tasks, create it from Codex desktop or web rather than inventing a CLI fallback. A local-project schedule runs only while its required desktop environment and machine are available, so verify the first two executions in the Scheduled task history. A user with no repositories does not need a fake Git project: Codex supports scheduled work in a non-version-controlled local directory, and the already initialized active Agent OS home provides that stable context.

The monitor does not push data into a second app database. It writes outcomes
through the installed Task Board runtime under the active private home, and the
Agent OS app reads that same canonical state. A successful monitor change is
therefore visible after the app refreshes; the notification deep link
`agent-os://board` opens that shared Board directly.

## Verify and recover

```bash
./bin/agent-os doctor --integrations
./tools/slack-state validate
```

`doctor --integrations` distinguishes core readiness from optional evidence. It
can verify local monitor config and the selected runtime's bundled hook files.
It cannot prove that an installed snapshot is current, Slack authentication,
hook trust in the current task, or the enabled state of a Codex Scheduled task.
Historical Task Bridge runtime files are not proof that the currently open task
loaded the latest hooks.

On repeated Slack failure, keep the last successful cursor, fix the connected integration, and run one manual pass before re-enabling the schedule. To remove the integration, disable or delete `Agent OS Slack Monitor` in Codex Scheduled and remove or set `enabled: false` on only the private `agent-os-slack-monitor` entry. Disable the Agent OS plugin as well only if Task Bridge hooks and MCP task operations are no longer wanted.
