# Task Board

Task Board связывает один реальный outcome с любым числом external threads, Codex tasks, PR, design и deployment sources. Его файлы живут только под private `AGENT_OS_HOME`; product checkout содержит implementation и это описание, но не пользовательские карточки.

## Хранилище

```text
work/
├── BOARD.md
├── board.json
└── items/<task-id>/
    ├── task.json
    ├── STATUS.md
    └── events.jsonl
```

- `BOARD.md` — generated human-readable dashboard по всем задачам;
- `task.json` — canonical structured snapshot;
- `STATUS.md` — автоматически обновляемый human-readable handoff;
- `events.jsonl` — append-only история material mutations;
- `board.json` — атомарно пересобираемый компактный индекс.

`BOARD.md` показывает общую сумму незавершённых outcomes, status sections, current summary, next action, blocker, linked Codex state и накопленное время. Он обновляется при каждом write через Task Board, включая activity hooks. Во время выполняющегося turn dashboard показывает active-turn count, а окончательная длительность добавляется после `Stop`.

Все structured writes выполняются через `tools/task-board`. Tool использует file lock и atomic replacement, поэтому два процесса не должны портить индекс.

## Когда создавать task

Создавайте task перед первой meaningful mutation, multi-step investigation, review, release, deployment или explicit request продолжить работу позже. Не создавайте task для короткого объяснения, FYI или одноразового lookup без next action.

Одна task представляет один coherent outcome. Несколько Slack roots или Codex tasks не являются причиной дробить outcome.

## Команды

```bash
tools/task-board list
tools/task-board summary
tools/task-board show TASK_ID
tools/task-board find --source URL_OR_ID

tools/task-board create \
  --title "Outcome-oriented title" \
  --project example-site \
  --kind delivery \
  --goal "Stable desired result" \
  --next-action "One concrete next step"

tools/task-board source TASK_ID \
  --kind slack_threads \
  --value "https://slack.example/thread/ROOT_ID"

tools/task-board codex TASK_ID \
  --thread-id THREAD_ID \
  --role implementation \
  --origin new

tools/task-board activity-start TASK_ID \
  --session-id THREAD_ID \
  --turn-id TURN_ID

tools/task-board activity-stop TASK_ID \
  --session-id THREAD_ID \
  --turn-id TURN_ID

tools/task-board routing-update TASK_ID \
  --route-id ROUTE_ID \
  --state routed \
  --attempt \
  --codex-thread-id THREAD_ID

tools/task-board validate
```

Для изолированных tests используется `--root PATH` или `AGENT_OS_TASK_ROOT`.

`tools/task-board summary` всегда считает все незавершённые outcomes: `inbox`, `planned`, `active`, `waiting` и `review`. `done` и `cancelled` в эту сумму не входят. Та же summary записывается в generated `work/board.json`; `--project KEY` ограничивает расчёт одним проектом.

`--project` можно не указывать для нового Slack/DM signal с неизвестным owner. Такая task остаётся unassigned в `inbox` до verified attribution; routing для неё не создаётся.

## Управление обычными фразами

Пользователю не нужно запускать CLI вручную. В корневой Agent OS task достаточно назвать карточку или её ID и явно сказать, что изменилось:

- `Останавливаюсь с legal до завтра` — lifecycle остаётся `active`; завершение или Stop текущего Codex-turn автоматически переводит только Codex membership в `idle` и останавливает его таймер.
- `Поставь legal в ожидание ответа Даши: нужен финальный текст cookies` — outcome переходит в `waiting`, причина сохраняется в `waiting_on`.
- `Продолжи legal, ответ получен` — outcome возвращается в `active`, `waiting_on` очищается.
- `Обнови legal: сделаны Privacy и Terms; следующий шаг — проверить mobile` — обновляются `summary` и `next_action` без ложного завершения карточки.
- `Legal готова к моей проверке` — outcome переходит в `review`.
- `Legal принята, проверки прошли — закрой` — outcome переходит в `done`.
- `Отмени задачу slider, она больше не нужна` — outcome переходит в `cancelled`.

`waiting` используется только для реальной внешней зависимости. Перерыв, конец рабочего дня или отсутствие запущенного Codex-turn не являются blocker и не меняют `active` outcome. `done` означает проверенный или явно принятый конечный результат, а не окончание одного ответа агента.

## Identity и корреляция

Сначала используется стабильная внешняя identity:

- Slack permalink → `slack:<channel_id>:<root_ts>`;
- GitHub PR → `github:<owner>/<repo>#<number>`;
- Figma file → `figma:<file_key>`;
- Codex membership → точный `thread_id` и `codex://threads/<id>`.

Только после exact identity допустима проверенная continuity. Semantic similarity сама по себе не разрешает автоматически объединять задачи. Один canonical GitHub PR не может принадлежать двум tasks.

## Codex membership и routing

Независимые Codex tasks являются peer memberships. У outcome нет обязательного «главного чата». Subagent threads не регистрируются.

Если подходящий saved project или Codex thread ещё неизвестен, Task Board хранит `routing_pending`. Это отдельное состояние от Slack-event processing: Slack event не replay-ится, а routing можно безопасно повторить позже.

В registered project chat [`Task Bridge`](task-bridge.md) может создать membership автоматически, но только при единственном exact task/source match. Project path ограничивает candidate set; он не выбирает карточку сам. Если есть только semantic similarity, агент обязан явно выполнить `claim` или создать новый coherent outcome.

## Activity evidence

Time evidence считается только после exact Codex `thread_id` membership. User-level hooks вызывают `tools/codex-activity-hook`: `UserPromptSubmit` выполняет безопасную correlation/claim и открывает exact `turn_id`, material `PostToolUse` требует checkpoint, а `Stop` закрывает turn и меняет membership `active` → `idle`. Повторная доставка идемпотентна и не удваивает время.

Это измерение времени выполнения Codex-turn, а не человеческий тайм-трекер и не копия UI-надписи `Working for…`. Паузы между turn не считаются. Exact `Stop` имеет приоритет; orphaned turn после crash ограничивается configured idle timeout. Chats вне registered project paths hook игнорирует, чтобы случайно не приписать работу неверному outcome.

После изменения hooks их нужно проверить и доверить в `/hooks`; уже открытый task не получает новый hook задним числом, поэтому надёжный автоматический подсчёт начинается в новом task. Подробный flow, policy и команды находятся в [`docs/task-bridge.md`](task-bridge.md).

Task Board activity является outcome-level временем и поэтому намеренно не включает непривязанные project chats. Общая сумма по всем тредам проекта формируется отдельно через [`Project Time`](project-time.md). Эти показатели нельзя складывать: linked turns присутствуют в обоих представлениях.
