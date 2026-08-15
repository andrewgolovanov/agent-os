# Durable work

Private `AGENT_OS_HOME/work/` хранит structured Task Board для outcomes, которые должны пережить переключение проекта, новый Codex task или compaction контекста. Этот файл является только shareable описанием layout; реальные карточки не входят в product source.

## Layout

```text
work/
├── BOARD.md
├── board.json
├── reports/project-time/<project>.{json,md}
└── items/<task-id>/
    ├── task.json
    ├── STATUS.md
    └── events.jsonl
```

- `BOARD.md` — автоматически обновляемый dashboard для человека: общая сумма, статусы, следующие шаги, blockers и Codex-время;
- `board.json` — compact machine-readable index для tools и automations;
- `reports/project-time/` — generated all-thread Codex-time ledger и помесячная project-сводка;
- `items/<task-id>/STATUS.md` — полная читаемая карточка одного outcome.

Статус меняется только через `tools/task-board update TASK_ID --status STATUS`. Доступные статусы: `inbox`, `planned`, `active`, `waiting`, `review`, `done`, `cancelled`.

## Когда создавать запись

Создавайте task для multi-step implementation, research, review, release или explicit request «продолжить позже». Не создавайте запись для короткого объяснения или одноразовой read-only проверки без next action.

## Как обновлять

- Structured snapshot и `STATUS.md` обновляет только `tools/task-board`.
- Generated `BOARD.md` и `board.json` пересобираются после каждой structured mutation и каждого activity start/stop.
- Один task представляет один coherent outcome, даже если источников несколько.
- Exact source identity важнее semantic similarity.
- В registered project chat Task Bridge автоматически прикрепляет session только при одном exact task/source match; иначе он лишь показывает candidates.
- После material changes Task Bridge требует checkpoint, поэтому `summary`, `next_action` и status не зависят от ручного обновления корневой Agent OS task.
- Неатрибутированный Slack/DM signal может временно иметь пустой `projects` и статус `inbox`.
- `events.jsonl` хранит только material mutations, не turn-by-turn transcript.
- Не сохраняйте secrets, полные переписки или большие logs.

Полный contract и примеры команд находятся в [`docs/task-board.md`](../docs/task-board.md).

Общий project total не является суммой карточек и описан отдельно в [`docs/project-time.md`](../docs/project-time.md).
