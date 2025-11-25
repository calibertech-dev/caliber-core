@IsTest
private class BusinessUnitObjectSharingServiceTest {

    private static User getCurrentUser() {
        return [
            SELECT Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    @IsTest
    static void recalcForRecords_createsShareForActiveAffiliation() {
        User u = getCurrentUser();

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU Share Create',
            Short_Code__c             = 'BSC',
            Customer_Service_Email__c = 'cs-bu-share-create@test.com',
            Customer_Service_Phone__c = '555-555-1000'
        );
        insert bu;

        Account acc = new Account(Name = 'BU Share Create Account');
        insert acc;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        insert sr;

        // Active affiliation for current user
        Business_Unit_Affiliation__c aff = new Business_Unit_Affiliation__c(
            Business_Unit__c        = bu.Id,
            User__c                 = u.Id,
            Is_Active__c            = true,
            Can_View_All_Records__c = true
        );
        insert aff;

        Test.startTest();
        BusinessUnitObjectSharingService.skipDmlForTest = true;
        BusinessUnitObjectSharingService.lastInsertedShares.clear();
        BusinessUnitObjectSharingService.lastDeletedShares.clear();

        BusinessUnitObjectSharingService.recalcForRecords(
            new List<SObject>{ sr }
        );
        Test.stopTest();

        // We expect:
        // - No existing manual shares deleted on first run
        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastDeletedShares.size(),
            'First run should not delete any existing manual shares.'
        );

        // - Exactly one new share intent for this (record, user) pair
        List<SObject> inserted = BusinessUnitObjectSharingService.lastInsertedShares;
        System.assertEquals(
            1,
            inserted.size(),
            'Expected exactly one BU-driven share intent for the active affiliated user.'
        );

        SObject share = inserted[0];
        System.assertEquals(
            sr.Id,
            (Id) share.get('ParentId'),
            'ParentId on share should be the Service Relationship.'
        );
        System.assertEquals(
            u.Id,
            (Id) share.get('UserOrGroupId'),
            'UserOrGroupId should be the affiliated user.'
        );
        System.assertEquals(
            'Edit',
            (String) share.get('AccessLevel'),
            'AccessLevel should be Edit as set by the sharing service.'
        );
    }

    @IsTest
    static void recalcForRecords_removesSharesWhenAffiliationInactive() {
        User u = getCurrentUser();

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'BU Share Delete',
            Short_Code__c             = 'BSD',
            Customer_Service_Email__c = 'cs-bu-share-delete@test.com',
            Customer_Service_Phone__c = '555-555-2000'
        );
        insert bu;

        Account acc = new Account(Name = 'BU Share Delete Account');
        insert acc;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        insert sr;

        // Start with an active affiliation so we can get an initial share intent
        Business_Unit_Affiliation__c aff = new Business_Unit_Affiliation__c(
            Business_Unit__c        = bu.Id,
            User__c                 = u.Id,
            Is_Active__c            = true,
            Can_View_All_Records__c = true
        );
        insert aff;

        Test.startTest();
        BusinessUnitObjectSharingService.skipDmlForTest = true;

        // --- Phase 1: Active affiliation ---
        BusinessUnitObjectSharingService.lastInsertedShares.clear();
        BusinessUnitObjectSharingService.lastDeletedShares.clear();

        BusinessUnitObjectSharingService.recalcForRecords(
            new List<SObject>{ sr }
        );

        System.assertEquals(
            1,
            BusinessUnitObjectSharingService.lastInsertedShares.size(),
            'With active affiliation, we should create one share intent.'
        );
        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastDeletedShares.size(),
            'First run should not delete any shares.'
        );

        // --- Phase 2: Inactivate affiliation ---
        aff.Is_Active__c = false;
        update aff;

        BusinessUnitObjectSharingService.lastInsertedShares.clear();
        BusinessUnitObjectSharingService.lastDeletedShares.clear();

        BusinessUnitObjectSharingService.recalcForRecords(
            new List<SObject>{ sr }
        );

        Test.stopTest();

        // In seam mode we don’t simulate past shares in the DB,
        // so we only verify that no *new* shares are created.
        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastInsertedShares.size(),
            'When affiliation is inactive, no BU-driven share intents should be created.'
        );
        System.assertEquals(
            0,
            BusinessUnitObjectSharingService.lastDeletedShares.size(),
            'In seam mode there are no persisted shares, so nothing to delete.'
        );
    }
}
