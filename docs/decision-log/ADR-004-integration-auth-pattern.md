# ADR-004: Integration Authentication Pattern — Banking App (project #2)

- **Status:** Accepted
- **Date:** 2026-06-17
- **Deciders:** Platform/Integration Architect hat + **InfoSec Approver**

> **Exercises:** integration security (auth/authz, secret management), Named Credentials,
> OAuth flows. **JD lines:** "Must have experience in Salesforce Integration patterns";
> "Salesforce security Model"; "Partner with Information Security representatives… execute
> security configurations and controls." **RTM design coverage:** NFR-1, NFR-5, NFR-6.

## Context

Two directions need auth, and both must keep **zero secrets in source** (NFR-5):
- **Outbound** (SF → core banking): balance reads, transfers.
- **Inbound** (core banking → SF): posted-transaction + fraud webhooks.

## Decision — Outbound

**Named Credentials + External Credentials** for every outbound callout.
- The endpoint URL and secret live in the **External Credential**; Apex references
  `callout:Core_Banking/...` — it never sees the URL or key.
- **Auth mode:** per-**named-principal** (one service identity for SF→core), *not*
  per-user — the integration acts as a system, and a single managed credential is what
  InfoSec can rotate and audit. (Per-user named principals are noted as the alternative if
  core banking ever required end-user identity propagation; not needed here.)
- Mock note: `frs-core-banking-mock` accepts a bearer/api-key supplied via the External
  Credential, so the *pattern* is exercised exactly as it would be against a real FRS system.

## Decision — Inbound

A **Connected App** governs inbound API access; the webhook caller authenticates via
**OAuth JWT-bearer (server-to-server, no interactive user)** — chosen by actor: core
banking is a system, not a person.
- Runs as the least-privilege **`Banking_Integration_User`** (security-model).
- Defense in depth: payload **signature/HMAC verification** + **replay protection**
  (dedupe on `External_Txn_Id__c`), so a leaked token alone can't forge or replay posts.
- Connected App scoped minimally (API only), with IP/where-possible policy + monitoring.

## Why not alternatives

| Alternative | Rejected because |
|---|---|
| Hardcoded endpoint/key in Apex or custom metadata | secrets in source — violates NFR-5; unrotatable; the #1 thing InfoSec rejects |
| Remote Site Setting + manual headers | no managed credential store; secret handling becomes the app's problem |
| Per-user OAuth for the system integration | core banking has no end-user identity to propagate; adds complexity, no benefit |
| Basic auth inbound, no signature | a leaked credential = forgeable/replayable posts; money-moving endpoints need defense in depth |

## InfoSec partnership (artifact in Phase 9)

This ADR is the basis of `infosec-signoff.md`: auth modes, secret storage + rotation,
least-privilege integration user, data classification of what crosses the boundary, and a
sign-off checklist — enacting "Partner with Information Security… execute security
configurations and controls."

## Consequences

- No secret ever lives in source/logs (NFR-5); credentials are rotatable + auditable.
- Inbound is authenticated **and** signed **and** replay-protected — a single failure
  doesn't breach money movement.
- Connected App + External Credential are **per-org config** (not fully packageable) → the
  org-setup script + runbook document this as a post-install step (NFR-9).
