# Release Runbook — Banking App (two-package)

> How to cut a release of the `frs-platform-core` ← `frs-banking` package pair through the
> pipeline. Adapted from the todo-app single-package runbook; the new element is **two
> packages with a dependency**, so **order and version compatibility are load-bearing**.

## Golden rules
1. **Install order is core → banking, always.** `frs-banking` declares a dependency on
   `frs-platform-core` (`sfdx-project.json`); installing banking first fails.
2. **Compatible versions ship together.** A release is a *pair* of SubscriberPackageVersionIds
   (core + banking) verified together in staging-install. Never mix a banking version against
   an untested core version.
3. **Pipeline is the only writer to prod** (NFR-8). Break-glass CLI install only when CI is
   unavailable (out of compute minutes) and only with explicit human authorization, recorded
   in the CHANGELOG per `drift-policy.md`.

## Procedure
1. **Branch & MR** — feature branch → MR to `main`. Pipeline runs: scan (PMD High gate) →
   lwc-test → apex-test (RunLocalTests, coverage ≥ 85%).
2. **Merge** → `main` pipeline runs `package` (builds BOTH versions, core then banking; emits
   `CORE_SPV_ID` / `APP_SPV_ID` via dotenv) → `staging-install` (fresh scratch: install core →
   banking → assign perm sets) → **`prod-install` (manual gate)**.
3. **Pre-prod check** (Release-Manager hat): staging-install green? scan green? coverage ≥ 85%?
   CHANGELOG updated? RTM current? Then play `prod-install`.
4. **`prod-install`** installs core → banking into prod. No scratch cost.
5. **Post-install** (documented human surface, not drift): assign perm sets
   (`Banking_Servicing_Agent`, `Banking_Integration_User`, `Platform_Core_Consumer`);
   configure the **Named Credential** `Core_Banking` (per `../devops/named-credential-setup.md`)
   and the **webhook secret** (`Webhook_Config__c.Shared_Secret__c`) — both per-org, never packaged.
6. **Tag** `vX.Y.Z` on the merge commit; record both package versions in the CHANGELOG.
7. **Smoke** — run `smoke-test-vX.Y.Z.md` against prod (live NC→mock callout; webhook auth).
8. **Close** — RTM status → verified for the shipped rows; write `post-release-review-vX.Y.Z.md`.

## Budget note (free-tier)
`apex-test` + `staging-install` each create one scratch org (shared DailyScratchOrgs across
projects). Confirm ≥ 2 creates available before merging; `package` uses the separate
Package2VersionCreates quota. Out of GitLab CI minutes ⇒ pipeline can't run ⇒ break-glass path.

## Rollback / hotfix
See `rollback-runbook.md` (two-package downgrade order = reverse) and `hotfix-runbook.md`.
