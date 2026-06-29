@isTest
private class TransferServiceTest {
    private static final String U = 'bank_transfer_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        // Setup-object DML (User + perm-set assignments) isolated from data DML (MIXED_DML).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                ProfileId = p.Id, LastName = 'XferTest', Email = U, Username = U, Alias = 'xfer',
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            PermissionSet appPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Servicing_Agent' LIMIT 1];
            PermissionSet corePs = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = appPs.Id),
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = corePs.Id)
            };
        }
        User agent = [SELECT Id FROM User WHERE Username = :U LIMIT 1];
        System.runAs(agent) {
            Account a = new Account(Name = 'Ada Lovelace');
            insert a;
            insert new Bank_Account__c(Name = 'Checking', Customer__c = a.Id,
                Core_Account_Id__c = 'abc', Type__c = 'Checking', Status__c = 'Active');
        }
    }
    private static User agent() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }
    private static Id fromAcct() { return [SELECT Id FROM Bank_Account__c LIMIT 1].Id; }

    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200);
            r.setBody('{"core_transfer_id":"ct_1","status":"completed"}'); return r;
        }
    }
    private class ErrMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(500); r.setBody('{"error":"down"}'); return r;
        }
    }
    private class BadReqMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(400); r.setBody('{"error":"bad"}'); return r;
        }
    }

    @isTest
    static void initiate_blankKey_throws() {
        System.runAs(agent()) {
            Boolean threw = false;
            try {
                TransferService.initiate(fromAcct(), 'dest', 1000, 'USD', null);
            } catch (TransferService.TransferException e) {
                threw = true;
            }
            System.assert(threw, 'a blank idempotency key must be rejected');
        }
    }

    @isTest
    static void initiate_idempotent_noDoublePost() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new OkMock());
            Test.startTest();
            Transfer__c first = TransferService.initiate(fromAcct(), 'dest', 1000, 'USD', 'k-idem');
            Transfer__c second = TransferService.initiate(fromAcct(), 'dest', 1000, 'USD', 'k-idem');
            Test.stopTest();
            System.assertEquals(first.Id, second.Id, 'same key must return the same transfer');
            System.assertEquals(1, [SELECT COUNT() FROM Transfer__c WHERE Idempotency_Key__c = 'k-idem'],
                'no double-post');
        }
    }

    @isTest
    static void transfer_success_completesAndPublishes() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new OkMock());
            Test.startTest();
            TransferService.initiate(fromAcct(), 'dest', 2500, 'USD', 'k-ok');
            Test.stopTest(); // async callout runs here
            Transfer__c t = [SELECT Status__c, Core_Transfer_Id__c FROM Transfer__c WHERE Idempotency_Key__c = 'k-ok'];
            System.assertEquals('Completed', t.Status__c);
            System.assertEquals('ct_1', t.Core_Transfer_Id__c);
            System.assertEquals(1, [SELECT COUNT() FROM Integration_Log__c
                WHERE Correlation_Id__c = 'k-ok' AND Category__c = 'Event'], 'Transfer_Completed__e published + logged');
        }
    }

    @isTest
    static void transfer_transientFailure_failsAndDeadLetters() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new ErrMock());
            Test.startTest();
            TransferService.initiate(fromAcct(), 'dest', 2500, 'USD', 'k-500');
            Test.stopTest();
            Transfer__c t = [SELECT Status__c FROM Transfer__c WHERE Idempotency_Key__c = 'k-500'];
            System.assertEquals('Failed', t.Status__c);
            System.assertEquals(1, [SELECT COUNT() FROM Dead_Letter__c WHERE Correlation_Id__c = 'k-500'],
                'a transient failure is captured for replay');
        }
    }

    @isTest
    static void transfer_permanentFailure_failsNoDeadLetter() {
        System.runAs(agent()) {
            Test.setMock(HttpCalloutMock.class, new BadReqMock());
            Test.startTest();
            TransferService.initiate(fromAcct(), 'dest', 2500, 'USD', 'k-400');
            Test.stopTest();
            Transfer__c t = [SELECT Status__c FROM Transfer__c WHERE Idempotency_Key__c = 'k-400'];
            System.assertEquals('Failed', t.Status__c);
            System.assertEquals(0, [SELECT COUNT() FROM Dead_Letter__c WHERE Correlation_Id__c = 'k-400'],
                'a 4xx is permanent — not dead-lettered');
        }
    }
}
