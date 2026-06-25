/**
 * WebhookResource (frs-banking) — inbound webhooks from core-banking (FR-3 / FR-4).
 *
 * POST /services/apexrest/core-banking/webhooks/*. Defense in depth, in order:
 *   1. Auth — a shared-secret `X-Webhook-Token` header checked against Webhook_Config__c
 *      (value set per-org post-install, never in source).
 *   2. Replay protection — the `X-Event-Id` header is recorded in Webhook_Event__c (unique);
 *      a repeated delivery fails the unique insert and is acknowledged (200) without reprocessing.
 *   3. Validation — required fields per event type.
 * Then routes: `posted_transaction` → Transaction__c (ledger), `fraud_alert` → Case.
 * Every call is logged (Category = Webhook, Direction = Inbound) via platform-core Logger.
 */
@RestResource(urlMapping='/core-banking/webhooks/*')
global with sharing class WebhookResource {

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String eventId = header(req, 'X-Event-Id');
        String corr = String.isBlank(eventId) ? 'wh-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)) : eventId;

        if (!authorized(req)) {
            respond(res, 401, '{"error":"unauthorized"}');
            log(corr, Logger.ERROR, 'auth failed');
            return;
        }
        if (String.isBlank(eventId)) {
            respond(res, 400, '{"error":"X-Event-Id header required"}');
            return;
        }

        Map<String, Object> body;
        try {
            body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        } catch (Exception e) {
            respond(res, 400, '{"error":"invalid JSON"}');
            return;
        }
        String eventType = str(body.get('event_type'));
        if (String.isBlank(eventType)) {
            respond(res, 400, '{"error":"event_type required"}');
            return;
        }

        // Replay guard — record the event id first (unique). Duplicate = already processed.
        try {
            insert as user new Webhook_Event__c(
                Event_Id__c = eventId, Event_Type__c = eventType, Correlation_Id__c = corr);
        } catch (DmlException e) {
            if (isDuplicate(e)) {
                respond(res, 200, '{"status":"duplicate-ignored"}');
                log(corr, Logger.SUCCESS, 'replay ignored: ' + eventType);
                return;
            }
            respond(res, 500, '{"error":"processing failed"}');
            log(corr, Logger.ERROR, 'event-record insert failed');
            return;
        }

        if (eventType == 'posted_transaction') {
            postedTransaction(body, res, corr);
        } else if (eventType == 'fraud_alert') {
            fraudAlert(body, res, corr);
        } else {
            respond(res, 400, '{"error":"unknown event_type"}');
            log(corr, Logger.ERROR, 'unknown event_type: ' + eventType);
        }
    }

    private static void postedTransaction(Map<String, Object> body, RestResponse res, String corr) {
        String extId = str(body.get('txn_id'));
        if (String.isBlank(extId)) {
            respond(res, 400, '{"error":"txn_id required"}');
            return;
        }
        Transaction__c t = new Transaction__c(
            External_Txn_Id__c = extId,
            Amount_Minor__c = num(body.get('amount_minor')),
            Direction__c = str(body.get('direction')),
            Description__c = str(body.get('description')),
            Correlation_Id__c = corr,
            Posted_Date__c = Datetime.now()
        );
        insert as user t;
        respond(res, 201, '{"status":"created","id":"' + t.Id + '"}');
        log(corr, Logger.SUCCESS, 'posted txn ' + extId);
    }

    private static void fraudAlert(Map<String, Object> body, RestResponse res, String corr) {
        Case c = new Case(
            Subject = 'Fraud alert: ' + str(body.get('reason')),
            Status = 'New',
            Origin = 'Web',
            Description = Logger.redact(str(body.get('detail')))
        );
        insert as user c;
        respond(res, 201, '{"status":"created","id":"' + c.Id + '"}');
        log(corr, Logger.SUCCESS, 'fraud alert → case ' + c.Id);
    }

    // ---- helpers ----
    private static Boolean authorized(RestRequest req) {
        String token = header(req, 'X-Webhook-Token');
        Webhook_Config__c cfg = Webhook_Config__c.getOrgDefaults();
        String expected = (cfg == null) ? null : cfg.Shared_Secret__c;
        return String.isNotBlank(expected) && expected == token;
    }
    private static Boolean isDuplicate(DmlException e) {
        return e.getMessage().containsIgnoreCase('DUPLICATE') || e.getMessage().containsIgnoreCase('duplicate value');
    }
    private static String header(RestRequest req, String key) {
        return (req != null && req.headers != null) ? req.headers.get(key) : null;
    }
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
    private static Decimal num(Object o) { return o == null ? null : Decimal.valueOf(String.valueOf(o)); }
    private static void respond(RestResponse res, Integer code, String body) {
        res.statusCode = code;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(body);
    }
    private static void log(String corr, String status, String msg) {
        Logger.write(Logger.entry().category(Logger.WEBHOOK).correlation(corr)
            .direction(Logger.INBOUND).status(status).alias('core-banking/webhooks').message(msg));
    }
}
