# Test & Quality Strategy — Banking App

> The test pyramid for an **integration** application: prove the integration and the
> financial-data security, don't assert them. Failures are simulated *deterministically*
> (mocks), never by depending on a live endpoint failing on command.

## The pyramid

| Layer | Tool | What it covers | Where |
|---|---|---|---|
| **Apex unit (outbound)** | `HttpCalloutMock` | callout success / 5xx / 429 / transport-throw / malformed body; retry, backoff, circuit-breaker, dead-letter, idempotency | `CalloutServiceTest`, `DeadLetterServiceTest`, `TransferServiceTest` |
| **Apex unit (inbound)** | `RestContext` mocks | webhook auth, replay guard, validation, routing → ledger / Case | `WebhookResourceTest` |
| **Apex unit (events/batch)** | `EventBus.publish` + `Test.stopTest`; `Database.executeBatch` | PE subscriber → ledger; reconciliation & interest batches | `TransferCompletedHandlerTest`, `ReconciliationBatchTest`, `StatementInterestBatchTest` |
| **Security** | `System.runAs` + describe/DML | cross-customer isolation, read-only balance FLS, least-priv integration user | `SecurityModelTest` |
| **LWC** | Jest (`sfdx-lwc-jest`) | `bankAccountCard` render + fail-soft | `bankAccountCard.test.js` |
| **E2E** | Playwright vs **installed package + live Vercel mock** | happy path (deterministic mock) + a dedicated **forced-failure** spec asserting the dead-letter path | `e2e/` (Phase 9 wiring; staging-install job) |

## Conventions that keep these tests honest
- **Failure switch = `HttpCalloutMock`**, not the live mock. Automated tests must be
  deterministic; the live `x-mock-fail` switch is for manual drills only (see
  `../release/integration-failure-drills.md`). Playwright uses the mock's deterministic mode;
  the failure switch appears *only* in the dedicated drill spec (kept out of CI happy-path to
  avoid flakiness).
- **Run as the real persona.** Tests `System.runAs` a user holding the actual permission set
  (`Banking_Servicing_Agent` / `Banking_Integration_User` / `Platform_Core_Consumer`) — never
  the org admin — so FLS/CRUD/sharing are exercised the way production hits them. (A test that
  passes only because the admin holds every grant is a false negative; see the build-org
  lessons in `progress.txt`.)
- **Describe-based FLS checks go *inside* `runAs`** — a describe evaluated outside reflects the
  test-running user, not the persona.
- **No callout with DML pending / no loops of callouts** — one callout per transaction; bulk
  replay/reconciliation use Batchable scope 1.
- **Money is integer minor units**; assertions use exact integer values.

## Contract with the core-banking mock
`GET /api/accounts/:id/balance` → `{core_account_id, balance_minor, currency, as_of}`;
`POST /api/transfers` (Idempotency-Key) → `{core_transfer_id, status}`; inbound webhooks POST
`{event_type, ...}` with `X-Webhook-Token` + `X-Event-Id`. The Apex mocks mirror these shapes;
a contract drift would surface in the Playwright run against the live mock.

## Gates (enforced in CI — `ci-templates/salesforce-multipackage-pipeline.yml`)
- **PMD / Code Analyzer** `--severity-threshold 2` (fail on High+).
- **Coverage ≥ 85%** org-wide (`SF_COVERAGE_MIN`, `test "$COVERAGE" -ge ...`). Current: **93%**.
- LWC Jest must pass. Package version build runs Apex with coverage too.

## Current state
77 local Apex tests + LWC Jest, **100% pass, 93% org-wide coverage** on devhub. Every FR/NFR
maps to a test in `../requirements/rtm.md` (Test column).
