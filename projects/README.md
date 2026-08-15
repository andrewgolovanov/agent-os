# Projects

Один private каталог `AGENT_OS_HOME/projects/<key>/` представляет один рабочий проект. Product source хранит только это описание и wrapper template. Поддерживаются два явных layout:

- `wrapper` — Agent OS-owned operational context, который ссылается на один или несколько репозиториев в других путях;
- `direct-repository` — существующий Git-репозиторий, вручную помещённый прямо в `projects/<key>/`.

Wrapper хранит личные роли репозиториев, правила публикации, внешние источники, project-only tools и долговечные пояснения. Для direct repository эти данные остаются в `config/projects.yaml`, а проектные инструкции читаются из уже существующего repository `AGENTS.md`, когда он есть. Если локального файла нет, действуют корневые инструкции Agent OS; Agent OS не внедряет служебный `AGENTS.md` внутрь продукта только ради onboarding.

## Правила

- Project key использует lowercase kebab-case и совпадает с ключом в `config/projects.yaml`.
- Layout фиксируется явно в `config/projects.yaml`.
- Wrapper создаётся через `$onboard-project` из `templates/project/`; source code туда не копируется автоматически.
- Onboarding не перемещает direct repository автоматически. Физический перенос выполняется только по явному запросу после проверки Git-состояния и зависимостей пути; затем repository исключается из Git index Agent OS отдельным точным правилом.
- Absolute repository paths хранятся в canonical registry; wrapper также зеркалирует их в `project.yaml`.
- Unknown facts остаются `unknown`; их нельзя угадывать по имени каталога или remote.
- Wrapper `AGENTS.md` дополняет корневые инструкции, а nested repository `AGENTS.md` имеет ещё более узкую область. В direct repository его собственный `AGENTS.md`, если он существует, сразу является ближайшей инструкцией; иначе наследуется корневой файл.

Actual project entries and paths belong only to the private registry and are not listed in product documentation.
