# Roadmap

This roadmap contains only the next verifiable product outcomes.

## Now

### Verify app-coordinated stable plugin updates

The packaged runtime can now compare an already installed Agent OS plugin with
the signed app bundle, plan the exact matching stable marketplace tag, and
perform a user-confirmed or separately opted-in replacement with rollback. A
real local retry completed `v0.4.3` to `v0.6.0`; the preceding stalled clone
also proved restoration of the previous tag. Fresh-task pickup and second-Mac
Sparkle coordination remain open.

Done when:

- Settings shows installed and bundled plugin versions plus an enabled install
  action only for a supported official stable-tag transition;
- a real local `v0.4.3` to `v0.6.0` plugin update re-pins the marketplace,
  installs the exact bundled plugin version, preserves `AGENT_OS_HOME`, and is
  loaded by a fresh Codex task;
- a simulated installation failure restores the prior marketplace tag and
  plugin version;
- a newer plugin, an unpinned marketplace, and a non-official marketplace are
  left unchanged with an actionable explanation;
- the same behavior is confirmed after one genuine Sparkle app update on a
  second Mac.

### Verify local-only project sync and structured Slack bot mentions in a packaged install

The public `v0.7.0` app/runtime/plugin artifacts and an anonymous tag checkout
are verified. The remaining proof is pickup in a fresh installed Codex task and
one real Scheduled Slack monitor execution.

Done when:

- a fresh app launch registers active Codex roots without requiring Git,
  reading thread bodies, or changing repository state;
- a fresh plugin task in a previously unknown local folder registers its
  current root before Task Bridge routing;
- adding a first commit and then a remote enriches that same project key;
- missing, overlapping, duplicate-origin, conflicting, and transient-only paths
  are skipped without blocking the app;
- a manual Slack monitor pass dynamically inventories visible channels, finds
  one exact current-user mention hidden in a bot/app Block Kit root, reads its
  complete thread, and ignores a comparable root without the mention;
- an interrupted channel pass resumes from per-channel cursors without moving
  the global cursor, and an unchanged complete repeat returns `DONT_NOTIFY`;
- the live `Agent OS Slack Monitor` Scheduled prompt is updated only after its
  exact preview is approved.

### Verify the no-checkout packaged setup with a second installation

`v0.3.0` packages the checkout-independent minimal runtime in both the Codex
plugin and macOS app.
Complete the remaining real-user proof using only those two public artifacts:
launch either component first, onboard a repository located outside any Agent
OS directory, create and resume one durable outcome, then launch the other
component and confirm it sees the same private state.

Done when:

- the versioned Git marketplace installation requires no manual clone;
- the app initializes the same clean private home when installed first;
- onboarding previews and registers an arbitrary existing repository without
  changing its Git status, HEAD, remotes, or filesystem location;
- reviewed Slack channel mappings reconcile only unfinished unassigned outcomes,
  keep their channel labels on cards, and do not duplicate mapped labels in the
  top-level sidebar;
- a fresh Codex task loads the packaged runtime, onboarding skill, MCP tools,
  and Task Bridge hooks;
- the packaged app reads the same project and task immediately afterward.

### Validate packaged installation and updates on a second Mac

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
- the monorepo Agent OS plugin is installed; its MCP reads the active home in an
  installed-snapshot smoke and Context Loop passes its isolated
  lifecycle/hook smoke — verified;
- fresh Codex tasks load the installed Agent OS skill and invoke its MCP tools;
  the vetted Task Bridge hook bundle also executes against an isolated private
  home — verified;
- the tag workflow validates a clean temporary private home, runs the full
  publication audit, and asserts an Apple Silicon (`arm64`) app binary before
  publishing — verified locally against the release workflow contract;
- the Ed25519 key has an independently verified encrypted recovery copy —
  verified;
- GitHub Actions has the matching Ed25519 repository secret — verified;
- `v0.1.0` published its zip, checksum, and appcast from commit
  `0d816b4724dc0ef14a2f49f7f0c451e5a1684f8f` — verified;
- the public assets, stable appcast, bundle metadata, Apple Silicon binary,
  checksum, strict bundle signature, and Sparkle Ed25519 signature pass an
  independent post-publication verification — verified;
- `v0.2.0` published the no-checkout plugin/app runtime from commit
  `ecab617fa23abdaefdea42a4c9d157e2b737ed9f` in successful workflow run
  `31909930801` — verified;
- an anonymous HTTPS clone of `v0.2.0` initializes a separate private home and
  passes the complete Ruby suite, runtime synchronization, plugin package
  checks, and publication audit — verified.
- `v0.2.1` published the checkout-independent runtime from commit
  `d7607144fcf21fa4781ee9beabff9f3c0c9786d3` in successful workflow run
  `31913614945` — verified;
- the public `v0.2.1` zip, checksum, appcast, Apple Silicon/macOS metadata,
  exact embedded runtime tree, strict bundle signature, and Sparkle Ed25519
  signature pass independent post-publication verification — verified;
- an anonymous HTTPS clone of `v0.2.1` initializes a separate private home and
  passes 54 Ruby tests/420 assertions, runtime synchronization, plugin and
  Context Loop checks, Task Board and Slack-state validation, and publication
  audit — verified.
- `v0.3.0` published the direct-first onboarding and durable Done workflow from
  commit `e9cdf0ab0434a7ad99b36c8b5d1cbe6023d9026a` in successful workflow run
  `31946760759` — verified;
- the clean tag checkout passed 62 Ruby tests/520 assertions, 22 Swift tests,
  plugin package validation, runtime synchronization, and the publication
  audit before packaging — verified;
- the public `v0.3.0` zip, checksum, latest appcast, Apple Silicon/macOS
  metadata, embedded runtime version, strict bundle signature, archive length,
  and Sparkle Ed25519 signature pass independent post-publication verification
  — verified.
- `v0.3.2` published Slack-only labels and short Slack source titles from
  commit `91b209ae02af854ccb52dee28037bc876298da73` in successful workflow run
  `32059910788`; its exact public archive, checksum, metadata, runtime, strict
  bundle signature, appcast, and Sparkle Ed25519 signature passed independent
  post-publication verification — verified.
- `v0.4.0` published reviewed Slack channel-to-project reconciliation, the
  saved Light/Dark appearance, cleaner Board scrolling, and the wider inspector
  from commit `f6417fcaac6c9176d3bebdd43394a30782d3adc5` in successful workflow
  run `32075412237`; its public checksum, Apple Silicon/macOS metadata, exact
  22-file runtime, strict bundle signature, stable appcast, and Sparkle Ed25519
  signature passed independent post-publication verification — verified.
- `v0.4.1` published local-calendar Focus recency sections, project context
  above task titles, cleaner row hierarchy, bounded inspector resizing, and
  consistent titlebar separation from commit
  `e847fd9465d5b9e9128f1eb7f16b3a2048e662f5` in successful workflow run
  `32080926193`; its public checksum, Apple Silicon/macOS metadata, exact
  22-file runtime, strict bundle signature, stable appcast, and Sparkle Ed25519
  signature passed independent post-publication verification — verified.
- `v0.4.2` published explicit exact-outcome reassignment, preservation of
  completed activity on the original outcome, conflicting-ID timing pauses,
  and visible archived Codex memberships from commit
  `17e1c450d9ba4516f643f0b64c9ad910de9b8feb` in successful workflow run
  `32298222853`; its public checksum, Apple Silicon/macOS metadata, exact
  22-file runtime, strict bundle signature, stable appcast, and Sparkle Ed25519
  signature passed independent post-publication verification — verified.
- `v0.4.3` published compatible `taskId`, `task_id`, and `id` handling across
  task-targeting MCP mutations from commit
  `d196e5ddef4c467e5614c84668756037af117da0` in successful workflow run
  `32300042057`; its public checksum, Apple Silicon/macOS metadata, exact
  22-file runtime, strict bundle signature, stable appcast, Sparkle Ed25519
  signature, and fresh anonymous tag-clone validation passed — verified.
- `v0.5.0` published automatic eligible Codex repository registration and
  exact-current-user Slack bot/app mention intake from commit
  `5e6d0f16dd880e15ca681e6fa1e713acbf00facb` in successful workflow run
  `32495953322`; its public checksum, Apple Silicon/macOS metadata, exact
  23-file runtime, strict bundle signature, stable appcast, Sparkle Ed25519
  signature, and fresh anonymous tag-clone validation passed — verified.
- `v0.6.0` published local-only project registration, stable same-name keys,
  and later same-root repository enrichment from commit
  `da78a9124cad93ee0a365b7d6b8e9eeb5256c239` in successful workflow run
  `32499730792`; its public checksum, Apple Silicon/macOS metadata, exact
  23-file runtime, strict bundle signature, stable appcast, Sparkle Ed25519
  signature, and fresh anonymous tag-clone validation passed — verified.
- `v0.7.0` published deterministic Slack reconciliation, ordered app-local
  project pins, safe stable-tag plugin updates, completed-only label cleanup,
  and GUI-safe Codex App Server resolution from commit
  `66fb08f77d7d6497f85fc7d4c1ebcb67e781284c` in successful workflow run
  `32508847564`; its public checksum, Apple Silicon/macOS metadata, exact
  23-file runtime, strict bundle signature, stable appcast, Sparkle Ed25519
  signature, and fresh anonymous tag-clone validation passed — verified.

Remaining release checks:

- a second Mac completes an approved clean install and a genuine `v0.6.0` to
  `v0.7.0` update.

### Complete the local Agent OS app pilot

The native app remains a replaceable cockpit over canonical Agent OS state.
Continue real use before investing in distribution infrastructure.

Done when:

- Focus, Board, independently scrolling columns with hidden indicators, Done, inspector,
  refresh, lifecycle and completion-follow-up mutations, and exact Codex
  handoff remain reliable during the pilot;
- completed and cancelled outcomes retain their context in Done; completed
  Slack-backed work makes unsent follow-up visible without sending externally,
  and project/period filters summarize only exact-linked outcome time; broader
  Project Time remains an explicit CLI/private-report workflow;
- the official shadcn Neutral light/dark semantic system, saved toolbar toggle,
  dashboard-01 control geometry, prominent tracked time, readable Focus
  typography with local-calendar recency sections and full-width row
  separators, and the on-demand resizable detail split remain legible and
  predictable across Focus, Board, and narrow window layouts;
- contextual source rows remain useful without provider authentication and
  enhance GitHub PR state read-only when an authenticated `gh` is available;
- a fresh task loads the new monorepo plugin rather than an older cached build;
- the ad-hoc signed download, checksum, and user-approved Gatekeeper flow remain
  reliable during a second-user installation;
- release packaging and update behavior continue to satisfy the public release
  checks above.

## Next

### Mirror Codex project icons and colors when the public contract supports it

Agent OS now provides a narrow local fallback for project pins because that
navigation affordance is useful without changing canonical project state. It
should remain a read-only follower for Codex project icons and colors. The
current supported App Server contract does not expose stable project
presentation metadata, so those fields still wait on that boundary.

Done when:

- a supported Codex API returns stable project identity plus icon and color
  without reading private desktop files;
- Agent OS mirrors those values read-only and falls back to the folder glyph for
  older Codex versions or missing fields;
- thread pins are never misinterpreted as project pins, and any future Codex
  project-pin migration explicitly reconciles the existing app-local ordering.

### Prove setup with a second user

Provide only the app release, versioned plugin command, and installation guide.
Capture every undocumented assumption, then repair the packages/docs without
copying that user's private state into the source tree. If that user opts into
Slack monitoring, verify the documented sequence end to end: minimal connected-
Slack read, reviewed `/hooks`, fresh-task Task Bridge pickup, one manual bounded
monitor pass, and the first two Codex Scheduled executions. Include a
zero-repository case that runs from the active Agent OS home and creates one
named-channel inbox outcome with a label but no project route.

### Complete uninstall contract

Tagged upgrade now preserves the private home and refuses dirty/diverged source.
Uninstall may remove product-owned configuration only after previewing exact
targets and must never remove project repositories or Task Board history
implicitly.

## Later, only with demonstrated need

- read-only provider enrichment;
- richer board fields or scheduling beyond the single read-only Slack heartbeat;
- a formal support policy.
