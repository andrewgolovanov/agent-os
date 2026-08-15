# Task Bridge

Task Bridge автоматически связывает работу в registered Codex project с одной canonical Task Board карточкой. Он решает две отдельные проблемы: активность карточки начинается вместе с первым точным рабочим turn, а verified summary/next action сохраняются до завершения ответа агента.

## Data flow

```text
project Codex chat
  -> UserPromptSubmit
  -> project-time start for every registered project chat
  -> registered cwd + exact task/source identity
  -> one Task Board membership
  -> activity-start
  -> material-change marker
  -> checkpoint
  -> Stop / activity-stop
  -> project-time stop and monthly rollup
```

Canonical outcome остаётся только в `work/items/<task-id>/task.json`. В project repository не создаются копии задач, конфиги или runtime-файлы.

Project-level time хранится отдельно в `work/reports/project-time/`: он включает и exact-linked, и пока непривязанные chats. Task Bridge state и lifecycle от этого отчёта не зависят.

## Автоматическая корреляция

Task Bridge разрешает project по самому длинному точному path из `config/projects.yaml`. Автоматический claim допустим только при одном exact match:

- Task Board ID прямо указан в prompt;
- Slack permalink совпадает по canonical channel/root timestamp;
- GitHub PR совпадает по owner/repository/number;
- Figma URL совпадает точно или содержит тот же file key и `node-id`.

Title и похожий текст используются только для списка кандидатов. Semantic similarity никогда не прикрепляет Codex chat автоматически. При нуле или нескольких exact matches hook возвращает инструкции и кандидатов, но оставляет outcome неизменным.

## Lifecycle и время

- Первый exact claim прикрепляет `session_id`, переводит outcome из `inbox`, `planned` или `review` в `active` и открывает exact `turn_id`.
- Каждый следующий `UserPromptSubmit` в linked chat открывает новый turn; повторное событие идемпотентно.
- `Stop` закрывает тот же turn и переводит только Codex membership в `idle`. Outcome остаётся `active`, `waiting` или `review` согласно checkpoint.
- Exact `Stop` timestamp всегда имеет приоритет. Новый turn в том же session закрывает предыдущий незавершённый turn, а `idle_timeout_minutes` ограничивает его длительность; текущий default — 30 минут. Глобальный reconcile запускается только явно и не вмешивается в параллельный активный chat.
- Считается время выполнения Codex turns, а не человеческое время между сообщениями.
- `done` и `cancelled` никогда не выставляются автоматически. Их подтверждает пользователь через обычный Task Board flow.

После material file mutation (`apply_patch`, `Edit`, `Write`) `Stop` требует checkpoint с verified `summary`, одним concrete `next_action` и status `active`, `waiting` или `review`. Это не даёт реализации исчезнуть из доски только потому, что завершился один ответ.

## Runtime state и privacy

Exact hook state хранится в ignored `.runtime/task-bridge/`:

```text
.runtime/task-bridge/sessions/<session-id>/turns/<turn-id>.json
```

Runtime содержит IDs, timestamps, candidate IDs, claim reason, material/checkpoint flags и SHA-256 prompt. Raw prompt, source content и tool payload не сохраняются. Durable summary и task state меняются только через Task Board API.

## Policy

`config/task-bridge.yaml` задаёт defaults и редкие project overrides:

- `enabled` — участвует ли registered project в bridge;
- `auto_claim` — `exact_sources` или `disabled`;
- `require_checkpoint` — блокировать ли Stop после material mutation без checkpoint;
- `max_candidates` — размер безопасного candidate list;
- `idle_timeout_minutes` — fallback cap для orphaned turns.

## Ручные команды

Обычно команды вызывает сам агент из hook context:

```bash
tools/task-bridge claim TASK_ID \
  --session-id SESSION_ID \
  --turn-id TURN_ID

tools/task-bridge checkpoint TASK_ID \
  --session-id SESSION_ID \
  --turn-id TURN_ID \
  --summary "Verified current state" \
  --next-action "One concrete next step" \
  --status review

tools/task-bridge context --session-id SESSION_ID --turn-id TURN_ID
tools/task-bridge reconcile --session-id SESSION_ID
```

Если exact outcome ещё не существует, агент сначала создаёт его через `tools/task-board`, затем выполняет `claim`. Старые turns импортируются только по exact Codex timestamps; guessed time запрещён.

Legacy chat, в котором последовательно выполнялись разные outcomes, нельзя автоматически переиспользовать как durable membership. К нему прикрепляется только доказанная historical activity, membership получает `archived`, а следующая работа начинается в fresh project chat. Иначе один старый thread ID навсегда смешивал бы время нескольких карточек.

## Codex setup

User-level Codex hook configuration подключает один command hook для `UserPromptSubmit`, material `PostToolUse` и `Stop`. После изменения конфигурации её нужно открыть и доверить через `/hooks`, затем начать новый project chat: уже запущенный task не получает новую hook configuration задним числом.

`AGENTS.override.md` для Task Bridge не используется: такой файл заменил бы, а не дополнил project `AGENTS.md`. Project-specific task context передаётся динамически через `additionalContext` hook response.
