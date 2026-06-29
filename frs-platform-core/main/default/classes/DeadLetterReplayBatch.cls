/**
 * DeadLetterReplayBatch (frs-platform-core) — bulk replay of dead letters, one callout per
 * transaction (scope = 1). Run ad hoc (DeadLetterService.replayPending) or on a schedule.
 */
public with sharing class DeadLetterReplayBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private Integer max;

    public DeadLetterReplayBatch(Integer max) {
        this.max = (max == null || max <= 0) ? 200 : max;
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        String newStatus = DeadLetterService.NEW_STATUS;
        String failedStatus = DeadLetterService.FAILED;
        Integer lim = max;
        return Database.getQueryLocator([
            SELECT Id, Correlation_Id__c, Endpoint_Alias__c, Http_Method__c,
                   Idempotency_Key__c, Payload__c, Replay_Count__c, Status__c
            FROM Dead_Letter__c
            WHERE Status__c = :newStatus OR Status__c = :failedStatus
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT :lim
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Dead_Letter__c> scope) {
        // scope size is 1 (one callout per transaction).
        for (Dead_Letter__c dl : scope) {
            DeadLetterService.replay(dl);
        }
    }

    public void finish(Database.BatchableContext ctx) {
        Logger.write(Logger.entry().category(Logger.SYSTEM_CATEGORY)
            .direction(Logger.OUTBOUND).status(Logger.SUCCESS).alias('dead-letter-replay')
            .message('replay batch finished: ' + ctx.getJobId()));
    }
}
