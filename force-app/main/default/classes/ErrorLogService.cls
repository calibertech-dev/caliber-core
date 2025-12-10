global with sharing class ErrorLogService {

    /*
     * -------------------------------------------------------------------------
     *  Severity levels
     *
     *  DEBUG – noisy info for dev/debug mode
     *  INFO  – noteworthy but not a problem
     *  WARN  – something is wrong but execution continues; usually data/config
     *  ERROR – a failure occurred but was caught/handled
     *  FATAL – catastrophic / unrecoverable condition
     * -------------------------------------------------------------------------
     */
    global enum Severity { DEBUG, INFO, WARN, ERROR, FATAL }


    /*
     * -------------------------------------------------------------------------
     *  Minimal overload (legacy use)
     *
     *  - Use only if you have no component, source, or parent context.
     *  - Most callers should use the 9-arg or 11-arg method instead.
     *
     *  Maps to:
     *    Context__c       → human-readable business context
     *    Message__c       → human-readable error message
     *    Severity__c      → error/warn/info/etc.
     *    Correlation_Id__c→ external correlation (Envelope Id, Flow Guid, etc.)
     *    Exception fields → extracted from Exception
     *    Payload__c       → JSON payload with structured diagnostic info
     * -------------------------------------------------------------------------
     */
    global static Id log(
        String context,
        String message,
        String severity,
        String correlationId,
        Exception ex,
        String payloadJson
    ) {
        return log(
            context,
            message,
            severity,
            correlationId,
            ex,
            payloadJson,
            null,   // Source__c     – execution channel (APEX/FLOW/TRIGGER/REST…)
            null,   // Component__c  – class/flow/trigger name
            null,   // Operation__c  – method / flow step name
            null,   // Parent Id     – business record related to this error
            null    // Parent Type   – API name of the parent record
        );
    }


    /*
     * -------------------------------------------------------------------------
     *  9-argument overload
     *
     *  Adds:
     *    Source__c    → Where the logic ran (APEX / FLOW / TRIGGER / REST / …)
     *    Component__c → Name of class, flow, trigger handler, LWC, etc.
     *    Operation__c → Method name or logical operation ("createEnvelope")
     *
     *  This version is appropriate for most logging in Apex & Flow.
     * -------------------------------------------------------------------------
     */
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
        return log(
            context,
            message,
            severity,
            correlationId,
            ex,
            payloadJson,
            source,
            component,
            operation,
            null,   // Optional Parent__c Id
            null    // Optional Parent__c Type
        );
    }


    /*
     * -------------------------------------------------------------------------
     *  Full overload: 11 arguments
     *
     *  Includes polymorphic parent record fields:
     *    Parent_Record_Id__c
     *    Parent_Record_Type__c
     *    Parent_Record_Name__c
     *
     *  Use this version whenever the error is tied to a business object
     *  (Envelope__c, Proposal__c, Contract__c, Case, Opportunity, etc.).
     *
     *  Final field meanings:
     *
     *    Context__c  (Long Text)
     *       → Human-readable description of the *scenario*.
     *         Example: "[Caliber eSign] Creating ceremony for Envelope_Recipient__c 003…"
     *
     *    Message__c (Long Text)
     *       → Human explanation of what *went wrong*.
     *         Example: "Ceremony creation failed: received HTTP 500 from SignatureAPI"
     *
     *    Severity__c (Picklist)
     *       → DEBUG / INFO / WARN / ERROR / FATAL
     *
     *    Correlation_Id__c (Long Text)
     *       → External or cross-system identifier.
     *         Example: SignatureAPI Envelope Id, Flow Interview Guid, Batch Job Id.
     *
     *    Exception_Type__c (Text)
     *       → Ex.getTypeName()
     *
     *    Stacktrace__c (Long Text)
     *       → Ex.getStackTraceString() (trimmed)
     *
     *    Payload__c (Long Text)
     *       → Structured JSON with relevant callout details, IDs, status codes, inputs.
     *
     *    Source__c (Picklist)
     *       → Execution channel (APEX / FLOW / TRIGGER / REST / BATCH / SCHEDULED / OTHER)
     *
     *    Component__c (Text)
     *       → Class / Flow / Trigger Handler / LWC name
     *
     *    Operation__c (Text)
     *       → Method or logical operation name
     *
     *    Parent_Record_Id__c / _Type__c / _Name__c
     *       → Optional polymorphic link for debugging errors in context of a record.
     * -------------------------------------------------------------------------
     */
    global static Id log(
        String context,
        String message,
        String severity,
        String correlationId,
        Exception ex,
        String payloadJson,
        String source,
        String component,
        String operation,
        Id parentRecordId,
        String parentRecordType
    ) {
        if (!Schema.sObjectType.Error_Log__c.isCreateable()) return null;

        Error_Log__c rec = new Error_Log__c();

        // Core fields
        rec.Context__c        = fit(context,        Error_Log__c.Context__c);
        rec.Message__c        = fit(message,        Error_Log__c.Message__c);
        rec.Severity__c       = normalizeSeverity(severity);
        rec.Correlation_Id__c = fit(correlationId,  Error_Log__c.Correlation_Id__c);

        // Exception details
        rec.Exception_Type__c = fit(ex == null ? null : ex.getTypeName(),         Error_Log__c.Exception_Type__c);
        rec.Stacktrace__c     = fit(ex == null ? null : ex.getStackTraceString(), Error_Log__c.Stacktrace__c);

        // Diagnostic payload (JSON)
        rec.Payload__c        = fit(payloadJson,    Error_Log__c.Payload__c);

        // Location metadata
        rec.Source__c         = fit(source,         Error_Log__c.Source__c);
        rec.Component__c      = fit(component,      Error_Log__c.Component__c);
        rec.Operation__c      = fit(operation,      Error_Log__c.Operation__c);

        /*
         * -------------------------------------------------------------
         * Polymorphic Parent Record
         *
         * Allows logs to be tied directly to any object:
         *   – Envelope__c
         *   – Contract__c
         *   – Proposal__c
         *   – Case
         *   – Opportunity
         *   – Custom objects
         *
         * Great for dashboards and “Logs related to this record” UI.
         * -------------------------------------------------------------
         */
        if (parentRecordId != null) {
            String effectiveType = parentRecordType;

            // Infer type from Id prefix if not supplied
            if (String.isBlank(effectiveType)) {
                try {
                    Schema.SObjectType sType = parentRecordId.getSObjectType();
                    if (sType != null) {
                        effectiveType = sType.getDescribe().getName();
                    }
                } catch (Exception ignore) {}
            }

            if (!String.isBlank(effectiveType)) {
                rec.Parent_Record_Id__c   = String.valueOf(parentRecordId);
                rec.Parent_Record_Type__c = effectiveType;

                // Try to fetch Name for readability (non-blocking)
                try {
                    String name = PolymorphicRecordNameUtil.getRecordName(parentRecordId, effectiveType);
                    rec.Parent_Record_Name__c = fit(name, Error_Log__c.Parent_Record_Name__c);
                } catch (Exception ignore) {}
            }
        }

        insert rec;
        return rec.Id;
    }



    /*
     * Normalize severity to allowable values.
     * Defaults to ERROR if invalid or null.
     */
    private static String normalizeSeverity(String s) {
        String v = (s == null) ? 'ERROR' : s.trim().toUpperCase();
        return (new Set<String>{ 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' }).contains(v)
            ? v
            : 'ERROR';
    }


    /*
     * Safely truncate strings to the field's max length.
     */
    private static String fit(String s, SObjectField f) {
        if (s == null) return null;
        Integer n = f.getDescribe().getLength();
        return s.length() <= n ? s : s.substring(0, n);
    }
}
