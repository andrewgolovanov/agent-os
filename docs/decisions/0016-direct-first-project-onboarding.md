# 0016 — Registry-only project onboarding

Date: 2026-08-16

Status: accepted

## Context

Agent OS can register an existing Git repository anywhere on the computer, but
the original model also supported Agent OS-owned project folders with duplicated
metadata. That created two concepts for the same routing problem, made normal
projects appear twice, and produced generated documentation that could diverge
from the repositories that actually own the work.

## Decision

- Use one project topology: private `AGENT_OS_HOME/config/projects.yaml` stores each project
  `root` and its verified `repositories`.
- Never create an Agent OS-owned project container or write Agent OS metadata
  into a registered product repository.
- Represent multi-repository projects in the same registry entry; the primary
  repository is the project root.
- Provide a preview-first, one-way upgrade for obsolete `layout` and `wrapper`
  entries. Move an old managed folder to a private recovery backup before
  updating the registry. Never move or edit registered Git repositories.
- Do not expose a command, skill, or template that creates the old topology.

## Consequences

- A user installs the plugin and app, opens any repository, and onboards it
  without creating a second project folder.
- Existing registry-only projects remain unchanged.
- Legacy generated folders leave active routing without losing their contents.
- Project-specific instructions and durable context remain with the repositories
  that own them.
- This decision supersedes the two-layout model in decision 0002 while
  preserving the packaged-runtime boundary in decision 0013.
