/**
 * CalloutRetryQueueable (frs-platform-core) — async retry with exponential backoff.
 *
 * Enqueued by CalloutService.sendWithRetry on a transient failure. Each run re-attempts the
 * call; if it fails transiently and budget remains, it chains the next attempt with a longer
 * backoff (min(2^attempt, 10) minutes). When the budget is exhausted it hands the call to
 * DeadLetterService so it's captured, not lost.
 */
public class CalloutRetryQueueable implements Queueable, Database.AllowsCallouts {
    private CalloutRequest req;

    public CalloutRetryQueueable(CalloutRequest req) {
        this.req = req;
    }

    /** Bump the attempt, compute backoff, and enqueue. Delay is skipped under test. */
    public static void enqueue(CalloutRequest prior) {
        CalloutRequest next = cloneForRetry(prior);
        if (Test.isRunningTest()) {
            System.enqueueJob(new CalloutRetryQueueable(next));
        } else {
            Integer delay = (Integer) Math.min(Math.pow(2, next.attempt), 10); // exp backoff, cap 10 min
            System.enqueueJob(new CalloutRetryQueueable(next), delay);
        }
    }

    public void execute(QueueableContext ctx) {
        CalloutResult r = CalloutService.send(req);
        if (!r.isSuccess && r.isTransient() && req.attempt < req.maxRetries) {
            enqueue(req);
        } else if (!r.isSuccess) {
            DeadLetterService.capture(req, r);
        }
    }

    private static CalloutRequest cloneForRetry(CalloutRequest req) {
        CalloutRequest n = new CalloutRequest(req.method, req.path);
        n.body = req.body;
        n.correlationId = req.correlationId;
        n.idempotencyKey = req.idempotencyKey;
        n.maxRetries = req.maxRetries;
        n.timeoutMs = req.timeoutMs;
        n.category = req.category;
        n.attempt = req.attempt + 1;
        return n;
    }
}
