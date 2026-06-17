/**
 * CalloutService (frs-platform-core) — the reusable outbound-callout enabler.
 *
 * v0.1.0 (walking skeleton): a generic GET via a Named Credential, with structured
 * logging to Integration_Log__c. The endpoint + secret live in the Named Credential
 * (alias passed in as `namedCredentialPath`), never in Apex — so no consumer ever sees a
 * URL or key (NFR-5 / ADR-004).
 *
 * Phase 6 will mature this into the full enabler: retry + exponential backoff, idempotency
 * keys, circuit-breaker, typed results, and dead-letter on exhaustion. Kept thin here so
 * the walking skeleton proves the integration spine end to end first.
 */
public with sharing class CalloutService {
    public class CalloutException extends Exception {}

    private static final Integer DEFAULT_TIMEOUT_MS = 10000;

    /**
     * GET `callout:<namedCredentialPath>`. Logs the attempt (redaction-safe: alias +
     * status + correlation id only) AFTER the send, so there is no DML-before-callout.
     */
    public static HttpResponse httpGet(String namedCredentialPath, String correlationId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCredentialPath);
        req.setMethod('GET');
        req.setTimeout(DEFAULT_TIMEOUT_MS);

        String status = 'Success';
        HttpResponse res;
        try {
            res = new Http().send(req);
            if (res.getStatusCode() >= 400) {
                status = 'Error';
            }
            return res;
        } catch (Exception e) {
            status = 'Error';
            throw new CalloutException('Callout failed for ' + namedCredentialPath + ': ' + e.getMessage());
        } finally {
            log(namedCredentialPath, correlationId, status);
        }
    }

    private static void log(String alias, String correlationId, String status) {
        // Best-effort structured log; never let logging failure mask the callout outcome.
        try {
            insert new Integration_Log__c(
                Correlation_Id__c = correlationId,
                Direction__c = 'Outbound',
                Status__c = status,
                Endpoint_Alias__c = alias
            );
        } catch (Exception ignored) {
            System.debug(LoggingLevel.WARN, 'Integration log insert failed: ' + ignored.getMessage());
        }
    }
}
