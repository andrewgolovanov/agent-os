# Slack Monitor runbook

Этот runbook принадлежит одному Agent OS-wide heartbeat monitor. Он читает Slack через connected Slack integration, связывает новые сигналы с Task Board и готовит локальный handoff. Новый проект не получает отдельную automation: registry нужен только для attribution и routing.

## Configuration

Новая установка сначала preview-ит sanitized template и только после review
добавляет его в private home:

```bash
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00
./bin/agent-os configure-slack-monitor \
  --timezone Europe/Madrid \
  --days MO,TU,WE,TH,FR \
  --times 10:00,14:00,18:00 \
  --apply
```

Команда меняет только private `config/monitors.yaml`: она не подключает Slack
и не создаёт Codex Scheduled task. Полная последовательность, canonical prompt
и recovery описаны в [optional integrations](optional-integrations.md).

1. Найти `agent-os-slack-monitor` в private `config/monitors.yaml`.
2. Каждый run заново разрешить current Slack user profile и использовать точный user ID для mention search.
3. Разрешить project attribution через `config/projects.yaml`; channel IDs не угадывать и не дублировать в prompt.
4. Использовать `tools/task-board` для task state и `tools/slack-state` для runtime cursor, seen ledger и watched roots.

Если config, registry или Slack integration недоступны, записать monitor failure. После partial read не продвигать ни один cursor.

## Authority

Разрешены:

- read-only Slack observation;
- correlation с local Task Board;
- создание или обновление local task snapshot;
- подготовка `routing_pending` handoff;
- компактная рекомендация пользователю.

Без отдельного запроса запрещены Slack messages/reactions, external tracker writes, code edits, commits, pushes, PR actions, deployments и управление user-owned Codex task.

## Run sequence

1. Прочитать current Slack user profile; это availability check и источник exact user ID/timezone.
2. Проверить bounded набор open tasks и `routing_pending`.
3. Прочитать active exact-root watches до общего поиска; Slack search не гарантирует все replies.
4. Взять последний successful cursor из `.runtime/dispatcher/slack-monitor.json` и применить overlap из monitor config. Если cursor ещё `null`, читать только один configured interval плюс overlap; старую историю не backfill-ить.
5. Искать exact `<@USER_ID>` mentions во всех доступных public/private channels за bounded window.
6. Отдельно искать входящие DMs и group DMs. Dedupe conversations, раскрывать только кандидаты с новым unresolved ask; acknowledgement/FYI без действия не считать задачей.
7. Для найденных roots/replies читать thread/channel context только в объёме, необходимом для resolution. Зарегистрированные project channels используются для attribution, но ambient traffic без mention не сканируется.
8. Для каждого нового сообщения использовать identity `channel_id + thread_ts + message_ts` и проверить exact-event ledger до обработки.
9. Correlate сначала по exact Task Board source, затем по channel mapping, repository/PR links и verified continuity. Если проект неизвестен, создать unassigned inbox task; не merge по похожему тексту.
10. Сохранить только disposition и identifiers через `tools/slack-state seen`. Raw message text, author names и summaries в runtime state не сохранять.
11. После полного успешного scan сначала записать все seen events, затем продвинуть watched-root cursors и global cursor с обязательным `--complete`.
12. Перед финальным решением получить `tools/task-board summary --json`. Каждое пользовательское `NOTIFY` завершать ссылкой на dashboard из `notifications.task_board_dashboard` и строкой `Невыполнено: N` с общей Agent OS-суммой. Путь и label принадлежат private monitor config; при полезности перед ними можно добавить компактную разбивку по status.

## Source-specific rules

### Mentions

- Search public/private channels for exact current-user mention.
- A mention inside a thread требует чтения thread до конца, чтобы не создать уже resolved task.
- `@channel`, `@here` и user-group mentions не являются direct mention пользователя.

### Direct and group DMs

- Scan `im` и `mpim` отдельно, потому что DM обычно не содержит explicit mention.
- Оставлять только conversation, где последний unresolved ask пришёл от другого человека или после последнего substantive ответа пользователя появились новые сообщения.
- Emoji-only, acknowledgements и собственные сообщения пользователя не создают task.

### Attribution

- Exact source identity имеет приоритет.
- Затем использовать registered Slack channel mapping и explicit repository/PR/project links.
- Если project ещё не зарегистрирован или неоднозначен, task остаётся unassigned и получает один конкретный clarification next action.

Пример:

```bash
tools/slack-state seen \
  --channel CHANNEL_ID \
  --thread-ts ROOT_TIMESTAMP \
  --message-ts MESSAGE_TIMESTAMP \
  --permalink "https://slack.example/thread/ROOT_ID" \
  --disposition actionable \
  --project example-site \
  --task-id TASK_ID

tools/slack-state monitor-success --cursor CURSOR_TIMESTAMP --complete
```

## Watches

Каждый active root watch хранит exact channel/thread identity, last seen reply, reason, optional task ID и expiry. Watch cursor меняется только после полного чтения root и записи всех новых events.

Закрытые/done tasks должны постепенно удаляться из активного bounded scan; полный бесконечный реестр threads не нужен.

```bash
tools/slack-state close-watch --channel CHANNEL_ID --thread-ts ROOT_TIMESTAMP
```

## Circuit breaker и notifications

- Первая outage может вернуть `NOTIFY`.
- Повторная одинаковая outage возвращает `DONT_NOTIFY` и не меняет cursor.
- Recovery уведомляется один раз.
- Empty run, duplicate или unchanged state возвращает `DONT_NOTIFY`.
- Новая actionable task, blocker, ambiguity или material lifecycle change возвращает `NOTIFY`.
- Каждое `NOTIFY` содержит кликабельную ссылку на generated Task Board dashboard и актуальную общую сумму незавершённых outcomes. Quiet `DONT_NOTIFY` не создаёт отдельное пользовательское уведомление только ради неизменившейся суммы.

Monitor не использует Chrome, Slack Desktop или Computer Use как fallback и не читает полный ambient traffic всех project channels.
