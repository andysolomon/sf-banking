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

**Status: `designed` after Phase 3** — design column filled for every row; components/tests
fill through Phases 5–9.

## Functional requirements

| ID | Summary | Design | Component(s) | Test(s) | Status |
|---|---|---|---|---|---|
| FR-1 | View accounts + live balances | data-model.md (Bank_Account__c, cached balance), security-model.md (sharing), integration-architecture.md (FR-1), sequence-diagrams.md §1 | — | — | designed |
| FR-2 | Initiate transfer (idempotent) | data-model.md (Transfer__c state machine), integration-architecture.md (transfer), sequence-diagrams.md §2 | — | — | designed |
| FR-3 | Inbound posted-txn webhook | data-model.md (Transaction__c, External_Txn_Id__c unique), security-model.md (integration user), integration-architecture.md (inbound), sequence-diagrams.md §3 | — | — | designed |
| FR-4 | Inbound fraud-alert → Case | security-model.md (integration user), integration-architecture.md (inbound), data-model.md (Case) | — | — | designed |
| FR-5 | Publish Transfer_Completed__e | integration-architecture.md (PE vs CDC), sequence-diagrams.md §4 | — | — | designed |
| FR-6 | Servicing screen flow | data-model.md, integration-architecture.md (open-account via callout framework) | — | — | designed |

## Non-functional requirements

| ID | Summary | Design | Component(s) | Test(s) | Status |
|---|---|---|---|---|---|
| NFR-1 | Security & least privilege | security-model.md (OWD/FLS/least-priv/access matrix), data-classification.md | — | — | designed |
| NFR-2 | Idempotency (no double-post) | data-model.md (Idempotency_Key__c / External_Txn_Id__c unique), integration-architecture.md (idempotency), sequence-diagrams.md §2,§3 | — | — | designed |
| NFR-3 | Retry, resilience & recovery | integration-architecture.md (retry/backoff/dead-letter), data-model.md (Dead_Letter__c), sequence-diagrams.md §2 | — | — | designed |
| NFR-4 | Tenant/owner isolation | security-model.md (OWD Private, sharing, access matrix) | — | — | designed |
| NFR-5 | Secret handling | security-model.md, data-classification.md, ADR-004-integration-auth-pattern.md | — | — | designed |
| NFR-6 | Integration SLA & fail-closed | integration-architecture.md (circuit-breaker, no-callout-in-trigger), sequence-diagrams.md §1, ADR-004 | — | — | designed |
| NFR-7 | Auditability & reconciliation | data-model.md (immutable ledger), integration-architecture.md (monitoring & reconciliation) | — | — | designed |
| NFR-8 | Code quality & test automation | ../governance/definition-of-done.md (callout-mock/coverage gates) | — | — | designed |
| NFR-9 | Reproducibility & two-package automation | ADR-003-two-package-architecture.md, ADR-002-branching-strategy.md | — | — | designed |
