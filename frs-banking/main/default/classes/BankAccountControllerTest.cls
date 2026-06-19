@isTest
private class BankAccountControllerTest {
    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"core_account_id":"core-abc","balance_minor":250000,"currency":"USD","as_of":"2026-06-17T00:00:00.000Z"}');
            return res;
        }
    }
    private class DownMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"core banking unavailable"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Ada Lovelace');
        insert a;
        insert new Bank_Account__c(
            Name = 'Checking',
            Customer__c = a.Id,
            Core_Account_Id__c = 'core-abc',
            Type__c = 'Checking',
            Status__c = 'Active'
        );
    }

    @isTest
    static void getLiveBalance_success_returnsBalance() {
        Bank_Account__c ba = [SELECT Id FROM Bank_Account__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OkMock());
        Test.startTest();
        BankAccountController.BalanceView v = BankAccountController.getLiveBalance(ba.Id);
        Test.stopTest();
        System.assertEquals(250000L, v.balanceMinor, 'balance should come from the core-banking response');
        System.assertEquals('USD', v.currencyCode);
    }

    @isTest
    static void getLiveBalance_coreDown_failsSoft() {
        Bank_Account__c ba = [SELECT Id FROM Bank_Account__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new DownMock());
        Boolean threw = false;
        Test.startTest();
        try {
            BankAccountController.getLiveBalance(ba.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'core-down must surface as AuraHandledException (LWC shows fail-soft message)');
    }
}
