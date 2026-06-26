@isTest
private class StatementInterestBatchTest {
    private static final String U = 'bank_interest_test@frsbank.invalid';

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(ProfileId = p.Id, LastName = 'IntTest', Email = U, Username = U,
                Alias = 'intb', TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert u;
            List<PermissionSetAssignment> asn = new List<PermissionSetAssignment>();
            for (PermissionSet x : [SELECT Id FROM PermissionSet
                    WHERE Name IN ('Banking_Servicing_Agent','Banking_Integration_User','Platform_Core_Consumer')]) {
                asn.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = x.Id));
            }
            insert asn;
        }
        // Balance_Minor__c is read-only to interactive permsets (core-owned) → seed in SYSTEM_MODE,
        // owned by the agent so the batch's WITH USER_MODE query (OWD Private) sees the rows.
        User agent = [SELECT Id FROM User WHERE Username = :U LIMIT 1];
        Account a = new Account(Name = 'Interest Cust', OwnerId = agent.Id);
        Database.insert(a, AccessLevel.SYSTEM_MODE);
        Database.insert(new List<Bank_Account__c>{
            new Bank_Account__c(Name = 'A1', Customer__c = a.Id, Core_Account_Id__c = 'i1',
                Type__c = 'Savings', Status__c = 'Active', Balance_Minor__c = 1000000, OwnerId = agent.Id),
            new Bank_Account__c(Name = 'A2', Customer__c = a.Id, Core_Account_Id__c = 'i2',
                Type__c = 'Savings', Status__c = 'Active', Balance_Minor__c = 1000000, OwnerId = agent.Id)
        }, AccessLevel.SYSTEM_MODE);
    }
    private static User agent() { return [SELECT Id FROM User WHERE Username = :U LIMIT 1]; }

    @isTest
    static void accruesInterestCredits() {
        System.runAs(agent()) {
            Test.startTest();
            Database.executeBatch(new StatementInterestBatch(), 200);
            Test.stopTest();
            List<Transaction__c> credits = [SELECT Amount_Minor__c, Direction__c FROM Transaction__c
                WHERE Description__c = 'Interest accrual'];
            System.assertEquals(2, credits.size(), 'one interest credit per active positive-balance account');
            System.assertEquals('Credit', credits[0].Direction__c);
            System.assertEquals(100, credits[0].Amount_Minor__c, '1bp of 1,000,000 = 100');
        }
    }

    @isTest
    static void schedulable_runs() {
        System.runAs(agent()) {
            Test.startTest();
            new StatementInterestBatch().execute((SchedulableContext) null);
            Test.stopTest();
            System.assertEquals(2, [SELECT COUNT() FROM Transaction__c WHERE Description__c = 'Interest accrual']);
        }
    }
}
