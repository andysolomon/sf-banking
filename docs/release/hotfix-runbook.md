# Hotfix Runbook — Banking App (two-package)

> Ship a Tier-3 fix to prod fast, safely, through the gate. Inherits the todo-app hotfix drill
> lessons — the big one: **`hotfix/*` must be a protected ref** or the protected prod auth var
> is withheld and `prod-install` fails `INVALID_SFDX_AUTH_URL`. (main + `hotfix/*` are protected.)

## Decide which package
- Fix is in the **framework** (logging, callout, dead-letter, events) → patch `frs-platform-core`,
  bump its version. Banking consumers pick it up on their next install (or install the new core).
- Fix is in **banking** (transfer, webhook, flow) → patch `frs-banking` only.
- **Prefer the smallest package.** Only rev core if the defect is in core; revving core forces a
  compatibility re-check of banking.

## Procedure
1. Branch `hotfix/<ticket>` off `main` (protected ref → prod auth var available at deploy).
2. Fix + a regression test that fails-then-passes. Keep scope minimal.
3. MR → pipeline (scan / lwc / apex ≥ 85%). Merge.
4. `package` builds the bumped version(s); `staging-install` verifies the pair; play
   `prod-install` (manual gate).
5. Tag `vX.Y.Z` (patch); CHANGELOG `### Fixed`; smoke; back-merge `hotfix/*` → any active release branch.

## Two-package gotcha
If the hotfix is in core, the prod org now has new-core + old-banking — only valid if old-banking's
dependency allows new-core (patch bumps do). For a minor/major core change, rev banking too and
ship the **pair**. The pipeline's staging-install is the compatibility check — never skip it on a hotfix.

## RTO
Target ~15 min mechanical (todo-app drill: 1GP-style hotfix ~15 min mechanical / ~60 min total
incl. validation). Rehearse with the rollback drill.

> **Drill log:** _pending — execute a real Tier-3 hotfix once and record the gap it exposes
> (the todo-app drill's value was finding the unprotected-ref credential gap)._
