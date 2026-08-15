# Codex task model

Корневая Agent OS task координирует архитектуру, monitoring и cross-project работу. Обычная реализация должна выполняться в saved Codex project конкретного проекта, когда такой project настроен.

## Durable membership

- Durable Codex task регистрируется только по точному `thread_id`.
- Title, время создания, branch или semantic similarity не заменяют thread ID.
- Independent tasks и forks являются peer relationships; у outcome нет обязательного primary task.
- Spawned subagent threads не регистрируются.
- Disposable questions не создают Task Board membership.

## Как начинать project work

1. Найти или создать один Task Board outcome.
2. Открыть отдельный Codex task в registered project path и включить в первый meaningful prompt exact Task Board ID или stable Slack/GitHub/Figma source.
3. Task Bridge прикрепит exact `session_id` только при одном exact match. При отсутствии exact match агент покажет candidates и потребует explicit `claim` до substantive mutations.
4. После material changes агент checkpoint-ит verified summary, next action и `active`/`review`/`waiting`; `done` и `cancelled` остаются только explicit user decisions.

Hook считает время linked Codex-turn, автоматически переключает membership `active`/`idle` и переводит начатую карточку в `active`. `Stop` означает завершение ответа агента, а не завершение всей карточки; lifecycle после реализации фиксирует checkpoint.

Открытие saved Codex project само по себе не выбирает карточку: в одном проекте одновременно может быть несколько outcomes. Надёжный пользовательский flow:

1. В project chat написать задачу и приложить её exact ID/source URL; Task Bridge сам выполнит claim/start.
2. Если в prompt нет exact identity, выполнить предложенную agent-команду `claim TASK_ID`; похожее название само ничего не связывает.
3. Во время работы агент автоматически сохраняет checkpoint после material changes; пользователь сообщает только domain decisions: `поставь в ожидание`, `продолжи`, `готово к проверке`, `закрой` или `отмени`.
4. Если работа была начата до установки Bridge, один раз импортировать exact session/turn timestamps и затем продолжать в fresh hooked chat.

Таким образом, существуют два независимых состояния: Codex membership показывает, выполняется ли turn прямо сейчас (`active`/`idle`), а Task Board status показывает состояние всего результата (`inbox`/`planned`/`active`/`waiting`/`review`/`done`/`cancelled`).

## Ownership gate

Прямое сообщение пользователя в routed Codex task передаёт task под user ownership. Monitor после этого может обновить Task Board, но не должен писать, будить, останавливать или перенаправлять этот task без нового пользовательского запроса.

## Handoff

Self-contained handoff содержит:

- Task Board ID и goal;
- exact project/repository paths;
- current summary и next action;
- exact external identities/URLs;
- permissions и явные запреты;
- validation уже выполненную и ещё необходимую.

Если saved project или stable thread ID неизвестен, создать `routing_pending`, а не вымышленную membership.
