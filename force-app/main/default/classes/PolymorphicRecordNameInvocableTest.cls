@IsTest
private class PolymorphicRecordNameInvocableTest {
    @IsTest
    static void testGetRecordName_Single() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create test Contact
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;

        // Prepare inputs for invocable
        PolymorphicRecordNameInvocable.Input accInput = new PolymorphicRecordNameInvocable.Input();
        accInput.recordId = acc.Id;
        accInput.recordType = 'Account';
        
        PolymorphicRecordNameInvocable.Input conInput = new PolymorphicRecordNameInvocable.Input();
        conInput.recordId = con.Id;
        conInput.recordType = 'Contact';

        List<PolymorphicRecordNameInvocable.Input> inputs = new List<PolymorphicRecordNameInvocable.Input>{ accInput, conInput };
        Test.startTest();
        List<PolymorphicRecordNameInvocable.Output> outputs = PolymorphicRecordNameInvocable.getRecordNames(inputs);
        Test.stopTest();

        System.assertEquals('Test Account', outputs[0].recordName, 'Account name should match');
        System.assertEquals('Test Contact', outputs[1].recordName, 'Contact name should match');
    }

    @IsTest
    static void testGetRecordName_NullHandling() {
        PolymorphicRecordNameInvocable.Input badInput = new PolymorphicRecordNameInvocable.Input();
        badInput.recordId = null;
        badInput.recordType = null;
        List<PolymorphicRecordNameInvocable.Input> badInputs = new List<PolymorphicRecordNameInvocable.Input>{ badInput };
        Test.startTest();
        List<PolymorphicRecordNameInvocable.Output> badOutputs = PolymorphicRecordNameInvocable.getRecordNames(badInputs);
        Test.stopTest();

        System.assertEquals(null, badOutputs[0].recordName, 'Should handle null gracefully');
    }

    @IsTest
    static void testBulkUpdateUtility() {
        // Create referenced records
        Account acc = new Account(Name = 'Bulk Account');
        insert acc;
        Contact con = new Contact(LastName = 'Bulk Contact');
        insert con;

        // Try to dynamically get any object with the right fields
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        // You must define at least one object in your org/package with the fields:
        // Parent_Record_Id__c, Parent_Record_Type__c, Parent_Record_Name__c
        String testObjName = null;
        for (String objName : gd.keySet()) {
            Schema.SObjectType sObjType = gd.get(objName);
            Schema.DescribeSObjectResult sObjDesc = sObjType.getDescribe();
            Map<String, Schema.SObjectField> fields = sObjDesc.fields.getMap();
            if (
                fields.containsKey('Parent_Record_Id__c') && 
                fields.containsKey('Parent_Record_Type__c') &&
                fields.containsKey('Parent_Record_Name__c')
            ) {
                testObjName = objName;
                break;
            }
        }

        System.assertNotEquals(null, testObjName, 'No test object with required fields was found for universal test.');

        SObject custom1 = Schema.getGlobalDescribe().get(testObjName).newSObject();
        custom1.put('Parent_Record_Id__c', acc.Id);
        custom1.put('Parent_Record_Type__c', 'Account');
        SObject custom2 = Schema.getGlobalDescribe().get(testObjName).newSObject();
        custom2.put('Parent_Record_Id__c', con.Id);
        custom2.put('Parent_Record_Type__c', 'Contact');
        List<SObject> testRecords = new List<SObject>{custom1, custom2};

        Test.startTest();
        PolymorphicRecordNameUtil.updateRecordNames(testRecords);
        Test.stopTest();

        System.assertEquals('Bulk Account', custom1.get('Parent_Record_Name__c'), 'Should populate correct account name');
        System.assertEquals('Bulk Contact', custom2.get('Parent_Record_Name__c'), 'Should populate correct contact name');
    }

}
