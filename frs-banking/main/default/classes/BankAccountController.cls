/**
 * BankAccountController (frs-banking) — walking-skeleton FR-1.
 *
 * Reads a Bank_Account__c (FLS-enforced) and fetches its LIVE balance from the external
 * core-banking system through frs-platform-core's CalloutService (Named Credential
 * abstraction — no endpoint/secret in this code). Fail-soft: on a non-200 the LWC shows
 * "temporarily unavailable" rather than an error page.
 *
 * No DML before the callout (we only read), so there is no uncommitted-work conflict.
 */
public with sharing class BankAccountController {

    @AuraEnabled
    public static BalanceView getLiveBalance(Id bankAccountId) {
        // FLS/CRUD-enforced read of the account we're servicing.
        List<Bank_Account__c> accts = [
            SELECT Id, Core_Account_Id__c
            FROM Bank_Account__c
            WHERE Id = :bankAccountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (accts.isEmpty()) {
            throw new AuraHandledException('Account not found or not accessible');
        }

        String correlationId = String.valueOf(System.now().getTime()) + '-' + bankAccountId;
        HttpResponse res = CalloutService.httpGet(
            'Core_Banking/api/accounts/' + EncodingUtil.urlEncode(accts[0].Core_Account_Id__c, 'UTF-8') + '/balance',
            correlationId
        );

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Balance temporarily unavailable');
        }

        CoreBalance cb = (CoreBalance) JSON.deserialize(res.getBody(), CoreBalance.class);
        BalanceView v = new BalanceView();
        v.accountId = bankAccountId;
        v.balanceMinor = cb.balance_minor;
        v.currency = cb.currency;
        v.asOf = cb.as_of;
        return v;
    }

    // DTO returned to the LWC.
    public class BalanceView {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Long balanceMinor;
        @AuraEnabled public String currency;
        @AuraEnabled public String asOf;
    }

    // Maps the core-banking JSON (snake_case) into Apex.
    public class CoreBalance {
        public Long balance_minor;
        public String currency;
        public String as_of;
        public String core_account_id;
    }
}
