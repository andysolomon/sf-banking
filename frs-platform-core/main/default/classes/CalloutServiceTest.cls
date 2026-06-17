@isTest
private class CalloutServiceTest {
    // --- mocks ---------------------------------------------------------------
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
        HttpResponse res = CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-1');
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode(), 'expected 200 from the mock');
        Integration_Log__c log = [SELECT Status__c, Direction__c, Endpoint_Alias__c
                                  FROM Integration_Log__c WHERE Correlation_Id__c = 'corr-1' LIMIT 1];
        System.assertEquals('Success', log.Status__c);
        System.assertEquals('Outbound', log.Direction__c);
    }

    @isTest
    static void httpGet_errorStatus_logsError() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        HttpResponse res = CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-2');
        Test.stopTest();

        System.assertEquals(500, res.getStatusCode());
        Integration_Log__c log = [SELECT Status__c FROM Integration_Log__c WHERE Correlation_Id__c = 'corr-2' LIMIT 1];
        System.assertEquals('Error', log.Status__c, '4xx/5xx must log Error');
    }

    @isTest
    static void httpGet_thrown_wrapsAndLogsError() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Boolean threw = false;
        Test.startTest();
        try {
            CalloutService.httpGet('Core_Banking/api/accounts/abc/balance', 'corr-3');
        } catch (CalloutService.CalloutException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'a transport failure must surface as CalloutException');
        Integration_Log__c log = [SELECT Status__c FROM Integration_Log__c WHERE Correlation_Id__c = 'corr-3' LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }
}
