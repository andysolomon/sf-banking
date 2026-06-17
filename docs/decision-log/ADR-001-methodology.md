# ADR-001: Development Methodology — Banking App (project #2)

- **Status:** Accepted
- **Date:** 2026-06-17
- **Deciders:** Platform/Integration Architect hat (CCB + InfoSec consulted)

> **Exercises:** planning-development-models (methodology decision matrix),
> application-lifecycle-management. **JD line:** "Experience with Scaled Agile Framework
> (SAFe) highly desired."
>
> Inherited from the todo-app's ADR-001; the hybrid decision is unchanged, with an added
> **platform-team-as-a-product** framing.

## Context

This project needs a methodology before requirements are written. Same dual signal as the
todo-app: requirements are deliberately frozen early (compliance-style, to practice CCB
discipline) **and** implementation should iterate in small reviewed increments (the
~80%-DevOps reality of the role rewards many small pipeline runs over big batches).

New wrinkle: this repo ships a **reusable package (`frs-platform-core`) as a product** to
consuming app teams, which adds an API-versioning/compatibility concern a single app
doesn't have.

## Decision

**Hybrid:** waterfall-style *stage gates between rungs*, agile *iteration within rungs* —
plus **product-style versioning for the platform package**.

- Plan phases are sequential gates — Phase N+1 doesn't start until Phase N's acceptance
  criteria pass (requirements and integration/security architecture genuinely precede code).
- Inside implementation phases: small FR backlog, one MR per story, test-first, shippable
  after every merge, scope changes via CCB.
- **`frs-platform-core` is versioned semantically and treated as a product**: consumers
  pin a version; breaking API changes are a governed (Integration/Security + CCB) event
  with a consumer-impact assessment — the discipline a shared platform owes its teams.

## SAFe simulation notes (one person can't run SAFe, but can practice its mechanics)

- **PI-style cadence:** group minor releases into a planned increment (v0.x → v1.0.0 = one
  PI); plan, then demo via post-release review.
- **DoD as team agreement:** `definition-of-done.md` is immutable mid-PI.
- **WSJF-lite prioritization:** order the FR backlog by value/effort notes.
- **Platform-as-shared-service:** the core package + consumer README model the SAFe idea
  of a shared platform serving multiple ARTs/app teams.
- Not simulated (and noted honestly in interviews): ARTs, cross-team PI planning, RTE role.

## Consequences

- Positive: stage gates produce the audit artifacts the JD asks about; product-style
  package versioning is the literal "reusable enablers for multiple app teams" evidence.
- Negative: more ceremony than a solo project needs — accepted; the ceremony *is* the
  curriculum.
- Risk: gate perfectionism stalls progress → acceptance criteria are checklists; when they
  pass, the gate closes, no gold-plating.
