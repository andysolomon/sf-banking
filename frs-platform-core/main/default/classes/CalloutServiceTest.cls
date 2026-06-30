@isTest
private class CalloutServiceTest {
    private static final String U = 'core_callout_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId = p.Id, LastName = 'CalloutTest', Email = 'core_callout_test@frsbank.invalid',
            Username = U, Alias = 'ccal', TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }
    private static User svc() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    // --- mocks ---------------------------------------------------------------------------
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
    private class ThrowMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) { throw new CalloutException('boom'); }
    }
    private class FlakyMock implements HttpCalloutMock {
        Integer n = 0;
        public HttpResponse respond(HttpRequest req) {
            n++; HttpResponse r = new HttpResponse();
            r.setStatusCode(n == 1 ? 500 : 200); r.setBody('{"n":' + n + '}'); return r;
        }
    }

    @isTest
    static void httpGet_success_logsSuccess() {
        System.runAs(svc()) {
            Test.setMock(HttpCalloutMock.class, new OkMock());
            Test.startTest();
            // httpGet is the LEGACY HttpResponse method (back-compat); send() is the typed path.
            HttpResponse r = CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'c-ok');
            Test.stopTest();
            System.assertEquals(200, r.getStatusCode(), 'legacy httpGet returns HttpResponse');
            System.assertEquals(1, [SELECT COUNT() FROM Integration_Log__c
                WHERE Correlation_Id__c = 'c-ok' AND Status__c = 'Success']);
        }
    }

    @isTest
    static void send_errorStatus_isTransient() {
        System.runAs(svc()) {
            Test.setMock(HttpCalloutMock.class, new ErrMock());
            Test.startTest();
            CalloutResult r = CalloutService.send(
                new CalloutRequest('GET', 'Core_Banking/api/x').withCorrelation('c-err'));
            Test.stopTest();
            System.assert(!r.isSuccess);
            System.assertEquals(500, r.statusCode);
            System.assert(r.isTransient(), '5xx must be transient');
        }
    }

    @isTest
    static void send_transportError_isTransient() {
        System.runAs(svc()) {
            Test.setMock(HttpCalloutMock.class, new ThrowMock());
            Test.startTest();
            CalloutResult r = CalloutService.send(
                new CalloutRequest('GET', 'Core_Banking/api/x').withCorrelation('c-throw').withCategory(Logger.CALLOUT));
            Test.stopTest();
            System.assert(!r.isSuccess);
            System.assert(r.isTransient(), 'transport error must be transient');
            System.assertNotEquals(null, r.errorMessage);
        }
    }

    @isTest
    static void circuitBreaker_opensAfterThreshold() {
        System.runAs(svc()) {
            List<Integration_Log__c> seed = new List<Integration_Log__c>();
            for (Integer i = 0; i < 5; i++) {
                seed.add(new Integration_Log__c(Endpoint_Alias__c = 'Core_Banking/api/x',
                    Status__c = 'Error', Direction__c = 'Outbound', Category__c = 'Callout',
                    Correlation_Id__c = 'seed' + i));
            }
            insert seed;
            Test.setMock(HttpCalloutMock.class, new OkMock()); // would succeed, but breaker must skip it
            Test.startTest();
            CalloutResult r = CalloutService.send(
                new CalloutRequest('GET', 'Core_Banking/api/x').withCorrelation('c-breaker'));
            Test.stopTest();
            System.assert(r.circuitOpen, 'breaker should be open after 5 recent errors');
            System.assert(!r.isSuccess);
        }
    }

    @isTest
    static void sendWithRetry_exhausts_deadLetters() {
        System.runAs(svc()) {
            Test.setMock(HttpCalloutMock.class, new ErrMock());
            Test.startTest();
            CalloutService.httpPost('Core_Banking/api/transfers', '{"amt":100}', 'c-retry', 'idem-1', 1);
            Test.stopTest(); // the single async retry runs, fails again → dead-letter
            System.assertEquals(1, [SELECT COUNT() FROM Dead_Letter__c WHERE Correlation_Id__c = 'c-retry'],
                'exhausted retry must dead-letter');
        }
    }

    @isTest
    static void sendWithRetry_succeedsOnRetry_noDeadLetter() {
        System.runAs(svc()) {
            Test.setMock(HttpCalloutMock.class, new FlakyMock());
            Test.startTest();
            CalloutService.httpPost('Core_Banking/api/transfers', '{"amt":100}', 'c-flaky', 'idem-2', 1);
            Test.stopTest(); // first 500 → retry → 200 success
            System.assertEquals(0, [SELECT COUNT() FROM Dead_Letter__c WHERE Correlation_Id__c = 'c-flaky'],
                'a successful retry must not dead-letter');
        }
    }
}
