# 0002: Support direct repositories under projects

- Status: accepted; amended by 0013
- Date: 2026-08-09

## Context

Первый реальный pilot был вручную помещён в `projects/<key>` как полноценный Git-репозиторий. Исходная архитектура предполагала только wrappers и требовала бы либо повторного перемещения репозитория, либо добавления Agent OS metadata внутрь product source tree.

## Decision

Поддерживать два явных project layout:

- `wrapper` для Agent OS-owned context, который ссылается на один или несколько внешних репозиториев;
- `direct-repository` для одного существующего Git root, который совпадает с
  зарегистрированным project root. Первоначально этот root находился под
  `projects/<key>`; decision 0013 и identity-checked relink разрешили сохранить
  layout после отдельного переноса repository в любую абсолютную папку.

В direct layout structured Agent OS metadata хранится только в `config/projects.yaml`. Agent OS не добавляет `project.yaml` и документацию внутрь репозитория и исключает его точный каталог из собственной Git history.

## Consequences

- Direct repository остаётся на месте и сохраняет независимые remotes, history,
  instructions и dirty worktree; relink меняет только private path metadata.
- Agent OS не создаёт случайный embedded-repository gitlink.
- Multi-repository projects и личный operational context продолжают использовать wrapper layout.
- Переход direct project в wrapper требует отдельного явного решения и безопасного перемещения вне onboarding.
