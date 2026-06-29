# Integration-Failure Runbook — Core-Banking Unreachable

> The failure mode a normal Salesforce app never has: **the dependency is down.** This is the
> deepened analogue of the todo-app hotfix drill — operate the integration when core-banking
> is slow, erroring, or gone. Detect → degrade → recover → communicate.

## 1. Detect
Signals, fastest first:
- **Circuit breaker trips** — `CalloutService.isCircuitOpen` opens after ≥ 5 errors in 5 min
  for an endpoint; subsequent calls return `circuitOpen=true` (fail fast, no HTTP). Balance
  reads show "temporarily unavailable" immediately.
- **`Integration_Log__c`** — a spike of `Status=Error`, `Direction=Outbound` rows for the
  `Core_Banking%` alias (query/dashboard).
- **`Dead_Letter__c`** — new rows accumulating (`Status=New`) = transfers that exhausted retries.
- **Reconciliation** — `ReconciliationBatch` raising mismatch Cases (slower signal).

## 2. Degrade gracefully (automatic — verify, don't fix)
The framework already does the right thing; the operator's job is to confirm it:
- **Reads (FR-1 balance):** fail-soft — the LWC shows "temporarily unavailable," no error page,
  no retry storm (the breaker suppresses calls).
- **Writes (FR-2 transfer):** the async callout marks the transfer `Failed` and **dead-letters**
  it (recoverable), or — if transient — retries with backoff. Money is **never** double-posted:
  the Idempotency-Key makes every retry/replay safe.
- **Inbound (webhooks):** unaffected by an *outbound* outage; the replay guard still dedupes.

## 3. Recover (when core is back)
1. Confirm core health: a single manual `CalloutService.httpGet('Core_Banking/api/accounts/<id>/balance', 'health')`
   returns 200, and the breaker window has aged out (5 min of no new errors).
2. **Replay the dead letters:** `DeadLetterService.replayPending(n)` → runs `DeadLetterReplayBatch`
   (scope 1, one callout/txn). Each carries its original Idempotency-Key, so replay cannot
   double-post. Letters move `New → Resolved` (or `Failed`, leave for the next pass).
3. **Reconcile:** run `ReconciliationBatch` to confirm SF ledger == core balances; resolve any
   mismatch Cases.

## 4. Communicate
- Status note to servicing agents: "core-banking degraded HH:MM–HH:MM; balances were stale,
  transfers queued and are settling; no action needed."
- If any transfer stayed `Failed` after replay → Tier-3 ticket per the dead letter's
  correlation id (it ties to the `Integration_Log__c` trail).

## 5. The drill (mandatory acceptance — "a runbook is a hypothesis until executed")
Executed against the **live Vercel mock** failure switch:
1. Set the mock to fail (`MOCK_FAIL_MODE=500` / `x-mock-fail: 500`).
2. Initiate transfers → observe `Failed` + `Dead_Letter__c` rows + the Error `Integration_Log__c`
   trail; confirm balance reads fail-soft and the breaker opens.
3. Clear the mock → `DeadLetterService.replayPending` → confirm letters `Resolved` and no
   double-post (one `core_transfer_id` per transfer).
4. Record detect→recover wall-clock here as the integration MTTR.

> **Drill log:** _pending live execution (devhub + live mock); record MTTR + any corrected
> assumption here. The behaviour is already proven deterministically in
> `integration-failure-drills.md` (HttpCalloutMock); this live run is the operational proof._
