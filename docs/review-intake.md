# Review intake

Review intake остаётся read-only до отдельного пользовательского запроса. Slack даёт context, GitHub должен подтвердить canonical PR, author, state и head SHA.

## Пользователь — reviewer

1. Найти или создать `kind=review` task.
2. Attach canonical PR и Slack review root.
3. Подготовить отдельный analysis-only Codex handoff в соответствующий saved project.
4. Передать repository, head SHA, PR URL, task ID и exact Slack root.
5. Сохранить findings локально; не публиковать review и не менять код автоматически.

## Пользователь — author

1. Найти исходную delivery/research task по canonical PR.
2. Attach review root и классифицировать verified feedback.
3. Actionable changes возвращают task в `active`; approval обычно оставляет `review` до merge.
4. Verified merge может завершить task, если обязательных follow-up больше нет.
5. Не писать автоматически в user-owned implementation task; обновить Task Board snapshot.

При конфликте ролей author behavior безопаснее. Неоднозначность требует решения пользователя, а не догадки.
