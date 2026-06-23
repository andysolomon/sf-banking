# Changelog — Banking App (project #2)

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

### Post-install steps still owed (per docs/release/release + named-credential-setup)
- Configure Named Credential **Core_Banking** → the mock's stable production URL (ADR-004).
- Run `docs/release/smoke-test-v0.1.0.md` against prodtest.
