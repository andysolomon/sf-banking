/**
 * SecurityModelTest (frs-banking) — Phase 8.2. Makes the financial-data security model
 * PROVABLE, not asserted: cross-customer isolation, read-only balance FLS, and the
 * least-privilege integration identity. Each is a negative test (the thing that must NOT
 * be possible) plus its positive control.
 */
@isTest
private class SecurityModelTest {
    private static final String AGENT_A = 'sec_agent_a@frsbank.invalid';
    private static final String AGENT_B = 'sec_agent_b@frsbank.invalid';
    private static final String INTEG   = 'sec_integ@frsbank.invalid';

    @TestSetup
    static void setup() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User a = newUser(p.Id, 'AgentA', AGENT_A, 'sa_a');
            User b = newUser(p.Id, 'AgentB', AGENT_B, 'sa_b');
            User i = newUser(p.Id, 'Integ', INTEG, 'sa_i');
            insert new List<User>{ a, b, i };
            Id agentPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Servicing_Agent' LIMIT 1].Id;
            Id integPs = [SELECT Id FROM PermissionSet WHERE Name = 'Banking_Integration_User' LIMIT 1].Id;
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = a.Id, PermissionSetId = agentPs),
                new PermissionSetAssignment(AssigneeId = b.Id, PermissionSetId = agentPs),
                new PermissionSetAssignment(AssigneeId = i.Id, PermissionSetId = integPs)
            };
        }
        // A Bank_Account owned by Agent A (OWD Private → only A's context can see it).
        User a = [SELECT Id FROM User WHERE Username = :AGENT_A LIMIT 1];
        System.runAs(a) {
            Account cust = new Account(Name = 'Customer A');
            insert cust;
            insert new Bank_Account__c(Name = 'A Checking', Customer__c = cust.Id,
                Core_Account_Id__c = 'acct-A', Type__c = 'Checking', Status__c = 'Active');
        }
    }

    private static User newUser(Id profileId, String last, String uname, String alias) {
        return new User(ProfileId = profileId, LastName = last, Email = uname, Username = uname,
            Alias = alias, TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
    }
    private static User u(String uname) { return [SELECT Id FROM User WHERE Username = :uname LIMIT 1]; }

    @isTest
    static void isolation_agentB_cannotSeeAgentA_account() {
        System.runAs(u(AGENT_B)) {
            System.assertEquals(0, [SELECT COUNT() FROM Bank_Account__c],
                'Agent B must NOT see Agent A\'s account (OWD Private, no sharing)');
        }
        System.runAs(u(AGENT_A)) {
            System.assertEquals(1, [SELECT COUNT() FROM Bank_Account__c],
                'Agent A sees the account they own (positive control)');
        }
    }

    @isTest
    static void balanceField_isReadOnly_forServicingAgent() {
        System.runAs(u(AGENT_A)) {
            // Describe must be evaluated INSIDE runAs to reflect the agent's FLS, not the
            // test-running user's.
            DescribeFieldResult bal = Bank_Account__c.Balance_Minor__c.getDescribe();
            System.assert(bal.isAccessible(), 'agent can READ the balance');
            System.assert(!bal.isUpdateable(), 'agent must NOT be able to WRITE the balance (core-owned)');
        }
    }

    @isTest
    static void balanceWrite_userMode_isBlocked() {
        System.runAs(u(AGENT_A)) {
            Bank_Account__c acct = [SELECT Id, Balance_Minor__c FROM Bank_Account__c LIMIT 1];
            acct.Balance_Minor__c = 999999;
            Boolean blocked = false;
            try {
                update as user acct; // user-mode DML enforces FLS → must fail on read-only balance
            } catch (Exception e) {
                blocked = true;
            }
            System.assert(blocked, 'a user-mode write to the read-only balance must be blocked');
        }
    }

    @isTest
    static void integrationUser_isLeastPrivilege() {
        System.runAs(u(INTEG)) {
            System.assert(!Schema.sObjectType.Bank_Account__c.isAccessible(),
                'integration user must NOT see Bank_Account__c (no balance/PII access)');
            System.assert(!Schema.sObjectType.Transfer__c.isAccessible(),
                'integration user must NOT touch transfers');
            System.assert(Schema.sObjectType.Transaction__c.isCreateable(),
                'integration user CAN create ledger Transactions (its job — positive control)');
        }
    }
}
