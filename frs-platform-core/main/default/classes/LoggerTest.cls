@isTest
private class LoggerTest {
    private static final String TEST_USERNAME = 'core_logger_test@frsbank.invalid';

    @TestSetup
    static void makeUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId = p.Id, LastName = 'LogTest', Email = 'core_logger_test@frsbank.invalid',
            Username = TEST_USERNAME, Alias = 'clog', TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Platform_Core_Consumer' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }

    private static User svcUser() {
        return [SELECT Id FROM User WHERE Username = :TEST_USERNAME LIMIT 1];
    }

    @isTest
    static void redact_masksDigitsAndSecrets() {
        System.assertEquals('acct ****', Logger.redact('acct 123456789'), 'long digit runs must be masked');
        System.assert(Logger.redact('Authorization: Bearer abc123XYZ').containsIgnoreCase('****'),
            'bearer token must be masked');
        System.assert(!Logger.redact('token=supersecretvalue').contains('supersecretvalue'),
            'secret token value must not survive');
        System.assertEquals(null, Logger.redact(null), 'null in → null out');
        System.assertEquals('no secrets here', Logger.redact('no secrets here'), 'clean text is untouched');
    }

    @isTest
    static void write_persistsRedactedRow() {
        System.runAs(svcUser()) {
            Test.startTest();
            Logger.write(Logger.entry()
                .category(Logger.CALLOUT).correlation('log-1').direction(Logger.OUTBOUND)
                .status(Logger.SUCCESS).alias('Core_Banking/api/accounts/abc/balance')
                .message('balance for account 123456789 ok').retry(1));
            Test.stopTest();

            Integration_Log__c row = [
                SELECT Category__c, Status__c, Direction__c, Endpoint_Alias__c, Message__c, Retry_Count__c
                FROM Integration_Log__c WHERE Correlation_Id__c = 'log-1' LIMIT 1
            ];
            System.assertEquals('Callout', row.Category__c);
            System.assertEquals('Success', row.Status__c);
            System.assertEquals('Outbound', row.Direction__c);
            System.assertEquals(1, row.Retry_Count__c);
            System.assert(!row.Message__c.contains('123456789'), 'digits must be redacted in the persisted message');
        }
    }

    @isTest
    static void write_nullEntry_isNoOp() {
        Test.startTest();
        Logger.write(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Integration_Log__c], 'null entry writes nothing');
    }
}
