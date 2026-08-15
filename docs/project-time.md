# Project time

Project Time отвечает на отдельный от Task Board вопрос: сколько активного Codex-времени было затрачено на проект во всех его тредах, независимо от того, была ли каждая сессия привязана к конкретной карточке.

## Источник и scope

Canonical project paths находятся в `config/projects.yaml`. Для перенесённых репозиториев проект может дополнительно определить:

```yaml
activity:
  historical_paths:
    - /previous/exact/project/path
  include_thread_ids: []
  exclude_threads:
    - id: exact-codex-thread-id
      reason: Why this thread is not client project work.
```

- Current `wrapper` и repository paths включаются автоматически.
- `historical_paths` нужны только для точных старых checkout paths после физического переноса.
- `include_thread_ids` — узкое ручное включение доказанной project-сессии, запущенной из другого cwd.
- `exclude_threads` удаляет ложную атрибуцию, например системное обслуживание, случайно начатое из project cwd.

## Что измеряется

Единица учёта — exact Codex turn:

```text
task_started / hook start
  -> активное выполнение Codex
task_complete | turn_aborted | hook stop
```

Учитываются только завершённые интервалы. Паузы между сообщениями, Slack, встречи, ручная browser QA и любая работа вне Codex не входят. Поэтому отчёт является воспроизводимым минимумом Codex-времени, а не автоматическим доказательством всех billable human hours.

Turn, пересекающий границу месяца, делится между месяцами в `agent_os.timezone`. Exact `thread_id + turn_id` предотвращает двойной подсчёт при повторяющихся session events, compaction или повторном refresh.

Месячный `thread_count` означает число тредов с активным временем в этом месяце. Один долгий тред может присутствовать в двух месяцах, тогда как общий `thread_count` дедуплицирован по thread ID.

## Файлы и команды

```text
work/reports/project-time/<project>.json  canonical generated ledger
work/reports/project-time/<project>.md    human-readable monthly report
```

```bash
tools/project-time refresh --project example-site
tools/project-time show --project example-site
tools/project-time show --project example-site --json
tools/project-time validate --project example-site
```

`refresh` заново читает локальные Codex session histories, применяет configured scope/exclusions и атомарно пересобирает оба файла. User-level hook обновляет тот же ledger на каждом новом turn и Stop даже тогда, когда chat ещё не имеет exact Task Board outcome.

## Связь с Task Board

- Task Board time отвечает: сколько Codex-времени связано с конкретным outcome.
- Project Time отвечает: сколько Codex-времени прошло во всех project chats.
- Эти суммы нельзя складывать: task turns уже входят в project total.
- Project report не создаёт task, не меняет lifecycle карточек и не пишет в product repository.

Для внешнего отчёта используйте помесячную таблицу из generated Markdown и отдельно добавляйте подтверждённое ручное время, если оно учитывается договором.
