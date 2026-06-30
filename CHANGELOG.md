# Changelog — Banking App (project #2)

## [0.2.1] — 2026-06-30 — Phases 6–9 (RELEASED via GitHub Actions)

Package versions: `frs-platform-core` 0.2.1 (04tgK000000E1nRQAS) → `frs-banking` 0.2.1
(04tgK000000E1p3QAC). Tag `v0.2.1`. First release through the **GitHub Actions** pipeline,
installed into the lab org `arc-devhub-banking-system` (devhub-as-prod).

### frs-platform-core (the reusable platform — Phase 6)
- **Logger** + `Integration_Log__c` (Category/Message/Retry_Count) with payload-safe redaction.
- **CalloutService** matured: typed `CalloutRequest`/`CalloutResult`, `send()`, circuit-breaker,
  Idempotency-Key, async retry + exponential backoff (`CalloutRetryQueueable`), dead-letter on
  exhaustion. `httpGet(path, corr)` **kept returning `HttpResponse`** for backward compatibility.
- **Dead_Letter__c** + `DeadLetterService` (replay) + `DeadLetterReplayBatch` (scope 1).
- **PlatformEvents** publisher + generic `Integration_Event__e`. Consumer `README.md`.

### frs-banking (integration features — Phase 7)
- FR-2 Transfer (idempotent, async, dead-letter on failure); FR-3/4 inbound webhooks
  (`WebhookResource`: auth + replay guard → `Transaction__c` / `Case`); FR-5
  `Transfer_Completed__e` subscriber → ledger; FR-6 dispute Flow; reconciliation + interest batches.
- New least-privilege `Banking_Integration_User` permission set.

### Quality, security & ops (Phases 8–9)
- `SecurityModelTest` (isolation, read-only balance FLS, least-priv integration user); full suite
  **82 tests, 93% coverage**. RTM test column complete. test-strategy + release/rollback/hotfix +
  integration-failure runbooks + InfoSec sign-off + DORA metrics.

### Platform / release
- **Migrated GitLab → GitHub**; pipeline ported to GitHub Actions (`.github/workflows/salesforce.yml`):
  PR gate (scan/lwc/apex≥85%) → push-to-main release (package → staging-install → prod-install
  gated on the `production` Environment).
- **Fixed a 2GP breaking-change** that blocked the in-place upgrade: Phase 6 had changed
  `CalloutService.httpGet`'s return type; restored it to `HttpResponse` (new code uses `send()`),
  so the resident v0.1.0 recompiles cleanly on upgrade. *(Lesson: never change a public method's
  signature in a base package others depend on — add a new method.)*

## [0.1.0] — 2026-06-23 — Phase 5 walking skeleton (RELEASED to prodtest)

Package versions: `frs-platform-core` 0.1.0.2 (04tgK000000DvlFQAS) → `frs-banking`
0.1.0.2 (04tgK000000DvoTQAS). Tag `v0.1.0` on main @ 3917fb2.

Thinnest integrated slice: a `Bank_Account__c`'s **live balance** fetched from the
external core-banking mock via a Named Credential.

### frs-platform-core
- `CalloutService` — generic Named-Credential GET + structured logging
- `Integration_Log__c` — correlation id / direction / status / endpoint alias

### frs-banking
- `Bank_Account__c` (+ Customer, Core_Account_Id, Type, Balance_Minor, Balance_As_Of, Status)
- `BankAccountController.getLiveBalance` — live balance via callout, FLS-enforced, fail-soft
- `bankAccountCard` LWC — renders balance, fail-soft "temporarily unavailable", Refresh
- `Banking_Servicing_Agent` permission set (least-privilege; read-only on financial fields)

### Tests
- `CalloutServiceTest` (success / error-status / thrown), `BankAccountControllerTest`
  (success / core-down), `bankAccountCard` Jest (render + fail-soft)

### Integration config
- Named Credential **Core_Banking** = post-install setup (no secrets in source) — see
  `docs/devops/named-credential-setup.md` and ADR-004.

### Release mechanics (break-glass — managed change, not drift)
- CI/CD pipeline (MR !1 → main pipeline 2622737437) gated all green: scan, lwc-test,
  apex-test (7/7, 95% org-wide coverage), package (both 2GP versions), staging-install
  (core→app in a fresh scratch org).
- **Prod install via documented break-glass CLI**, not the pipeline: the manual
  `prod-install` job failed `ci_quota_exceeded` (GitLab namespace out of compute
  minutes). Per `docs/release/drift-policy.md` break-glass cycle, installed the
  **same pipeline-built artifacts** directly with `sf package install --target-org prod`
  (core→app), authorized by Andy. Reconciles to source — not silent drift.
- **Prerequisite:** uninstalled the `platform-enablement` sibling's `frs-platform`
  0.2.0.1 (04tgK000000DvN3QAK) from prodtest first — both packages are namespace-less
  and define `CalloutService`, so they cannot coexist in one org. That version is
  reinstallable; `platform-enablement` source/package untouched.

### Post-install — DONE 2026-06-23
- Named Credential **Core_Banking** deployed to prodtest (legacy no-auth: `NoAuthentication`
  / `Anonymous`) → stable production URL `https://mock-andrewsolomonedus-projects.vercel.app`
  (ADR-004; no secret in source).
- Smoke test (`docs/release/smoke-test-v0.1.0.md`) — API checks PASS in prodtest: live
  NC→mock callout HTTP 200, balance $1,323.19; `Integration_Log__c` Success/Outbound,
  alias-only; mock fail switch `x-mock-fail:500`→500 confirmed; no endpoint/secret in
  installed source. RTM FR-1 / NFR-5 / NFR-6 → **verified**.
- Remaining = Andy's UI sign-off only: add `bankAccountCard` to the `Bank_Account__c`
  record page, confirm live render + the fail-soft "temporarily unavailable" on mock-fail.
