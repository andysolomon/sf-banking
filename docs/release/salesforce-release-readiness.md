# Salesforce Seasonal Release Readiness — Integration Focus

> A Salesforce seasonal upgrade (Spring/Summer/Winter) can change platform behaviour under our
> feet. This checklist is scoped to **what the upgrade can do to the *integration***, beyond
> the usual regression pass.

## Integration-specific impact areas
| Area | What can change | Our exposure | Check |
|---|---|---|---|
| **API version** | new default; deprecations | classes/objects pinned at `67.0` (`sourceApiVersion`); callout/REST behaviour | re-run full Apex suite + the e2e against the installed package on a **preview org** |
| **Named / External Credentials** | model changes, new auth protocols, legacy NC deprecation | `Core_Banking` (legacy no-auth in lab) | confirm the NC still resolves; plan the External-Credential upgrade (residual risk in `infosec-signoff.md`) |
| **`@RestResource` / inbound** | header handling, guest/site auth, URL mapping | `WebhookResource` | re-run `WebhookResourceTest`; verify auth header still arrives |
| **Platform Events / CDC** | volume limits, publish behaviour, delivery semantics | `Transfer_Completed__e`, `Integration_Event__e` | `TransferCompletedHandlerTest`; check high-volume event limits |
| **Apex security** | `WITH USER_MODE` / `as user` semantics, FLS enforcement | used pervasively | `SecurityModelTest` is the canary |
| **Async/governor** | Queueable/Batch limits, callout limits | retry queueable, recon/interest batches | run batches on the preview org |
| **Code Analyzer / PMD** | new/changed rules, engine versions | scan gate (High threshold) | re-run scan; triage new High findings |

## Readiness procedure (per season)
1. Spin up a **preview (pre-release) org**; install the current package pair.
2. Run the full pipeline against it (scan, apex ≥ 85%, staging-install, e2e happy + forced-failure).
3. Run the **drift check** (`drift-policy.md`) after the upgrade — auto-enabled features change
   defaults; surface platform-introduced divergence.
4. Re-confirm the Named Credential + webhook secret config still authenticate.
5. Record findings + any required code change; schedule before the upgrade hits prod.

> Seasonal upgrades are the one source of drift that isn't human-introduced — the post-upgrade
> drift check is how we catch it (see `drift-policy.md` §Relationship to the seasonal release).
