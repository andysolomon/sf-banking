/**
 * DeadLetterService (frs-platform-core) — capture + replay for exhausted integrations.
 *
 * When the retry framework gives up (CalloutRetryQueueable) it `capture()`s a Dead_Letter__c
 * holding the redacted payload + error so the call is never silently lost. `replay()` re-drives
 * captured letters through CalloutService and marks them Resolved/Failed. This is the
 * dead-letter + replay enabler Phase 7's transfer resilience consumes.
 */
public with sharing class DeadLetterService {

    public static final String NEW_STATUS = 'New';
    public static final String REPLAYING = 'Replaying';
    public static final String RESOLVED = 'Resolved';
    public static final String FAILED = 'Failed';

    /** Persist an exhausted call. Best-effort (never throws into the caller). */
    public static Dead_Letter__c capture(CalloutRequest req, CalloutResult result) {
        String err = 'unknown';
        Integer attempts = req.attempt + 1;
        if (result != null) {
            err = result.errorMessage != null ? result.errorMessage : ('HTTP ' + result.statusCode);
            attempts = result.attempts != null ? result.attempts : attempts;
        }
        Dead_Letter__c dl = new Dead_Letter__c(
            Correlation_Id__c = req.correlationId,
            Endpoint_Alias__c = req.alias(),
            Http_Method__c = req.method,
            Idempotency_Key__c = req.idempotencyKey,
            Payload__c = Logger.redact(req.body),
            Error__c = Logger.redact(err),
            Attempts__c = attempts,
            Status__c = NEW_STATUS,
            Replay_Count__c = 0
        );
        try {
            insert as user dl;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'dead-letter insert failed: ' + e.getMessage());
        }
        Logger.write(Logger.entry().category(Logger.SYSTEM_CATEGORY).correlation(req.correlationId)
            .direction(Logger.OUTBOUND).status(Logger.ERROR).alias(req.alias())
            .message('dead-lettered after ' + attempts + ' attempts').retry(req.attempt));
        return dl;
    }

    /**
     * Re-drive ONE letter: callout, then update its status. One callout per transaction is
     * the platform rule, so bulk replay runs through DeadLetterReplayBatch (scope = 1), never
     * a loop here — a loop would do DML between callouts and trip "uncommitted work pending".
     */
    public static void replay(Dead_Letter__c dl) {
        if (dl == null) {
            return;
        }
        CalloutRequest req = new CalloutRequest(dl.Http_Method__c, dl.Endpoint_Alias__c)
            .withBody(dl.Payload__c)
            .withCorrelation(dl.Correlation_Id__c)
            .withIdempotencyKey(dl.Idempotency_Key__c);
        CalloutResult r = CalloutService.send(req);
        dl.Replay_Count__c = (dl.Replay_Count__c == null ? 0 : dl.Replay_Count__c) + 1;
        dl.Status__c = r.isSuccess ? RESOLVED : FAILED;
        try {
            update as user dl;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'dead-letter replay update failed: ' + e.getMessage());
        }
    }

    /** Bulk replay: a Batchable with scope 1 (one callout per transaction). Returns the job id. */
    public static Id replayPending(Integer max) {
        return Database.executeBatch(new DeadLetterReplayBatch(max), 1);
    }

    /** Query the oldest pending (New/Failed) letters, bounded — the batch's work-list. */
    public static List<Dead_Letter__c> pending(Integer max) {
        String newStatus = NEW_STATUS;
        String failedStatus = FAILED;
        return [
            SELECT Id, Correlation_Id__c, Endpoint_Alias__c, Http_Method__c,
                   Idempotency_Key__c, Payload__c, Replay_Count__c, Status__c
            FROM Dead_Letter__c
            WHERE Status__c = :newStatus OR Status__c = :failedStatus
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT :max
        ];
    }
}
