//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

public inherited sharing class FlowCustomMetadataCreator {

    public class FlowInput {
        @InvocableVariable(required=true label='The API name of the custom metadata type')
        public String customMetadataTypeName;

        @InvocableVariable(required=true label='The label of the new custom metadata record')
        public String masterLabel;

        @InvocableVariable(required=true label='The API name of the new custom metadata record')
        public String developerName;
    }

    // Logging constants (keep consistent with CustomMetadataSaver)
    private static final String LOG_CONTEXT   = 'FlowCustomMetadataCreator';
    private static final String LOG_SOURCE    = 'Caliber Core';
    private static final String LOG_COMPONENT = 'FlowCustomMetadataCreator';

    private FlowCustomMetadataCreator() {
        // Static only
    }

    @InvocableMethod(
        category='Custom Metadata'
        label='Creates a New Instance of a Custom Metadata Record'
        description='Provides the ability to create a new custom metadata record'
    )
    public static List<SObject> newInstance(List<FlowInput> inputs) {
        String correlationId = newCorrelationId();
        List<SObject> customMetadataRecords = new List<SObject>();

        try {
            if (inputs == null || inputs.isEmpty()) {
                // Nothing to do; return empty list to Flow
                return customMetadataRecords;
            }

            for (FlowInput input : inputs) {
                if (input == null) {
                    continue;
                }

                // Resolve the CMDT type
                SObjectType sobjectType = Schema.getGlobalDescribe().get(input.customMetadataTypeName);
                if (sobjectType == null) {
                    logError(
                        correlationId,
                        'Type.Resolve',
                        'Custom metadata type not found',
                        new Map<String, Object>{ 'typeName' => input.customMetadataTypeName },
                        null
                    );
                    // Skip this item so one bad input doesn’t nuke the batch
                    continue;
                }

                SObject newCustomMetadataRecord = sobjectType.newSObject();
                newCustomMetadataRecord.put('MasterLabel',  input.masterLabel);
                newCustomMetadataRecord.put('DeveloperName', input.developerName);

                // Optional: keep computing full name (useful for debug), even though we only return the SObject
                String fullName = getFullName(newCustomMetadataRecord);
                logInfo(
                    correlationId,
                    'Record.Build',
                    'Constructed CMDT record shell',
                    new Map<String, Object>{
                        'fullName'     => fullName,
                        'masterLabel'  => input.masterLabel,
                        'developerName'=> input.developerName
                    }
                );

                customMetadataRecords.add(newCustomMetadataRecord);
            }

            return customMetadataRecords;

        } catch (Exception ex) {
            // Top-level safety net: log and rethrow so Flow still surfaces the error
            logError(
                correlationId,
                'Invocable.Unhandled',
                'Unhandled exception building CMDT instances',
                new Map<String, Object>{ 'inputCount' => inputs == null ? 0 : inputs.size() },
                ex
            );
            throw ex;
        }
    }

    private static String getFullName(SObject customMetadataRecord) {
        String customMetadataTypePrefix = customMetadataRecord.getSObjectType().getDescribe().getName().replace('__mdt', '');
        return customMetadataTypePrefix + '.' + (String)customMetadataRecord.get('DeveloperName');
    }

    // ----------------------------
    // Logging helpers (direct to ErrorLogService)
    // ----------------------------
    private static void log(String correlationId, String severity, String operation, String message, Object payload, Exception ex) {
        try {
            ErrorLogService.log(
                /* context      */ LOG_CONTEXT,
                /* message      */ message,
                /* severity     */ severity,
                /* correlation  */ correlationId,
                /* exception    */ ex,
                /* payloadJson  */ payload == null ? null : Json.serialize(payload),
                /* source       */ LOG_SOURCE,
                /* component    */ LOG_COMPONENT,
                /* operation    */ operation
            );
        } catch (Exception ignore) {
            // never let logging break functional flow
        }
    }
    private static void logInfo(String correlationId, String operation, String message, Object payload) {
        log(correlationId, 'INFO', operation, message, payload, null);
    }
    private static void logError(String correlationId, String operation, String message, Object payload, Exception ex) {
        log(correlationId, 'ERROR', operation, message, payload, ex);
    }

    private static String newCorrelationId() {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(
                DateTime.now().getTime() + ':' + UserInfo.getUserId() + ':' + Limits.getCpuTime()
            ))
        ).substring(0, 16);
    }
}
