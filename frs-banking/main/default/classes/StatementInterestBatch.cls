/**
 * StatementInterestBatch (frs-banking) — bulkified async interest accrual over the ledger.
 *
 * Demonstrates async/batch + governor-limit-aware DML over many accounts (no callouts, pure
 * DML, default scope). Posts a daily interest Credit per active positive-balance account.
 * Idempotent per account per day via the unique External_Txn_Id__c ('int-<acct>-<date>') +
 * partial insert, so a re-run the same day adds nothing. Schedulable for nightly runs.
 */
public with sharing class StatementInterestBatch implements Database.Batchable<SObject>, Schedulable {

    private static final Decimal RATE_BPS = 1; // 0.01% (1 basis point) demo daily rate

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new StatementInterestBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, Balance_Minor__c FROM Bank_Account__c
            WHERE Status__c = 'Active' AND Balance_Minor__c > 0
            WITH USER_MODE
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Bank_Account__c> scope) {
        List<Transaction__c> credits = new List<Transaction__c>();
        String today = System.today().format();
        for (Bank_Account__c a : scope) {
            Long interest = (a.Balance_Minor__c * RATE_BPS / 10000).longValue();
            if (interest <= 0) {
                continue;
            }
            credits.add(new Transaction__c(
                External_Txn_Id__c = 'int-' + a.Id + '-' + today,
                Bank_Account__c = a.Id,
                Amount_Minor__c = interest,
                Direction__c = 'Credit',
                Description__c = 'Interest accrual',
                Posted_Date__c = Datetime.now()
            ));
        }
        if (!credits.isEmpty()) {
            Database.insert(credits, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public void finish(Database.BatchableContext ctx) {
        Logger.write(Logger.entry().category(Logger.SYSTEM_CATEGORY)
            .direction(Logger.OUTBOUND).status(Logger.SUCCESS)
            .alias('statement-interest').message('interest accrual batch finished'));
    }
}
