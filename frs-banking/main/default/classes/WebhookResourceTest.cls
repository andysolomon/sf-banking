@isTest
private class WebhookResourceTest {
    private static final String U = 'bank_integ_test@frsbank.invalid';
    private static final String SECRET = 's3cr3t-test';

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                ProfileId = p.Id, LastName = 'IntegTest', Email = U, Username = U, Alias = 'integ',
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            PermissionSet integPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Integration_User' LIMIT 1];
            PermissionSet corePs = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = integPs.Id),
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = corePs.Id)
            };
        }
        // Org-level webhook secret (non-setup DML, after the runAs-isolated user creation).
        insert new Webhook_Config__c(SetupOwnerId = UserInfo.getOrganizationId(), Shared_Secret__c = SECRET);
    }
    private static User integ() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    private static void request(String eventId, String token, String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/core-banking/webhooks/';
        req.httpMethod = 'POST';
        if (eventId != null) req.headers.put('X-Event-Id', eventId);
        if (token != null) req.headers.put('X-Webhook-Token', token);
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @isTest
    static void auth_badToken_401() {
        System.runAs(integ()) {
            request('e1', 'wrong-token', '{"event_type":"posted_transaction","txn_id":"t1"}');
            WebhookResource.handlePost();
            System.assertEquals(401, RestContext.response.statusCode);
            System.assertEquals(0, [SELECT COUNT() FROM Transaction__c]);
        }
    }

    @isTest
    static void postedTransaction_creates201() {
        System.runAs(integ()) {
            request('e-txn', SECRET,
                '{"event_type":"posted_transaction","txn_id":"core-tx-1","amount_minor":4200,"direction":"Debit","description":"Coffee"}');
            WebhookResource.handlePost();
            System.assertEquals(201, RestContext.response.statusCode);
            Transaction__c t = [SELECT External_Txn_Id__c, Amount_Minor__c, Direction__c FROM Transaction__c LIMIT 1];
            System.assertEquals('core-tx-1', t.External_Txn_Id__c);
            System.assertEquals(4200, t.Amount_Minor__c);
        }
    }

    @isTest
    static void replay_sameEventId_200_idempotent() {
        System.runAs(integ()) {
            String b = '{"event_type":"posted_transaction","txn_id":"core-tx-2","amount_minor":100,"direction":"Credit"}';
            request('e-dup', SECRET, b);
            WebhookResource.handlePost();           // first → 201
            request('e-dup', SECRET, b);
            WebhookResource.handlePost();           // replay → 200 ignored
            System.assertEquals(200, RestContext.response.statusCode);
            System.assertEquals(1, [SELECT COUNT() FROM Transaction__c WHERE External_Txn_Id__c = 'core-tx-2'],
                'replay must not create a second ledger row');
        }
    }

    @isTest
    static void fraudAlert_createsCase201() {
        System.runAs(integ()) {
            request('e-fraud', SECRET,
                '{"event_type":"fraud_alert","reason":"velocity","detail":"5 txns in 60s on card 4111111111111111"}');
            WebhookResource.handlePost();
            System.assertEquals(201, RestContext.response.statusCode);
            System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Subject LIKE 'Fraud alert:%']);
        }
    }

    @isTest
    static void missingEventId_400() {
        System.runAs(integ()) {
            request(null, SECRET, '{"event_type":"posted_transaction","txn_id":"x"}');
            WebhookResource.handlePost();
            System.assertEquals(400, RestContext.response.statusCode);
        }
    }

    @isTest
    static void unknownType_and_missingTxnId_400() {
        System.runAs(integ()) {
            request('e-unk', SECRET, '{"event_type":"nope"}');
            WebhookResource.handlePost();
            System.assertEquals(400, RestContext.response.statusCode);

            request('e-notxn', SECRET, '{"event_type":"posted_transaction"}');
            WebhookResource.handlePost();
            System.assertEquals(400, RestContext.response.statusCode);
        }
    }
}
