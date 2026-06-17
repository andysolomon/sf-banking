# Definition of Done — Banking App (project #2)

> **Exercises:** building-quality-code, testing-execution-and-coverage. **JD lines:**
> "Ensure code quality through static analysis, unit testing and test automation";
> secure coding; "Salesforce Integration patterns."
>
> Inherited from the todo-app; adds integration- and secrets-specific gates.

A story/MR is **done** only when every applicable line is true. Gates are not waivable
(see charter — change the gate via ADR instead).

## Code

- [ ] Implements exactly one classified change (one FR story per Minor MR)
- [ ] Apex: bulkified (no SOQL/DML in loops), `with sharing` unless an ADR says otherwise,
      FLS/CRUD checked on user-facing paths (USER_MODE where applicable)
- [ ] Trigger logic lives in a handler framework, never in the trigger body
- [ ] **No callout occurs synchronously inside a trigger** (callouts are async via the
      platform-core framework)
- [ ] No commented-out code, no debug statements left behind

## Security & integration (project #2 additions)

- [ ] **No secrets in source or logs** — endpoints/credentials via Named Credentials / CI
      variables only; logs redact payloads/PII
- [ ] Outbound callouts go through `frs-platform-core`'s callout framework (Named
      Credential abstraction; consumer never sees the endpoint/secret)
- [ ] Integration error paths handled by taxonomy (retryable vs validation vs auth vs
      limit); money/state-moving operations are **idempotent**
- [ ] Inbound endpoints authenticate the caller and validate + replay-protect the payload
- [ ] Any new field crossing the SF↔core boundary has a recorded **data classification**
- [ ] `frs-platform-core` **public-API** changes: README/CHANGELOG updated, version bumped
      per semver, consumer-impact considered

## Tests

- [ ] Test-first where practical; user-focused (behavior, not implementation)
- [ ] Positive, negative, and (where access matters) `runAs` permission cases
- [ ] **Callouts covered by `HttpCalloutMock`** (success + timeout/500/malformed); inbound
      endpoints tested via `RestContext`
- [ ] All test data via a data factory; no `SeeAllData=true`; bulk paths tested at 200+
- [ ] Org coverage ≥ 85% after merge; every class/trigger touched has coverage

## Quality gates (enforced by pipeline, verified by reviewer)

- [ ] Salesforce Code Analyzer: zero new criticals/highs
- [ ] LWC: Jest green; a11y check passes
- [ ] Full pipeline green on the MR (both packages build in dependency order)

## Documentation & traceability

- [ ] RTM row(s) updated: requirement → component → test
- [ ] Diagrams/ADRs updated if schema, security model, integration, or pipeline changed
- [ ] CHANGELOG entry if user-visible or if the package public API changed

## Review

- [ ] Reviewed against `code-review-checklist.md` by the reviewer hat, honoring the
      cooling-off rule
- [ ] Integration/security-class MRs additionally carry a recorded **InfoSec-hat approval**
- [ ] Review comments resolved with re-review, not self-dismissed
