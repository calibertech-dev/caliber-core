@IsTest
private class ServiceRelationshipNameServiceTest {

    @IsTest
    static void populateName_setsShortCodePlusAccountNumber_onInsert() {
        // Arrange
        Account acc = new Account(
            Name          = 'SR Name Test Account',
            AccountNumber = '00001234' // explicitly set so we don't depend on AccountNumberGenerator
        );
        insert acc;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU - Name Test',
            Short_Code__c             = 'CHS',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555'
        );
        insert bu;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
            // Name intentionally left null to allow auto-population
        );

        Test.startTest();
        insert sr;
        Test.stopTest();

        // Reload to verify
        Service_Relationship__c reloaded = [
            SELECT Id, Name, Account__c, Business_Unit__c
            FROM Service_Relationship__c
            WHERE Id = :sr.Id
            LIMIT 1
        ];

        System.assertEquals(
            'CHS00001234',
            reloaded.Name,
            'Service Relationship Name should be Short_Code__c + Account.AccountNumber'
        );
        System.assertEquals(
            acc.Id,
            reloaded.Account__c,
            'Account__c should be preserved'
        );
        System.assertEquals(
            bu.Id,
            reloaded.Business_Unit__c,
            'Business_Unit__c should be preserved'
        );
    }

    @IsTest
    static void populateName_doesNotOverwriteExistingName() {
        // Arrange
        Account acc = new Account(
            Name          = 'SR Existing Name Account',
            AccountNumber = '00009999'
        );
        insert acc;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU - Existing Name',
            Short_Code__c             = 'VVG',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555'
        );
        insert bu;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id,
            Name             = 'CUSTOMNAME'
        );

        Test.startTest();
        insert sr;
        Test.stopTest();

        Service_Relationship__c reloaded = [
            SELECT Id, Name
            FROM Service_Relationship__c
            WHERE Id = :sr.Id
            LIMIT 1
        ];

        System.assertEquals(
            'CUSTOMNAME',
            reloaded.Name,
            'Existing Name should not be overwritten by the auto-population logic'
        );
    }
}
