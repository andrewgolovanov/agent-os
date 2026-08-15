# Roadmap

This roadmap contains only the next verifiable product outcomes.

## Now

### Close the first private release gate

Stage 1 source/home separation, monorepo consolidation, clean initialization,
doctor, validation, app build, MCP isolation, and plugin smoke tests are complete.

Done when:

- `agent-os audit-publication` reports zero findings — verified;
- a dedicated secret scanner and manual candidate review report no private data;
- no nested Git repository or generated build artifact is a commit candidate;
- Agent OS app and its MCP work from a default clean private home;
- both monorepo marketplace plugins are installed; Agent OS MCP reads
  the active home in a standalone installed-snapshot smoke — verified;
- a fresh Codex task picks up the same installed Agent OS build;
- the private remote is configured only after those gates pass;
- the first commit is reviewed before push.

### Complete the local Agent OS app pilot

The native app remains a replaceable cockpit over canonical Agent OS state.
Continue real use before investing in distribution infrastructure.

Done when:

- Focus, Board, inspector, refresh, one lifecycle mutation, and exact Codex
  handoff remain reliable during the pilot;
- a fresh task loads the new monorepo plugin rather than an older cached build;
- the ad-hoc signed download, checksum, and user-approved Gatekeeper flow remain
  reliable during a second-user installation;
- the Ed25519 key has an offline backup and the release repository has the
  `AGENT_OS_SPARKLE_PRIVATE_KEY` secret;
- a tagged release publishes zip, checksum, and appcast, then a second Mac
  completes a genuine old-version → new-version update.

## Next

### Prove setup with a second user

Provide only the repository and installation guide. Capture every undocumented
assumption, then repair the installer/docs without copying that user's private
state into the source tree.

### Complete uninstall contract

Tagged upgrade now preserves the private home and refuses dirty/diverged source.
Uninstall may remove product-owned configuration only after previewing exact
targets and must never remove project repositories or Task Board history
implicitly.

## Later, only with demonstrated need

- read-only provider enrichment;
- richer board fields or scheduling;
- public visibility and a support policy.
