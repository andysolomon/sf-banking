# Rollback Runbook — Banking App (two-package)

> Reverting a bad banking release. The **two-package dependency makes order the whole game**:
> you install core→banking, so you must roll back **banking→core** (reverse), and you can only
> downgrade core to a version the *currently installed* banking still depends on.

## Decision: downgrade-in-place vs uninstall
Per the todo-app rollback rehearsal, **in-place package-version downgrade is non-destructive
and fast** (it swaps code/metadata, preserves data) — prefer it. Destructive uninstall (which
deletes the package's data) is the last resort.

## Order (the load-bearing part)
A release installed **core `c2` → banking `b2`**. To roll back to **core `c1` / banking `b1`**:

1. **Banking first (the dependent):** install/downgrade `frs-banking` to `b1`.
   `sf package install --package <b1-SPV> --target-org prod`.
   - `b1` must depend on a core version ≤ what's installed. If `b1` needs `c1`, see step 2 — you
     may need to downgrade banking to a version compatible with the core you'll land on.
2. **Core second (the dependency):** downgrade `frs-platform-core` to `c1` only if `b1` does not
   require `c2`. Never downgrade core below what the installed banking depends on — the org
   blocks it, correctly defending the dependency.
3. **Verify** — smoke test (live balance callout, a webhook) confirms the prior behaviour.
4. **Post-install config is unaffected** — the Named Credential / webhook secret are per-org
   config, not package data, so they survive a downgrade.

## Data
Custom-object data (`Transfer__c`, `Transaction__c`, `Dead_Letter__c`, `Integration_Log__c`)
**persists** across an in-place downgrade. Field *removals* between versions can drop column
data — check the version diff before rolling back across a schema-shrinking version.

## When NOT to roll back
If the failure is a **transient integration outage** (core down), rollback is the wrong tool —
the framework already degrades (circuit-breaker + dead-letter) and recovers (replay). See
`integration-failure-runbook.md`. Roll back only for a **defect in our packaged code**.

## RTO
Target: in-place downgrade of the pair < 15 min mechanical (per the todo-app rehearsal, a
single-package in-place downgrade was ~17s; the pair is two installs). **Rehearse once per
major release** and record the measured time here.

> **Rehearsal log:** _pending — to be executed against prodtest/scratch and recorded (Phase 9 acceptance)._
