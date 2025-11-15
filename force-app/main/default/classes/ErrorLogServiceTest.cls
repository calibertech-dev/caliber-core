@IsTest
private class ErrorLogServiceTest {

    @IsTest
    static void service_creates_record_and_normalizes_severity() {
        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }

        Id id = ErrorLogService.log('Stripe', 'Division by zero', 'notalevel', 'abc-123', ex, '{"foo":1}');
        System.assertNotEquals(null, id);

        Error_Log__c rec = [
            SELECT Context__c,
                   Message__c,
                   Severity__c,
                   Correlation_Id__c,
                   Exception_Type__c,
                   Stacktrace__c,
                   Payload__c
            FROM Error_Log__c
            WHERE Id = :id
        ];
        System.assertEquals('Stripe',  rec.Context__c);
        System.assertEquals('ERROR',   rec.Severity__c);
        System.assertEquals('abc-123', rec.Correlation_Id__c);
        System.assert(rec.Stacktrace__c != null);
        System.assert(rec.Exception_Type__c != null);
    }

    @IsTest
    static void invocable_creates_record_with_source_component_operation() {
        ErrorLogInvocable.Request r = new ErrorLogInvocable.Request();
        r.Message       = 'Hello';
        r.Context       = 'Core';
        r.Severity      = 'WARN';
        r.CorrelationId = 'cid-1';
        r.PayloadJson   = '{"a":2}';
        r.Source        = 'FLOW';
        r.Component     = 'My_Flow';
        r.Operation     = 'Decision_Fork';

        List<Id> ids = ErrorLogInvocable.log(new List<ErrorLogInvocable.Request>{ r });
        System.assertEquals(1, ids.size());

        Error_Log__c rec = [
            SELECT Severity__c,
                   Context__c,
                   Message__c,
                   Source__c,
                   Component__c,
                   Operation__c
            FROM Error_Log__c
            WHERE Id = :ids[0]
        ];
        System.assertEquals('WARN',         rec.Severity__c);
        System.assertEquals('Core',         rec.Context__c);
        System.assertEquals('Hello',        rec.Message__c);
        System.assertEquals('FLOW',         rec.Source__c);
        System.assertEquals('My_Flow',      rec.Component__c);
        System.assertEquals('Decision_Fork',rec.Operation__c);
    }

    @IsTest
    static void service_logs_polymorphic_parent_record() {
        // Arrange: create a parent record
        Account acc = new Account(Name = 'Error Parent - Service');
        insert acc;

        // Act: call the full 11-argument overload with a parentRecordId, but no explicit type
        Id id = ErrorLogService.log(
            'SvcContext',          // context
            'SvcMessage',          // message
            'INFO',                // severity
            'svc-corr-1',          // correlationId
            null,                  // ex
            null,                  // payloadJson
            'APEX',                // source
            'ErrorLogServiceTest', // component
            'service_logs_poly',   // operation
            acc.Id,                // parentRecordId
            null                   // parentRecordType -> force inference from Id
        );
        System.assertNotEquals(null, id, 'Expected an Error_Log__c record to be created');

        // Assert: polymorphic fields are populated
        Error_Log__c rec = [
            SELECT Parent_Record_Id__c,
                   Parent_Record_Type__c,
                   Parent_Record_Name__c
            FROM Error_Log__c
            WHERE Id = :id
        ];

        System.assertEquals(
            String.valueOf(acc.Id),
            rec.Parent_Record_Id__c,
            'Parent_Record_Id__c should match the Account Id'
        );
        System.assertEquals(
            'Account',
            rec.Parent_Record_Type__c,
            'Type should be inferred from the Id when not provided'
        );
        System.assertEquals(
            'Error Parent - Service',
            rec.Parent_Record_Name__c,
            'Name should come from PolymorphicRecordNameUtil.getRecordName'
        );
    }

    @IsTest
    static void invocable_logs_polymorphic_parent_record() {
        // Arrange: create a parent record
        Account acc = new Account(Name = 'Error Parent - Invocable');
        insert acc;

        ErrorLogInvocable.Request r = new ErrorLogInvocable.Request();
        r.Message         = 'Invocable message';
        r.Context         = 'InvocableContext';
        r.Severity        = 'ERROR';
        r.CorrelationId   = 'inv-corr-1';
        r.PayloadJson     = '{"b":3}';
        r.Source          = 'FLOW';
        r.Component       = 'Test_Flow';
        r.Operation       = 'Test_Path';
        r.ParentRecordId  = acc.Id;
        // leave r.ParentRecordType = null to exercise type inference

        // Act
        List<Id> ids = ErrorLogInvocable.log(new List<ErrorLogInvocable.Request>{ r });
        System.assertEquals(1, ids.size(), 'Should have gotten one Error_Log__c Id back');

        // Assert
        Error_Log__c rec = [
            SELECT Parent_Record_Id__c,
                   Parent_Record_Type__c,
                   Parent_Record_Name__c,
                   Context__c,
                   Message__c,
                   Source__c
            FROM Error_Log__c
            WHERE Id = :ids[0]
        ];

        System.assertEquals(
            String.valueOf(acc.Id),
            rec.Parent_Record_Id__c,
            'Parent_Record_Id__c should match the Account Id from the invocable'
        );
        System.assertEquals(
            'Account',
            rec.Parent_Record_Type__c,
            'Type should be inferred from the Id in the invocable path'
        );
        System.assertEquals(
            'Error Parent - Invocable',
            rec.Parent_Record_Name__c,
            'Name should be resolved via PolymorphicRecordNameUtil for the invocable path'
        );

        // Sanity check that the rest of the logging still works
        System.assertEquals('InvocableContext', rec.Context__c);
        System.assertEquals('Invocable message', rec.Message__c);
        System.assertEquals('FLOW', rec.Source__c);
    }
}
