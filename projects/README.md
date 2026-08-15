# Projects

Один зарегистрированный project root представляет один рабочий проект. Product
source хранит только это описание и wrapper template. Поддерживаются два явных
layout:

- `wrapper` — Agent OS-owned operational context, который ссылается на один или несколько репозиториев в других путях;
- `direct-repository` — совместимый специальный layout, в котором project root
  совпадает с единственным существующим Git root. После identity-checked relink
  этот каталог может находиться в любой пользовательской папке.

Wrapper хранит личные роли репозиториев, правила публикации, внешние источники, project-only tools и долговечные пояснения. Для direct repository эти данные остаются в `config/projects.yaml`, а проектные инструкции читаются из уже существующего repository `AGENTS.md`, когда он есть. Если локального файла нет, действуют корневые инструкции Agent OS; Agent OS не внедряет служебный `AGENTS.md` внутрь продукта только ради onboarding.

## Правила

- Project key использует lowercase kebab-case и совпадает с ключом в `config/projects.yaml`.
- Layout фиксируется явно в `config/projects.yaml`.
- Wrapper создаётся через `$onboard-project` из `templates/project/`; это
  layout по умолчанию для repository из любой папки, а source code туда не
  копируется.
- Onboarding не перемещает direct repository автоматически. Физический перенос
  выполняется только по явному запросу после проверки Git-состояния и
  зависимостей пути; relink сохраняет direct layout и обновляет абсолютный
  project root. Точное исключение из Git index Agent OS требуется только пока
  direct repository физически находится под development checkout.
- После выполненного пользователем переноса relink проверяет repository identity
  и обновляет только private registry/wrapper metadata.
- Absolute repository paths хранятся в canonical registry; wrapper также зеркалирует их в `project.yaml`.
- Unknown facts остаются `unknown`; их нельзя угадывать по имени каталога или remote.
- Wrapper `AGENTS.md` дополняет корневые инструкции, а nested repository `AGENTS.md` имеет ещё более узкую область. В direct repository его собственный `AGENTS.md`, если он существует, сразу является ближайшей инструкцией; иначе наследуется корневой файл.

Actual project entries and paths belong only to the private registry and are not listed in product documentation.
