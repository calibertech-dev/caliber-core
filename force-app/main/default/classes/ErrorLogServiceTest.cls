@IsTest
private class ErrorLogServiceTest {

    @IsTest static void service_creates_record_and_normalizes_severity() {
        Exception ex;
        try { Integer x = 1/0; } catch (Exception e) { ex = e; }

        Id id = ErrorLogService.log('Stripe','Division by zero','notalevel','abc-123',ex,'{"foo":1}');
        System.assertNotEquals(null, id);

        Error_Log__c rec = [SELECT Context__c, Message__c, Severity__c, Correlation_Id__c,
                                   Exception_Type__c, Stacktrace__c, Payload__c
                            FROM Error_Log__c WHERE Id = :id];
        System.assertEquals('Stripe', rec.Context__c);
        System.assertEquals('ERROR',  rec.Severity__c);
        System.assertEquals('abc-123', rec.Correlation_Id__c);
        System.assert(rec.Stacktrace__c != null);
        System.assert(rec.Exception_Type__c != null);
    }

    @IsTest static void invocable_creates_record_with_source_component_operation() {
        ErrorLogInvocable.Request r = new ErrorLogInvocable.Request();
        r.Message = 'Hello';
        r.Context = 'Core';
        r.Severity = 'WARN';
        r.CorrelationId = 'cid-1';
        r.PayloadJson = '{"a":2}';
        r.Source = 'FLOW';
        r.Component = 'My_Flow';
        r.Operation = 'Decision_Fork';

        List<Id> ids = ErrorLogInvocable.log(new List<ErrorLogInvocable.Request>{ r });
        System.assertEquals(1, ids.size());

        Error_Log__c rec = [
            SELECT Severity__c, Context__c, Message__c, Source__c, Component__c, Operation__c
            FROM Error_Log__c WHERE Id = :ids[0]
        ];
        System.assertEquals('WARN', rec.Severity__c);
        System.assertEquals('Core', rec.Context__c);
        System.assertEquals('Hello', rec.Message__c);
        System.assertEquals('FLOW', rec.Source__c);
        System.assertEquals('My_Flow', rec.Component__c);
        System.assertEquals('Decision_Fork', rec.Operation__c);
    }
}
