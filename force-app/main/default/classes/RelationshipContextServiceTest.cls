@IsTest
private class RelationshipContextServiceTest {

    @IsTest
    static void resolve_usesAccountAndBusinessUnit_whenNoPlugin() {
        // Arrange
        Account acc = new Account(Name = 'Context Test Account');
        insert acc;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Test BU',
            Short_Code__c             = 'TBU',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555'
        );
        insert bu;

        // Use a Core object that has Account__c + Business_Unit__c
        Review_Request__c rr = new Review_Request__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        // No need to insert; we just care about field-reading logic.

        // Act
        RelationshipContextService.RelationshipContext ctx =
            RelationshipContextService.resolve(rr);

        // Assert
        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertEquals(
            acc.Id,
            ctx.accountId,
            'Expected accountId from Account__c'
        );
        System.assertEquals(
            bu.Id,
            ctx.businessUnitId,
            'Expected businessUnitId from Business_Unit__c'
        );
        System.assertEquals(
            null,
            ctx.serviceRelationshipId,
            'We are not populating Service Relationship yet'
        );
    }

    @IsTest
    static void resolve_handlesRecordWithNoRelevantFields() {
        Account acc = new Account(Name = 'Bare Account');

        RelationshipContextService.RelationshipContext ctx =
            RelationshipContextService.resolve(acc);

        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertEquals(
            null,
            ctx.accountId,
            'Plain Account should not resolve an accountId lookup'
        );
        System.assertEquals(
            null,
            ctx.businessUnitId,
            'No Business_Unit__c on Account'
        );
        System.assertEquals(
            null,
            ctx.serviceRelationshipId,
            'No Service Relationship logic yet'
        );
    }
}
