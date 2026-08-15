# Security policy

## Supported versions

Until the first release, only the current private `main` candidate is supported.

## Reporting a vulnerability

Do not open a public issue containing credentials, private project paths, client
data, or provider identifiers. Contact the repository owner privately with a
minimal reproduction and the affected version or commit.

## Security boundary

Agent OS is local-first. Real configuration, tasks, runtime cursors, and project
checkouts live in `AGENT_OS_HOME` and are not distributable source. Initialization
does not enable provider access, hooks, schedules, repository writes, commits,
pushes, deploys, or external messages.

Before release, maintainers must run `bin/agent-os audit-publication`, a dedicated
secret scanner, the full validator, and manual candidate review. The built-in
publication audit is a boundary check, not a complete credential scanner.
