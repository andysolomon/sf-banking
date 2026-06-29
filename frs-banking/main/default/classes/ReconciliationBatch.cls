/**
 * ReconciliationBatch (frs-banking) — the daily integration SAFETY NET (FR / NFR-7).
 *
 * Behind idempotency + retries, drift still happens. This scheduled batch fetches each
 * account's LIVE balance from core-banking (via platform-core CalloutService) and compares it
 * to the Salesforce cached Balance_Minor__c. A mismatch raises a Case for a human to resolve.
 *
 * One callout per transaction → scope = 1 (same rule as DeadLetterReplayBatch). Schedulable so
 * it can run nightly: System.schedule('Daily Reconciliation', cron, new ReconciliationBatch()).
 */
public with sharing class ReconciliationBatch implements Database.Batchable<SObject>,
        Database.AllowsCallouts, Database.Stateful, Schedulable {

    private Integer mismatches = 0;

    // Schedulable entry point.
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new ReconciliationBatch(), 1);
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, Core_Account_Id__c, Balance_Minor__c
            FROM Bank_Account__c
            WHERE Core_Account_Id__c != null AND Status__c = 'Active'
            WITH USER_MODE
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Bank_Account__c> scope) {
        List<Case> cases = new List<Case>();
        for (Bank_Account__c acct : scope) {
            String corr = 'recon-' + acct.Id;
            CalloutResult r = CalloutService.httpGet(
                'Core_Banking/api/accounts/' + EncodingUtil.urlEncode(acct.Core_Account_Id__c, 'UTF-8') + '/balance',
                corr);
            if (!r.isSuccess) {
                continue; // core unreachable now — next run retries; not a drift signal
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.body);
            Object bm = body.get('balance_minor');
            Decimal coreBalance = (bm == null) ? null : Decimal.valueOf(String.valueOf(bm));
            Decimal sfBalance = acct.Balance_Minor__c;
            if (coreBalance != null && coreBalance != sfBalance) {
                mismatches++;
                cases.add(new Case(
                    Subject = 'Reconciliation mismatch: ' + acct.Id,
                    Status = 'New',
                    Origin = 'Web',
                    Description = 'SF cached balance ' + sfBalance + ' ≠ core balance ' + coreBalance
                ));
            }
        }
        if (!cases.isEmpty()) {
            Database.insert(cases, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public void finish(Database.BatchableContext ctx) {
        Logger.write(Logger.entry().category(Logger.RECONCILIATION)
            .direction(Logger.OUTBOUND).status(mismatches == 0 ? Logger.SUCCESS : Logger.ERROR)
            .alias('reconciliation').message('reconciliation finished: ' + mismatches + ' mismatch(es)'));
    }
}
