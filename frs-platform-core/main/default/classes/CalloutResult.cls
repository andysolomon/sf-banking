/**
 * CalloutResult (frs-platform-core) — the typed outcome of a callout.
 *
 * Consumers branch on `isSuccess` and read `statusCode`/`body`; they never touch
 * HttpResponse. `circuitOpen` distinguishes a fail-fast (breaker) from a real attempt.
 */
public class CalloutResult {
    @AuraEnabled public Boolean isSuccess = false;
    @AuraEnabled public Integer statusCode;
    @AuraEnabled public String body;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public Integer attempts = 0;
    @AuraEnabled public Boolean circuitOpen = false;
    @AuraEnabled public String correlationId;

    /** Transient = worth retrying: transport error (no/!2xx-!4xx), 5xx, or 429. */
    public Boolean isTransient() {
        if (statusCode == null) {
            return true; // transport-level failure (timeout, connection)
        }
        return statusCode >= 500 || statusCode == 429;
    }
}
