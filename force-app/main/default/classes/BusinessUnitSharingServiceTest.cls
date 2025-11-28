@IsTest
private class BusinessUnitSharingServiceTest {

    private static User getCurrentUser() {
        return [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    @IsTest
    static void recalc_sharesServiceRelationshipsByAffiliation() {
        User u = getCurrentUser();

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        // BU and SR
        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Test BU',
            Short_Code__c             = 'TBU',
            Customer_Service_Email__c = 'cs@test.com',
            Customer_Service_Phone__c = '555-555-0000',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        insert sr;

        Test.startTest();

        // No affiliations yet → BU sharing should do nothing
        BusinessUnitObjectSharingService.skipDmlForTest = true;
        BusinessUnitObjectSharingService.lastInsertedShares.clear();
        BusinessUnitObjectSharingService.lastDeletedShares.clear();

        BusinessUnitSharingService.recalcForServiceRelationships(
            new Set<Id>{ sr.Id }
        );

        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastInsertedShares.size(),
            'No affiliations – no BU-driven shares expected.'
        );
        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastDeletedShares.size(),
            'No affiliations – nothing to delete either.'
        );

        // Create an active affiliation
        Business_Unit_Affiliation__c aff = new Business_Unit_Affiliation__c(
            Business_Unit__c        = bu.Id,
            User__c                 = u.Id,
            Is_Active__c            = true,
            Can_View_All_Records__c = true
        );
        insert aff;

        // Recalc via affiliation path
        BusinessUnitObjectSharingService.lastInsertedShares.clear();
        BusinessUnitObjectSharingService.lastDeletedShares.clear();

        BusinessUnitSharingService.recalcForAffiliations(
            new List<Business_Unit_Affiliation__c>{ aff },
            null
        );

        Test.stopTest();

        List<SObject> inserted = BusinessUnitObjectSharingService.lastInsertedShares;

        System.assertEquals(
            1,
            inserted.size(),
            'One BU-based share intent expected for the affiliated user on the SR.'
        );

        SObject share = inserted[0];
        System.assertEquals(
            sr.Id,
            (Id) share.get('ParentId'),
            'ParentId on share intent should be the Service Relationship.'
        );
        System.assertEquals(
            u.Id,
            (Id) share.get('UserOrGroupId'),
            'UserOrGroupId on share intent should be the affiliated user.'
        );
        System.assertEquals(
            'Edit',
            (String) share.get('AccessLevel'),
            'Share intent should grant Edit access by default.'
        );
    }
}
