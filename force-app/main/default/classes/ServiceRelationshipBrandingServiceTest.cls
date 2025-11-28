@IsTest
private class ServiceRelationshipBrandingServiceTest {

    @IsTest
    static void forBusinessUnit_populatesBrandingContext() {

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        // Arrange
        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Branding BU',
            Short_Name__c             = 'Brand BU',
            Short_Code__c             = 'CHS',
            Website__c                = 'https://example.com',
            Support_Email__c          = 'support@example.com',
            Support_Phone__c          = '555-000-0001',
            Customer_Service_Email__c = 'cs@example.com',
            Customer_Service_Phone__c = '555-000-0002',
            No_Reply_Email__c         = 'noreply@example.com',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        Business_Unit_Branding__c branding = new Business_Unit_Branding__c(
            Business_Unit__c = bu.Id,
            Logo_URL__c      = 'https://example.com/logo.png',
            Primary_Color__c = '#112233',
            Accent_Color__c  = '#445566'
        );
        insert branding;

        // Act
        ServiceRelationshipBrandingService.BrandingContext ctx =
            ServiceRelationshipBrandingService.forBusinessUnit(bu.Id);

        // Assert
        System.assertEquals(bu.Id, ctx.businessUnitId, 'BU Id should match');
        System.assertEquals('Branding BU', ctx.businessUnitName);
        System.assertEquals('Brand BU', ctx.businessUnitShortName);
        System.assertEquals('CHS', ctx.businessUnitShortCode);
        System.assertEquals('https://example.com', ctx.website);

        System.assertEquals('support@example.com', ctx.supportEmail);
        System.assertEquals('555-000-0001', ctx.supportPhone);
        System.assertEquals('cs@example.com', ctx.customerServiceEmail);
        System.assertEquals('555-000-0002', ctx.customerServicePhone);
        System.assertEquals('noreply@example.com', ctx.noReplyEmail);

        System.assertEquals(branding.Id, ctx.brandingId);
        System.assertEquals('https://example.com/logo.png', ctx.logoUrl);
        System.assertEquals('#112233', ctx.primaryColor);
        System.assertEquals('#445566', ctx.accentColor);
    }
}
