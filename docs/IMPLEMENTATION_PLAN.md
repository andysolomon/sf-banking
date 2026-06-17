# Banking App — Salesforce Platform Engineering Learning Project (#2)

A deliberately simple **retail-banking servicing app** built **Salesforce-native** and
wrapped in a deliberately rigorous delivery process. As with the sibling
[`todo-app`](../../todo-app/docs/IMPLEMENTATION_PLAN.md), the product is kept thin on
purpose — the learning target is the **platform engineering discipline around it**. The
difference: this project deliberately goes **deep on the three JD areas the todo-app left
thin** — **Salesforce integration patterns**, **reusable platform enablers / components**,
and **security & governance of financial data** — because the Federal Reserve JD is a
**Financial Services** role and a banking domain *demands* exactly those.

> **Role weighting (different from todo-app):** the todo-app proved the **DevOps & CI/CD
> spine** (~80% of the role) and shipped `v1.0.0` to "prod". This project does **not**
> re-prove that spine — it *reuses* it — and instead spends its time on the JD lines the
> todo-app explicitly deferred:
> 1. **"Must have experience in Salesforce Integration patterns"** (todo-app: deferred Phase 10)
> 2. **"delivery of platform enablers including… reusable components in support of business
>    products"** + **"supporting multiple Salesforce application teams"** (todo-app: grazed in Phase 9)
> 3. **"Must have experience in Salesforce security Model"** + **"Partner with Information
>    Security representatives"** — exercised on *financial* data, not todos.
>
> Accordingly **Phases 3, 6, 7, and 9** (integration architecture, the reusable platform
> core package, the integration features, and integration operations) are the core and
> should get the bulk of the time. Phases 1–2, 4–5 reuse the proven todo-app formula at
> speed. **The app is the cargo; the integration platform is the product.**

## The two-team framing (enacts the JD)

The JD's mission is a **platform team** that delivers **reusable enablers** and supports
**multiple application teams**. This project enacts that literally:

- **`frs-platform-core`** — a base **unlocked package (2GP)**: logging/error-handling
  framework, a generic outbound-callout framework (Named Credential abstraction + retry +
  idempotency), a generic Platform Event publisher, and an integration dead-letter object.
  This is the **platform enabler** — written as if *N* app teams will consume it.
- **`frs-banking`** — an **extension package** that *depends on* `frs-platform-core` and
  builds the actual banking-servicing features on top of it. It is **consumer #1**.
- The existing **`todo-app`** is named as the candidate **consumer #2** (proof the core is
  genuinely reusable, not a single-app library) — see Deferred.

## The integration counterpart (heterogeneous SaaS environment)

The JD requires **"Integrations and/or Connectors between Salesforce.com and FRS and other
3rd party applications"** across **"heterogeneous datacenter, cloud, and SaaS
environments."** Salesforce here is the **CRM / servicing layer**; the **system of record
for money is external** — a self-built **mock core-banking SaaS on Vercel**
(`frs-core-banking-mock`, a small Next.js / serverless REST service). It is **bidirectional
by design** so failure-mode drills are possible end-to-end:

- **Outbound (SF → core banking):** balance lookups and money transfers via REST callout
  (Named Credential + External Service), with an `Idempotency-Key` header.
- **Inbound (core banking → SF):** webhooks (transaction-posted, fraud-alert) to an Apex
  inbound REST resource.
- **Failure injection:** the mock can be told to return 500 / time out / delay, so the
  retry, idempotency, circuit-breaker, and dead-letter paths can be **drilled for real**.

## JD Traceability

Every top skill in the JD maps to at least one rung; the **three deepened areas are bold**:

| JD requirement | Where exercised |
|---|---|
| **Salesforce Integration patterns** (Named Creds, External Services, REST callouts, Platform Events, CDC, idempotency/retry) | **Phases 3, 5, 6, 7** (integration architecture → callout framework → transfer/webhook/event features) |
| **Platform enablers / reusable components for multiple app teams** | **Phases 6, 9** (`frs-platform-core` base package; cross-package dependency + versioning; consumer README) |
| **Salesforce security Model** + least-privilege on financial data | **Phases 3, 7, 8** (OWD Private + sharing on `Bank_Account__c`, FLS on balances, integration-user least-priv, cross-customer isolation tests) |
| **Partner with Information Security** (auth, secrets, controls) | **Phases 3, 9** (Named Credential auth pattern ADR, secret handling, InfoSec sign-off artifact) |
| Salesforce DevOps & CI/CD, source-driven dev, Salesforce CLI | Phases 4, 9 (DX **multi-package** project, GitLab pipeline reused from todo-app, package promotion) |
| Sandbox strategies, versioning, branching models | Phases 3–4 (env strategy, ADR branching, **two-package semver + dependency pinning**) |
| Apex classes, triggers, async/batch, governor limits | Phases 6–7 (callout framework, Queueable retry, batch statement/interest job, bulkified posting) |
| Data modeling, large data volumes, indexing/selectivity | Phase 3 (ledger ERD — `Transaction__c` as a high-volume object; selective queries, skinny-index notes) |
| Automated testing, SFDX test automation, static analysis | Phases 5–8 (`HttpCalloutMock`, mock inbound, Jest, Playwright against the live Vercel mock, Code Analyzer in CI) |
| Flow optimization, screen flow | Phase 7 (servicing screen flow: open-account / dispute-a-transaction) |
| Salesforce release evaluations, change mgmt, release governance | Phases 1, 9 (charter/change classes; release readiness; **integration-failure runbook + drill**) |
| Scripting (shell/PowerShell) | Phases 4, 9 (pipeline + org-setup + mock-deploy scripts) |
| Data Cloud | Out of scope (note in Deferred) |

## Objective and Scope Boundaries

**Objective:** Build and operate a Salesforce banking-servicing app that **integrates with
an external core-banking SaaS**, on top of a **reusable platform-core package**, through a
full auditable ALM cycle — so the integration, reusable-enabler, and financial-data-security
concepts the JD demands are exercised hands-on against the real platform.

**In scope:** governance reused-and-trimmed from todo-app; functional banking stories +
integration/security NFRs (idempotency, SLAs, isolation); **integration architecture
diagrams before code**; a **two-package** DX project (base core + banking extension); the
**Vercel mock core-banking SaaS**; outbound + inbound + Platform Event integration with
retry/idempotency/dead-letter; GitLab CI (reused); test pyramid incl. callout mocks + live
e2e; release/rollback/hotfix **plus an integration-failure drill**; InfoSec sign-off artifact.

**Out of scope:** Financial Services Cloud (licensed — model with custom objects instead),
real money/banking rails, Data Cloud, real multi-team coordination, paid tooling, real
sandbox tiers. See "Deferred".

**Stack:** Salesforce DX (sf CLI), Apex + LWC + Flow, **two unlocked packages (2GP) with a
dependency**, scratch orgs, GitLab CI (`.gitlab-ci.yml`, reused from todo-app), Salesforce
Code Analyzer (PMD), Apex tests (`HttpCalloutMock`) + Jest + Playwright, Named Credentials +
External Services + Platform Events, **Next.js mock SaaS on Vercel**, Mermaid diagrams.

**Environment constraint (known limitation):** same free-tier substitution as the todo-app
(no paid sandboxes), **plus** the integration counterpart is self-hosted free:

| Study/JD concept | This project |
|---|---|
| Production org | Developer Edition org ("prod") — may reuse the todo-app Dev Hub |
| Dev Hub | Developer Edition org with Dev Hub enabled |
| Developer / QA / staging sandbox | Scratch org per branch / seeded scratch org / package-built scratch org |
| External 3rd-party SaaS / "FRS" system | **`frs-core-banking-mock` on Vercel** (free tier) |
| Real integration user / service account | Named Credential + a low-priv integration permission set |
| Platform Shield field encryption | *Documented* in the security model; not enabled (not free) |

The real patterns (paid sandbox tiers, Shield encryption, a hardened integration service
account) are still **documented** as if for a paid Fed org — that's the JD-relevant artifact.

## Current Baseline

Greenfield. `projects/banking-app/` contains this plan and `progress.txt` only. The sibling
`projects/todo-app/` is feature-complete at `v1.0.0` and supplies the **reusable assets to
inherit**: the GitLab CI pipeline shape, the governance doc templates, the scratch-org
lifecycle discipline, and the free-tier org/limits knowledge (6 scratch creates/day, etc.).
No banking code, no second repo, and no Vercel mock exist yet.

## Capability Map (greenfield)

1. Governance & process artifacts (reuse todo-app templates; add InfoSec partnership model)
2. Requirements (banking functional stories + integration/security NFRs + traceability)
3. **Integration & security architecture** (ledger data model, sharing/FLS, the callout/
   webhook/event/retry/idempotency sequence diagrams, ADRs) — the centerpiece
4. Delivery platform (two-package DX project, reused GitLab CI, scratch orgs, **Vercel mock**)
5. Walking skeleton (thinnest vertical slice: one Named-Credential balance callout, mocked + live)
6. **Reusable platform-core package** (logging, callout framework, event publisher, dead-letter)
7. **Banking integration features** (transfer via callout, inbound webhook, Platform Event, drills)
8. Test & quality strategy (callout mocks, inbound mocks, live e2e, isolation tests, RTM)
9. **Release & integration operations** (runbooks + integration-failure drill, versions, InfoSec sign-off)

---

## Phase 1 - Governance and Project Charter (reuse + adapt)

**Study tie-in:** planning-governance, application-lifecycle-management. **JD tie-in:**
"change-management controls, auditability, and release governance"; "partnering with IT and
Security teams".

**Goal:** Stand up governance fast by inheriting the todo-app's artifacts, then add what a
*platform-team-serving-app-teams* needs.

**Deliverables (in `docs/governance/` and `docs/decision-log/`):**
- `charter.md` — adapted from todo-app; adds the **two-team operating model** (this repo is
  the platform team producing `frs-platform-core`; banking + todo are consuming app teams),
  the hats (Developer, Release Manager, **Platform/Integration Architect**, InfoSec
  approver, CCB), and segregation-of-duties for who approves an integration/security change.
- `change-management.md` — change classes mapped to release paths, **plus an
  "integration/security change" class** that requires the InfoSec hat's approval.
- `definition-of-done.md` — reviewed, tests pass (incl. callout mocks), static analysis
  clean, RTM updated, **no secrets in source**, docs updated.
- `ADR-001-methodology.md` — reuse the todo-app methodology decision; note SAFe and the
  platform-team-as-a-shared-service framing.

**Dependencies:** none (todo-app templates exist). **Risks:** re-writing what already exists
— *inherit and diff*, don't redraft.

**Acceptance criteria:** four docs exist; the new integration/security change class maps to
a release path with an explicit InfoSec gate.

## Phase 2 - Functional and Non-Functional Requirements

**Study tie-in:** ALM Plan stage, testing-methodologies (RTM), planning-environment-risks.
**JD tie-in:** "clarify scope of the Salesforce platform integrations"; secure coding.

**Goal:** Define a thin but *integration-shaped* banking scope and the NFRs that make the
integration provable.

**Deliverables (in `docs/requirements/`):**
- `functional-requirements.md` — FR-IDs, e.g.: FR-1 view a customer's bank accounts &
  balances (balance fetched live from core banking); FR-2 initiate a **transfer** between
  accounts (outbound callout, idempotent); FR-3 receive a **posted-transaction webhook** →
  create `Transaction__c`; FR-4 receive a **fraud-alert webhook** → open a `Case`; FR-5
  publish a `Transfer_Completed__e` **Platform Event** on success; FR-6 a **servicing screen
  flow** (open account / file a dispute).
- `non-functional-requirements.md` — heavy on the deepened areas: **NFR-idempotency**
  (duplicate transfer requests never double-post), **NFR-retry** (transient core-banking
  failures retried with backoff, exhaustion → dead-letter), **NFR-isolation** (a customer/
  agent sees only permitted accounts — financial-data sharing), **NFR-secrets** (no
  credential in source/logs), **NFR-SLA** (callout timeout + circuit-breaker threshold),
  plus coverage ≥85%.
- `rtm.md` skeleton covering all FR/NFR IDs.
- `risk-register.md` — integration-specific risks (core-banking down, duplicate posting,
  webhook replay/spoofing, secret leakage) using the study risk categories.

**Dependencies:** Phase 1. **Risks:** scope creep into a real bank — keep it to the 6 FRs.

**Acceptance criteria:** every FR/NFR has an ID and lands in the RTM; the idempotency,
retry, isolation, and secrets NFRs are explicit and testable.

## Phase 3 - Integration & Security Architecture (centerpiece)

**Study tie-in:** system-design integration patterns, planning-environment-risks,
sharing/security model. **JD tie-in:** "Salesforce Integration patterns", "Salesforce
security Model", "Partner with Information Security", "heterogeneous… cloud and SaaS".

**Goal:** Design the integration and the financial-data security model **before any code** —
this is where the project earns its interview value.

**Deliverables (in `docs/architecture/`):**
- `data-model.md` — ERD: `Account` (customer), `Bank_Account__c` (type, masked number,
  **balance is a cached/decorated value, source-of-truth is core banking**),
  `Transaction__c` (the **high-volume ledger** — selectivity, indexing, skinny-table/LDV
  notes), `Transfer__c` (status state-machine: Requested→Posting→Completed/Failed,
  idempotency key), and the platform-core `Integration_Log__c` / `Dead_Letter__c`.
- `security-model.md` — **OWD Private** on `Bank_Account__c`/`Transaction__c`, sharing so a
  customer/servicing agent sees only permitted records, **FLS on balance/number fields**,
  the **least-privilege integration permission set** (what the inbound webhook user may
  touch — nothing more), Shield field-encryption *documented*, an access matrix.
- `data-classification.md` — classify every field that crosses the SF↔core-banking
  boundary (public / internal / confidential / restricted) with PII / residency /
  retention notes; drives FLS, Shield-encryption candidates, and what may be logged.
  (InfoSec input; from the integration study guide.)
- `integration-architecture.md` + `sequence-diagrams.md` (Mermaid) — the four core flows:
  **(a)** balance lookup (SF → Named Credential → core banking), **(b)** transfer with
  **idempotency key + retry/backoff + circuit-breaker + dead-letter**, **(c)** inbound
  posted-transaction webhook (auth, validation, replay protection), **(d)** Platform Event
  publish/subscribe on transfer completion; plus CDC vs Platform Event trade-off notes.
- ADRs: `ADR-002-branching-strategy.md` (reuse), `ADR-003-two-package-architecture.md`
  (base core + banking extension; dependency direction; versioning/pinning), **
  `ADR-004-integration-auth-pattern.md`** (Named Credential auth: per-named-principal vs
  per-user; secret storage; why not hardcoded; how InfoSec reviews it).
- Fill the RTM **design** column for every FR/NFR.

**Dependencies:** Phase 2. **Risks:** analysis paralysis — timebox; diagrams over prose.

**Acceptance criteria:** all four integration sequence diagrams exist; the security model
proves least-privilege for the integration user; ADR-003 and ADR-004 decided; RTM design
column 100% filled.

## Phase 4 - Source Control, Two-Package DX Project, and the Vercel Mock

**Study tie-in:** source-driven development, environment strategy. **JD tie-in:** DevOps &
CI/CD (GitLab), "engineering solutions across… cloud and SaaS environments", scripting.

**Goal:** Stand up the delivery platform by **reusing the todo-app pipeline**, but for a
**multi-package** project, and deploy the integration counterpart.

**Deliverables:**
- DX project with **two package directories** in `sfdx-project.json`: `frs-platform-core`
  (no dependency) and `frs-banking` (`dependencies: frs-platform-core`); scratch def,
  `.forceignore`.
- **USER step:** create/confirm Dev Hub + "prod" Developer Edition orgs (may reuse todo-app's
  Dev Hub); register **both** packages; create the GitLab project (`sf-banking`).
- `.gitlab-ci.yml` — **adapted from the todo-app pipeline** (the reuse is itself the JD
  evidence): scan → scratch-org test → **build BOTH package versions in dependency order** →
  test-release (install core then banking into a staging scratch) → release (manual). Store
  SFDX auth URLs as masked CI vars (reuse the base64 discipline).
- **`frs-core-banking-mock`** (`mock/` subdir or sibling) — Next.js/serverless on Vercel:
  `GET /accounts/:id/balance`, `POST /transfers` (honors `Idempotency-Key`), webhook sender,
  and a **failure-injection switch** (return 500 / delay / timeout). `scripts/deploy-mock.sh`.
- `docs/devops/pipeline-design.md` (multi-package delta) + MR template + review checklist
  (inherited).

**Dependencies:** Phase 3. **Risks:** scratch-org daily limits (6/day, **shared with
todo-app**) — a 2-package build burns more; batch and count before pushing. Multi-package
install order errors — pin dependency versions.

**Acceptance criteria:** pipeline green on an empty 2-package skeleton; both packages
version-create in CI in dependency order; the Vercel mock is deployed and reachable (curl
the balance endpoint); a deliberate PMD violation + failing Apex test go red then green.

## Phase 5 - Walking Skeleton (thinnest integrated slice)

**Study tie-in:** walking-skeleton / tracer-bullet. **JD tie-in:** integration patterns end
to end; secure coding.

**Goal:** Prove the **entire integration spine** with the smallest possible feature: show a
`Bank_Account__c`'s **live balance** fetched from the Vercel mock via a Named Credential.

**Deliverables (across both packages):**
- `frs-platform-core` v0.1.0: a minimal `CalloutService` (Named Credential call + structured
  `Integration_Log__c`) — the first reusable enabler.
- `frs-banking` v0.1.0: `Bank_Account__c` + a `bankAccountCard` LWC + an Apex controller that
  calls `CalloutService` to fetch balance; **least-priv perm set**; Named Credential to the
  Vercel mock.
- Apex tests with **`HttpCalloutMock`** (success + timeout) at ≥85%; Jest for the LWC; a live
  **post-install smoke test** that hits the real Vercel mock and records the result.
- Both package versions installed into "prod" in dependency order via the release job; tag
  `v0.1.0` + CHANGELOG; RTM FR-1 + the secrets/isolation NFRs marked verified.

**Dependencies:** Phase 4. **Risks:** Named Credential setup in a scratch org (per-org config
vs packaged) — document whether it's packaged metadata or a post-install setup step.

**Acceptance criteria:** balance renders live from the mock in "prod"; `HttpCalloutMock`
tests green in CI; no credential anywhere in source or logs; tag `v0.1.0` released.

## Phase 6 - Reusable Platform-Core Package (the enabler)

**Study tie-in:** platform enablers, common patterns (logging/monitoring/error handling).
**JD tie-in:** "delivery of platform enablers… reusable components in support of business
products", "explicit APIs and abstractions… for application developers", "patterns for
common platform needs (logging, monitoring, alerting…)".

**Goal:** Build `frs-platform-core` into a genuine **reusable platform library** with an
explicit API that an app team could adopt without reading its internals.

**Deliverables (in `frs-platform-core` + `docs/architecture/`):**
- **Logging/error framework:** `Logger` + `Integration_Log__c` (correlation id, category,
  payload-safe redaction), used by every callout.
- **Callout framework:** `CalloutService` matured with **retry + exponential backoff**
  (Queueable), **idempotency-key** support, a **circuit-breaker** read of recent failures,
  and a typed result; Named Credential abstraction so consumers never see endpoints/secrets.
- **Generic Platform Event publisher:** `EventBus`-style wrapper + a base `Dead_Letter__c`
  object and **replay** entry point for exhausted retries.
- **Consumer README** (`frs-platform-core/README.md`) — the **explicit API/abstractions**
  doc: how an app team installs the package, what classes/permission sets to use, with a
  worked example. Written as if for *the todo-app team* as the next adopter.
- Its **own** test suite (mocked) at ≥85%, independent of `frs-banking`.

**Dependencies:** Phase 5. **Risks:** over-building a framework — every capability must be
consumed by Phase 7 or it's cut. Packaging an abstract base others extend (global vs public
access modifiers in 2GP) — decide and document.

**Acceptance criteria:** `frs-banking` consumes the framework with **zero** direct callout/
HTTP code of its own; the README lets a hypothetical second team integrate from docs alone;
core package versions and installs independently.

## Phase 7 - Banking Integration Features + Failure Drills

**Study tie-in:** integration patterns, async/batch, governor limits. **JD tie-in:**
"Creates Integrations and/or Connectors between Salesforce.com and FRS and other 3rd party
applications"; Flow; Tier-3 defect resolution.

**Goal:** Build the real banking features **on top of the core package**, then **drill every
failure mode** — the part only execution can prove.

**Deliverables (in `frs-banking`):**
- **FR-2 Transfer** — outbound callout via `CalloutService` with idempotency key; `Transfer__c`
  state machine; double-submit safe.
- **FR-3 / FR-4 inbound webhooks** — Apex inbound REST resource (`@RestResource`) for
  posted-transaction (→ `Transaction__c`) and fraud-alert (→ `Case`), with auth + payload
  validation + replay protection.
- **FR-5 Platform Event** — publish `Transfer_Completed__e` via the core publisher; a
  subscriber (trigger or Flow) updates the ledger; CDC trade-off noted.
- **FR-6 servicing screen flow** — open-account / file-a-dispute.
- Async **batch** statement/interest job (bulkified, governor-limit-aware) over the ledger.
- **Daily reconciliation job** — scheduled batch comparing the SF ledger against
  core-banking balances; mismatches raise an alert/Case. (Integration guide's
  reconciliation pattern — the safety net *behind* idempotency + retries.)
- **Failure drills (mandatory, via the mock's failure switch), each recorded:** core-banking
  **timeout** → retry → success; **HTTP 500** → retry exhaustion → **dead-letter** →
  **replay**; **duplicate transfer** → idempotency blocks double-post; **webhook replay** →
  rejected. Each drill that corrects a wrong assumption is interview gold ("a runbook is a
  hypothesis until executed").

**Dependencies:** Phase 6. **Risks:** Named Credential / inbound-auth config differences
between scratch and "prod"; callout-in-trigger anti-pattern (must be async) — enforce via the
framework.

**Acceptance criteria:** all 6 FRs work in "prod"; all four failure drills executed and
documented; no callout occurs synchronously in a trigger; ledger stays correct under
duplicate/replay.

## Phase 8 - Test, Quality, and Security Strategy

**Study tie-in:** testing-methodologies, static analysis, SFDX test automation. **JD
tie-in:** automated/e2e testing, secure coding, "design least-privilege access models".

**Goal:** Make the integration and the financial-data security **provable**, not asserted.

**Deliverables (in `docs/testing/` + code):**
- `test-strategy.md` — the pyramid for an *integration* app: Apex unit with `HttpCalloutMock`
  (success/timeout/500/malformed), **inbound** REST tested via `RestContext` mocks, Jest for
  LWCs, **Playwright e2e against the installed package + the live Vercel mock** (incl. a
  forced-failure run that asserts the dead-letter path), contract notes vs the mock's API.
- **Security tests:** cross-customer **isolation** negative tests (agent A cannot read
  customer B's `Bank_Account__c`), FLS-enforcement tests on balance fields, an
  integration-user least-priv assertion.
- Code Analyzer (PMD) gate already in CI; add any integration-specific rules.
- RTM **test** column 100% filled; coverage gate ≥85% enforced in CI.

**Dependencies:** Phase 7. **Risks:** Playwright against a live external service is flaky —
use the mock's deterministic mode for e2e, the failure switch only in the dedicated drill spec.

**Acceptance criteria:** RTM test column complete; isolation proven by failing-then-passing
negative tests; e2e (happy + forced-failure) green in CI; coverage gate green.

## Phase 9 - Release Management & Integration Operations

**Study tie-in:** release-management-strategy, operating-direct-changes-production. **JD
tie-in:** release evaluations, Tier-3 support, deployment automation, "drafts and maintains
solution documentation for… integrations", "Partner with Information Security".

**Goal:** Operate the integrated platform like a platform engineer — including the failure
mode a normal app never has: **the dependency is down.**

**Deliverables (in `docs/release/` unless noted):**
- `release-runbook.md` / `rollback-runbook.md` / `hotfix-runbook.md` — adapted from todo-app
  for a **two-package** release (install/rollback order: core then banking; dependency
  pinning), each **rehearsed once** and documented against the RTO NFR.
- **`integration-failure-runbook.md` + live drill** — core-banking SaaS unreachable: detect
  (circuit-breaker/logs), degrade gracefully (queue + dead-letter), recover (replay), comms.
  This is the deepened analogue of the todo-app hotfix drill.
- `infosec-signoff.md` — the **InfoSec partnership artifact**: the integration auth pattern,
  secret handling, least-priv integration user, data-classification of what crosses the
  boundary, and a sign-off checklist (enacts "Partner with Information Security
  representatives" + "Manages the core security model… in accordance with information
  security").
- `salesforce-release-readiness.md` — next seasonal release impact, **specifically on the
  integration** (API version, callout/Named Credential changes).
- `deployment-metrics.md` — DORA-style numbers from this project's real history, incl. the
  integration drill's recovery time.
- Release **`v1.0.0`** — full FR set, both packages tagged at compatible versions, CHANGELOG,
  RTM frozen as audit evidence; `post-release-review-v1.0.0.md`.

**Dependencies:** Phases 7–8. **Risks:** runbooks written but never executed — the
integration-failure drill and rollback rehearsal are mandatory acceptance criteria; 2-package
rollback ordering is easy to get wrong — that's why it's rehearsed.

**Acceptance criteria:** `v1.0.0` (both packages) installed in "prod"; rollback + integration-
failure drills executed and documented; InfoSec sign-off artifact complete; metrics populated
from real history; retro written.

---

## Out of Scope / Deferred

- **Consumer #2 (proof of reuse):** have the **todo-app team adopt `frs-platform-core`** (its
  logging/callout framework) — the literal "supporting multiple application teams" line. Best
  next increment after `v1.0.0`; deferred only to keep this project shippable.
- **Data Cloud** (JD "preferred") — study-only; no free playground assumed.
- Financial Services Cloud, real banking rails, Shield encryption enablement, real sandbox
  tiers, Copado/Gearset, load/stress testing, multi-dev SAFe ceremonies.

## Immediate Next Steps

1. **Confirm this plan** (esp. the 6 FRs and the two-package split) before any org/CI/repo/
   Vercel work — the plan is the artifact to review.
2. Phase 1: inherit-and-diff the todo-app governance docs into `docs/governance/`.
3. Decide whether to **reuse the todo-app Dev Hub/"prod" orgs** or stand up fresh ones
   (interactive step only Andy can do), and create the `sf-banking` GitLab project.
4. Confirm the Vercel mock scope (endpoints + failure switch) so Phase 4 can scaffold it.

> **Operating constraints carried from todo-app (still apply):** 6 scratch-org creates/day
> shared across local + CI **and now shared with the todo-app project** — count before
> pushing; main protected = MR-only; SFDX auth URLs base64 in masked CI vars; never reuse
> unverified Thrivent metrics; do not push/merge/deploy/deploy-the-mock unless Andy asks.
