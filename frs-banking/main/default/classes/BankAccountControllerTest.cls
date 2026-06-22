@isTest
private class BankAccountControllerTest {
    private static final String AGENT_USERNAME = 'bank_agent_test@frsbank.invalid';

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
        // Setup-object DML (User + PermissionSetAssignment) isolated in runAs(self) so it
        // doesn't mix with the data DML below (MIXED_DML_OPERATION otherwise).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                ProfileId = p.Id, LastName = 'BankAgent', Email = 'bank_agent_test@frsbank.invalid',
                Username = AGENT_USERNAME, Alias = 'bagt', TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Servicing_Agent' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        // The agent must SEE the account, but OWD is Private — so the agent OWNS it
        // (models a servicing book). The controller's WITH USER_MODE query then succeeds.
        Id agentId = [SELECT Id FROM User WHERE Username = :AGENT_USERNAME LIMIT 1].Id;
        Account a = new Account(Name = 'Ada Lovelace');
        insert a;
        insert new Bank_Account__c(
            Name = 'Checking', OwnerId = agentId, Customer__c = a.Id,
            Core_Account_Id__c = 'core-abc', Type__c = 'Checking', Status__c = 'Active'
        );
    }

    private static User agentUser() {
        return [SELECT Id FROM User WHERE Username = :AGENT_USERNAME LIMIT 1];
    }

    @isTest
    static void getLiveBalance_success_returnsBalance() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        Test.startTest();
        System.runAs(agentUser()) {
            Bank_Account__c ba = [SELECT Id FROM Bank_Account__c LIMIT 1];
            BankAccountController.BalanceView v = BankAccountController.getLiveBalance(ba.Id);
            System.assertEquals(250000L, v.balanceMinor, 'balance should come from the core-banking response');
            System.assertEquals('USD', v.currencyCode);
        }
        Test.stopTest();
    }

    @isTest
    static void getLiveBalance_coreDown_failsSoft() {
        Test.setMock(HttpCalloutMock.class, new DownMock());
        Boolean threw = false;
        Test.startTest();
        System.runAs(agentUser()) {
            Bank_Account__c ba = [SELECT Id FROM Bank_Account__c LIMIT 1];
            try {
                BankAccountController.getLiveBalance(ba.Id);
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();
        System.assert(threw, 'core-down must surface as AuraHandledException (LWC shows fail-soft message)');
    }
}
