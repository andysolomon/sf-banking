# Change Management — Banking App (project #2)

> **Exercises:** releasing-release-management-strategy, operating-direct-changes-production,
> operating-integrating-direct-changes-alm. **JD lines:** "Experience with change
> management systems and processes"; "change-management controls, auditability, and
> release governance"; "Partner with Information Security representatives."
>
> Inherited from the todo-app and extended with an **Integration/Security change class**
> and **two-package** release rules.

## Change classes and release paths

Every change is classified before work starts. Disputes go to the CCB hat.

| Class | Examples | Approval | Release path | Cadence |
|---|---|---|---|---|
| **Immediate** | Doc fixes, comments, CI tweaks not touching gates | Reviewer hat | MR → main (pipeline runs; no package release) | As needed |
| **Minor** | One FR story; non-breaking field addition; LWC change | Reviewer hat | MR → pipeline → package version → next planned release | Per release |
| **Major** | Schema change, sharing-model change, pipeline gate change, multi-story batch | Architect (design) + CCB (scope) before work | Minor path + staging-org UAT sign-off | Planned release only |
| **Integration / Security** | Named Credential / auth change, secret handling, inbound endpoint, FLS/sharing on financial data, **breaking `frs-platform-core` public-API change** | Platform Architect (design) **+ InfoSec Approver** before work; CCB if breaking API | Minor/Major path **plus an InfoSec sign-off gate** before release; breaking API → consumer-impact assessment | Planned release only |
| **Hotfix** | Production defect blocking use | CCB authorizes; Release Manager fast-tracks | Branch from release tag → all gates (none skipped) → patch version(s) → prod → back-merge | Urgent only |

Notes:
- "Fast-track" means *priority*, not *fewer gates*. Every class runs every gate.
- Schema changes must be **additive** within a major version so package-version rollback
  stays safe. Destructive changes are Major (or Integration/Security) and require an ADR.
- **No secrets in source, ever** — endpoints/keys live in Named Credentials / CI
  variables, never in Apex, custom metadata, logs, or scripts. A change introducing a
  secret into source is rejected at review, not reclassified.

## Two-package release rules

- **Install/upgrade order: `frs-platform-core` → `frs-banking`** (dependency direction).
  Rollback order is the reverse where a downgrade is needed.
- `frs-banking` **pins** a specific `frs-platform-core` version; bumping the pin is itself
  a change (Minor, or Integration/Security if the new core API changes auth/contracts).
- A **breaking** change to the core public API is Integration/Security class + CCB, and
  requires updating the consumer README and a consumer-impact note (todo-app is the
  hypothetical second consumer to consider).

## Direct changes to production: forbidden

No setup edits or "quick fixes" in the "prod" org. If it happens anyway, run the
retroactive-integration cycle in order: **Document → Approve (retroactive CCB/InfoSec
entry) → Back-integrate (`sf project retrieve` → normal MR) → Update downstream scratch
orgs → Validate (full pipeline + drift check) → Monitor (next post-release review).**

## Scope changes

FR/NFR baseline is set at the end of Phase 2. After that, any new/changed requirement is
a CCB decision *before* implementation — logged with rationale, RTM updated in the same MR.

## Communication

Each release gets a short comms note in the changelog (audience: the consuming app
teams). Hotfixes and integration incidents additionally get a one-paragraph note:
impact, cause, fix, prevention.
