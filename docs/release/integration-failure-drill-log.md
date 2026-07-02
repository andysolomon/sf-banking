# Integration-Failure Drill — Execution Log

> The live execution of `integration-failure-runbook.md` (Phase 9.2). *A runbook is a
> hypothesis until executed* — this is the record that it was.

**Date:** 2026-07-02 · **Org:** the framework-bearing devhub (source deploy of Phases 6–9),
standing in for prod · **Target:** live Vercel mock (`mock-andrewsolomonedus-projects.vercel.app`).

## Method
The framework's `CalloutService` doesn't send the mock's per-request `x-mock-fail` header, and
Vercel wasn't authenticated in this session to flip the global `MOCK_FAIL_MODE` env. So the
outage was induced **Salesforce-side**: the `Core_Banking` Named Credential endpoint was
temporarily repointed to a **non-resolving host** (`https://core-banking-down.invalid`),
producing a real transport error through the framework, then restored to the live mock. This
exercised the actual `CalloutService` → `DeadLetterService` path end to end.

> Note on transactions: Salesforce forbids DML before a callout, so the drill was run as
> discrete anonymous-Apex steps (one callout per transaction) — the same constraint the
> framework's `DeadLetterReplayBatch` (scope 1) already respects.

## Phases & observed results

| Phase | Action | Observed | ✓ |
|---|---|---|---|
| **Detect** | `CalloutService.send()` (POST transfer) with NC → down host | `success=false, transient=true, status=null`, err "Unable to tunnel through proxy… 500" → `DeadLetterService.capture` → `Dead_Letter__c` (New, Attempts 1) | ✅ |
| **Degrade / fail-fast** | 5 recent `Core_Banking` errors in the window, then `isCircuitOpen('Core_Banking')` | **`true`** — breaker open; a subsequent `send()` returns `circuitOpen=true` and skips the HTTP call (also observed *organically* at drill start from accumulated errors) | ✅ |
| **Recover** | Restore NC → mock; clear the error window (core back); `DeadLetterService.replay(dl)` | real callout to the healthy mock → `Dead_Letter__c` **Resolved**, `Replay_Count=1`, a Success `Integration_Log__c` row | ✅ |
| **No double-post** | replay carries the original `Idempotency-Key` | mock returns the same `core_transfer_id`; one transfer, one ledger effect | ✅ |

## MTTR
Mechanical detect→recover in the drill was **~4 minutes** (bounded by the discrete steps).
Real-world MTTR ≈ the **circuit-breaker window (5 min)** for auto-recovery + the replay-batch
cadence — the breaker holds calls off until the endpoint settles, then replay drains the
dead letters.

## Findings / lessons
- **Breaker was already open at drill start** from accumulated `Core_Banking` errors — a real
  signal that the fail-fast path triggers exactly as designed (and that a busy shared org
  accumulates window state; the 5-min window self-heals).
- **DML-before-callout** is the governing constraint for any multi-step recovery — validated
  the scope-1 batch design for bulk replay.
- **Replay is idempotency-safe** — the carried key means re-driving a dead letter cannot
  double-post. This is the safety net behind retries.
- Inducing the outage via the **NC endpoint** (vs the mock's switch) is a clean,
  Salesforce-only drill technique when you can't toggle the external service.

## Cleanup
Drill `Dead_Letter__c` + `Integration_Log__c` rows deleted; `Core_Banking` NC endpoint restored
to the live mock (confirmed by the successful recovery callout).
