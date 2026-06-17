# ADR-003: Two-Package Architecture (base + extension) — Banking App (project #2)

- **Status:** Accepted
- **Date:** 2026-06-17
- **Deciders:** Platform/Integration Architect hat (CCB consulted)

> **Exercises:** releasing-packaging-strategy (unlocked 2GP, dependencies, versioning),
> planning-development-models (package model), platform-enablers design. **JD lines:**
> "delivery of platform enablers including… reusable components in support of business
> products"; "supporting multiple Salesforce application teams"; "Deliver explicit APIs
> and abstractions that offer flexibility for application developers." **RTM design
> coverage:** NFR-9 (and the reusable-enabler JD theme overall).
>
> The todo-app's ADR-003 explicitly deferred splitting "(e.g. core/audit)… a new ADR" —
> this is that ADR.

## Context

The JD's core mission is a **platform team** delivering **reusable components** to
**multiple application teams**. The todo-app proved a *single* unlocked package; this
project must demonstrate the multi-package, reusable-enabler reality the JD describes.

## Options

| Option | For | Against |
|---|---|---|
| One package (like todo-app) | Simplest; lowest Phase-5 friction | Can't demonstrate reusable enablers / cross-team consumption / dependency+versioning — the entire JD theme this project targets |
| **Two unlocked packages: base + extension (chosen)** | Models a real platform: `frs-platform-core` (enablers) consumed by `frs-banking` (app); exercises cross-package dependency, versioning, and an explicit public API | Packaging discipline: dependency completeness, install ordering, access-modifier decisions surface early (intended learning) |
| Many packages | Realistic at enterprise scale | Over-engineered for a solo lab; diminishing learning vs. cost |

## Decision

Two **unlocked packages (2GP), no namespace**:

- **`frs-platform-core`** — the **reusable enabler**: logging/error framework, callout
  framework (Named Credential abstraction + retry/backoff + idempotency + circuit-breaker),
  generic Platform Event publisher, `Integration_Log__c` + `Dead_Letter__c`. Has an
  **explicit public API** (documented in its README) and **no dependency**.
- **`frs-banking`** — the **extension/app**: depends on `frs-platform-core` and builds the
  banking features on top. **Consumer #1.**
- **`todo-app`** is named as the candidate **consumer #2** (proof of reuse) — deferred.

Specifics:
- Dependency declared in `sfdx-project.json`; `frs-banking` **pins** a specific core
  version (bumping the pin is a governed change — see change-management).
- **Access modifiers:** core classes intended for consumers are `global`/`public` per the
  README's published API; internals stay `private`/`@TestVisible`. (2GP: `public` is
  package-scoped, so the consumable surface is deliberate.)
- CI builds versions in dependency order; installs (staging + prod) go **core → banking**.
- Versioned independently but released at compatible points (ADR-002).

## Consequences

- Demonstrates the JD's "reusable components for multiple app teams" concretely — the
  README lets a second team adopt the core from docs alone (acceptance criterion, Phase 6).
- Adds real packaging discipline (dependency completeness, install order, API/version
  governance) — the intended curriculum.
- A breaking core public-API change is an Integration/Security + CCB event with a
  consumer-impact assessment (the platform owes its consumers stability).
