/**
 * PlatformEvents (frs-platform-core) — the EventBus publish enabler.
 *
 * A thin wrapper over EventBus.publish that adds structured logging (Category = Event) and a
 * uniform success/failure read, so consumers publish domain events (Phase 7's
 * Transfer_Completed__e, or the generic Integration_Event__e envelope) without touching the
 * raw EventBus or worrying about logging. Publish failures are logged as Errors for follow-up.
 */
public with sharing class PlatformEvents {

    /** Publish a batch of platform events; log the aggregate outcome. */
    public static List<Database.SaveResult> publish(List<SObject> events, String correlationId) {
        List<Database.SaveResult> results = new List<Database.SaveResult>();
        if (events == null || events.isEmpty()) {
            return results;
        }
        results = EventBus.publish(events);
        Integer ok = 0, failed = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                failed++;
            }
        }
        Logger.write(Logger.entry()
            .category(Logger.EVENT)
            .correlation(correlationId)
            .direction(Logger.OUTBOUND)
            .status(failed == 0 ? Logger.SUCCESS : Logger.ERROR)
            .alias(String.valueOf(events[0].getSObjectType()))
            .message('published ' + ok + ' ok / ' + failed + ' failed'));
        return results;
    }

    /** Publish a single event. */
    public static Database.SaveResult publish(SObject event, String correlationId) {
        return publish(new List<SObject>{ event }, correlationId)[0];
    }

    /** Convenience: publish the generic Integration_Event__e envelope. */
    public static Database.SaveResult publishIntegrationEvent(String topic, String payload, String correlationId) {
        Integration_Event__e e = new Integration_Event__e(
            Topic__c = topic,
            Payload__c = Logger.redact(payload),
            Correlation_Id__c = correlationId
        );
        return publish(e, correlationId);
    }
}
