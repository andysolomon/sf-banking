/**
 * TransferCalloutQueueable (frs-banking) — the async outbound leg of FR-2.
 *
 * Runs the core-banking transfer callout via platform-core's CalloutService (carrying the
 * Idempotency-Key so a replay can't double-post). On success → Transfer Completed + publish
 * Transfer_Completed__e (FR-5). On a transient failure → Failed + dead-letter (recoverable
 * via DeadLetterReplayBatch). On a permanent (4xx) failure → Failed, no dead-letter.
 */
public with sharing class TransferCalloutQueueable implements Queueable, Database.AllowsCallouts {
    private Id transferId;

    public TransferCalloutQueueable(Id transferId) {
        this.transferId = transferId;
    }

    public void execute(QueueableContext ctx) {
        Transfer__c t = [
            SELECT Id, To_Account_Id__c, Amount_Minor__c, Currency_Code__c,
                   Idempotency_Key__c, Correlation_Id__c, Status__c
            FROM Transfer__c WHERE Id = :transferId WITH USER_MODE LIMIT 1
        ];

        Map<String, Object> payload = new Map<String, Object>{
            'to_account_id' => t.To_Account_Id__c,
            'amount_minor' => t.Amount_Minor__c,
            'currency' => t.Currency_Code__c
        };
        CalloutRequest req = new CalloutRequest('POST', 'Core_Banking/api/transfers')
            .withBody(JSON.serialize(payload))
            .withCorrelation(t.Correlation_Id__c)
            .withIdempotencyKey(t.Idempotency_Key__c);

        CalloutResult r = CalloutService.send(req);

        if (r.isSuccess) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.body);
            t.Core_Transfer_Id__c = (String) body.get('core_transfer_id');
            t.Status__c = 'Completed';
            update as user t;
            PlatformEvents.publish(new Transfer_Completed__e(
                Transfer_Record_Id__c = t.Id,
                Core_Transfer_Id__c = t.Core_Transfer_Id__c,
                Amount_Minor__c = t.Amount_Minor__c,
                Correlation_Id__c = t.Correlation_Id__c
            ), t.Correlation_Id__c);
        } else {
            t.Status__c = 'Failed';
            t.Failure_Reason__c = (r.errorMessage != null ? r.errorMessage : ('HTTP ' + r.statusCode));
            update as user t;
            if (r.isTransient()) {
                // Recoverable: capture for replay (DeadLetterReplayBatch re-drives, idempotency-safe).
                DeadLetterService.capture(req, r);
            }
        }
    }
}
