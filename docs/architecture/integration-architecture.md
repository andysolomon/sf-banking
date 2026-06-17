# Integration Architecture — Banking App (project #2)

> **Exercises:** Salesforce integration patterns, outbound call options, error handling &
> resilience, integration security. **JD lines:** "Must have experience in Salesforce
> Integration patterns"; "Creates Integrations and/or Connectors between Salesforce.com
> and FRS and other 3rd party applications"; "engineering solutions across… cloud and SaaS
> environments." **RTM design coverage:** FR-1, FR-2, FR-3, FR-4, FR-5, NFR-2, NFR-3, NFR-6.
> Grounded in the integration study guide's "fast answer template": *classify the
> integration → classify the data → choose the pattern → choose the API + auth primitive →
> require monitoring + idempotency + retry/dead-letter + resync.*

## The heterogeneous landscape

Salesforce (servicing/CRM) ↔ **`frs-core-banking-mock` on Vercel** (the external core-
banking SaaS / "FRS system"). Bidirectional, with a failure-injection switch so resilience
paths can be drilled for real (Phase 7/9).

## Pattern selection (requirement → pattern → mechanism)

| Flow | Pattern | Mechanism | Why |
|---|---|---|---|
| FR-1 balance read | **Request–Reply** | synchronous Apex REST callout via Named Credential | user needs an immediate answer; bounded by callout timeout + circuit-breaker |
| FR-2 transfer | **Request–Reply, executed async** | Queueable + REST callout w/ idempotency key | money movement must survive retries and not block the user or hit callout-in-trigger limits |
| FR-3 posted-txn | **Remote Call-In** | inbound `@RestResource` | core banking is the initiator; SF records the ledger entry |
| FR-4 fraud alert | **Remote Call-In** | inbound `@RestResource` | external event → SF Case |
| FR-5 transfer completed | **Fire-and-Forget** | **Platform Event** `Transfer_Completed__e` | loose coupling; subscribers (ledger/notify) react independently, replayable |

## Outbound: the callout framework (`frs-platform-core`)

Consumers call `CalloutService`, never raw `Http`. It provides:
- **Named Credential abstraction** — consumer passes an alias + path + body; never sees the
  endpoint or secret (NFR-5).
- **Idempotency** — caller supplies/derives an `Idempotency-Key`; safe to retry (NFR-2).
- **Retry + exponential backoff** — transient failures (timeout, 5xx) retried via Queueable
  chaining; bounded budget (NFR-3).
- **Circuit-breaker** — reads recent failure rate from `Integration_Log__c`; when tripped,
  **fail closed** instead of hammering a down dependency (NFR-6).
- **Structured logging** — `Integration_Log__c` with a correlation id and **redacted**
  payload (data-classification).
- **Dead-letter on exhaustion** — `Dead_Letter__c` row with replay entry point (NFR-3).

**Rule:** no synchronous callout inside a trigger — the framework enforces async (NFR-6).

## Inbound: the call-in endpoints

`@RestResource` endpoints for posted-transaction (FR-3) and fraud-alert (FR-4):
- **AuthN** — Connected App / OAuth (JWT bearer or client-credentials) or a verified signed
  payload; runs as the least-privilege `Banking_Integration_User`.
- **Validation** — schema + required fields; reject malformed (400).
- **Replay protection / idempotency** — dedupe on `External_Txn_Id__c` (unique) / alert id;
  a replayed call is a no-op success (NFR-2).

## Platform Events vs CDC (the trade-off)

| | Platform Event (`Transfer_Completed__e`) | Change Data Capture |
|---|---|---|
| Semantics | a **business event** we choose to publish | a **data change** on an object |
| Control | explicit payload, versioned | automatic, schema-shaped |
| Use here | **chosen** for transfer-completion (it's a domain event, not "a row changed") | noted as the alternative if we needed raw row-change propagation |

Subscribers must track **replay id** and handle gaps/resync — noted for the ledger subscriber.

## Error taxonomy (drives handling)

| Class | Example | Handling |
|---|---|---|
| Retryable | timeout, 5xx, connection reset | retry w/ backoff → dead-letter on exhaustion |
| Validation | 400, business reject | fail fast → `Transfer__c` Failed, surface reason |
| Auth | 401/403 | fail closed, alert (config/secret problem) |
| Limit | 429 / governor | backoff/honor Retry-After; circuit-breaker |
| Conflict | duplicate idempotency key | treat as success-replay (no double-post) |

## Monitoring & reconciliation

`Integration_Log__c` (per-callout) + Platform Event delivery + the **daily reconciliation**
job (SF ledger vs core-banking balances, NFR-7) = the safety net *behind* idempotency and
retries. Mismatches raise an alert/Case.
