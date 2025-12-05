@IsTest
private class BusinessUnitFirewallServiceTest {

    private static Legal_Entity__c makeLegalEntity() {
        Legal_Entity__c le = new Legal_Entity__c(
            Name = 'Test Legal Entity'
        );
        insert le;
        return le;
    }

    @IsTest
    static void enforceBusinessUnitAccess_blocksUnauthorizedRecords() {
        Legal_Entity__c le = makeLegalEntity();

        // Enable the BusinessUnitFirewall feature for this test
        CaliberCoreFeatures.setForTest('BusinessUnitFirewall', true);

        Business_Unit__c buAllowed = new Business_Unit__c(
            Name                      = 'BU Enforce Allowed',
            Short_Code__c             = 'BEA',
            Legal_Entity__c           = le.Id,
            Customer_Service_Email__c = 'cse1@test.com',
            Customer_Service_Phone__c = '555-555-0001'
        );
        Business_Unit__c buBlocked = new Business_Unit__c(
            Name                      = 'BU Enforce Blocked',
            Short_Code__c             = 'BEB',
            Legal_Entity__c           = le.Id,
            Customer_Service_Email__c = 'cse2@test.com',
            Customer_Service_Phone__c = '555-555-0002'
        );
        insert new List<Business_Unit__c>{ buAllowed, buBlocked };

        Account acc = new Account(Name = 'Enforce SR Account');
        insert acc;

        // Two in-memory SRs, one in allowed BU, one in blocked BU
        Service_Relationship__c srAllowed = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = buAllowed.Id
        );
        Service_Relationship__c srBlocked = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = buBlocked.Id
        );

        List<SObject> sobjs = new List<SObject>{ srAllowed, srBlocked };

        String fwMsg = BusinessUnitFirewallService.getFirewallMessage();

        Test.startTest();
        // Inject the allowed BU set for this test
        BusinessUnitFirewallService.setTestAllowedBuIds(
            new Set<Id>{ buAllowed.Id }
        );

        // Run enforcement directly on in-memory records
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // Clear override so we don't leak into other tests
        BusinessUnitFirewallService.clearTestOverride();
        Test.stopTest();

        // Inspect errors on the in-memory records
        List<Database.Error> allowedErrors =
            ((Service_Relationship__c)sobjs[0]).getErrors();
        List<Database.Error> blockedErrors =
            ((Service_Relationship__c)sobjs[1]).getErrors();

        Boolean allowedHasFirewallError = false;
        for (Database.Error e : allowedErrors) {
            if (e.getMessage().contains(fwMsg)) {
                allowedHasFirewallError = true;
            }
        }

        Boolean blockedHasFirewallError = false;
        for (Database.Error e : blockedErrors) {
            if (e.getMessage().contains(fwMsg)) {
                blockedHasFirewallError = true;
            }
        }

        // Contract:
        // - Allowed BU record must NOT get the firewall error
        // - Disallowed BU record MUST get the firewall error
        System.assertEquals(
            false,
            allowedHasFirewallError,
            'Record in an allowed Business Unit should not get the firewall error.'
        );
        System.assertEquals(
            true,
            blockedHasFirewallError,
            'Record in a disallowed Business Unit should get the firewall error.'
        );
    }
}
