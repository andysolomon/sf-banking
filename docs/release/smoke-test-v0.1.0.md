# Smoke Test — v0.1.0 (walking skeleton)

Run after: both packages installed into "prod" (core → banking) + the `Core_Banking`
Named Credential configured (see `../devops/named-credential-setup.md`) + the mock deployed.

## API / functional checks
- [ ] Create an `Account`, then a `Bank_Account__c` with `Core_Account_Id__c` set
- [ ] Add `bankAccountCard` to the `Bank_Account__c` Lightning record page
- [ ] Open the record → **balance renders live** from the mock (matches
      `GET /api/accounts/<core id>/balance`)
- [ ] An `Integration_Log__c` row exists with `Status = Success`, `Direction = Outbound`

## Failure drill (fail-soft)
- [ ] Set the mock to fail (`MOCK_FAIL_MODE=500`, or header `x-mock-fail: 500`) → **Refresh**
      → card shows "Balance temporarily unavailable" (no error page)
- [ ] A new `Integration_Log__c` row exists with `Status = Error`

## Security
- [ ] No endpoint/secret anywhere in installed source (grep the package) — only the Named Credential
- [ ] `Banking_Servicing_Agent` cannot edit balance fields (FLS read-only)

## RTM advancement (on green)
- [ ] FR-1 → verified · NFR-5 (no secret in source) → verified · NFR-6 (fail-soft) → verified

UI sign-off (Andy): ______________________   Date: __________
