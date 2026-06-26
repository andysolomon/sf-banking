# Deployment Metrics (DORA) — Banking App

> DORA-style numbers from this project's **real** history. Honest over flattering — where a
> number is pending (the integration drill MTTR, v1.0.0), it says so.

## The four keys
| Metric | Value | Source / notes |
|---|---|---|
| **Deployment frequency** | 1 prod release so far (**v0.1.0**, 2026-06-23); v0.2.0 + v1.0.0 pending CI-minute reset | tags on `main` |
| **Lead time for change** | walking skeleton: design → prod in ~6 days (2026-06-17 staged → 06-23 released), incl. the CI shakeout; Phases 6–8 built in 2 days (06-25/26) on branch, ready to ship as v0.2.0 | git history |
| **Change failure rate** | 0 prod incidents on v0.1.0. Pre-prod, the pipeline caught **7+ defects before they shipped**: 3 first-compile (reserved word, forceignore, FLS), 4 CI (scan, login-stdin, node:22-await, budget), + the dead-letter loop bug | the gates did their job — failures caught left of prod |
| **MTTR** | rollback: in-place pair-downgrade target < 15 min (single-pkg rehearsed at ~17s on todo-app). **Integration MTTR: pending the live drill** (`integration-failure-runbook.md`) | rehearsal logs |

## What the numbers say
- **Quality is gate-driven, not heroic.** Almost every defect was caught by a gate (compile,
  scan, coverage, staging-install) or the free devhub validation loop — not in prod. The CI
  shakeout (4 bugs over 4 pushes) is the system working: each red revealed the next.
- **Two-package adds release surface** (build + install order, compatibility) but the pipeline
  absorbs it — `staging-install` is the compatibility gate.
- **The free-tier constraints are real DORA inputs:** shared DailyScratchOrgs and finite GitLab
  CI minutes gate deploy frequency more than code readiness does. Documented, not hidden.

## Test & coverage (current, devhub)
- **82 Apex tests + LWC Jest, 100% pass, 93% org-wide coverage** (gate ≥ 85%).
- Security provable (`SecurityModelTest`), integration resilience provable
  (`CalloutServiceTest` / `DeadLetterServiceTest` / drills).

## To populate at v1.0.0
- Number of prod releases + dates; integration-drill MTTR from the live run; final
  change-failure tally. Freeze into `post-release-review-v1.0.0.md`.
