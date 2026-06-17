# Project Charter — Banking App (project #2)

> **Exercises:** planning-governance (CoE, charter, decision authority),
> application-lifecycle-management (ALM stages). **JD lines:** "change-management
> controls, auditability, and release governance using SFDX+CI/CD"; "Partner with
> Information Security representatives"; "platform enablers… reusable components in
> support of business products… supporting multiple Salesforce application teams."
>
> Inherited from `projects/todo-app/docs/governance/charter.md` and extended for the
> platform-team / integration / financial-data-security depth this project targets.

## Purpose

Build a Salesforce-native **banking-servicing app** that integrates with an external
**core-banking system**, built on top of a **reusable platform-core package**, through a
fully governed, auditable ALM cycle. The app is the vehicle; the deliverable is
demonstrated platform-engineering discipline on the three JD areas the todo-app left
thin: **integration patterns, reusable enablers, and security of financial data.**

## Two-team operating model (enacts the JD)

This repo is run as a **platform team** that serves **application teams** — exactly the
JD's mission. One person plays both sides, made explicit:

| Side | Unit | Role |
|---|---|---|
| **Platform team** | `frs-platform-core` (base 2GP package) | Owns the reusable enablers (logging, callout framework, event publisher, dead-letter) and their **public API**; versions and releases the package as a product. |
| **App team (consumer #1)** | `frs-banking` (extension package) | Consumes `frs-platform-core`; builds banking features. **Pins** a core version. |
| **App team (consumer #2, candidate)** | `todo-app` | Named adopter that proves the core is reusable, not single-app. Deferred. |

## Roles ("hats")

One person plays all roles; discipline comes from making each hat's action explicit and
sequential — never author and approve in the same act.

| Hat | Responsibility | Authority |
|---|---|---|
| **Developer** | Author MRs: code, tests, docs. Self-review before requesting review. | Cannot approve own MR or trigger a release. |
| **Platform/Integration Architect** | Own ADRs, data/security model, integration patterns, and the **package public API**. Review MRs touching schema, sharing, integration, or the core API. | Approves design + API changes; cannot waive the DoD. |
| **InfoSec Approver** | Approve integration **auth patterns, secret handling, least-privilege access, and data classification** of anything crossing the SF boundary. | **Required gate** on any integration/security-class change (see change-management). |
| **Release Manager** | Run the release runbook for a **two-package** release (install order: core → banking), manual gate, smoke test, tag, comms. | Only hat allowed to trigger the `release` job. |
| **CCB Approver** | Approve scope changes, classification disputes, hotfix authorization, production exceptions, and **breaking core-API changes**. | Final say on backlog and what ships. |

## Segregation-of-duties rules (solo simulation)

1. Every governed action is recorded *as a hat*, with rationale.
2. **Cooling-off rule:** an MR may not be approved in the same working session it was
   authored.
3. **InfoSec gate:** an integration/security-class change cannot merge without a recorded
   InfoSec-hat approval (entry in `docs/governance/ccb-log.md` or `infosec-signoff.md`),
   distinct from the authoring act.
4. CCB and InfoSec decisions are logged: date, request, classification, decision, rationale.
5. The release job is manual-approval; clicking it *is* the Release Manager hat acting,
   and requires the runbook checklist completed first.

## Decision authority

| Decision | Owner | Recorded in |
|---|---|---|
| New/changed requirement | CCB | ccb-log.md + RTM |
| Architecture/stack/process choice | Platform/Integration Architect | ADR in docs/decision-log/ |
| **Integration auth pattern / secret handling / data classification** | **InfoSec Approver** | ADR + infosec-signoff.md |
| **`frs-platform-core` public API change** | Platform Architect (CCB if breaking) | ADR + package README/CHANGELOG |
| Merge to main | Reviewer hat (per checklist) | MR record |
| Production release / hotfix | Release Manager (CCB authorizes hotfixes) | Release runbook entry + tag |
| Waiving any gate | Nobody. Change the gate via ADR instead. | — |

## ALM stages (study material's six-stage cycle)

| Stage | Meaning here |
|---|---|
| Plan Release | Pick FR stories; classify changes (incl. integration/security class); update RTM |
| Develop | Feature branch + scratch org per story; test-first; `HttpCalloutMock` for callouts |
| Test | CI gates: static analysis, Apex tests + coverage, Jest, e2e against the Vercel mock |
| Build Release | CI builds **both** package versions in dependency order (core → banking) |
| Test Release | Install candidate versions in a staging scratch org (core then banking); UAT |
| Release | Manual-approval install to "prod" in order; smoke test; tags; changelog; comms |

## Governance maturity intent

Study ladder: Non-Existent → Emerging → Practicing → **Leading**. Starts at *Practicing*
by construction; the reusable package + consumer README + InfoSec partnership artifact
demonstrate *Leading* (a platform serving other teams).
