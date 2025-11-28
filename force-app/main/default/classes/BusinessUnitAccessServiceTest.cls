@IsTest
private class BusinessUnitAccessServiceTest {

    private static User getCurrentUser() {
        return [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    @IsTest
    static void getAffiliationsForUser_returnsEmptyForNullOrNoRows() {
        List<BusinessUnitAccessService.Affiliation> nullResult =
            BusinessUnitAccessService.getAffiliationsForUser(null);
        System.assertEquals(
            0,
            nullResult.size(),
            'Null userId should return empty list, not null.'
        );

        // Use a user with no affiliations
        User u = getCurrentUser();
        List<BusinessUnitAccessService.Affiliation> result =
            BusinessUnitAccessService.getAffiliationsForUser(u.Id);

        System.assertEquals(
            0,
            result.size(),
            'User with no affiliations should get empty list.'
        );
    }

    @IsTest
    static void getAffiliationsForUser_mapsFieldsCorrectly() {
        User u = getCurrentUser();

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Access BU',
            Short_Code__c             = 'ACC',
            Customer_Service_Email__c = 'cs-access@test.com',
            Customer_Service_Phone__c = '555-555-9999',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        Business_Unit_Affiliation__c bua = new Business_Unit_Affiliation__c(
            Business_Unit__c          = bu.Id,
            User__c                   = u.Id,
            Role__c                   = 'Manager',
            Is_Active__c              = true,
            Is_Primary__c             = true,
            Can_View_All_Records__c   = true,
            Can_Manage_Billing__c     = true
        );
        insert bua;

        List<BusinessUnitAccessService.Affiliation> result =
            BusinessUnitAccessService.getAffiliationsForUser(u.Id);

        System.assertEquals(1, result.size(), 'Exactly one affiliation should be returned.');
        BusinessUnitAccessService.Affiliation a = result[0];

        System.assertEquals(bua.Id, a.id, 'Id should map from BUA.Id.');
        System.assertEquals(u.Id, a.userId, 'userId should map from User__c.');
        System.assertEquals(bu.Id, a.businessUnitId, 'businessUnitId should map from Business_Unit__c.');
        System.assertEquals('Manager', a.role, 'role should map from Role__c.');
        System.assertEquals(true, a.isActive, 'isActive should map from Is_Active__c.');
        System.assertEquals(true, a.isPrimary, 'isPrimary should map from Is_Primary__c.');
        System.assertEquals(true, a.canViewAll, 'canViewAll should map from Can_View_All_Records__c.');
        System.assertEquals(true, a.canManageBilling, 'canManageBilling should map from Can_Manage_Billing__c.');
    }

    @IsTest
    static void userHasAccessToBusinessUnit_respectsActiveFlag() {
        User u = getCurrentUser();

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Access BU 2',
            Short_Code__c             = 'AC2',
            Customer_Service_Email__c = 'cs-access2@test.com',
            Customer_Service_Phone__c = '555-555-8888',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        // No affiliation yet → false
        System.assertEquals(
            false,
            BusinessUnitAccessService.userHasAccessToBusinessUnit(u.Id, bu.Id),
            'No affiliation should mean no access.'
        );

        // Inactive affiliation → still false
        Business_Unit_Affiliation__c inactiveAff = new Business_Unit_Affiliation__c(
            Business_Unit__c        = bu.Id,
            User__c                 = u.Id,
            Is_Active__c            = false,
            Can_View_All_Records__c = true
        );
        insert inactiveAff;

        System.assertEquals(
            false,
            BusinessUnitAccessService.userHasAccessToBusinessUnit(u.Id, bu.Id),
            'Inactive affiliation should not grant access.'
        );

        // Active affiliation → true
        inactiveAff.Is_Active__c = true;
        update inactiveAff;

        System.assertEquals(
            true,
            BusinessUnitAccessService.userHasAccessToBusinessUnit(u.Id, bu.Id),
            'Active affiliation should grant access.'
        );

        // Null arguments → false
        System.assertEquals(
            false,
            BusinessUnitAccessService.userHasAccessToBusinessUnit(null, bu.Id),
            'Null userId should return false.'
        );
        System.assertEquals(
            false,
            BusinessUnitAccessService.userHasAccessToBusinessUnit(u.Id, null),
            'Null businessUnitId should return false.'
        );
    }
}
