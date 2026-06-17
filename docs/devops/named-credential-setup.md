# Named Credential Setup (post-install) — `Core_Banking`

> **Why post-install, not packaged:** per ADR-004 / NFR-5, the endpoint URL and secret are
> **never** in source or packaged metadata. Apex references `callout:Core_Banking/...`; the
> credential is configured per-org after install.

After installing the packages (core → banking) and deploying the mock
(`scripts/deploy-mock.sh --prod` → capture the base URL):

1. **External Credential** `Core_Banking_Cred`
   - Authentication protocol: per the mock (API key / bearer header, or "Custom").
   - Add a **Named Principal** holding the mock's key (if any). Secret stays here, never in code.
2. **Named Credential** `Core_Banking`
   - URL = the deployed mock base URL (e.g. `https://frs-core-banking-mock.vercel.app`).
   - Link the External Credential above.
   - Generate Authorization header from the External Credential.
3. **Permission**: grant the running user (and `Banking_Servicing_Agent`) access to the
   External Credential principal.

Verify: anonymous Apex
`System.debug(CalloutService.httpGet('Core_Banking/api/accounts/abc/balance','smoke').getBody());`
returns the mock's balance JSON.

> **Phase 9 / NFR-9 follow-on:** script this in `scripts/org-setup.sh` so dev and CI
> configure the credential identically (one path, no drift).
