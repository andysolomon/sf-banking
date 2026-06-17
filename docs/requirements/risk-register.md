# Risk Register — Banking App (project #2)

> **Exercises:** planning-environment-risks (six risk categories + mitigations).
> **JD line:** "Critical Thinking (applies objective analysis and reasoning)" — risk-
> managed delivery in a Financial Services context.

Categories follow the study material. Likelihood/Impact: L/M/H. Owner is a hat.
Review cadence: each release's post-release review; new risks get CCB entries.
Integration-specific risks (R-3..R-8) are the focus of this project.

| # | Category | Risk | L | I | Mitigation | Owner |
|---|---|---|---|---|---|---|
| R-1 | Customization | Over-building banking features instead of integration/platform discipline | M | M | 6-FR scope cap; WSJF ordering; stage-gate acceptance checklists — when green, stop | CCB |
| R-2 | Customization | Logic split inconsistently between Flow and Apex | M | M | ADR when logic moves layers; review asks "why this layer?" | Architect |
| R-3 | Data security | Sharing/FLS misconfig exposes another customer's accounts/balances | L | H | OWD Private + perm-set-only grants + FLS (NFR-1/4); `runAs` cross-customer negatives in CI; access matrix at Phase 3 gate | InfoSec |
| R-4 | Data security | Secret (endpoint/key/auth URL) leaks via source, logs, or CI | M | H | Named Credentials only; masked CI vars; no secrets in source (DoD); grep-for-secrets CI check; InfoSec sign-off | InfoSec |
| R-5 | Integration | **Duplicate posting** — retried transfer or replayed webhook moves money twice | M | H | Idempotency keys + inbound external-id dedupe (NFR-2); double-submit tests; the data-layer uniqueness constraint | Architect |
| R-6 | Integration | **Core-banking unavailable** — callouts time out / 5xx, work lost or user blocked | M | H | Retry+backoff, circuit-breaker, dead-letter+replay (NFR-3/6); graceful degraded UI (FR-1); integration-failure drill (Phase 9) | Architect |
| R-7 | Integration | **Webhook spoofing/replay** — forged or duplicated inbound calls | M | H | Authenticated inbound (Connected App / signed payload), payload validation, replay protection (NFR-1/2); InfoSec review | InfoSec |
| R-8 | Integration | **Silent divergence** — SF ledger drifts from core-banking truth | L | H | Immutable ledger + **daily reconciliation** job raising alerts (NFR-7); balance source-of-truth is core banking, SF caches | Architect |
| R-9 | Governance | Solo project drifts from its own process (hats collapse, gates skipped) | H | M | Cooling-off rule; ccb-log/infosec-signoff as forcing functions; retro asks "which gate did I shortcut?" | CCB |
| R-10 | Project mgmt | Cross-package version mismatch / wrong install order breaks deploy | M | M | banking pins a core version; two-package release ordering in change-management; staging-org install test | Release Mgr |
| R-11 | Project mgmt | Free-tier limits (6 scratch/day, **shared with todo-app**, Dev Edition caps) stall the pipeline | M | M | Count scratch budget before pushing; batch CI experiments; local `sf` runs; document as real platform constraint | Release Mgr |
| R-12 | Development | Callout-in-trigger / non-bulkified code passes small tests, fails in prod | M | H | Callouts async via platform-core framework (never in trigger); 200+ record tests w/ Limits asserts; analyzer + review | Developer |
| R-13 | Testing | Tests pass against mock but real contract drifts (mock ≠ core banking) | M | M | Contract notes vs the mock API; live e2e against the deployed mock incl. forced-failure (Phase 8); pin the mock's API shape | Developer |
