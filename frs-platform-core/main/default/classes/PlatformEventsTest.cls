@isTest
private class PlatformEventsTest {
    private static final String U = 'core_evt_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId = p.Id, LastName = 'EvtTest', Email = 'core_evt_test@frsbank.invalid',
            Username = U, Alias = 'cevt', TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }
    private static User svc() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    @isTest
    static void publishIntegrationEvent_publishesAndLogs() {
        System.runAs(svc()) {
            Test.startTest();
            Database.SaveResult sr = PlatformEvents.publishIntegrationEvent(
                'transfer.completed', '{"account":123456789}', 'evt-1');
            Test.stopTest();
            System.assert(sr.isSuccess(), 'event publish should succeed');
            System.assertEquals(1, [SELECT COUNT() FROM Integration_Log__c
                WHERE Correlation_Id__c = 'evt-1' AND Category__c = 'Event' AND Status__c = 'Success'],
                'publish must write one Event log');
        }
    }

    @isTest
    static void publish_emptyList_returnsEmpty() {
        System.assertEquals(0, PlatformEvents.publish(new List<SObject>(), 'x').size());
        System.assertEquals(0, PlatformEvents.publish((List<SObject>) null, 'x').size());
    }
}
