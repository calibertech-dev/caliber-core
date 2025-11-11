//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//
// Creates/updates CMDT via Apex Metadata API; deletes CMDT via SOAP Metadata API (MetadataService)
// Logs to Error_Log__c using ErrorLogService.
//----------------------------------------------------------------------------------------------------//

public inherited sharing class CustomMetadataSaver {
    // ----------------------------
    // Constants & state
    // ----------------------------
    private static final Boolean DEFAULT_SEND_EMAIL_ON_ERROR   = false;
    private static final Boolean DEFAULT_SEND_EMAIL_ON_SUCCESS = false;
    private static final List<String> DEPLOYMENT_JOB_IDS       = new List<String>();
    private static final Set<String> IGNORED_FIELD_NAMES       = getIgnoredFieldNames();

    @TestVisible private static final String MOCK_DEPLOYMENT_ID = 'fakeDeploymentId';

    // Pin SOAP Metadata API version used by MetadataService
    @TestVisible private static String metadataApiVersionOverride;
    private static final String DEFAULT_METADATA_API_VERSION = '61.0';

    // Logging context
    @TestVisible private static String correlationIdInternal;
    private static final String LOG_CONTEXT   = 'CustomMetadataSaver';
    private static final String LOG_SOURCE    = 'Caliber Core';
    private static final String LOG_COMPONENT = 'CustomMetadataSaver';

    // ----------------------------
    // Flow input
    // ----------------------------
    public class FlowInput {
        @InvocableVariable(required=true label='Custom Metadata Type Records to Deploy')
        public List<SObject> customMetadataRecords;

        @InvocableVariable(
            required=false
            label='(Optional) Custom Metadata Full Names to DELETE'
            description='Full names like My_Type__mdt.My_RecordDevName'
        )
        public List<String> customMetadataFullNamesToDelete;

        @InvocableVariable(
            required=true
            label='Send Email Alert if the Deployment Fails'
            description='Only used by the default callback class.'
        )
        public Boolean sendEmailOnError;

        @InvocableVariable(
            required=true
            label='Send Email Alert if the Deployment Succeeds'
            description='Only used by the default callback class.'
        )
        public Boolean sendEmailOnSuccess;

        @InvocableVariable(
            required=false
            label='(Optional) Custom Callback Apex Class'
            description='Apex class to execute after deploy completes; used instead of default callback when provided.'
        )
        public String customCallbackName;
    }

    private CustomMetadataSaver() {}

    // ----------------------------
    // Invocable entry
    // ----------------------------
    @InvocableMethod(
        category='Custom Metadata'
        label='Deploy / Delete Custom Metadata Type Records'
        description='Creates/updates via Apex Metadata; deletes via SOAP Metadata API.'
    )
    public static List<String> deploy(List<FlowInput> inputs) {
        correlationIdInternal = newCorrelationId();  // thread logs for this run

        try {
            Boolean sendEmailOnError   = DEFAULT_SEND_EMAIL_ON_ERROR;
            Boolean sendEmailOnSuccess = DEFAULT_SEND_EMAIL_ON_SUCCESS;
            String  customCallbackName;

            List<SObject> consolidatedUpserts = new List<SObject>();
            List<String>  consolidatedDeletes = new List<String>();

            for (FlowInput input : inputs) {
                if (input == null) continue;
                if (input.customMetadataRecords != null) consolidatedUpserts.addAll(input.customMetadataRecords);
                if (input.customMetadataFullNamesToDelete != null) consolidatedDeletes.addAll(input.customMetadataFullNamesToDelete);
                if (input.sendEmailOnError == true)   sendEmailOnError = true;
                if (input.sendEmailOnSuccess == true) sendEmailOnSuccess = true;
                if (String.isNotBlank(input.customCallbackName)) customCallbackName = input.customCallbackName;
            }

            Metadata.DeployCallback callback = getFlowDeployCallback(customCallbackName, sendEmailOnError, sendEmailOnSuccess);

            String jobId;
            if (!consolidatedUpserts.isEmpty()) {
                jobId = deploy(consolidatedUpserts, callback);
                logInfo('Invocable.Upsert.Enqueue', 'Enqueued CMDT upsert deployment', new Map<String,Object>{
                    'recordsCount' => consolidatedUpserts.size(),
                    'jobId'        => jobId
                });
            }

            if (!consolidatedDeletes.isEmpty()) {
                enqueueDeleteCmdt(consolidatedDeletes);
                logInfo('Invocable.Delete.Enqueue', 'Enqueued CMDT delete job', new Map<String,Object>{
                    'deleteCount' => consolidatedDeletes.size()
                });
            }

            List<String> flowJobIds = new List<String>();
            for (Integer i = 0; i < inputs.size(); i++) flowJobIds.add(jobId);
            return flowJobIds;

        } catch (Exception ex) {
            // <- This guarantees a stacktrace is written even for unexpected failures
            logError(
                'Invocable.Unhandled',
                'Unhandled exception in CustomMetadataSaver.deploy(invocable)',
                new Map<String,Object>{
                    'inputCount' => (inputs == null ? 0 : inputs.size())
                },
                ex
            );
            throw ex; // preserve original platform behavior for Flow/LWC
        }
    }

    // ----------------------------
    // Public helpers
    // ----------------------------
    public static String deploy(List<SObject> customMetadataRecords) {
        return deploy(customMetadataRecords, new DefaultDeployCallback());
    }

    public static String deploy(List<SObject> customMetadataRecords, Metadata.DeployCallback callback) {
        Metadata.DeployContainer deployment = new Metadata.DeployContainer();
        for (SObject cmdtRecord : customMetadataRecords) {
            Metadata.CustomMetadata md = createDeployableCustomMetadata(cmdtRecord);
            deployment.addMetadata(md);
        }

        try {
            String jobId = Test.isRunningTest()
                ? MOCK_DEPLOYMENT_ID
                : Metadata.Operations.enqueueDeployment(deployment, callback);
            DEPLOYMENT_JOB_IDS.add(jobId);
            return jobId;
        } catch (Exception ex) {
            logError('Upsert.Enqueue', 'enqueueDeployment threw an exception',
                new Map<String,Object>{ 'recordsCount' => customMetadataRecords.size() }, ex);
            throw ex;
        }
    }

    public static List<String> getDeploymentJobIds() { return DEPLOYMENT_JOB_IDS; }

    public static String currentCorrelationId() { return correlationIdInternal; }

    // ----------------------------
    // Build deployable CMDT
    // ----------------------------
    private static Set<String> getIgnoredFieldNames() {
        return new Set<String>{ 'DeveloperName','Id','Label','Language','MasterLabel','NamespacePrefix','QualifiedApiName' };
    }

    private static Metadata.CustomMetadata createDeployableCustomMetadata(SObject customMetadataRecord) {
        String typePrefix = customMetadataRecord.getSObjectType().getDescribe().getName().replace('__mdt','');

        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = typePrefix + '.' + (String)customMetadataRecord.get('DeveloperName');
        cmd.label    = (String) customMetadataRecord.get('MasterLabel');

        for (String fieldName : customMetadataRecord.getPopulatedFieldsAsMap().keySet()) {
            if (IGNORED_FIELD_NAMES.contains(fieldName)) continue;

            Schema.SObjectField f = customMetadataRecord.getSObjectType().getDescribe().fields.getMap().get(fieldName);
            Schema.DisplayType t  = f.getDescribe().getType();

            Object value = (t == Schema.DisplayType.PICKLIST)
                ? String.valueOf(customMetadataRecord.get(fieldName))
                : customMetadataRecord.get(fieldName);

            Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
            v.field = fieldName;
            v.value = value;
            cmd.values.add(v);
        }
        return cmd;
    }

    // ----------------------------
    // Callback selection
    // ----------------------------
    private static Metadata.DeployCallback getFlowDeployCallback(String customCallbackName, Boolean sendEmailOnError, Boolean sendEmailOnSuccess) {
        try {
            if (String.isNotBlank(customCallbackName) && Type.forName(customCallbackName) != null) {
                return (Metadata.DeployCallback) Type.forName(customCallbackName).newInstance();
            }
        } catch (Exception ex) {
            logError('Callback.Instantiate', 'Failed to instantiate custom callback class',
                new Map<String,Object>{ 'customCallbackName' => customCallbackName }, ex);
        }
        return new DefaultDeployCallback(sendEmailOnError, sendEmailOnSuccess);
    }

    private static void sendEmail(String subject, String textBody) {
        try {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
            m.setSubject(subject);
            m.setPlainTextBody(textBody);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ m });
        } catch (Exception ex) {
            logError('Email.Send', 'Failed to send deployment email',
                new Map<String,Object>{ 'subject' => subject }, ex);
        }
    }

    // ----------------------------
    // Delete support (Queueable)
    // ----------------------------
    public class DeleteCmdtQueueable implements Queueable, Database.AllowsCallouts {
        private List<String> fullNames;
        public DeleteCmdtQueueable(List<String> fullNames) { this.fullNames = fullNames; }

        public void execute(QueueableContext qc) {
            try {
                MetadataService.MetadataPort svc = new MetadataService.MetadataPort();
                svc.SessionHeader = new MetadataService.SessionHeader_element();
                svc.SessionHeader.sessionId = UserInfo.getSessionId();

                String apiVersion = String.isBlank(metadataApiVersionOverride) ? DEFAULT_METADATA_API_VERSION : metadataApiVersionOverride;
                svc.endpoint_x = System.Url.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/' + apiVersion;

                // Synchronous delete — returns DeleteResult[]
                MetadataService.DeleteResult[] results = svc.deleteMetadata('CustomMetadata', fullNames);

                if (results != null) {
                    for (Integer i = 0; i < results.size(); i++) {
                        MetadataService.DeleteResult dr = results[i];
                        if (dr == null) {
                            continue;
                        }
                        if (dr.success == true) {
                            logInfo(
                                'Delete.Queueable.Result',
                                'CMDT delete succeeded',
                                new Map<String, Object>{
                                    'index'    => i,
                                    'fullName' => (dr.fullName == null ? (i < fullNames.size() ? fullNames[i] : null) : dr.fullName)
                                }
                            );
                        } else {
                            // Collect all error messages/status codes for this result
                            List<String> msgs = new List<String>();
                            if (dr.errors != null) {
                                for (MetadataService.Error e : dr.errors) {
                                    if (e == null) continue;
                                    msgs.add((e.statusCode == null ? '' : String.valueOf(e.statusCode)) + ': ' + (e.message == null ? '' : e.message));
                                }
                            }
                            logWarn(
                                'Delete.Queueable.Result',
                                'CMDT delete failed',
                                new Map<String, Object>{
                                    'index'    => i,
                                    'fullName' => (dr.fullName == null ? (i < fullNames.size() ? fullNames[i] : null) : dr.fullName),
                                    'errors'   => msgs
                                }
                            );
                        }
                    }
                }
            } catch (Exception ex) {
                logError(
                    'Delete.Queueable.Execute',
                    'Unhandled exception during CMDT delete',
                    new Map<String, Object>{ 'count' => (fullNames == null ? 0 : fullNames.size()) },
                    ex
                );
            }
        }

    }

    @TestVisible
    private static void enqueueDeleteCmdt(List<String> fullNames) {
        if (fullNames == null || fullNames.isEmpty()) return;
        if (Test.isRunningTest()) return; // no callouts in tests
        try {
            System.enqueueJob(new DeleteCmdtQueueable(fullNames));
        } catch (Exception ex) {
            logError('Delete.Enqueue', 'Failed to enqueue delete queueable',
                new Map<String,Object>{ 'count' => fullNames.size() }, ex);
            throw ex;
        }
    }

    // ----------------------------
    // Default deploy callback
    // ----------------------------
    @TestVisible
    private class DefaultDeployCallback implements Metadata.DeployCallback {
        @TestVisible private Boolean success;
        private Boolean sendEmailOnError;
        private Boolean sendEmailOnSuccess;

        @TestVisible private DefaultDeployCallback() {
            this(DEFAULT_SEND_EMAIL_ON_ERROR, DEFAULT_SEND_EMAIL_ON_SUCCESS);
        }
        @TestVisible private DefaultDeployCallback(Boolean sendEmailOnError, Boolean sendEmailOnSuccess) {
            this.sendEmailOnError   = sendEmailOnError;
            this.sendEmailOnSuccess = sendEmailOnSuccess;
        }

        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            try {
                this.success = result.success;

                String subject = 'Custom metadata type deployment completed';
                String textBody = String.format(
                    'Deployment ID {0} completed\nStatus: {1}\n{2} total items deployed\n{3} items failed\nDetails: {4}',
                    new List<Object>{
                        result.id,
                        result.status,
                        result.numberComponentsTotal,
                        result.numberComponentErrors,
                        Json.serializePretty(result.details)
                    }
                );

                if (result.success == true && this.sendEmailOnSuccess == true) sendEmail(subject, textBody);
                else if (result.success == false && this.sendEmailOnError == true) sendEmail(subject, textBody);

                if (result.success == false) {
                    logWarn('Callback.HandleResult', 'Deployment finished with errors', new Map<String,Object>{
                        'deploymentId' => result.id,
                        'status'       => result.status,
                        'errors'       => result.details
                    });
                } else {
                    logInfo('Callback.HandleResult', 'Deployment succeeded', new Map<String,Object>{
                        'deploymentId' => result.id,
                        'status'       => result.status
                    });
                }
            } catch (Exception ex) {
                logError('Callback.HandleResult', 'Exception while handling deployment result',
                    new Map<String,Object>{ 'context' => String.valueOf(context) }, ex);
            }
        }
    }

    // ----------------------------
    // Logging helpers
    // ----------------------------
    private static void log(String severity, String operation, String message, String payloadJson, Exception ex) {
        try {
            ErrorLogService.log(
                /* context      */ LOG_CONTEXT,
                /* message      */ message,
                /* severity     */ severity, // 'DEBUG','INFO','WARN','ERROR','FATAL'
                /* correlation  */ correlationIdInternal,
                /* exception    */ ex,
                /* payloadJson  */ payloadJson,
                /* source       */ LOG_SOURCE,
                /* component    */ LOG_COMPONENT,
                /* operation    */ operation
            );
        } catch (Exception ignore) {
            // never let logging break the functional path
        }
    }
    private static void logInfo(String operation, String message, Object payload) {
        log('INFO', operation, message, payload == null ? null : Json.serialize(payload), null);
    }
    private static void logWarn(String operation, String message, Object payload) {
        log('WARN', operation, message, payload == null ? null : Json.serialize(payload), null);
    }
    private static void logError(String operation, String message, Object payload, Exception ex) {
        log('ERROR', operation, message, payload == null ? null : Json.serialize(payload), ex);
    }

    private static String newCorrelationId() {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(
                DateTime.now().getTime() + ':' + UserInfo.getUserId() + ':' + Limits.getCpuTime()
            ))
        ).substring(0, 16);
    }
}
