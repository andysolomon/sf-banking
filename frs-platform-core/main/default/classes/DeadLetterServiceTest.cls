@isTest
private class DeadLetterServiceTest {
    private static final String U = 'core_dl_test@frsbank.invalid';

    // Dead letters are committed in @TestSetup (as a perm-set user, isolated from the setup-
    // object DML to avoid MIXED_DML) so the replay callout has no uncommitted work pending.
    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                ProfileId = p.Id, LastName = 'DLTest', Email = 'core_dl_test@frsbank.invalid',
                Username = U, Alias = 'cdl', TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        User dlUser = [SELECT Id FROM User WHERE Username = :U LIMIT 1];
        System.runAs(dlUser) {
            insert new List<Dead_Letter__c>{
                new Dead_Letter__c(Correlation_Id__c = 'dl-1', Endpoint_Alias__c = 'Core_Banking/api/transfers',
                    Http_Method__c = 'POST', Payload__c = '{"amt":1}', Status__c = 'New', Replay_Count__c = 0),
                new Dead_Letter__c(Correlation_Id__c = 'dl-2', Endpoint_Alias__c = 'Core_Banking/api/transfers',
                    Http_Method__c = 'POST', Payload__c = '{"amt":2}', Status__c = 'New', Replay_Count__c = 0)
            };
        }
    }
    private static User svc() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(200); r.setBody('{"ok":true}'); return r;
        }
    }
    private class ErrMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse(); r.setStatusCode(500); r.setBody('{"error":"down"}'); return r;
        }
    }

    @isTest
    static void replayPending_success_marksResolved() {
        System.runAs(svc()) {
            // Batchable-in-test rule: start() must yield ≤ scope (1) records → one execute().
            // Resolve dl-2 up front so exactly one letter (dl-1) is pending for the batch.
            Dead_Letter__c other = [SELECT Id FROM Dead_Letter__c WHERE Correlation_Id__c = 'dl-2' LIMIT 1];
            other.Status__c = 'Resolved';
            update other;

            Test.setMock(HttpCalloutMock.class, new OkMock());
            Test.startTest();
            DeadLetterService.replayPending(10);
            Test.stopTest();

            Dead_Letter__c dl = [SELECT Status__c, Replay_Count__c FROM Dead_Letter__c
                                 WHERE Correlation_Id__c = 'dl-1' LIMIT 1];
            System.assertEquals('Resolved', dl.Status__c, 'successful replay → Resolved');
            System.assertEquals(1, dl.Replay_Count__c);
        }
    }

    @isTest
    static void replay_failure_marksFailed() {
        System.runAs(svc()) {
            Dead_Letter__c dl = [SELECT Id, Correlation_Id__c, Endpoint_Alias__c, Http_Method__c,
                Idempotency_Key__c, Payload__c, Replay_Count__c, Status__c
                FROM Dead_Letter__c WHERE Correlation_Id__c = 'dl-2' LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new ErrMock());
            Test.startTest();
            DeadLetterService.replay(dl);
            Test.stopTest();
            dl = [SELECT Status__c FROM Dead_Letter__c WHERE Id = :dl.Id];
            System.assertEquals('Failed', dl.Status__c, 'a failed replay → Failed');
        }
    }

    @isTest
    static void replay_null_isNoOp() {
        Test.startTest();
        DeadLetterService.replay((Dead_Letter__c) null);
        Test.stopTest();
        System.assertEquals(2, [SELECT COUNT() FROM Dead_Letter__c], 'no-op leaves the seeded rows untouched');
    }
}
