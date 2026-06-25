@isTest
private class TransferCompletedHandlerTest {
    private static final String U = 'bank_evt_sub_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                ProfileId = p.Id, LastName = 'EvtSub', Email = U, Username = U, Alias = 'esub',
                TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            // Integration_User: Transaction__c read/create. Servicing_Agent: publish Transfer_Completed__e.
            PermissionSet integPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Integration_User' LIMIT 1];
            PermissionSet agentPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Servicing_Agent' LIMIT 1];
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = integPs.Id),
                new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = agentPs.Id)
            };
        }
    }
    private static User sub() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    @isTest
    static void event_projectsDebitToLedger() {
        System.runAs(sub()) {
            Test.startTest();
            EventBus.publish(new Transfer_Completed__e(
                Core_Transfer_Id__c = 'ct_99', Amount_Minor__c = 5000, Correlation_Id__c = 'corr-99'));
            Test.stopTest(); // subscriber fires (Automated Process, system mode)

            Transaction__c t = [SELECT External_Txn_Id__c, Direction__c, Amount_Minor__c
                                FROM Transaction__c WHERE External_Txn_Id__c = 'xfer-ct_99' LIMIT 1];
            System.assertEquals('Debit', t.Direction__c);
            System.assertEquals(5000, t.Amount_Minor__c);
        }
    }

    @isTest
    static void redelivery_isIdempotent() {
        System.runAs(sub()) {
            insert new Transaction__c(External_Txn_Id__c = 'xfer-ct_dup', Amount_Minor__c = 1, Direction__c = 'Debit');
            Test.startTest();
            EventBus.publish(new Transfer_Completed__e(
                Core_Transfer_Id__c = 'ct_dup', Amount_Minor__c = 1, Correlation_Id__c = 'c'));
            Test.stopTest();
            System.assertEquals(1, [SELECT COUNT() FROM Transaction__c WHERE External_Txn_Id__c = 'xfer-ct_dup'],
                're-delivered event must not duplicate the ledger row');
        }
    }
}
