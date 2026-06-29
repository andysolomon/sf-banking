/**
 * CalloutService (frs-platform-core) — the reusable outbound-callout enabler.
 *
 * One engine, `send(CalloutRequest)`, returns a typed `CalloutResult`. It wraps every call
 * with: the Named-Credential abstraction (`callout:<path>` — no URL/secret in code), a
 * **circuit-breaker** (fail fast when an endpoint is failing), structured **logging** via
 * Logger, an optional **Idempotency-Key** header (safe POST retries), and an opt-in
 * **async retry + exponential backoff** path (see CalloutRetryQueueable) that **dead-letters**
 * on exhaustion. Consumers never write HttpRequest/HttpResponse code (Phase 6 acceptance).
 *
 * Sync vs async: `send()` performs ONE attempt and returns immediately (used by reads like
 * FR-1 balance). `sendWithRetry()` does the first attempt, then — on a *transient* failure
 * with a retry budget — hands off to a Queueable so the caller isn't blocked (used by
 * writes like FR-2 transfer).
 */
public with sharing class CalloutService {
    public class CalloutException extends Exception {}

    // Circuit-breaker tuning (TestVisible so tests can tighten/loosen the window).
    @TestVisible private static Integer breakerThreshold = 5;
    @TestVisible private static Integer breakerWindowMinutes = 5;

    // ---- Convenience entry points -------------------------------------------------------

    /** Simple GET → typed result (used by FR-1 balance). */
    public static CalloutResult httpGet(String path, String correlationId) {
        return send(new CalloutRequest('GET', path).withCorrelation(correlationId));
    }

    /** POST with idempotency key + async retry budget (used by FR-2 transfer). */
    public static CalloutResult httpPost(String path, String body, String correlationId,
                                         String idempotencyKey, Integer maxRetries) {
        return sendWithRetry(new CalloutRequest('POST', path)
            .withBody(body).withCorrelation(correlationId)
            .withIdempotencyKey(idempotencyKey).withRetries(maxRetries));
    }

    // ---- Engine -------------------------------------------------------------------------

    /** One attempt: circuit-breaker check → HTTP → typed result + structured log. Never throws. */
    public static CalloutResult send(CalloutRequest req) {
        CalloutResult result = new CalloutResult();
        result.correlationId = req.correlationId;
        result.attempts = req.attempt + 1;
        String alias = req.alias();

        if (isCircuitOpen(serviceOf(req.path))) {
            result.isSuccess = false;
            result.circuitOpen = true;
            result.errorMessage = 'Circuit open for ' + serviceOf(req.path) + ' — failing fast';
            Logger.write(Logger.entry().category(req.category).correlation(req.correlationId)
                .direction(Logger.OUTBOUND).status(Logger.ERROR).alias(alias)
                .message('circuit open; skipped callout').retry(req.attempt));
            return result;
        }

        HttpRequest hr = new HttpRequest();
        hr.setEndpoint('callout:' + req.path);
        hr.setMethod(req.method);
        hr.setTimeout(req.timeoutMs);
        if (String.isNotBlank(req.body)) {
            hr.setBody(req.body);
            hr.setHeader('Content-Type', 'application/json');
        }
        if (String.isNotBlank(req.idempotencyKey)) {
            hr.setHeader('Idempotency-Key', req.idempotencyKey);
        }

        String status = Logger.SUCCESS;
        String msg;
        try {
            HttpResponse res = new Http().send(hr);
            result.statusCode = res.getStatusCode();
            result.body = res.getBody();
            result.isSuccess = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
            if (!result.isSuccess) {
                status = Logger.ERROR;
                msg = 'HTTP ' + res.getStatusCode();
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();
            status = Logger.ERROR;
            msg = 'transport error: ' + e.getMessage();
        }

        Logger.write(Logger.entry().category(req.category).correlation(req.correlationId)
            .direction(Logger.OUTBOUND).status(status).alias(alias).message(msg).retry(req.attempt));
        return result;
    }

    /**
     * First attempt synchronously; if it fails transiently and a retry budget remains, hand
     * off to CalloutRetryQueueable (async, exponential backoff). Returns the first result so
     * the caller can react immediately (e.g. "transfer accepted, settling").
     */
    public static CalloutResult sendWithRetry(CalloutRequest req) {
        CalloutResult result = send(req);
        if (!result.isSuccess && result.isTransient() && req.attempt < req.maxRetries) {
            CalloutRetryQueueable.enqueue(req);
        } else if (!result.isSuccess && req.maxRetries > 0 && req.attempt >= req.maxRetries) {
            DeadLetterService.capture(req, result);
        }
        return result;
    }

    // ---- Circuit breaker ----------------------------------------------------------------

    /** Open if ≥ threshold Error logs for this service in the recent window. */
    public static Boolean isCircuitOpen(String service) {
        if (String.isBlank(service)) {
            return false;
        }
        Datetime windowStart = Datetime.now().addMinutes(-breakerWindowMinutes);
        String aliasPrefix = service + '%';
        String errorStatus = Logger.ERROR;
        Integer errors = [
            SELECT COUNT()
            FROM Integration_Log__c
            WHERE Endpoint_Alias__c LIKE :aliasPrefix
              AND Status__c = :errorStatus
              AND CreatedDate >= :windowStart
            WITH USER_MODE
        ];
        return errors >= breakerThreshold;
    }

    /** Service name = the Named-Credential portion before the first '/'. */
    @TestVisible
    private static String serviceOf(String path) {
        if (String.isBlank(path)) {
            return path;
        }
        return path.contains('/') ? path.substringBefore('/') : path;
    }
}
