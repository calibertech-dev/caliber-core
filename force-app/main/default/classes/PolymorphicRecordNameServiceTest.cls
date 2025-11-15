@IsTest
private class PolymorphicRecordNameServiceTest {

    @testSetup
    static void setupData() {
        // Create a couple of parent records to resolve against
        Account a1 = new Account(Name = 'Parent Account 1');
        Account a2 = new Account(Name = 'Parent Account 2');
        insert new List<Account>{ a1, a2 };
    }

    @IsTest
    static void testInsertPathSetsParentName() {
        // Arrange
        Account a1 = [SELECT Id, Name FROM Account WHERE Name = 'Parent Account 1' LIMIT 1];

        // Create a "target" record that uses the polymorphic pattern.
        Error_Log__c target = new Error_Log__c();
        target.Parent_Record_Type__c = 'Account';
        target.Parent_Record_Id__c   = a1.Id;
        // Name is blank initially
        target.Parent_Record_Name__c = null;

        // We don't need to insert this record to test the service:
        // the service only cares about Parent_Record_Type/Id and sets Name in memory.

        List<SObject> newList = new List<SObject>{ target };

        // Act - simulate "before insert" (oldMap = null)
        PolymorphicRecordNameService.updateParentRecordNames(newList, null);

        // Assert
        System.assertEquals(
            a1.Name,
            (String)target.get('Parent_Record_Name__c'),
            'Parent_Record_Name__c should be populated from the Account Name on insert path.'
        );
    }

    @IsTest
    static void testUpdatePathChangesAndClearsName() {
        // Arrange
        List<Account> parents = [
            SELECT Id, Name
            FROM Account
            WHERE Name IN ('Parent Account 1', 'Parent Account 2')
            ORDER BY Name
        ];
        Account a1 = parents[0];
        Account a2 = parents[1];

        // Start with a record pointing to a1
        Error_Log__c target = new Error_Log__c();
        target.Parent_Record_Type__c = 'Account';
        target.Parent_Record_Id__c   = a1.Id;

        // First, simulate an insert to populate the name via the service
        List<SObject> insertList = new List<SObject>{ target };
        PolymorphicRecordNameService.updateParentRecordNames(insertList, null);
        System.assertEquals(
            a1.Name,
            (String)target.get('Parent_Record_Name__c'),
            'Sanity check: name should match first parent after insert simulation.'
        );

        // Now pretend this record is in the database and we're doing an update:
        // - oldMap holds the old values
        // - new record has a changed Parent_Record_Id__c (pointing to a2)

        // Clone the "old" state
        SObject oldState = target.clone(false, true, false, false);

        // Change parent to a2 in the "new" state
        target.Parent_Record_Id__c = a2.Id;

        List<SObject> newList = new List<SObject>{ target };
        Map<Id, SObject> oldMap = new Map<Id, SObject>();

        // We don't actually need a real Id for logic here; the service only uses Id
        // to match oldMap entries. In a real trigger context Id would be non-null,
        // but for this unit test we can simulate by assigning after a dummy insert.

        // Do a quick insert to get a real Id so the Map key is valid
        insert (Error_Log__c)oldState;
        target.Id = oldState.Id;
        oldMap.put(oldState.Id, oldState);

        // Act - simulate "before update"
        PolymorphicRecordNameService.updateParentRecordNames(newList, oldMap);

        // Assert: name should switch to the second parent
        System.assertEquals(
            a2.Name,
            (String)target.get('Parent_Record_Name__c'),
            'Parent_Record_Name__c should update when Parent_Record_Id__c changes.'
        );

        // Now test clearing parent info: service should null the name
        SObject oldState2 = target.clone(false, true, false, false);
        target.Parent_Record_Type__c = null;
        target.Parent_Record_Id__c   = null;

        List<SObject> newList2 = new List<SObject>{ target };
        Map<Id, SObject> oldMap2 = new Map<Id, SObject>{ target.Id => oldState2 };

        PolymorphicRecordNameService.updateParentRecordNames(newList2, oldMap2);

        System.assertEquals(
            null,
            (String)target.get('Parent_Record_Name__c'),
            'Parent_Record_Name__c should be cleared when parent type/id are blank.'
        );
    }
}
