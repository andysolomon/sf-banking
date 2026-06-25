/**
 * TransferService (frs-banking) — FR-2 money transfer.
 *
 * Idempotent + double-submit safe: the same idempotency key returns the existing Transfer__c
 * (pre-check), and Transfer__c.Idempotency_Key__c is unique (DB backstop for a concurrent
 * race). The outbound call to core-banking is **async** (TransferCalloutQueueable) — never a
 * callout inside the request/trigger transaction — and consumes the platform-core framework
 * (CalloutService + Idempotency-Key + dead-letter). No HTTP code lives here.
 */
public with sharing class TransferService {
    public class TransferException extends Exception {}

    public static Transfer__c initiate(Id fromAccountId, String toAccountId, Long amountMinor,
                                       String currencyCode, String idempotencyKey) {
        if (String.isBlank(idempotencyKey)) {
            throw new TransferException('idempotencyKey is required (double-submit safety)');
        }
        // Idempotency pre-check — a repeat submit returns the original, no second transfer.
        List<Transfer__c> existing = [
            SELECT Id, Status__c, Core_Transfer_Id__c, Idempotency_Key__c
            FROM Transfer__c WHERE Idempotency_Key__c = :idempotencyKey WITH USER_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }

        Transfer__c t = new Transfer__c(
            From_Account__c = fromAccountId,
            To_Account_Id__c = toAccountId,
            Amount_Minor__c = amountMinor,
            Currency_Code__c = currencyCode,
            Idempotency_Key__c = idempotencyKey,
            Correlation_Id__c = idempotencyKey,
            Status__c = 'Requested'
        );
        try {
            insert as user t;
        } catch (DmlException e) {
            // Unique-index backstop: concurrent double-submit → return the row that won.
            if (e.getMessage().containsIgnoreCase('DUPLICATE') || e.getMessage().containsIgnoreCase('duplicate value')) {
                List<Transfer__c> raced = [
                    SELECT Id, Status__c FROM Transfer__c
                    WHERE Idempotency_Key__c = :idempotencyKey WITH USER_MODE LIMIT 1
                ];
                if (!raced.isEmpty()) {
                    return raced[0];
                }
            }
            throw e;
        }

        // Async — the callout runs in its own transaction after this insert commits.
        System.enqueueJob(new TransferCalloutQueueable(t.Id));
        return t;
    }
}
