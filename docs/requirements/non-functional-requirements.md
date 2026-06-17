# Non-Functional Requirements — Banking App (project #2)

> **Exercises:** planning-environment-risks (risk-driven NFRs), building-quality-code,
> testing-execution-and-coverage, integration security/resilience. **JD lines:**
> "least-privilege, scalable access models"; "Salesforce Integration patterns"; "secure
> coding"; "Partner with Information Security."

Every NFR has a measurable target and a named verification method — if it can't fail a
check, it isn't a requirement. The deepened areas (idempotency, resilience, isolation,
secrets, SLA) are the heart of project #2.

## NFR-1 — Security & least privilege (financial data)

**Target:** All access flows through least-privilege permission sets; zero object/field
grants on profiles. OWD for `Bank_Account__c` and `Transaction__c` is **Private**;
visibility via sharing only. **FLS** restricts balance/number fields. The **integration
user** (inbound webhook context) can touch only the objects/fields it must — nothing more.
All user-facing Apex is `with sharing`, CRUD/FLS enforced (USER_MODE / stripInaccessible).
**Verified by:** security-model access matrix review (Phase 3); `runAs` cross-customer
negative tests (Phases 5–8); Code Analyzer security rules zero critical/high.

## NFR-2 — Idempotency (no double-posting of money)

**Target:** A retried **outbound transfer** (same idempotency key) posts **exactly once**;
a replayed **inbound webhook** (same external id) creates **no** duplicate record.
**Verified by:** Apex tests submitting the same transfer/webhook twice and asserting a
single effect; idempotency-key uniqueness enforced at the data layer.

## NFR-3 — Retry, resilience & recovery

**Target:** Transient core-banking failures (timeout, 5xx) are retried with **exponential
backoff** (async/Queueable); on retry exhaustion the operation lands in a **dead-letter**
store with enough context to **replay** — never silently lost. Inbound subscribers handle
disconnect/replay.
**Verified by:** `HttpCalloutMock` tests for timeout→retry→success and 5xx→exhaust→
dead-letter; a live failure drill via the mock's failure switch (Phase 7); replay test.

## NFR-4 — Tenant / owner isolation

**Target:** A servicing user or customer can read/act on **only** permitted accounts and
transactions; cross-customer access is impossible, enforced **server-side in the query**
(sharing + `WHERE` scoping), not in UI.
**Verified by:** `runAs` negative tests proving cross-customer reads/writes fail (Phases
5–8); security-model access matrix.

## NFR-5 — Secret handling

**Target:** **Zero** secrets in source, metadata, logs, or scripts. All outbound endpoints
+ credentials live in **Named Credentials / External Credentials**; CI auth via masked
variables. Logs redact payloads/PII.
**Verified by:** review checklist + Code Analyzer; grep-for-secrets check in CI; the
InfoSec sign-off artifact (Phase 9).

## NFR-6 — Integration SLA & fail-closed behavior

**Target:** Outbound callouts have a bounded **timeout**; repeated failures trip a
**circuit-breaker** (stop hammering a down dependency). On uncertainty the system **fails
closed** (no speculative money movement). Synchronous callouts never run inside a trigger.
**Verified by:** callout-config review; breaker unit tests; review checklist (no callout
in trigger); sequence diagrams (Phase 3).

## NFR-7 — Auditability & reconciliation

**Target:** Every money movement is an **immutable** ledger record (`Transaction__c` /
`Transfer__c` insert-only). A **daily reconciliation** job compares SF ledger vs
core-banking balances; mismatches raise an alert/Case within one cycle.
**Verified by:** tests asserting ledger immutability for the servicing role; reconciliation
job test on a seeded mismatch (Phase 7).

## NFR-8 — Code quality & test automation

**Target:** Org-wide Apex coverage ≥ **85%** (platform floor is 75%); every class/trigger
covered; **callouts covered by `HttpCalloutMock`**, inbound by `RestContext`; zero new Code
Analyzer critical/high; all trigger logic in the handler framework.
**Verified by:** CI coverage gate; CI Code Analyzer gate; review checklist.

## NFR-9 — Reproducibility & two-package automation

**Target:** Clean clone → ready-to-dev scratch org via **one documented command** (installs
`frs-platform-core` then `frs-banking`, assigns perm sets, seeds data, points a Named
Credential at the mock). Production install path is the pipeline's release job only, in
dependency order; **zero manual deploys**.
**Verified by:** timed onboarding walkthrough (Phase 9); release log shows pipeline-only,
ordered installs; drift check stays clean.
