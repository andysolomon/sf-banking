# Merge Request

## Change classification
<!-- per docs/governance/change-management.md -->
- [ ] Immediate / Minor / Major / **Integration-Security** / Hotfix (circle one)
- **FR/NFR ID(s):**
- **CCB entry (if Major / scope change / breaking core API):**
- **InfoSec sign-off (if Integration/Security class):**

## What & why

<!-- one paragraph; link the requirement, not just describe code -->

## Definition of Done (docs/governance/definition-of-done.md)

- [ ] One classified change only
- [ ] Apex bulkified, `with sharing`/USER_MODE, FLS-checked; trigger logic in handler only
- [ ] **No synchronous callout in a trigger** (async via the platform-core framework)
- [ ] **No secrets in source/logs** (Named Credentials only; payloads/PII redacted)
- [ ] **Idempotency** on any money/state-moving path; inbound dedupes on external id
- [ ] Positive + negative (+ `runAs` where access matters) tests; factory-only data
- [ ] **Callouts covered by `HttpCalloutMock`**; inbound by `RestContext`
- [ ] RTM row(s) updated in this MR
- [ ] Diagrams/ADRs updated if schema, security model, integration, or pipeline changed
- [ ] `frs-platform-core` public-API change → README/CHANGELOG updated, version bumped
- [ ] CHANGELOG entry if user-visible

## Reviewer (cooling-off rule: not the authoring session)

- [ ] Reviewed against docs/governance/code-review-checklist.md
- [ ] Integration/Security class → **InfoSec-hat approval recorded**
- **Hat & rationale:**
