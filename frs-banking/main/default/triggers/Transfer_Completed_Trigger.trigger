/**
 * Subscriber for Transfer_Completed__e (FR-5). Thin — delegates to TransferCompletedHandler.
 */
trigger Transfer_Completed_Trigger on Transfer_Completed__e (after insert) {
    TransferCompletedHandler.handle(Trigger.new);
}
