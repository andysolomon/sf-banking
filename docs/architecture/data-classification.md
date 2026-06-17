# Data Classification — Banking App (project #2)

> **Exercises:** integration data classification (confidential/secure/public), security &
> compliance. **JD lines:** "Familiarity with common compliance frameworks"; "Partner
> with Information Security representatives." **RTM design coverage:** NFR-1, NFR-5.
> Source: the integration study guide's "classify the data before you design the flow."

Classify **every field that crosses the SF ↔ core-banking boundary** before designing the
integration. Classification drives transport, storage, masking, logging, and encryption.

## Tiers

| Tier | Meaning | Handling |
|---|---|---|
| **Public** | No harm if disclosed | none special |
| **Internal** | Internal-only, low sensitivity | standard access controls |
| **Confidential** | Customer financial/PII | FLS + masking; redact in logs; encryption candidate |
| **Restricted** | High-harm (full account #, credentials) | least-priv only; never logged; Shield-encryption candidate; never in source |

## Field classification

| Field / datum | Tier | Crosses boundary? | Controls |
|---|---|---|---|
| `Account_Number__c` (full) | **Restricted** | yes (inbound/outbound) | masked on display; never logged; Shield candidate |
| `Core_Account_Id__c` | Confidential | yes | external-id; not user-displayed; redact in logs |
| `Balance_Minor__c` | Confidential | yes (outbound fetch) | FLS read-only to agents; redact in logs |
| Customer name / contact | Confidential (PII) | yes (some flows) | FLS; residency/retention apply |
| `Amount_Minor__c`, `Direction__c` | Confidential | yes | redact amounts in logs (or log ranges) |
| `Idempotency_Key__c`, `External_Txn_Id__c` | Internal | yes (headers/body) | not sensitive; safe to log for correlation |
| `Correlation_Id__c` | Internal | n/a | safe to log (the join key for tracing) |
| Named Credential secret / API key | **Restricted** | n/a (never in payload) | Named/External Credential only; never in source/logs/metadata |

## Logging rule (NFR-5)

`Integration_Log__c.Payload_Redacted__c` stores a **redacted** payload: correlation id +
idempotency key + status are kept; account numbers, balances, amounts, and PII are masked
or dropped. The redaction helper lives in `frs-platform-core` so every consumer logs safely
by default.

## Residency / retention / compliance (documented intent)

- **Residency:** financial PII assumed US-only (Fed/FRS context); no cross-region export
  in scope.
- **Retention:** ledger retained per policy (long); logs/dead-letter retained ~90 days
  then purged by a scheduled batch.
- **Shield Platform Encryption** candidates: `Account_Number__c` (Restricted), optionally
  `Balance_Minor__c`. Documented as the control; **not enabled** (not free-tier) — the
  architecture-relevant artifact for the InfoSec partnership (Phase 9).
