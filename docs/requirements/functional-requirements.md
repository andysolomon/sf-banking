# Functional Requirements — Banking App (project #2)

> **Exercises:** application-lifecycle-management (Plan stage), testing-methodologies
> (requirements written to be traceable to tests), integration requirements analysis.
> **JD lines:** "Creates Integrations and/or Connectors between Salesforce.com and FRS
> and other 3rd party applications"; Apex/LWC/Flow delivery "from design to production";
> screen flow experience.

Baseline set at end of Phase 2. Changes after baseline require a CCB entry
(see `../governance/change-management.md`). Priority is WSJF-lite per ADR-001:
**order = value ÷ effort**, highest first.

Context: Salesforce is the **servicing/CRM layer**; the **system of record for money is
the external core-banking system** (the Vercel mock, `frs-core-banking-mock`). Balances
shown in SF are fetched/decorated from core banking, not authored in SF. All FRs assume a
user with the least-privilege banking permission set; "my accounts" means accounts the
running user is permitted to see (OWD Private — see NFR-1, NFR-4).

---

## FR-1 — View my accounts and live balances

As a servicing user, I see a customer's bank accounts with **balances fetched live from
core banking** via a Named-Credential REST callout. *(Value: H, Effort: M — walking-skeleton story)*

- **Given** a customer with two accounts, **when** I open their account view, **then** I
  see each account with its current balance as returned by core banking.
- **Given** core banking is slow/unavailable, **when** I open the view, **then** I see a
  graceful "balance temporarily unavailable" state (not an error page), and the failure
  is logged (see NFR-3/NFR-6).
- **Given** an account I'm not permitted to see, **then** I have no path to view it
  (enforced server-side; NFR-4, `runAs` negative test).

## FR-2 — Initiate a transfer (idempotent)

As a servicing user, I move money from one of the customer's accounts to another account
by an **outbound callout to core banking**, carrying an **idempotency key**.
*(Value: H, Effort: H)*

- **Given** a valid source and destination and sufficient funds, **when** I submit a
  transfer, **then** core banking executes it and a `Transfer__c` is recorded as Completed.
- **Given** the same request is retried with the same idempotency key (network timeout),
  **then** the transfer posts **exactly once** (NFR-2).
- **Given** a transient core-banking failure, **then** the transfer is retried with
  backoff and, if retries exhaust, lands in the dead-letter store for replay (NFR-3) —
  never silently lost.

## FR-3 — Inbound posted-transaction webhook

As the platform, I expose an authenticated inbound REST endpoint so core banking can
**notify SF of a posted transaction**, creating a `Transaction__c` ledger record.
*(Value: H, Effort: M)*

- **Given** a valid, authenticated webhook with a new transaction, **when** it is
  received, **then** a `Transaction__c` is created and linked to the right account.
- **Given** a **replayed** (duplicate) webhook, **then** no duplicate `Transaction__c` is
  created (idempotent inbound; NFR-2).
- **Given** an unauthenticated or malformed payload, **then** it is rejected (401/400) and
  logged; no record is created (NFR-1, NFR-5).

## FR-4 — Inbound fraud-alert webhook → Case

As the platform, I accept a **fraud-alert** webhook from core banking and open a `Case`
for the servicing team. *(Value: M, Effort: M)*

- **Given** a valid fraud-alert for an account, **when** received, **then** a `Case` is
  created with severity and linked to the account/customer.
- **Given** a duplicate alert id, **then** no duplicate Case is created (idempotent).

## FR-5 — Publish a Platform Event on transfer completion

As the platform, I publish a `Transfer_Completed__e` **Platform Event** when a transfer
completes, so subscribers (ledger update, notifications) react without tight coupling.
*(Value: M, Effort: M)*

- **Given** a transfer completes, **when** the result is recorded, **then** a
  `Transfer_Completed__e` is published with the transfer reference and outcome.
- **Given** a subscriber (trigger/Flow), **when** the event fires, **then** the ledger /
  downstream record is updated; CDC-vs-Platform-Event trade-off documented (Phase 3).

## FR-6 — Servicing screen flow (open account / file a dispute)

As a servicing user, I use a **screen flow** to open a new account for a customer or file
a transaction dispute. *(Value: M, Effort: L)*

- **Given** the customer record, **when** I run "Open Account", **then** the flow creates
  a `Bank_Account__c` (initiating provisioning via the platform-core callout framework).
- **Given** a transaction, **when** I run "File Dispute", **then** a dispute `Case` is
  created and linked; validation prevents disputing an already-disputed transaction.
