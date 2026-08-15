---
name: setup-agent-os
description: Configure or repair optional Agent OS integrations, including the read-only Slack monitor, Codex Scheduled task, and plugin-bundled Task Bridge hooks. Use when a user asks to set up Agent OS automation, Slack intake, scheduled monitoring, hooks, or a fresh installation's optional integrations.
---

# Set up Agent OS

Keep reusable configuration in the active Agent OS runtime, private configuration and runtime state in the active Agent OS home, and provider/product state in the provider that owns it. The plugin bootstraps its bundled runtime automatically; do not require a manual repository checkout. Never invent a local API for a Codex Scheduled task or silently grant external write authority.

## Workflow

1. Resolve the active Agent OS home from `AGENT_OS_HOME`, the active-home pointer, or `~/.agent-os`, then resolve its `source-path`. Run that runtime's `bin/agent-os doctor --integrations --json` and report core failures separately from optional checks.
2. Confirm the Agent OS plugin is installed. Its Task Bridge hooks are bundled at `plugins/agent-os/hooks/hooks.json`; do not add a second user-level copy. Ask the user to review and trust them with `/hooks`, then start a fresh project task. Existing tasks do not reload hooks.
3. For Slack setup, verify a connected Slack integration with the smallest read-only profile request available. If it is unavailable, stop only the Slack portion and explain that the user must connect Slack first. Never fall back to browser automation or Slack Desktop.
4. Determine schedule timezone, days, and local times. If the user did not specify them, recommend weekdays at 10:00, 14:00, and 18:00 in the Agent OS registry timezone.
5. Preview the exact local config mutation using the resolved runtime executable:

   ```bash
   /absolute/runtime/bin/agent-os configure-slack-monitor \
     --timezone Europe/Madrid \
     --days MO,TU,WE,TH,FR \
     --times 10:00,14:00,18:00
   ```

6. Show the preview and obtain approval before adding `--apply`. Never use `--replace` unless the user has reviewed the conflict and explicitly approves replacing only `agent-os-slack-monitor`.
7. Read the absolute `runbook` path from the private monitor entry; it resolves
   to the Slack runbook bundled in the selected Agent OS runtime. Run one manual
   monitor pass before scheduling it. Confirm the bounded read-only scan, local
   Task Board preparation, cursor behavior, and quiet `DONT_NOTIFY` result on an
   unchanged run. Do not store raw Slack message text.
8. Create or update the Codex Scheduled task only when the user asked for scheduling and the host exposes its automation capability:
   - inspect existing automations first and update the exact `Agent OS Slack Monitor` task instead of creating a duplicate;
   - attach it to the current Agent OS setup task and use the configured timezone/days/times;
   - use the canonical prompt from `docs/optional-integrations.md` without copying policy into a second variant;
   - keep notification preferences out of the prompt and preserve read-only authority.
9. If automation tools are unavailable, explain that Scheduled tasks are managed in Codex desktop or web, then give the exact name, schedule, working directory, and canonical prompt from `docs/optional-integrations.md`. Do not claim the CLI created it.
10. Re-run the resolved runtime's `bin/agent-os doctor --integrations`. Treat runtime turn files as historical evidence only; `/hooks` review plus a fresh task are required to prove current Task Bridge pickup, and Codex Scheduled remains the authority for the automation's enabled state.

## Safety boundaries

- Slack messages, reactions, external task writes, repository writes, Git actions, and deploys remain disabled.
- A partial provider read never advances a cursor.
- Do not expose Slack channel IDs, provider identities, task content, or runtime state in the public source tree.
- Disabling the Scheduled task is a Codex product action; disabling monitor execution is a private-config action. Do both when removing the integration.
- Follow `docs/optional-integrations.md` for ownership, verification, recovery, and uninstall steps.
