@isTest
private class ReconciliationBatchTest {
    private static final String U = 'bank_recon_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(ProfileId = p.Id, LastName = 'ReconTest', Email = U, Username = U,
                Alias = 'rcn', TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert u;
            Map<String, Id> ps = new Map<String, Id>();
            for (PermissionSet x : [SELECT Id, Name FROM PermissionSet
                    WHERE Name IN ('Banking_Servicing_Agent','Banking_Integration_User','Platform_Core_Consumer')]) {
                ps.put(x.Name, x.Id);
            }
            List<PermissionSetAssignment> asn = new List<PermissionSetAssignment>();
            for (Id pid : ps.values()) {
                asn.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = pid));
            }
            insert asn;
        }
        // Balance_Minor__c is read-only to every interactive permset (core-owned), so seed it
        // in SYSTEM_MODE — as the core integration would — but owned by the agent so the batch's
        // WITH USER_MODE query (OWD Private) can see it.
        User agent = [SELECT Id FROM User WHERE Username = :U LIMIT 1];
        Account a = new Account(Name = 'Recon Cust', OwnerId = agent.Id);
        Database.insert(a, AccessLevel.SYSTEM_MODE);
        // SF cached balance 100; the mock will report something else → mismatch.
        Database.insert(new Bank_Account__c(Name = 'Checking', Customer__c = a.Id, Core_Account_Id__c = 'abc',
            Type__c = 'Checking', Status__c = 'Active', Balance_Minor__c = 100, OwnerId = agent.Id),
            AccessLevel.SYSTEM_MODE);
    }
    private static User agent() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    private class BalanceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200);
            r.setBody('{"core_account_id":"abc","balance_minor":99999,"currency":"USD"}'); return r;
        }
    }

    @isTest
    static void mismatch_raisesCase() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new BalanceMock());
            Test.startTest();
            Database.executeBatch(new ReconciliationBatch(), 1);
            Test.stopTest();
            System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Subject LIKE 'Reconciliation mismatch:%'],
                'a balance mismatch must raise a Case');
        }
    }

    @isTest
    static void schedulable_enqueuesBatch() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new BalanceMock());
            Test.startTest();
            new ReconciliationBatch().execute((SchedulableContext) null);
            Test.stopTest();
            System.assert([SELECT COUNT() FROM Case WHERE Subject LIKE 'Reconciliation mismatch:%'] >= 0);
        }
    }
}
