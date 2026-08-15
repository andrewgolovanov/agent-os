# Как расширять Agent OS

## Принцип

Расширение начинается с наблюдаемой боли, а не с красивой симметрии каталогов. Новый слой должен уменьшать повторную работу или риск и иметь понятного владельца данных.

## Как выбрать механизм

| Сигнал | Добавить |
| --- | --- |
| Нужна одна постоянная норма | правило в owning doc или `AGENTS.md` |
| Правило относится только к одному проекту | wrapper `AGENTS.md` или существующий direct repository `AGENTS.md` |
| Один workflow повторился минимум два раза | focused skill |
| Одни и те же точные команды переписываются или операция хрупкая | validated script/tool |
| Нужен компактный current handoff между чатами | task snapshot в `work/` |
| Нужно искать/связывать десятки задач | отдельный structured Task Board после пилота |
| Внешнее событие регулярно запускает одинаковую обработку | automation после определения authority, retries и idempotency |

## Новая документация

Перед созданием файла ответьте:

1. Какой вопрос он единолично закрывает?
2. Кто должен его читать и по какому trigger?
3. Какой существующий документ перестанет владеть этой информацией?
4. Как проверить, что документ не устарел?

Если на эти вопросы нет ответа, расширьте существующий owning doc.

## Новый skill

Repo-local skills хранятся в `.agents/skills/<skill-name>/`. Каждый skill:

- решает одну задачу;
- имеет `SKILL.md` с `name` и точным `description`;
- использует imperative steps и явные inputs/outputs;
- не содержит собственного README, changelog или дублированной общей документации;
- добавляет `scripts/`, `references/` или `assets/` только при реальной необходимости;
- проходит `quick_validate.py` из системного `skill-creator`.

Размещение соответствует [официальной документации Codex по skills](https://learn.chatgpt.com/docs/build-skills), где `.agents/skills` указан как repository scope.

Если workflow нужен вне этой установки Agent OS или должен поставляться вместе с connector/MCP, его можно упаковать в plugin. До этого repo-local skill проще и прозрачнее.

## Брендинг plugin

`apps/agent-os/Resources/AppIcon.svg` — канонический источник знака Agent OS.
Каждый plugin хранит собственную копию в `assets/agent-os-icon.svg`, потому что
установленный plugin archive не должен ссылаться на файлы за своими пределами.
Поля `interface.composerIcon`, `interface.logo` и `interface.logoDark` указывают
на эту bundled-копию. `node test/plugin_packages_test.mjs` проверяет, что обе
копии побайтово совпадают с канонической иконкой приложения.

## Новый tool

Tool должен иметь:

- узкую операцию и стабильный input contract;
- `--help` или ясный usage;
- validation до любой записи;
- preview/dry-run для потенциально опасных изменений;
- атомарную запись structured state, если это применимо;
- понятные exit codes;
- проверку на временной fixture или безопасном test target.

Не создавайте placeholder tools без рабочего сценария.

## Новая интеграция или automation

До включения зафиксируйте:

- внешний source of truth;
- минимальные permissions;
- read/write authority;
- idempotency key или de-duplication identity;
- retry и partial-failure semantics;
- что хранится локально и что запрещено хранить;
- human approval points;
- способ отключения и восстановления.

Первый pilot должен быть read-only или draft-only. Автоматические внешние изменения включаются отдельно.
