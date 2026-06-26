# Integration Failure Drills (Phase 7.5)

> Mandatory drills for the integration platform. Each failure mode is **executed and recorded**
> — proven deterministically by the Apex test suite (which simulates the core-banking failure
> switch via `HttpCalloutMock`, the only reliable way to drill failures in automated tests),
> and the **live** Vercel mock failure switch (`x-mock-fail` header / `MOCK_FAIL_MODE`) is
> confirmed working for manual exploratory runs.
>
> Principle: *a runbook is a hypothesis until executed.* These drills turn the framework's
> claimed resilience (retry / dead-letter / idempotency / replay protection) into evidence.

| # | Failure mode | Expected behaviour | Automated proof (test) | Result |
|---|---|---|---|---|
| 1 | Core **timeout / transient**, then recovers | callout retried (backoff), **succeeds on retry**, no dead-letter | `CalloutServiceTest.sendWithRetry_succeedsOnRetry_noDeadLetter` (mock 500-then-200) | ✅ PASS |
| 2 | Core **HTTP 500**, never recovers | retries **exhaust** → **dead-letter** captured → **replay** re-drives | `CalloutServiceTest.sendWithRetry_exhausts_deadLetters` + `DeadLetterServiceTest.replayPending_success_marksResolved`; transfer path: `TransferServiceTest.transfer_transientFailure_failsAndDeadLetters` | ✅ PASS |
| 3 | **Duplicate transfer** (double-submit) | idempotency key blocks the second post; one Transfer, one core call | `TransferServiceTest.initiate_idempotent_noDoublePost` | ✅ PASS |
| 4 | **Webhook replay** (same event re-delivered) | replay guard rejects reprocessing (200, no duplicate ledger row) | `WebhookResourceTest.replay_sameEventId_200_idempotent` | ✅ PASS |

## How each is wired (the mechanism under test)
1. **Timeout/transient → retry:** `CalloutService.sendWithRetry` → `CalloutRetryQueueable`
   (exponential backoff, cap 10 min). `CalloutResult.isTransient()` gates what retries (5xx /
   429 / transport error), so a 4xx is *not* retried.
2. **Exhaustion → dead-letter → replay:** on the last failed attempt, `DeadLetterService.capture`
   writes a `Dead_Letter__c` (redacted payload + error). `DeadLetterReplayBatch` (scope 1, one
   callout/txn) re-drives them; the carried Idempotency-Key makes replay safe.
3. **Duplicate transfer:** `Transfer__c.Idempotency_Key__c` is **unique** (DB backstop) and
   `TransferService.initiate` pre-checks it — a repeat returns the original transfer.
4. **Webhook replay:** `WebhookResource` records `X-Event-Id` in `Webhook_Event__c` (**unique**)
   before processing; a re-delivery fails that insert and is acknowledged (200) without effect.

## Live drill procedure (manual, against the Vercel mock)
The mock's failure switch is confirmed live:
```
curl -s -o /dev/null -w "%{http_code}\n" -H "x-mock-fail: 500" \
  https://mock-andrewsolomonedus-projects.vercel.app/api/accounts/abc/balance     # → 500
```
For an end-to-end live drill (e.g. balance fail-soft), set the mock to global fail
(`MOCK_FAIL_MODE=500` env + redeploy), exercise the LWC/anon-apex path, observe the
`Integration_Log__c` Error row + fail-soft UI, then revert. Recorded per release in the
matching `smoke-test-vX.Y.Z.md`.

## Drift recovery (the safety net behind all of the above)
`ReconciliationBatch` runs nightly: any SF-ledger vs core-balance mismatch that slips through
retries/idempotency raises a `Case` for a human — the last line of defence (NFR-7).
