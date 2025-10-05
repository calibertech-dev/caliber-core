global with sharing class ErrorLogService {
    global enum Severity { DEBUG, INFO, WARN, ERROR, FATAL }

    // Back-compat signature (still works)
    global static Id log(
        String context,
        String message,
        String severity,
        String correlationId,
        Exception ex,
        String payloadJson
    ) {
        return log(context, message, severity, correlationId, ex, payloadJson, null, null, null);
    }

    // New overload: adds Source/Component/Operation
    global static Id log(
        String context,
        String message,
        String severity,
        String correlationId,
        Exception ex,
        String payloadJson,
        String source,
        String component,
        String operation
    ) {
        if (!Schema.sObjectType.Error_Log__c.isCreateable()) return null;

        Error_Log__c rec = new Error_Log__c();
        rec.Context__c        = fit(context,        Error_Log__c.Context__c);
        rec.Message__c        = fit(message,        Error_Log__c.Message__c);
        rec.Severity__c       = normalizeSeverity(severity);
        rec.Correlation_Id__c = fit(correlationId,  Error_Log__c.Correlation_Id__c);
        rec.Exception_Type__c = fit(ex == null ? null : ex.getTypeName(),         Error_Log__c.Exception_Type__c);
        rec.Stacktrace__c     = fit(ex == null ? null : ex.getStackTraceString(), Error_Log__c.Stacktrace__c);
        rec.Payload__c        = fit(payloadJson,    Error_Log__c.Payload__c);
        rec.Source__c         = fit(source,         Error_Log__c.Source__c);
        rec.Component__c      = fit(component,      Error_Log__c.Component__c);
        rec.Operation__c      = fit(operation,      Error_Log__c.Operation__c);

        insert rec;
        return rec.Id;
    }

    private static String normalizeSeverity(String s) {
        String v = (s == null) ? 'ERROR' : s.trim().toUpperCase();
        return (new Set<String>{'DEBUG','INFO','WARN','ERROR','FATAL'}).contains(v) ? v : 'ERROR';
    }
    private static String fit(String s, SObjectField f) {
        if (s == null) return null;
        Integer n = f.getDescribe().getLength();
        return s.length() <= n ? s : s.substring(0, n);
    }
}
