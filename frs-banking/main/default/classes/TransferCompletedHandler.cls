/**
 * TransferCompletedHandler (frs-banking) — FR-5 subscriber.
 *
 * Reacts to Transfer_Completed__e (published by TransferCalloutQueueable) and projects each
 * completed transfer into the Transaction__c ledger as an outbound debit. Runs from the
 * platform-event trigger as the Automated Process user, so DML is SYSTEM_MODE (the ledger
 * projection must persist regardless of any interactive user's FLS). Idempotent: the unique
 * External_Txn_Id__c (`xfer-<coreId>`) means a re-delivered event is skipped, not duplicated.
 *
 * Platform Event vs Change Data Capture (trade-off, ADR-worthy): we publish an explicit
 * **Platform Event** rather than relying on CDC because (a) it carries a purpose-built,
 * stable contract (the fields we need) instead of raw field deltas, (b) it decouples the
 * subscriber from the Transfer__c schema, and (c) replay/volume semantics are simpler. CDC
 * would avoid the publish step but couples subscribers to the source object and emits on
 * every field change. For an integration boundary, the explicit event is the cleaner contract.
 */
public with sharing class TransferCompletedHandler {

    public static void handle(List<Transfer_Completed__e> events) {
        List<Transaction__c> ledger = new List<Transaction__c>();
        for (Transfer_Completed__e e : events) {
            if (String.isBlank(e.Core_Transfer_Id__c)) {
                continue;
            }
            ledger.add(new Transaction__c(
                External_Txn_Id__c = 'xfer-' + e.Core_Transfer_Id__c,
                Amount_Minor__c = e.Amount_Minor__c,
                Direction__c = 'Debit',
                Description__c = 'Outbound transfer settled',
                Correlation_Id__c = e.Correlation_Id__c,
                Posted_Date__c = Datetime.now()
            ));
        }
        if (ledger.isEmpty()) {
            return;
        }
        // allOrNone = false → a re-delivered event hits the unique index and is skipped,
        // not failing the batch (idempotent subscriber).
        Database.insert(ledger, false, AccessLevel.SYSTEM_MODE);
        Logger.write(Logger.entry().category(Logger.EVENT).direction(Logger.INBOUND)
            .status(Logger.SUCCESS).alias('Transfer_Completed__e')
            .message('projected ' + ledger.size() + ' transfer(s) to ledger'));
    }
}
