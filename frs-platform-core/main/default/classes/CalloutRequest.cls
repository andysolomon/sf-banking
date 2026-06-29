/**
 * CalloutRequest (frs-platform-core) — a fluent description of one outbound call.
 *
 * `path` is the Named-Credential path (e.g. 'Core_Banking/api/transfers') — never a URL.
 * Idempotency key (POST), async retry budget, and timeout are all opt-in. `attempt` is
 * managed by the retry framework (0 = first try).
 */
public class CalloutRequest {
    public String method = 'GET';
    public String path;
    public String body;
    public String correlationId;
    public String idempotencyKey;
    public Integer maxRetries = 0;
    public Integer timeoutMs = 10000;
    public String category = Logger.CALLOUT;
    public Integer attempt = 0;

    public CalloutRequest(String method, String path) {
        this.method = method;
        this.path = path;
    }

    public CalloutRequest withBody(String b) { this.body = b; return this; }
    public CalloutRequest withCorrelation(String c) { this.correlationId = c; return this; }
    public CalloutRequest withIdempotencyKey(String k) { this.idempotencyKey = k; return this; }
    public CalloutRequest withRetries(Integer n) { this.maxRetries = n; return this; }
    public CalloutRequest withTimeout(Integer ms) { this.timeoutMs = ms; return this; }
    public CalloutRequest withCategory(String c) { this.category = c; return this; }

    /** Endpoint alias for logging = the path (already secret-free). */
    public String alias() { return path; }
}
