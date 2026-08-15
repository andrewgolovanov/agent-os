# Архитектура

## Цель

Agent OS должен снижать стоимость переключения между проектами и сохранять рабочий контекст, не превращаясь во вторую ненадёжную копию внешних систем или проектных репозиториев.

## Слои

```text
Human entry point      README.md or installed app/plugin
Agent routing          packaged skills + registered project AGENTS.md
Structured facts       AGENT_OS_HOME/config/projects.yaml
Durable documentation docs/
Project context        registered project root (wrapper or direct repository)
Reusable workflows     installed plugin skills or .agents/skills/<skill>/
Deterministic helpers  selected packaged/development runtime
Durable task state     AGENT_OS_HOME/work/items/<task-id>/
Project time reports   AGENT_OS_HOME/work/reports/project-time/
Ephemeral cursors      AGENT_OS_HOME/.runtime/dispatcher/
Ephemeral task hooks   AGENT_OS_HOME/.runtime/task-bridge/
Optional operator UI   installed Agent OS.app
```

Каждый слой имеет одну функцию. Корневой `AGENTS.md` маршрутизирует, но не дублирует архитектуру. Skills описывают исполняемые процессы, но не становятся энциклопедиями. Private `work/` хранит current snapshot задачи, а не полную историю чата.

## Владение данными

| Данные | Canonical owner |
| --- | --- |
| Private home, timezone, project keys, aliases and repository paths | `AGENT_OS_HOME/config/projects.yaml` |
| Общая модель и границы | `docs/architecture.md` |
| Текущая проверенная готовность | `docs/state.md` |
| Архитектурное rationale | `docs/decisions/` |
| Project-specific правила и исключения | wrapper `AGENTS.md` или direct repository `AGENTS.md` |
| Durable project knowledge | wrapper `docs/PROJECT.md` или документация direct repository |
| Current goal, state, next action, sources, Codex memberships and linked-turn time | `AGENT_OS_HOME/work/items/<task-id>/task.json` |
| All-thread project Codex time and monthly rollups | generated `AGENT_OS_HOME/work/reports/project-time/<project>.json` |
| Human-readable task handoff | generated `AGENT_OS_HOME/work/items/<task-id>/STATUS.md` |
| Exact Slack events, watched roots and cursors | `AGENT_OS_HOME/.runtime/dispatcher/` |
| Exact Codex hook turn/candidate/checkpoint state | `AGENT_OS_HOME/.runtime/task-bridge/` |
| Slack connection and Codex recurring execution | connected Slack integration and Codex Scheduled |
| Selected executable runtime | `AGENT_OS_HOME/source-path`; packaged runtime by default, explicit valid development checkout when selected |
| Reusable Task Bridge event commands | installed Agent OS plugin hook bundle |
| Повторяемая процедура | `.agents/skills/<skill>/SKILL.md` |
| Код проекта, Git history and CI | соответствующий project repository |
| Issues, PR, provider state and conversations | соответствующая внешняя система |

## Project layouts

Каждый зарегистрированный project root имеет один из двух layout, явно
записанный в registry. Wrapper по умолчанию живёт в
`AGENT_OS_HOME/projects/<key>/`; direct repository остаётся в своём Git root.

Project onboarding принимает существующий абсолютный Git root из любой папки.
Agent OS хранит routing path и при необходимости создаёт приватный wrapper, но
не перемещает и не копирует repository. Каталог `projects/` — приватное место
для Agent OS wrappers, а не обязательный родительский каталог исходного кода.
Если пользователь позже сам переносит repository, relink проверяет его Git root
и origin identity, затем меняет только private registry и wrapper metadata.

### Wrapper

`layout: wrapper` — стабильный Agent OS-owned контекст, который может ссылаться на один или несколько существующих репозиториев. Wrapper не обязан быть Git-репозиторием и не содержит копии исходного кода.

Минимальный wrapper содержит:

- `project.yaml` — project-local представление ключа и repository roles;
- `AGENTS.md` — правила, которые неуместны в исходных репозиториях;
- `docs/PROJECT.md` — долговечный контекст, только если он реально известен;
- `repos/` — ссылки на способы доступа к репозиториям, но не обязательные копии;
- `tools/` — только проверенные project-specific helpers.

Private `config/projects.yaml` остаётся глобальным источником истины. Project file уточняет локальную работу и проверяется на согласованность с реестром.

### Direct repository

`layout: direct-repository` используется, когда один существующий
Git-репозиторий одновременно является зарегистрированным project root. Его
repository root обязан совпадать с полем `wrapper`, но сам абсолютный каталог
может находиться где угодно на компьютере. Новое onboarding создаёт direct
layout только если выбранный Git root уже совпадает с ожидаемым private project
root; identity-checked relink сохраняет direct layout после отдельного
пользовательского переноса repository в другую папку.

- Agent OS хранит structured metadata только в private `config/projects.yaml`.
- Существующие repository `AGENTS.md` и `README.md` остаются владельцами project-local правил и документации. Если repository `AGENTS.md` отсутствует, direct project наследует корневой Agent OS `AGENTS.md`; onboarding не создаёт служебный файл внутри продукта.
- Agent OS не добавляет `project.yaml` или другие служебные файлы внутрь репозитория.
- Если direct repository находится под development checkout Agent OS, его
  точный каталог исключается из Git index Agent OS, чтобы не создать случайный
  gitlink и не смешать истории. Внешнему Git root это исключение не требуется.

Direct layout подходит для одного репозитория. Если проекту понадобится несколько репозиториев или отдельный личный operational context, его следует отдельно мигрировать в wrapper layout.

## Безопасность и полномочия

- Discovery и чтение разрешены внутри заданной установки Agent OS и зарегистрированных paths.
- Подключение проекта не перемещает, не клонирует и не меняет его репозитории.
- External/provider tools работают read-only по умолчанию.
- Commit, push, PR, deploy, сообщения и изменение внешних задач требуют явного пользовательского запроса.
- Secrets, полные переписки и build logs не сохраняются в Agent OS.
- Potentially destructive tools обязаны иметь точный target, validation и preview/dry-run.

## Continuity layer

Task Board хранит structured outcome, stable source identities, Codex memberships и retryable `routing_pending`. File lock, atomic replacement и generated index дают локальную надёжность без SQLite. Runtime Slack state отделён от долгоживущей корреляции задач: seen event не replay-ится только потому, что Codex routing временно не удался.

User-level Task Bridge обслуживает chats внутри registered project paths и уже linked Codex tasks. Он автоматически создаёт membership только при единственном exact task/source match, суммирует `UserPromptSubmit` → `Stop` turns и требует durable checkpoint после material changes. Project path выбирает область поиска, но никогда не выбирает outcome сам; title и semantic similarity дают только candidates.

Project Time параллельно учитывает каждый Codex turn внутри registered project независимо от Task Board claim. Его project-level ledger не меняет outcome lifecycle и не складывается с Task Board time: linked outcome turns уже являются частью общего project total. Historical paths и exact exclusions принадлежат project registry, а generated report агрегирует завершённые интервалы по месяцам Agent OS timezone.

Slack Monitor является одним Agent OS-wide read-only heartbeat. Он собирает direct mentions, incoming DMs/group DMs и active watched roots; project channels используются для attribution, а не для полного ambient scan. Его короткий prompt ссылается на canonical `config/monitors.yaml` и `docs/slack-monitor.md`; policy не копируется в automation. Cursor продвигается только после complete scan, а watched roots компенсируют неполноту Slack search.

Optional integration setup не смешивает владельцев: Agent OS CLI управляет
только private monitor config, plugin bundle поставляет hook commands, connected
Slack integration владеет provider access, а Codex Scheduled владеет recurring
execution. Setup skill оркестрирует эти шаги, но не сохраняет credentials и не
эмулирует отсутствующий product API.

Packaged bootstrap также не смешивает владельцев. Версионированные plugin/app
bundles владеют только read-only runtime payload, `AGENT_OS_HOME` владеет
mutable state и выбранным runtime pointer, а project repositories остаются
самостоятельными Git roots. Первый запущенный компонент выполняет idempotent
bootstrap; второй использует тот же private home.

Agent OS for macOS реализуется как replaceable presentation/action layer над этими владельцами данных. Native app не получает собственную task database и выполняет mutations только через deterministic Agent OS tools. Agent-facing integration оформлена как installed skills + root-confined MCP. Native app создаёт и именует idle Codex task через stable App Server `stdio`, записывает exact membership, копирует подготовленный prompt и открывает публичный `codex://threads/<id>` handoff; старт turn остаётся в desktop-клиенте, чтобы два App Server client не конкурировали за один task. App/plugin source живёт в monorepo, а mutable routing и durable context — только в private home.

Update plane также не получает отдельной базы. Core и plugin принимают только
version-tag fast-forward через preview-first CLI; app получает подписанный
Ed25519 архив из appcast одного GitHub Release. Автоматическая установка обоих
контуров — отдельный user opt-in, а private home не является целью update.

## Что намеренно отложено

- public GitHub Release и реальный cross-version/second-Mac update pilot;
- Slack/GitHub/provider writes;
- Daily Chores и Trackline integration;
- project/repository auto-discovery с мутациями.

Новый слой появляется только после повторяющейся реальной работы. Сначала проверяется continuity, затем telemetry.
