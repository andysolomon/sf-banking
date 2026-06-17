# Pipeline Design — Banking App (project #2)

> **Exercises:** system-design-deployment-strategy, deploying-metadata-tooling-apis,
> operating-managing-common-release-artifacts. **JD lines:** "Salesforce DevOps & CI/CD…
> GitLab"; "develops and maintains automation for deployments"; "platform enablers…
> reusable components… supporting multiple Salesforce application teams." **RTM design
> coverage:** NFR-8, NFR-9.
>
> **Design authority.** When `.gitlab-ci.yml` / the template and this doc disagree, an MR
> fixes one of them. Written **before** the YAML is wired live (per stage-gate ADR-001).

## Stages

`validate → test → package → test-release → release`

| Stage | Job | Burns scratch? | Gate |
|---|---|---|---|
| validate | `scan` (Code Analyzer over both package dirs) | no | unconditional (anchors pipeline existence) |
| validate | `lwc-test` (Jest) | no | code-gated |
| test | `apex-test` (deploy whole project → scratch → tests + coverage ≥85%) | **1 create** | code-gated |
| package | `version` (build **core → banking** versions) | no (uses Package2VersionCreates quota) | release-gated (main/hotfix) |
| test-release | `staging-install` (install **core → banking** into fresh scratch) | **1 create** | release-gated |
| release | `prod-install` (install **core → banking** into prod) | no | release-gated + **manual** |

## The multi-package delta (what's different from the todo-app)

This is the project's core CI lesson. A single-package pipeline does one
`version create` and one `install`. Two dependent packages require **ordering**:

1. **Build order:** `version` creates `frs-platform-core` first, then `frs-banking`.
   `frs-banking`'s `sfdx-project.json` dependency (`frs-platform-core 0.1.0.LATEST`)
   resolves against the just-created core version, so core MUST exist first. Both
   SubscriberPackageVersionIds are passed forward as a `dotenv` artifact
   (`CORE_SPV_ID`, `APP_SPV_ID`).
2. **Install order:** staging + prod install **core then app** — installing the app first
   fails its dependency check. Rollback order is the reverse.
3. **Deploy (apex-test):** `sf project deploy start` with no `--source-dir` deploys the
   **whole project** (both package dirs) to the scratch org, so one deploy covers both.
4. **Quota note:** `Package2VersionCreates` is a **separate** 6/day limit from
   `DailyScratchOrgs` (learned on the todo-app) — two versions/pipeline uses two of it.

## Reuse lineage (the JD evidence — and an honest finding)

`ci-templates/salesforce-multipackage-pipeline.yml` is **derived from the todo-app's**
`ci-templates/salesforce-pipeline.yml` (the platform team's reusable template). Adopting
that template for a **second app** surfaced real parameterization gaps:

- it **hardcoded `force-app`** (banking has `frs-platform-core` + `frs-banking`);
- it assumed a **single `SF_PACKAGE`** (banking has two, ordered).

So this variant generalizes: `SF_PACKAGE_DIRS` (scan/deploy paths), `SF_CORE_PACKAGE` /
`SF_APP_PACKAGE` (ordered build/install), `SF_PERMSETS` (a list). **Platform backlog
(Phase 9 candidate):** fold these back so **one** shared template serves both single- and
multi-package consumers — *that* is the "reusable components supporting multiple
application teams" story, and adopting-by-a-second-team is exactly how the gaps were found.

## Secrets handling (reused discipline)

- `SFDX_AUTH_URL_DEVHUB_B64` / `SFDX_AUTH_URL_PROD_B64` — **base64-encoded** SFDX auth URLs
  (GitLab masking rejects the raw `force://` charset; base64 keeps them maskable). Decoded
  at point of use via `base64 -d | sf org login sfdx-url --sfdx-url-stdin -`, never logged.
- **DevHub var UNPROTECTED** (MR pipelines, which run on unprotected feature branches, need
  it to create scratch orgs) — hardening path is a dedicated low-priv CI user.
- **PROD var PROTECTED** (only `main` + `hotfix/*` protected refs reach it).
- Since we **reuse the todo-app orgs**, these are the **same auth-URL values** as `sf-todo`,
  just set as variables on the new `sf-banking` project. No new orgs, no new secrets.
- Mock/core-banking secrets never touch SF source — they live in the **Named/External
  Credential** (ADR-004); the mock's base URL is configured post-install, not committed.

## Scratch-org budget (shared!)

**6 scratch-org creates/day are shared across local work, this pipeline, AND the todo-app.**
An MR pipeline burns 1 (apex-test); a main pipeline burns 2 (apex-test + staging-install).
**Count before pushing.** This is a real free-tier platform constraint, documented as such.

## Conditional execution

Org-burning jobs are **code-gated** (`.sf-rules-code-gated`): they run only when SF
source/config changed (a docs-only MR runs `scan` only, 0 scratch creates). `version` /
installs are **release-gated** (main/hotfix). The first walking-skeleton MR (Phase 5) does
the deliberate-PMD-violation + failing-Apex-test red→green drill to prove the gates bite
(and to verify `sf` CLI flag syntax at first real run, per the todo-app's hard-won note).
