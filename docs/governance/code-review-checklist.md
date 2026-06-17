# Code Review Checklist — Banking App (project #2)

> **Exercises:** building-quality-code (checklist-driven review; automation catches style,
> humans catch logic). **JD lines:** "secure coding"; "Salesforce Integration patterns."
>
> The pipeline already enforced: static analysis (both packages), Jest, Apex tests,
> coverage ≥85%. This checklist is what the *human* adds. Inherited from the todo-app;
> the **Integration** section is project #2's addition.

## Security (the study material's #1 failure category)

- [ ] CRUD/FLS: every user-facing read/write uses USER_MODE or stripInaccessible
- [ ] `with sharing` on user-facing classes; any `without sharing` is justified by an ADR
- [ ] No dynamic SOQL; bind variables everywhere
- [ ] **No secrets/endpoints/keys hardcoded**; outbound only via Named Credentials; no
      `System.debug` of record data / payloads / PII left behind
- [ ] New fields: FLS deliberately set; financial fields masked/least-priv per data-classification

## Integration (project #2)

- [ ] Outbound callouts go through `frs-platform-core`'s `CalloutService` (no raw `Http`)
- [ ] **No callout inside a trigger** — async (Queueable) per design
- [ ] **Idempotency** present on money/state-moving calls (key on outbound; external-id
      dedupe on inbound) — a retry/replay cannot double-post
- [ ] Error handling matches the taxonomy (retryable → retry/dead-letter; validation →
      fail fast; auth → fail closed); exhaustion → `Dead_Letter__c`, never silent loss
- [ ] Inbound endpoint authenticates + validates + replay-protects the payload
- [ ] Data crossing the boundary is classified; logs redact per data-classification.md

## Governor limits & scale

- [ ] No SOQL/DML inside loops (incl. indirect)
- [ ] Collections in, collections out; handler consumes full trigger context
- [ ] Async used per design (one enqueue per transaction; batch for unbounded volume)
- [ ] 200+ record test exists with `Limits` assertions; `Transaction__c` queries selective (LDV)

## Design conformance

- [ ] Trigger logic only in the handler framework
- [ ] Change matches its classification (touches integration/secrets/financial sharing → Integration-Security)
- [ ] Schema changes additive-only; destructive → Major + ADR
- [ ] Logic in the right layer (Flow vs Apex per ADR)
- [ ] `frs-platform-core` public-API change: deliberate, documented, versioned; consumer impact considered

## Tests (Kent C. Dodds standard: behavior, not implementation)

- [ ] Tests fail if the behavior breaks (no assert-free coverage padding)
- [ ] `HttpCalloutMock` covers success + timeout + 5xx + malformed for each callout
- [ ] Inbound tested via `RestContext`; duplicate/replay asserted to be a no-op
- [ ] `runAs` used where access control / cross-customer isolation is the point
- [ ] All data via a test-data factory; zero `SeeAllData=true`

## Traceability

- [ ] RTM updated in this MR (status advanced honestly)
- [ ] MR maps to exactly one FR/story (or is an honest Immediate/Hotfix)
