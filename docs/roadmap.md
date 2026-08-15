# Roadmap

This roadmap contains only the next verifiable product outcomes.

## Now

### Close the first public release gate

Stage 1 source/home separation, monorepo consolidation, clean initialization,
doctor, validation, app build, MCP isolation, and plugin smoke tests are complete.

Completed publication checks:

- `agent-os audit-publication` reports zero findings — verified;
- Gitleaks 8.30.1 and manual review report no private data — verified for all
  126 initial candidates;
- no nested Git repository or generated build artifact is a commit candidate —
  verified;
- the accepted app redesign and release-candidate assets are committed and
  pushed to public `main` — verified at
  `e98dc8118585e22d6f6ba2c070a6c146347d1103`;
- an anonymous HTTPS clone of that exact commit passes clean private-home
  initialization, doctor, validation, Ruby/plugin checks, Swift build/tests,
  and the publication audit — verified;
- both monorepo marketplace plugins are installed; Agent OS MCP reads
  the active home in a standalone installed-snapshot smoke — verified;
- fresh Codex tasks load the installed Agent OS skill and invoke its MCP tools;
  the vetted Task Bridge hook bundle also executes against an isolated private
  home — verified;
- the tag workflow validates a clean temporary private home, runs the full
  publication audit, and asserts an Apple Silicon (`arm64`) app binary before
  publishing — verified locally against the release workflow contract;

Remaining release checks:

- GitHub Actions has the matching Ed25519 repository secret — verified;
- the Ed25519 key has an independent offline backup;
- `v0.1.0` publishes the zip, checksum, and appcast;
- a second Mac completes an approved first install and a later genuine
  old-version to new-version update.

### Complete the local Agent OS app pilot

The native app remains a replaceable cockpit over canonical Agent OS state.
Continue real use before investing in distribution infrastructure.

Done when:

- Focus, Board, inspector, refresh, one lifecycle mutation, and exact Codex
  handoff remain reliable during the pilot;
- the official shadcn Neutral dark semantic system and dashboard-01 control
  geometry, prominent tracked time, and
  on-demand resizable detail split remain legible and predictable across Focus,
  Board, and narrow window layouts;
- contextual source rows remain useful without provider authentication and
  enhance GitHub PR state read-only when an authenticated `gh` is available;
- a fresh task loads the new monorepo plugin rather than an older cached build;
- the ad-hoc signed download, checksum, and user-approved Gatekeeper flow remain
  reliable during a second-user installation;
- release packaging and update behavior continue to satisfy the public release
  checks above.

## Next

### Prove setup with a second user

Provide only the repository and installation guide. Capture every undocumented
assumption, then repair the installer/docs without copying that user's private
state into the source tree. If that user opts into Slack monitoring, verify the
documented sequence end to end: minimal connected-Slack read, reviewed `/hooks`,
fresh-task Task Bridge pickup, one manual bounded monitor pass, and the first two
Codex Scheduled executions.

### Complete uninstall contract

Tagged upgrade now preserves the private home and refuses dirty/diverged source.
Uninstall may remove product-owned configuration only after previewing exact
targets and must never remove project repositories or Task Board history
implicitly.

## Later, only with demonstrated need

- read-only provider enrichment;
- richer board fields or scheduling beyond the single read-only Slack heartbeat;
- a formal support policy.
