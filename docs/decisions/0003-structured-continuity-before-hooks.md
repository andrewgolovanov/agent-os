# 0003 — Structured continuity before activity hooks

Date: 2026-08-09

Status: accepted

## Context

Первый read-only intake pilot доказал, что plain Markdown folders недостаточны для надёжной корреляции replies, Codex tasks и будущих PR. Изученный reference harness решает это через Task Board, exact-event ledger, watched roots, routing queue и activity hooks.

## Decision

Сначала внедрить structured Task Board и отдельный Slack runtime state:

- один coherent outcome имеет stable task ID;
- exact external identities связываются с task;
- Codex threads являются peer memberships;
- Slack event de-duplication отделено от durable task correlation;
- failed Codex routing становится `routing_pending`, а не replay Slack event;
- automation prompt остаётся коротким и ссылается на local runbook.

Activity hooks, time evidence, Daily Chores и автоматическое управление Codex tasks пока не устанавливать.

## Rationale

Hooks измеряют активность, но не исправляют потерю task identity. Их ранняя установка добавила бы глобальный шум и privacy surface до появления проверенного consumer. Structured continuity уже нужна monitor workflow и может быть протестирована локально без внешних write permissions.

## Consequences

- `work/` меняется с status folders на locked structured Task Board.
- Monitor хранит only identifiers/dispositions в ignored `.runtime/dispatcher/`.
- Следующий pilot должен проверить полный Slack → task → Codex handoff → PR/review цикл.
- К Activity возвращаемся только после нескольких циклов, когда понятны нужные поля и отчёт.
