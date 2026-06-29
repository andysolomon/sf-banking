/**
 * Logger (frs-platform-core) — the platform logging/error enabler.
 *
 * One funnel for every integration log row (Integration_Log__c). Callers describe WHAT
 * happened (category, direction, status, correlation id, a human message); Logger handles
 * persistence, **payload-safe redaction**, and never lets a logging failure mask the
 * caller's real outcome (best-effort insert, swallowed on error).
 *
 * Redaction (NFR-5 / data-classification): the `message` is passed through `redact()`
 * before persistence — long digit runs (account/card numbers) and secret-like tokens are
 * masked, so an audit trail can never leak PII or credentials. Callers MUST pass the alias,
 * never a full URL or secret.
 *
 * DML runs `as user` (user-mode CRUD/FLS): consumers hold Platform_Core_Consumer, which
 * grants create on Integration_Log__c + its fields. A caller without that grant simply
 * gets no log row (best-effort), never an exception.
 */
public with sharing class Logger {

    // Category values — mirror Integration_Log__c.Category__c.
    public static final String CALLOUT = 'Callout';
    public static final String EVENT = 'Event';
    public static final String WEBHOOK = 'Webhook';
    public static final String RECONCILIATION = 'Reconciliation';
    public static final String SYSTEM_CATEGORY = 'System';

    // Direction / status tokens.
    public static final String OUTBOUND = 'Outbound';
    public static final String INBOUND = 'Inbound';
    public static final String SUCCESS = 'Success';
    public static final String ERROR = 'Error';

    /** A single log row, built fluently by the caller. */
    public class Entry {
        public String category = CALLOUT;
        public String correlationId;
        public String direction;
        public String status;
        public String endpointAlias;
        public String message;
        public Integer retryCount = 0;

        public Entry category(String v) { this.category = v; return this; }
        public Entry correlation(String v) { this.correlationId = v; return this; }
        public Entry direction(String v) { this.direction = v; return this; }
        public Entry status(String v) { this.status = v; return this; }
        public Entry alias(String v) { this.endpointAlias = v; return this; }
        public Entry message(String v) { this.message = v; return this; }
        public Entry retry(Integer v) { this.retryCount = v; return this; }
    }

    /** Start a new log entry. */
    public static Entry entry() {
        return new Entry();
    }

    /**
     * Persist an entry. Best-effort: redacts the message, inserts `as user`, and swallows
     * any failure (logging must never break the caller's flow).
     */
    public static void write(Entry e) {
        if (e == null) {
            return;
        }
        try {
            Integration_Log__c row = new Integration_Log__c(
                Category__c = e.category,
                Correlation_Id__c = e.correlationId,
                Direction__c = e.direction,
                Status__c = e.status,
                Endpoint_Alias__c = e.endpointAlias,
                Message__c = redact(e.message),
                Retry_Count__c = e.retryCount
            );
            insert as user row;
        } catch (Exception ignored) {
            System.debug(LoggingLevel.WARN, 'Integration log insert failed: ' + ignored.getMessage());
        }
    }

    /**
     * Mask PII and secret-like tokens so the audit trail is safe to keep.
     * - runs of 5+ digits (account / card / phone numbers) → ****
     * - bearer tokens and token/secret/api-key/password/authorization values → ****
     */
    public static String redact(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        String out = input;
        out = out.replaceAll('\\d{5,}', '****');
        out = out.replaceAll('(?i)(bearer\\s+)[A-Za-z0-9._\\-]+', '$1****');
        out = out.replaceAll('(?i)("?(?:token|secret|api[_-]?key|password|authorization)"?\\s*[:=]\\s*"?)[^"\\s,}]+', '$1****');
        return out;
    }
}
