# Рабочие процессы

## Подключить проект

1. Вызвать `$onboard-project`.
2. Передать project key, display name и абсолютные пути существующих репозиториев.
3. Проверить для каждого репозитория root, remotes, branch, HEAD и dirty state.
4. Определить layout: `wrapper` по умолчанию или `direct-repository`, если один Git root уже совпадает с `projects/<key>/`.
5. Просмотреть план создаваемых файлов и registry entry.
6. Для wrapper создать `projects/<key>/` из `templates/project/`. Для direct repository не добавлять файлы Agent OS внутрь проекта и исключить точный каталог из Git index Agent OS.
7. Обновить `config/projects.yaml`.
8. Запустить `ruby tools/validate-agent-os`.
9. Отдельно отметить verified и unknown facts.

Подключение не даёт разрешения на clone, move, remote changes, commit или publish.

## Начать проектную работу

1. Разрешить имя/alias через `config/projects.yaml`.
2. Определить layout и прочитать `AGENTS.md` зарегистрированного project root.
3. Для wrapper перейти в точный repository path и прочитать ближайший repository `AGENTS.md`, если он есть.
4. Проверить Git identity и dirty state.
5. Для durable outcome передать в первый project-chat prompt exact Task Board ID или stable source URL. Task Bridge автоматически прикрепит stable `session_id` только при одном exact match.
6. Если exact match отсутствует, выбрать предложенную карточку через `tools/task-bridge claim` или сначала создать outcome через `tools/task-board`; не угадывать его по title или branch.
7. Выполнить и проверить работу в проектном репозитории. Task Bridge считает exact Codex turns, а не человеческие паузы.
8. После material changes выполнить checkpoint с verified summary, next action и status; `done` остаётся explicit user action.

## Жизненный цикл durable task

```text
inbox -> planned -> active -> review -> done
                       \-> waiting -> active
```

- `inbox`: outcome обнаружен, но ещё не triaged.
- `planned`: scope и следующий шаг подтверждены.
- `active`: есть один текущий next action.
- `waiting`: указан внешний blocker и условие возобновления.
- `review`: реализация или analysis ждёт проверки/merge.
- `done`: результат и validation зафиксированы; дальнейших обязательных действий нет.
- `cancelled`: outcome сознательно остановлен с зафиксированной причиной.

Статус меняется только через `tools/task-board`. `task.json` остаётся structured source, `STATUS.md` — автоматически обновляемый handoff, `events.jsonl` — append-only material history.

## Slack intake

1. Один Agent OS heartbeat разрешает current Slack user profile через connected integration.
2. Active watched roots читаются до global mentions/DM search.
3. Direct mentions ищутся во всех доступных public/private channels; DMs и group DMs читаются отдельно.
4. Exact event identity проверяется через `tools/slack-state`.
5. Correlation идёт по stable Task Board sources и registry attribution, а не по похожему тексту.
6. Unknown-project signal может стать unassigned inbox task.
7. Cursor продвигается только после полного успешного scan.
8. Внешние сообщения, ambient full-channel scans, code/Git/deploy actions и управление user-owned Codex tasks запрещены.

Canonical sequence и circuit breaker описаны в `docs/slack-monitor.md`.

## Изменить Agent OS

1. Определить владельца изменяемого знания по `docs/architecture.md`.
2. Сделать минимальное изменение без дублирования facts.
3. Обновить `docs/state.md` и `docs/changelog.md`.
4. Добавить decision record, если rationale не очевиден.
5. Запустить Agent OS validation.

## Создать skill

1. Собрать минимум два реальных примера одинаковой процедуры.
2. Сформулировать один job и точные trigger phrases.
3. По умолчанию создать instruction-only skill в `.agents/skills/<name>/`.
4. Добавить script только для детерминированной или хрупкой операции.
5. Проверить skill validator и один реалистичный dry run.

Подробные критерии находятся в `docs/extending.md`.
