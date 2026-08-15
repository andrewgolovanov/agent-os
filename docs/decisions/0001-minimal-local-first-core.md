# 0001: Minimal local-first core

- Status: accepted
- Date: 2026-08-09

## Context

Agent OS создаётся с нуля. Reference harness включает Task Board CLI, Slack dispatcher, activity hooks и automations, но ни один реальный project workflow в новой установке ещё не подтверждён.

## Decision

Начать с шести независимых слоёв: small root router, canonical project registry, project wrappers, durable documentation, Markdown task snapshots и repo-local skills. Не реализовывать integrations, database-backed task state или automations до реального pilot.

## Consequences

- Структура уже поддерживает несколько проектов и специализированные skills.
- Первый проект можно подключить без изменения архитектурных границ.
- Task management пока намеренно ручной и прозрачно хранится в Markdown.
- Новые подсистемы требуют evidence повторяемого сценария и отдельного решения.
