# 0012 — Provider-owned optional integration setup

Date: 2026-08-15

Status: accepted

## Context

Agent OS can provide a useful read-only Slack monitor and automatic Task Bridge continuity, but a shareable installation cannot assume one developer's Slack account, schedule, hook approval state, paths, or runtime state. Codex Scheduled, connected integrations, local private configuration, and plugin hooks are separate trust domains.

## Decision

- Keep initialization provider-free and automation-free.
- Add a preview-first CLI command that merges one sanitized Slack monitor entry into the private Agent OS home. It does not connect Slack or create a schedule.
- Ship Task Bridge event commands inside the Agent OS plugin's standard hook bundle rather than editing a global user hook file. The user still reviews trust with `/hooks` and starts a fresh task.
- Add a plugin setup skill that verifies the connected Slack integration, previews local configuration, performs a manual read-only pass, and then creates or updates one Codex Scheduled task only after explicit user approval.
- Treat Codex Scheduled as the authority for recurring execution. When its automation capability is unavailable, provide the same canonical prompt and UI instructions instead of inventing a CLI schedule API.
- Extend `doctor` with opt-in integration checks while keeping local evidence distinct from provider authentication, hook trust, and Scheduled task state.

## Consequences

- A new user gets an executable and documented setup path without receiving private provider data.
- Re-running setup is idempotent: the local monitor is preserved when identical, conflicts stop unless explicitly replaced, and an exact Scheduled task is updated rather than duplicated.
- Plugin installation supplies Task Bridge code consistently across machines, but current-task activation still requires an explicit trust review and a fresh task.
- Slack and Codex remain the authoritative places to revoke provider access and recurring execution; Agent OS only owns its private policy and runtime records.
- Setup cannot be reported complete from local files alone. Verification must include a minimal Slack read, `/hooks` review in a fresh task, and the first Scheduled executions.
