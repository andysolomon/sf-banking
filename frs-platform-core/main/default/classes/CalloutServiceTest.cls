@isTest
private class CalloutServiceTest {
    private static final String TEST_USERNAME = 'core_svc_test@frsbank.invalid';

    // Create a user holding Platform_Core_Consumer. In a package-version build org no
    // perm set is assigned to anyone, so the framework's own object (Integration_Log__c)
    // is invisible until a user has this grant — we run the assertions as that user.
    @TestSetup
    static void makeUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId = p.Id,
            LastName = 'CoreSvc',
            Email = 'core_svc_test@frsbank.invalid',
            Username = TEST_USERNAME,
            Alias = 'csvc',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }

    private static User svcUser() {
        return [SELECT Id FROM User WHERE Username = :TEST_USERNAME LIMIT 1];
    }

    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"balance_minor":250000,"currency":"USD"}');
            return res;
        }
    }
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"core banking unavailable"}');
            return res;
        }
    }
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('simulated timeout');
        }
    }

    @isTest
    static void httpGet_success_logsSuccess() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        Test.startTest();
        System.runAs(svcUser()) {
            HttpResponse res = CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-1');
            System.assertEquals(200, res.getStatusCode(), 'expected 200 from the mock');
            Integration_Log__c log = [SELECT Status__c, Direction__c FROM Integration_Log__c
                                      WHERE Correlation_Id__c = 'corr-1' LIMIT 1];
            System.assertEquals('Success', log.Status__c);
            System.assertEquals('Outbound', log.Direction__c);
        }
        Test.stopTest();
    }

    @isTest
    static void httpGet_errorStatus_logsError() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        System.runAs(svcUser()) {
            HttpResponse res = CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-2');
            System.assertEquals(500, res.getStatusCode());
            Integration_Log__c log = [SELECT Status__c FROM Integration_Log__c
                                      WHERE Correlation_Id__c = 'corr-2' LIMIT 1];
            System.assertEquals('Error', log.Status__c, '4xx/5xx must log Error');
        }
        Test.stopTest();
    }

    @isTest
    static void httpGet_thrown_wrapsAndLogsError() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Boolean threw = false;
        Test.startTest();
        System.runAs(svcUser()) {
            try {
                CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-3');
            } catch (CalloutService.CalloutException e) {
                threw = true;
            }
            System.assert(threw, 'a transport failure must surface as CalloutException');
            Integration_Log__c log = [SELECT Status__c FROM Integration_Log__c
                                      WHERE Correlation_Id__c = 'corr-3' LIMIT 1];
            System.assertEquals('Error', log.Status__c);
        }
        Test.stopTest();
    }
}
