# InfoSec Sign-Off — Banking App Integration

> The Information-Security partnership artifact: what crosses the trust boundary, how it's
> protected, and the sign-off checklist a security reviewer signs before a production release.
> Enacts the JD's "Partner with Information Security representatives" and "Manages the core
> security model in accordance with information security."

## 1. Trust boundary & data classification
The boundary is **Salesforce ⇄ core-banking SaaS** (the Vercel mock stands in). What crosses it,
classified per `../requirements/data-classification.md`:

| Data | Direction | Classification | Control |
|---|---|---|---|
| Account balance (minor units) | inbound (read) | **Confidential** financial | Named Credential endpoint; never persisted with PII; `Balance_Minor__c` read-only FLS |
| Transfer instruction (amount, to-account) | outbound | **Confidential** | Idempotency-Key; payload redacted in logs/dead-letters |
| Posted transaction | inbound (webhook) | **Confidential** | shared-secret auth + replay guard |
| Fraud alert | inbound (webhook) | **Restricted** | auth + → Case (no raw PII stored; `detail` redacted) |
| Correlation / endpoint alias | logs | Internal | alias only — **never** URL/secret/PII (`Logger.redact`) |

## 2. Controls (with evidence)
| Control | Implementation | Proof |
|---|---|---|
| **No secret in source** (NFR-5) | endpoints/secrets in Named Credential + `Webhook_Config__c` (post-install), Apex uses `callout:Core_Banking` | prodtest smoke (alias-only log); grep of installed source |
| **Outbound auth** | Named/External Credential (ADR-004); per-org, not packaged | `named-credential-setup.md` |
| **Inbound auth** | shared-secret `X-Webhook-Token` vs `Webhook_Config__c` | `WebhookResourceTest.auth_badToken_401` |
| **Replay protection** | unique `Webhook_Event__c.Event_Id__c`; unique `External_Txn_Id__c` | `WebhookResourceTest.replay_*` |
| **Idempotency** (no double-post) | unique `Transfer__c.Idempotency_Key__c` + Idempotency-Key header | `TransferServiceTest.initiate_idempotent` |
| **Least-privilege integration user** (NFR-1) | `Banking_Integration_User`: ledger/Case/event only — no balance, no transfers | `SecurityModelTest.integrationUser_isLeastPrivilege` |
| **Tenant isolation** | OWD Private; sharing; `WITH USER_MODE` | `SecurityModelTest.isolation_*` |
| **Balance integrity** | `Balance_Minor__c` read-only to all interactive personas (core-owned) | `SecurityModelTest.balance*` |
| **Audit trail** | `Integration_Log__c` every call (redacted), immutable ledger | `NFR-7` row in RTM |
| **Payload redaction** | `Logger.redact` masks digit runs + token/secret/bearer | `LoggerTest.redact_*` |
| **Resilience / no data loss** | retry + dead-letter + replay; reconciliation | `integration-failure-runbook.md` |

## 3. Residual risks
- Mock uses a **no-auth** Named Credential for the lab; **production must use a real
  External Credential (key/OAuth)** — tracked, must be closed before real go-live.
- Webhook auth is a shared secret (symmetric); a signed-HMAC upgrade is the next hardening step.
- Field-history/Shield encryption on `Balance_Minor__c` deferred (data-classification notes it).

## 4. Sign-off checklist (reviewer ticks before each prod release)
- [ ] No endpoint/secret in the package (grep installed source)
- [ ] Named Credential + webhook secret configured per-org, not in source
- [ ] Least-priv integration user assigned (not an admin) for inbound
- [ ] `SecurityModelTest` + `WebhookResourceTest` green in the release pipeline
- [ ] Data-classification unchanged, or re-reviewed if a new field crosses the boundary
- [ ] Residual-risk register reviewed; no new High without mitigation

**InfoSec reviewer:** ______________________  **Date:** __________  **Release:** __________
