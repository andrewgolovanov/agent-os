# 0005 — Linked Codex activity and unfinished totals

Date: 2026-08-10

Status: accepted

Supersedes: activity deferral in `0003-structured-continuity-before-hooks.md`

## Context

Первый реальный continuity cycle дошёл до active implementation task. Появился конкретный consumer: пользователю нужна общая сумма незавершённых outcomes в monitor notifications и измеримое время Codex work по каждой карточке.

## Decision

- Task Board generated index всегда содержит `unfinished_total`; `done` и `cancelled` исключаются.
- Каждый Slack Monitor `NOTIFY` показывает общую Agent OS-сумму незавершённых outcomes.
- Activity учитывается только после exact Codex `thread_id` membership.
- `UserPromptSubmit` открывает turn, `Stop` завершает тот же exact `turn_id`; повторная доставка события не удваивает время.
- Hook синхронизирует только Codex membership `active`/`idle`; lifecycle outcome остаётся explicit.
- Незарегистрированные Codex sessions игнорируются. Hook не делает semantic routing и не меняет lifecycle outcome автоматически.

## Rationale

Codex hook payload даёт стабильные `session_id` и `turn_id`, но не готовую длительность outcome. Собственный bounded timer делает evidence воспроизводимым, а exact membership не позволяет случайно приписать время похожей карточке.

## Consequences

- Это agent execution time по completed turns, не человеческий timesheet и не UI `Working for…`.
- Новый hook требует review/trust и fresh task; прошлое время не реконструируется догадкой.
- Status `review`, `waiting`, `done` остаётся explicit domain decision.
