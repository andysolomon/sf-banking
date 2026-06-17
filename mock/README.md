# frs-core-banking-mock

A **mock core-banking SaaS** for the banking-app integration lab — the external "FRS
system" Salesforce integrates with. Zero-dependency Vercel serverless functions
(`api/`), **stateless** (deterministic responses), **bidirectional**, with a **failure
switch** so the SF retry / circuit-breaker / dead-letter / reconciliation paths can be
drilled for real (plan Phase 7/9).

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/accounts/:id/balance` | Live balance (FR-1). Deterministic from the id. |
| POST | `/api/transfers` | Execute a transfer (FR-2). Honors `Idempotency-Key`. |
| POST | `/api/webhooks/send` | INBOUND: push a `posted_transaction` / `fraud_alert` event to a SF Apex REST endpoint (FR-3/FR-4). |

### Idempotency (outbound, stateless)
`/api/transfers` derives `core_transfer_id` from the `Idempotency-Key` header, so the
**same key always returns the same id** — simulating core-side idempotency without storage.
SF-side dedupe (`Transfer__c.Idempotency_Key__c` unique) is the primary guard; this makes
the mock behave correctly under retries too.

### Failure switch (drills)
Send header **`x-mock-fail`** (or set env **`MOCK_FAIL_MODE`**) on balance/transfers:
- `500` → server error → drills SF retry → dead-letter
- `timeout` → bounded delay (`MOCK_DELAY_MS`, default 8000ms; `maxDuration` 15s in
  `vercel.json`) → set the SF callout timeout *below* this to drill the timeout path
- `422` → insufficient funds (also when `amount_minor > 100000000`)

## Local run / deploy
```bash
# local (Vercel CLI):  vercel dev      → http://localhost:3000
# deploy:              ../scripts/deploy-mock.sh   (wraps `vercel --prod`)
```
Deploying requires `vercel login` (interactive — Andy). The deployed base URL becomes the
**Named Credential** target in Salesforce (ADR-004); never hard-code it in Apex.

## Example
```bash
curl -s "$BASE/api/accounts/abc/balance"
curl -s -XPOST "$BASE/api/transfers" -H 'content-type: application/json' \
  -H 'idempotency-key: k1' -d '{"from_account_number":"1","to_account_number":"2","amount_minor":2500}'
curl -s -XPOST "$BASE/api/transfers" -H 'x-mock-fail: 500' -d '{"amount_minor":2500}'  # drill
```
