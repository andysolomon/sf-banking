# Requirements Traceability Matrix (RTM) — Banking App (project #2)

> **Exercises:** testing-methodologies (RTM as UAT/audit evidence),
> operating-managing-common-release-artifacts (component provenance).
> **JD line:** "auditability" — this document is the project's audit-evidence backbone.

Rules:
- Every FR/NFR has a row. Rows are updated **in the same MR** that adds the design,
  component, or test (per definition-of-done).
- "Design" → file in `docs/architecture/` (or governance/decision-log). "Component" →
  metadata/source path (note the **package**: core vs banking). "Test" → test class/suite.
  `—` = intentionally pending; never blank.
- Status: `planned` → `designed` → `built` → `verified` (test green in CI) → `frozen`.

**Status: Phases 1–9 built; v0.2.1 (Phases 6–9) RELEASED to `banking-prod`** through the
GitHub Actions pipeline (promote → in-place upgrade over v0.1.0, gated by `upgrade-install`).
Rows are `verified` where their tests are green in CI; FR-6's Screen Flow awaits manual UI sign-off.

## Functional requirements

| ID | Summary | Design | Component(s) | Test(s) | Status |
|---|---|---|---|---|---|
| FR-1 | View accounts + live balances | data-model.md, security-model.md, integration-architecture.md (FR-1), sequence-diagrams.md §1 | core: CalloutService, Integration_Log__c; banking: Bank_Account__c, BankAccountController, bankAccountCard LWC, Banking_Servicing_Agent; Core_Banking NamedCredential (post-install) | CalloutServiceTest (3), BankAccountControllerTest (success/core-down), bankAccountCard Jest (2); **v0.1.0 live proof (devhub)**: live NC→mock = $1,323.19, HTTP 200; v0.1.0 (0.1.0.2) installed to **banking-prod** (own prod org) | verified |
| FR-2 | Initiate transfer (idempotent) | data-model.md (Transfer__c state machine), integration-architecture.md (transfer), sequence-diagrams.md §2 | Transfer__c (Idempotency_Key__c unique), TransferService (async), TransferCalloutQueueable; consumes core CalloutService + DeadLetterService | TransferServiceTest (5: blank-key, idempotent no-double-post, success+publish, transient→dead-letter, 4xx) | verified |
| FR-3 | Inbound posted-txn webhook | data-model.md (Transaction__c, External_Txn_Id__c unique), security-model.md (integration user), integration-architecture.md (inbound), sequence-diagrams.md §3 | WebhookResource @RestResource, Transaction__c, Webhook_Event__c (replay), Webhook_Config__c, Banking_Integration_User | WebhookResourceTest (posted 201, replay 200 idempotent, validation 400s, auth 401) | verified |
| FR-4 | Inbound fraud-alert → Case | security-model.md (integration user), integration-architecture.md (inbound), data-model.md (Case) | WebhookResource (fraud_alert → Case), Banking_Integration_User (Case create) | WebhookResourceTest.fraudAlert_createsCase201 | verified |
| FR-5 | Publish Transfer_Completed__e | integration-architecture.md (PE vs CDC), sequence-diagrams.md §4 | Transfer_Completed__e, Transfer_Completed_Trigger, TransferCompletedHandler; consumes core PlatformEvents | TransferCompletedHandlerTest (ledger projection; re-delivery idempotent) | verified |
| FR-6 | Servicing screen flow | data-model.md, integration-architecture.md (open-account via callout framework) | File_a_Dispute Screen Flow (→ Case) | Flow (manual UI sign-off); Case-create path proven in WebhookResourceTest/SecurityModelTest | built |

## Non-functional requirements

| ID | Summary | Design | Component(s) | Test(s) | Status |
|---|---|---|---|---|---|
| NFR-1 | Security & least privilege | security-model.md (OWD/FLS/least-priv/access matrix), data-classification.md | 3 permsets (Servicing_Agent / Integration_User / Platform_Core_Consumer); OWD Private; WITH USER_MODE + insert as user throughout | SecurityModelTest (isolation, read-only balance FLS, integration-user least-priv) | verified |
| NFR-2 | Idempotency (no double-post) | data-model.md (Idempotency_Key__c / External_Txn_Id__c unique), integration-architecture.md (idempotency), sequence-diagrams.md §2,§3 | Transfer__c.Idempotency_Key__c unique + Idempotency-Key header; Webhook_Event__c.Event_Id__c + Transaction__c.External_Txn_Id__c unique | TransferServiceTest.initiate_idempotent_noDoublePost; WebhookResourceTest.replay_sameEventId_200_idempotent | verified |
| NFR-3 | Retry, resilience & recovery | integration-architecture.md (retry/backoff/dead-letter), data-model.md (Dead_Letter__c), sequence-diagrams.md §2 | CalloutService.sendWithRetry + CalloutRetryQueueable (backoff); DeadLetterService + DeadLetterReplayBatch; circuit-breaker | CalloutServiceTest (retry/exhaust/breaker); DeadLetterServiceTest (replay); integration-failure-drills.md | verified |
| NFR-4 | Tenant/owner isolation | security-model.md (OWD Private, sharing, access matrix) | OWD Private on Bank_Account__c / Transfer__c / Transaction__c | SecurityModelTest.isolation_agentB_cannotSeeAgentA_account | verified |
| NFR-5 | Secret handling | security-model.md, data-classification.md, ADR-004-integration-auth-pattern.md | endpoint in Core_Banking NamedCredential; Apex uses `callout:Core_Banking` (no URL/secret in source); Integration_Log__c stores alias only | v0.1.0 live proof (devhub): log alias-only; grep of installed source = no URL/secret | verified |
| NFR-6 | Integration SLA & fail-closed | integration-architecture.md (circuit-breaker, no-callout-in-trigger), sequence-diagrams.md §1, ADR-004 | BankAccountController fail-soft (non-200 → AuraHandledException); bankAccountCard "temporarily unavailable" | BankAccountControllerTest.getLiveBalance_coreDown_failsSoft (unit); mock fail switch x-mock-fail:500→HTTP 500 confirmed | verified |
| NFR-7 | Auditability & reconciliation | data-model.md (immutable ledger), integration-architecture.md (monitoring & reconciliation) | Integration_Log__c (every callout/event/webhook, redacted); ReconciliationBatch (live core vs SF → Case) | ReconciliationBatchTest.mismatch_raisesCase; logging asserted across the suite | verified |
| NFR-8 | Code quality & test automation | ../governance/definition-of-done.md (callout-mock/coverage gates), ../testing/test-strategy.md | 82 Apex tests + LWC Jest; PMD (High gate) + coverage≥85% enforced in CI | full local suite 100% pass, 93% local / 91% CI org-wide coverage; test-strategy.md | verified |
| NFR-9 | Reproducibility & two-package automation | ADR-003-two-package-architecture.md, ADR-002-branching-strategy.md | two-package 2GP build (core←banking) + reusable **GitHub Actions** pipeline (gate → package → staging-install → upgrade-install → prod-install) | v0.1.0 **and** v0.2.1 both released end-to-end through the pipeline; the v0.2.1 in-place upgrade over v0.1.0 is guarded by the `upgrade-install` gate (install prior released → upgrade to new build) | verified |
