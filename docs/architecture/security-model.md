# Security Model — Banking App (project #2)

> **Exercises:** sharing/security model, least-privilege access design, secure coding.
> **JD lines:** "Must have experience in Salesforce security Model"; "design least-
> privilege, scalable access models"; "Manages the core security model… in accordance
> with information security." **RTM design coverage:** NFR-1, NFR-4, NFR-5.

## Org-wide defaults (OWD)

| Object | OWD | Why |
|---|---|---|
| `Bank_Account__c` | **Private** | financial data; visibility only via sharing |
| `Transaction__c` | **Controlled by parent** | inherits Bank_Account__c |
| `Transfer__c` | **Private** | money movement; owner/role scoped |
| `Integration_Log__c`, `Dead_Letter__c` | **Private** | ops-only; not customer-facing |

## Permission sets (least privilege; zero grants on profiles)

| Perm set | Grants | For |
|---|---|---|
| `Banking_Servicing_Agent` | R/U on Bank_Account__c (no balance edit), R on Transaction__c, C/R on Transfer__c + Case; run servicing flows | human servicing users |
| `Banking_Integration_User` | **Minimal**: C on Transaction__c (via External_Txn_Id__c), C on Case (fraud), R on Bank_Account__c by Core_Account_Id__c — **nothing else** | the inbound webhook execution context |
| `Platform_Core_Consumer` | access to logging/callout framework Apex (no secrets) | apps consuming frs-platform-core |

**FLS:** balance/number fields (`Balance_Minor__c`, `Account_Number__c`) are read-only
to agents and **not granted at all** to the integration user beyond what FR-3 needs.
Account number is **masked** on display.

## Sharing

- Agents see accounts via role hierarchy / a sharing rule tied to a servicing book; a
  customer (if ever portal-exposed) sees only their own (`Customer__c = current user's
  contact`). Cross-customer access is impossible — enforced **server-side in the query**
  (`WITH USER_MODE` / `WHERE` scoping), not the UI (NFR-4).
- All user-facing Apex is `with sharing` + CRUD/FLS enforced.

## The integration user (inbound) — the least-privilege story

Inbound webhooks (FR-3/FR-4) execute as a dedicated **integration user/context** holding
only `Banking_Integration_User`. It can create a `Transaction__c` or fraud `Case` and
resolve an account by `Core_Account_Id__c` — and **cannot** read balances, edit accounts,
or see other objects. This is the JD's "least-privilege access model" made concrete and is
a primary InfoSec sign-off item (Phase 9).

## Access matrix

| Actor | Bank_Account__c | Transaction__c | Transfer__c | Case | Logs/Dead-letter |
|---|---|---|---|---|---|
| Servicing agent | R, U (no balance) | R | C, R | C, R | — |
| Integration user (inbound) | R (by core id) | **C only** | — | C (fraud) | — (framework writes) |
| Customer (future portal) | R own | R own | — | R own | — |
| Admin/ops | full | R | R | R | R |

## Secret handling (NFR-5)

No secrets in source/metadata/logs. Outbound endpoints + credentials via **Named
Credentials / External Credentials** only; CI auth via masked variables. Logs redact
payloads/PII. Enforced by DoD + Code Analyzer + a grep-for-secrets CI check; reviewed in
the InfoSec sign-off. Encryption-at-rest for the most sensitive fields → Shield Platform
Encryption *candidates* listed in `data-classification.md` (documented, not enabled — not
free-tier).

## Enforcement → verification map

| Control | Enforced by | Verified by |
|---|---|---|
| OWD Private + sharing | org config | `runAs` cross-customer negative tests (Phases 5–8) |
| FLS on balances | perm sets | FLS-enforcement Apex tests |
| Least-priv integration user | `Banking_Integration_User` | inbound test asserting it cannot read balances/other objects |
| No secrets in source | Named Credentials | review checklist + grep-for-secrets CI + analyzer |
| with-sharing + USER_MODE | code | analyzer security rules; review |
