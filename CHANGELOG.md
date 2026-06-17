# Changelog — Banking App (project #2)

## [Unreleased] — Phase 5 walking skeleton (metadata STAGED 2026-06-17, pre-deploy)

Thinnest integrated slice: a `Bank_Account__c`'s **live balance** fetched from the
external core-banking mock via a Named Credential.

### frs-platform-core
- `CalloutService` — generic Named-Credential GET + structured logging
- `Integration_Log__c` — correlation id / direction / status / endpoint alias

### frs-banking
- `Bank_Account__c` (+ Customer, Core_Account_Id, Type, Balance_Minor, Balance_As_Of, Status)
- `BankAccountController.getLiveBalance` — live balance via callout, FLS-enforced, fail-soft
- `bankAccountCard` LWC — renders balance, fail-soft "temporarily unavailable", Refresh
- `Banking_Servicing_Agent` permission set (least-privilege; read-only on financial fields)

### Tests
- `CalloutServiceTest` (success / error-status / thrown), `BankAccountControllerTest`
  (success / core-down), `bankAccountCard` Jest (render + fail-soft)

### Integration config
- Named Credential **Core_Banking** = post-install setup (no secrets in source) — see
  `docs/devops/named-credential-setup.md` and ADR-004.

> NOT YET deployed/packaged — awaits the Phase 4 interactive steps (register packages,
> create the GitLab project, deploy the mock). On deploy this becomes **v0.1.0**.
