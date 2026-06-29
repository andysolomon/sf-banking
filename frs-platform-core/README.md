# frs-platform-core — Platform Integration Library

> The reusable enabler package. An application team installs this, assigns one permission
> set, and gets **structured logging, a resilient callout framework (retry / backoff /
> idempotency / circuit-breaker), a dead-letter + replay store, and an event publisher** —
> without writing a line of `HttpRequest`/`EventBus` code or ever seeing an endpoint or secret.
>
> This README is the **explicit API** — you should be able to integrate from here without
> reading the internals. (`frs-banking` is the reference consumer; `getLiveBalance` in
> `BankAccountController` is a worked example.)

## Install & enable (4 steps)

1. **Install** the package (your pipeline installs `frs-platform-core` *before* your app —
   it's a 2GP dependency): `sf package install --package <core-version-id>`.
2. **Assign** the permission set to every user/integration identity that will call out or log:
   `sf org assign permset --name Platform_Core_Consumer`.
3. **Configure a Named Credential** per environment (post-install, never packaged — no secret
   in source; see ADR-004). Reference it by alias in the `path` you pass the framework.
4. **Call the API** (below). Done.

### Access model (2GP decision)
`frs-platform-core` is a **namespace-less unlocked package**, so its `public` Apex is visible
org-wide to consumer code — `global` is **not** required (that's only for namespaced managed
packages). The API is therefore plain `public`. If this ever becomes a namespaced/managed
package, the public API classes would need `global`.

---

## API

### 1. Callouts — `CalloutService`
Never build an `HttpRequest`. Describe the call; get a typed `CalloutResult`.

```apex
// Simple GET (e.g. read a balance) — one attempt, fail-soft on the typed result:
CalloutResult r = CalloutService.send(
    new CalloutRequest('GET', 'Core_Banking/api/accounts/' + acctId + '/balance').withCorrelation(correlationId));
if (r.isSuccess) {
    Map<String,Object> body = (Map<String,Object>) JSON.deserializeUntyped(r.body);
    ...
} // r.circuitOpen tells you it failed fast because the endpoint is unhealthy

// NOTE: CalloutService.httpGet(path, corr) still exists but returns a raw HttpResponse — it's
// the LEGACY method kept for backward compatibility (v0.1.0 consumers). New code uses send().

// Resilient POST (e.g. a transfer) — idempotency key + async retry with backoff:
CalloutService.httpPost(
    'Core_Banking/api/transfers',
    JSON.serialize(payload),
    correlationId,
    idempotencyKey,   // sent as Idempotency-Key header; makes retries safe
    3                 // max async retries; exhaustion → dead-letter (never lost)
);
```
- `path` is the **Named-Credential path** (`<NamedCredential>/<resource>`), never a URL.
- The **circuit breaker** fails fast (returns `circuitOpen=true`, no HTTP) when an endpoint has
  ≥ 5 errors in the last 5 minutes — protecting you and the downstream.
- Retries run in `CalloutRetryQueueable` (exponential backoff, capped at 10 min).
- For full control use `CalloutService.send(new CalloutRequest('POST', path).withBody(..).withRetries(..)..)`.

### 2. Logging — `Logger`
Every callout logs automatically. To log your own integration steps:
```apex
Logger.write(Logger.entry()
    .category(Logger.WEBHOOK).correlation(corrId)
    .direction(Logger.INBOUND).status(Logger.SUCCESS)
    .alias('Core_Banking/webhooks/posted-txn').message('processed txn'));
```
- `message` is **redacted** before persistence (`Logger.redact` masks long digit runs and
  token/secret/bearer values) — the `Integration_Log__c` trail is always PII/secret-safe.
- Best-effort: a logging failure never breaks your flow.

### 3. Dead-letter + replay — `DeadLetterService`
Exhausted callouts are captured to `Dead_Letter__c` automatically. To re-drive them:
```apex
DeadLetterService.replay(deadLetter);        // one letter, now
DeadLetterService.replayPending(50);          // bulk via DeadLetterReplayBatch (1 callout/txn)
```
Replay is **one callout per transaction** (the platform rule) — bulk replay always goes
through `DeadLetterReplayBatch` (scope 1); never loop callouts yourself.

### 4. Events — `PlatformEvents`
```apex
PlatformEvents.publish(myEvents, correlationId);                 // any platform event(s)
PlatformEvents.publishIntegrationEvent('transfer.completed',     // generic envelope
    JSON.serialize(payload), correlationId);
```
Wraps `EventBus.publish` with a logged, uniform success/failure read.

---

## What you must NOT do
- Don't put endpoints/secrets in Apex or metadata — use the Named Credential (NFR-5 / ADR-004).
- Don't loop callouts (DML-between-callouts fails) — use `httpPost` retries / the replay batch.
- Don't insert `Integration_Log__c` / `Dead_Letter__c` directly — go through `Logger` /
  `DeadLetterService` so redaction and user-mode CRUD are handled.

## Objects shipped
`Integration_Log__c` (audit trail), `Dead_Letter__c` (failed-call capture),
`Integration_Event__e` (generic event envelope). Permission set: `Platform_Core_Consumer`.
