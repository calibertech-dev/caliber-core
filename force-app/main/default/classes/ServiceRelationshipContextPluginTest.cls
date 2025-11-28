@IsTest
private class ServiceRelationshipContextPluginTest {

    @IsTest
    static void enrichContext_usesExistingServiceRelationship() {
        // Arrange
        Account acc = new Account(Name = 'SR Account');
        insert acc;

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU - Existing SR',
            Short_Code__c             = 'SR1',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        insert sr;

        // Child record that points directly to Service Relationship
        Review_Request__c rr = new Review_Request__c(
            Service_Relationship__c = sr.Id
            // Intentionally not setting Account__c / Business_Unit__c;
            // plugin should derive those from SR
        );

        RelationshipContextService.RelationshipContext baseCtx =
            new RelationshipContextService.RelationshipContext();

        ServiceRelationshipContextPlugin plugin =
            new ServiceRelationshipContextPlugin();

        // Act
        RelationshipContextService.RelationshipContext ctx =
            plugin.enrichContext(rr, baseCtx);

        // Assert
        System.assertEquals(
            sr.Id,
            ctx.serviceRelationshipId,
            'Should use SR from Service_Relationship__c lookup'
        );
        System.assertEquals(
            acc.Id,
            ctx.accountId,
            'Account should come from Service Relationship'
        );
        System.assertEquals(
            bu.Id,
            ctx.businessUnitId,
            'Business Unit should come from Service Relationship'
        );
    }

    @IsTest
    static void enrichContext_createsServiceRelationshipWhenMissing() {
        // Arrange
        Account acc = new Account(Name = 'SR Create Account');
        insert acc;

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU - Create SR',
            Short_Code__c             = 'SR2',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        // Record with Account + BU, but no Service Relationship yet
        Review_Request__c rr = new Review_Request__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );

        RelationshipContextService.RelationshipContext baseCtx =
            new RelationshipContextService.RelationshipContext();
        baseCtx.accountId      = acc.Id;
        baseCtx.businessUnitId = bu.Id;

        ServiceRelationshipContextPlugin plugin =
            new ServiceRelationshipContextPlugin();

        Test.startTest();
        RelationshipContextService.RelationshipContext ctx =
            plugin.enrichContext(rr, baseCtx);
        Test.stopTest();

        // Assert
        System.assertNotEquals(
            null,
            ctx.serviceRelationshipId,
            'Plugin should create or find a Service Relationship'
        );

        Service_Relationship__c created = [
            SELECT Id, Account__c, Business_Unit__c
            FROM Service_Relationship__c
            WHERE Id = :ctx.serviceRelationshipId
            LIMIT 1
        ];

        System.assertEquals(
            acc.Id,
            created.Account__c,
            'SR should be linked to the Account from context'
        );
        System.assertEquals(
            bu.Id,
            created.Business_Unit__c,
            'SR should be linked to the Business Unit from context'
        );
    }
}
