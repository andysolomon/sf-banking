# ADR-002: Branching Strategy & Versioning — Banking App (project #2)

- **Status:** Accepted
- **Date:** 2026-06-17
- **Deciders:** Platform/Integration Architect hat

> **Exercises:** building-source-control (branching matrix, merge strategy, semver).
> **JD line:** "versioning, branching models." Inherited from the todo-app's ADR-002;
> unchanged except where the **two-package** repo adds specifics.

## Context

One developer, MR-gated CI on GitLab, frequent small releases, a required hotfix drill
(Phase 9), **and** a two-package repo (`frs-platform-core` + `frs-banking`) whose versions
are released together in dependency order.

## Decision

**GitHub Flow on GitLab** (same as todo-app):

1. `main` protected: MR-only, pipeline must pass, reviewed per checklist.
2. Feature branches `feature/FR-<n>-<slug>`, short-lived, deleted after merge.
3. **Merge commits, never fast-forward** — the merge event is the audit record.
4. Hotfix path: `hotfix/<slug>` cut **from the release tag**, full gates, patch version(s),
   back-merged to `main`.
5. **Semver on package versions** (the release artifacts): MAJOR = breaking/destructive (or
   a breaking core public-API change), MINOR = new FR stories, PATCH = defect/hotfix.

## Two-package specifics

- A single MR may touch **both** packages; CI builds them in **dependency order**
  (`frs-platform-core` → `frs-banking`).
- Git tags carry both versions at a compatible point, e.g. `v1.0.0` →
  `core 1.0.0 + banking 1.0.0` (mapping recorded in CHANGELOG).
- A change that bumps the **core public API** follows the Integration/Security change class
  (charter / change-management) — CCB if breaking, with a consumer-impact note.

## Consequences

- Every change takes the gated path (maximum pipeline reps).
- Tag-based hotfix branching is rehearsed in Phase 9 before it's needed for real.
- Two-package version coupling adds release-ordering discipline (handled in the runbooks).
