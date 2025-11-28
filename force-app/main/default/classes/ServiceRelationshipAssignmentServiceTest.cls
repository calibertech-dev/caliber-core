@IsTest
private class ServiceRelationshipAssignmentServiceTest {

    @IsTest
    static void assign_createsAndReusesServiceRelationship_forGenericSObjects() {
        // Arrange
        Account acc = new Account(Name = 'SR Test Account');
        insert acc;

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU - SR Test',
            Short_Code__c             = 'SR1',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        // Use a Core object that has:
        // - Account__c
        // - Business_Unit__c
        // - Service_Relationship__c
        Review_Request__c r1 = new Review_Request__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        Review_Request__c r2 = new Review_Request__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );

        List<SObject> records = new List<SObject>{ r1, r2 };

        Test.startTest();
        ServiceRelationshipAssignmentService.assign(records);
        Test.stopTest();

        // Assert: both records should now have the same SR id in-memory
        System.assertNotEquals(
            null,
            r1.get('Service_Relationship__c'),
            'SR should be set on first record'
        );
        System.assertNotEquals(
            null,
            r2.get('Service_Relationship__c'),
            'SR should be set on second record'
        );
        System.assertEquals(
            (Id)r1.get('Service_Relationship__c'),
            (Id)r2.get('Service_Relationship__c'),
            'Both records should share the same SR'
        );

        // Verify only one Service Relationship was created
        List<Service_Relationship__c> srs = [
            SELECT Id, Account__c, Business_Unit__c
            FROM Service_Relationship__c
        ];
        System.assertEquals(1, srs.size(), 'Expected exactly one Service Relationship');
        System.assertEquals(acc.Id, srs[0].Account__c, 'SR Account should match');
        System.assertEquals(bu.Id, srs[0].Business_Unit__c, 'SR BU should match');
    }
}
