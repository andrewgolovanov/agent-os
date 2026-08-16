# Security policy

## Supported versions

Security fixes target the latest public release and the current `main`
candidate. Older releases are not maintained unless a security notice says
otherwise.

## Reporting a vulnerability

Do not open a public issue containing credentials, private project paths, client
data, or provider identifiers. Contact the repository owner privately with a
minimal reproduction and the affected version or commit.

## Security boundary

Agent OS is local-first. Real configuration, tasks, reports, and runtime cursors
live in `AGENT_OS_HOME` and are not distributable source. Registered project
repositories remain in user-selected folders; only their verified local paths
are stored in the private registry. Initialization does not enable provider
access, hooks, schedules, repository writes, commits, pushes, deploys, or
external messages.

Before publishing any release, maintainers must run
`bin/agent-os audit-publication`, a dedicated secret scanner, the full validator,
and manual candidate review. The built-in publication audit is a boundary check,
not a complete credential scanner.
