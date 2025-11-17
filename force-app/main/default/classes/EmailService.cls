public with sharing class EmailService {

    // ======================================================
    // Request / Result DTOs
    // ======================================================
    public class EmailRequest {
        // Template-based email (Classic or Lightning). Optional.
        public Id templateId;

        // whatId = related record (Contract, Opportunity, Envelope__c, etc.)
        public Id whatId;

        // whoId = Contact/Lead/User. Used with setTargetObjectId().
        public Id whoId;

        // Direct addressing (if whoId is not used)
        public List<String> toAddresses;
        public List<String> ccAddresses;
        public List<String> bccAddresses;

        // Optional org-wide email address
        public Id orgWideEmailAddressId;

        // Behavioral flags
        public Boolean saveAsActivity;
        public Boolean useSignature;
        public Boolean treatTargetObjectAsRecipient;

        // Non-template usage
        public String subject;
        public String plainTextBody;
        public String htmlBody;

        // Optional headers
        public String replyTo;
        public String senderDisplayName;
    }

    public class EmailResult {
        public Integer totalRequests;
        public Integer builtEmails;
        public Integer sentEmails;
        public String error;
    }

    // ======================================================
    // Logging
    // ======================================================
    private static final String LOG_CONTEXT_PREFIX = '[Caliber Core] Single Email Service';
    private static final String LOG_SOURCE         = 'APEX';
    private static final String LOG_COMPONENT      = 'EmailService';
    private static final String LOG_OPERATION_SEND = 'send';

    private static void logEvent(
        String contextDetail,
        String message,
        String severity,
        Exception ex,
        String correlationId,
        Id parentRecordId,
        String parentRecordType,
        String payloadJson
    ) {
        String fullContext = LOG_CONTEXT_PREFIX;
        if (!String.isBlank(contextDetail)) {
            fullContext += ' - ' + contextDetail;
        }

        try {
            ErrorLogService.log(
                fullContext,        // Context__c (LTA)
                message,            // Message__c
                severity,           // Severity__c
                correlationId,      // Correlation_Id__c
                ex,
                payloadJson,        // Payload__c
                LOG_SOURCE,         // Source__c
                LOG_COMPONENT,      // Component__c
                LOG_OPERATION_SEND, // Operation__c
                parentRecordId,
                parentRecordType
            );
        } catch (Exception ignore) {
            // Logging failures must not break email sending
        }
    }

    // ======================================================
    // Public API
    // ======================================================

    /**
     * Core send method.
     *
     * @param requests          - list of EmailRequest objects
     * @param contextDetail     - human-readable context (e.g. "Envelope__c 01XX... - Signing notifications")
     * @param correlationId     - external correlation id (SignatureAPI envelope, flow run id, etc.)
     * @param parentRecordId    - optional parent business record to link logs to
     * @param parentRecordType  - API name of parent record
     */
    public static EmailResult send(
        List<EmailRequest> requests,
        String contextDetail,
        String correlationId,
        Id parentRecordId,
        String parentRecordType
    ) {
        EmailResult result = new EmailResult();
        result.totalRequests = (requests == null) ? 0 : requests.size();
        result.builtEmails   = 0;
        result.sentEmails    = 0;
        result.error         = null;

        if (requests == null || requests.isEmpty()) {
            // Nothing to do
            return result;
        }

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for (EmailRequest req : requests) {
            if (req == null) {
                continue;
            }

            // Normalize lists
            if (req.toAddresses == null)  req.toAddresses  = new List<String>();
            if (req.ccAddresses == null)  req.ccAddresses  = new List<String>();
            if (req.bccAddresses == null) req.bccAddresses = new List<String>();

            Boolean hasRecipient =
                (req.whoId != null) ||
                (!req.toAddresses.isEmpty());

            if (!hasRecipient) {
                // Not sendable – no whoId and no direct recipients
                logEvent(
                    contextDetail,
                    'Email request skipped: no whoId and no toAddresses.',
                    'WARN',
                    null,
                    correlationId,
                    parentRecordId,
                    parentRecordType,
                    JSON.serialize(req)
                );
                continue;
            }

            Boolean hasTemplate = (req.templateId != null);
            Boolean hasBody =
                !String.isBlank(req.subject) ||
                !String.isBlank(req.plainTextBody) ||
                !String.isBlank(req.htmlBody);

            if (!hasTemplate && !hasBody) {
                // No template and no body – nothing meaningful to send
                logEvent(
                    contextDetail,
                    'Email request skipped: no template and no body content.',
                    'WARN',
                    null,
                    correlationId,
                    parentRecordId,
                    parentRecordType,
                    JSON.serialize(req)
                );
                continue;
            }

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();

            // Template vs non-template
            if (hasTemplate) {
                msg.setTemplateId(req.templateId);
            } else {
                if (!String.isBlank(req.subject)) {
                    msg.setSubject(req.subject);
                }
                if (!String.isBlank(req.plainTextBody)) {
                    msg.setPlainTextBody(req.plainTextBody);
                }
                if (!String.isBlank(req.htmlBody)) {
                    msg.setHtmlBody(req.htmlBody);
                }
            }

            // whatId: related record for merge fields
            if (req.whatId != null) {
                msg.setWhatId(req.whatId);
            }

            // whoId vs toAddresses
            if (req.whoId != null) {
                msg.setTargetObjectId(req.whoId);

                Boolean treat =
                    (req.treatTargetObjectAsRecipient == null)
                    ? true
                    : req.treatTargetObjectAsRecipient;
                msg.setTreatTargetObjectAsRecipient(treat);
            } else if (!req.toAddresses.isEmpty()) {
                msg.setToAddresses(req.toAddresses);
            }

            if (!req.ccAddresses.isEmpty()) {
                msg.setCcAddresses(req.ccAddresses);
            }
            if (!req.bccAddresses.isEmpty()) {
                msg.setBccAddresses(req.bccAddresses);
            }

            if (req.orgWideEmailAddressId != null) {
                msg.setOrgWideEmailAddressId(req.orgWideEmailAddressId);
            }

            if (req.saveAsActivity != null) {
                msg.setSaveAsActivity(req.saveAsActivity);
            }
            if (req.useSignature != null) {
                msg.setUseSignature(req.useSignature);
            }

            if (!String.isBlank(req.replyTo)) {
                msg.setReplyTo(req.replyTo);
            }
            if (!String.isBlank(req.senderDisplayName)) {
                msg.setSenderDisplayName(req.senderDisplayName);
            }

            messages.add(msg);
            result.builtEmails++;
        }

        if (messages.isEmpty()) {
            // We had requests but none were sendable
            logEvent(
                contextDetail,
                'No valid email messages built from requests; nothing was sent.',
                'WARN',
                null,
                correlationId,
                parentRecordId,
                parentRecordType,
                JSON.serialize(new Map<String, Object>{
                    'requestCount' => result.totalRequests
                })
            );
            return result;
        }

        try {
            Messaging.sendEmail(messages, false);
            result.sentEmails = messages.size();

            logEvent(
                contextDetail,
                'Successfully sent ' + result.sentEmails + ' email(s).',
                'INFO',
                null,
                correlationId,
                parentRecordId,
                parentRecordType,
                JSON.serialize(new Map<String, Object>{
                    'builtEmails' => result.builtEmails,
                    'sentEmails'  => result.sentEmails
                })
            );

            return result;

        } catch (Exception ex) {
            result.error = ex.getMessage();

            logEvent(
                contextDetail,
                'Exception while sending emails: ' + ex.getMessage(),
                'ERROR',
                ex,
                correlationId,
                parentRecordId,
                parentRecordType,
                JSON.serialize(new Map<String, Object>{
                    'requestCount' => result.totalRequests,
                    'builtEmails'  => result.builtEmails
                })
            );

            throw ex;
        }
    }
}
