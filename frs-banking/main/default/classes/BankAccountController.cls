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

        // Untyped deserialize: the core JSON key "currency" is an Apex reserved word and
        // cannot be a typed-class member, so we read the body as a Map.
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object bm = body.get('balance_minor');

        BalanceView v = new BalanceView();
        v.accountId = bankAccountId;
        v.balanceMinor = (bm == null) ? null : Long.valueOf(String.valueOf(bm));
        v.currencyCode = (String) body.get('currency');
        v.asOf = (String) body.get('as_of');
        return v;
    }

    // DTO returned to the LWC.
    public class BalanceView {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Long balanceMinor;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String asOf;
    }
}
