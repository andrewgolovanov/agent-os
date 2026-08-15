# Документация Agent OS

Эта папка отвечает на три вопроса: как система устроена, как в ней работать и почему были приняты важные решения.

## Карта

| Документ | Владеет информацией |
| --- | --- |
| [architecture.md](architecture.md) | слои, границы и источник истины для каждого типа данных |
| [workflows.md](workflows.md) | подключение проекта, выполнение и передача задач |
| [task-board.md](task-board.md) | structured outcomes, source identity и Codex memberships |
| [task-bridge.md](task-bridge.md) | автоматическая project-chat correlation, checkpoints и time evidence |
| [project-time.md](project-time.md) | общий учёт Codex-времени по всем тредам проекта и месяцам |
| [agent-os-app.md](agent-os-app.md) | approved boundary, UX proposal и implementation notes для native macOS app |
| [installation.md](installation.md) | reproducible core, Codex plugin, and macOS app installation |
| [agent-os.md](agent-os.md) | portable product boundary, local/private split и publication gates |
| [slack-monitor.md](slack-monitor.md) | read-only Slack intake, cursor и watched-root contract |
| [review-intake.md](review-intake.md) | безопасная маршрутизация PR review для reviewer/author |
| [chat-model.md](chat-model.md) | Codex task topology, ownership и handoff |
| [harness-comparison.md](harness-comparison.md) | gap analysis относительно PixelPoint example и принятый scope |
| [extending.md](extending.md) | критерии для новых docs, skills, tools и интеграций |
| [state.md](state.md) | только проверенное текущее состояние и ограничения |
| [roadmap.md](roadmap.md) | ближайшие outcomes, а не список возможных функций |
| [changelog.md](changelog.md) | датированные существенные изменения |
| [decisions/](decisions/README.md) | решения и rationale, которые нельзя потерять |

## Правило обновления

Материальное изменение Agent OS обновляет:

1. ближайший `AGENTS.md`, если изменились agent-команды, проверки, пути или ownership;
2. релевантный README, если изменились установка, использование или другое пользовательское поведение;
3. документ-владелец;
4. `state.md`, если изменилось фактическое состояние;
5. `roadmap.md`, если изменился следующий outcome;
6. `changelog.md`;
7. новый decision record, если решение неочевидно или отменяет старое.

Обновляйте только документы, утверждения которых действительно изменились; не
нужно механически редактировать каждый README или `AGENTS.md`. Перед handoff
ищите удалённые или переименованные команды, пути и названия и выполняйте все
затронутые документированные команды проверки.

Не копируйте структурированные project facts из `config/projects.yaml` в эти документы. Здесь описывается модель и способ использования реестра.
