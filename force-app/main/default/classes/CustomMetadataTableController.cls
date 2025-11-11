//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

public without sharing class CustomMetadataTableController {
    // Use a modern REST version; align with your MetadataService DEFAULT_METADATA_API_VERSION (61.0).
    private static final String API_VERSION   = '61.0';
    private static final String BASE_URL      = System.Url.getOrgDomainUrl().toExternalForm() + '/services/data/v' + API_VERSION;
    // Logging constants
    private static final String LOG_CONTEXT   = 'CustomMetadataTableController';
    private static final String LOG_SOURCE    = 'Caliber Core';
    private static final String LOG_COMPONENT = 'CustomMetadataTableController';

    @AuraEnabled
    public static String getSObjectApiName(SObject customMetadataRecord) {
        try {
            return customMetadataRecord.getSObjectType().getDescribe().getName();
        } catch (Exception ex) {
            logError('GetSObjectApiName', 'Failed to resolve sObject API name',
                new Map<String, Object>{ 'record' => String.valueOf(customMetadataRecord) }, ex, null);
            throw ex;
        }
    }

    // --- Upsert (create/update) via CustomMetadataSaver as before
    @AuraEnabled
    public static String deploy(List<SObject> customMetadataRecords) {
        try {
            String jobId = CustomMetadataSaver.deploy(customMetadataRecords);
            // Optionally attach correlation id for the client if desired
            logInfo('Deploy.Upsert', 'Enqueued CMDT upsert from LWC',
                new Map<String, Object>{ 'count' => (customMetadataRecords == null ? 0 : customMetadataRecords.size()), 'jobId' => jobId },
                CustomMetadataSaver.currentCorrelationId());
            return jobId;
        } catch (Exception ex) {
            logError('Deploy.Upsert', 'Error enqueuing CMDT upsert from LWC',
                new Map<String, Object>{ 'count' => (customMetadataRecords == null ? 0 : customMetadataRecords.size()) },
                ex,
                CustomMetadataSaver.currentCorrelationId());
            throw ex;
        }
    }

    // --- New: Delete support for the LWC (no upserts)
    @AuraEnabled
    public static String deleteCmdt(List<String> customMetadataFullNames) {
        // We call the invocable with only deletes so UI can drive deletion without Flow.
        try {
            CustomMetadataSaver.FlowInput fi = new CustomMetadataSaver.FlowInput();
            fi.customMetadataFullNamesToDelete = (customMetadataFullNames == null) ? new List<String>() : customMetadataFullNames;
            fi.sendEmailOnError = false;
            fi.sendEmailOnSuccess = false;

            List<String> ids = CustomMetadataSaver.deploy(new List<CustomMetadataSaver.FlowInput>{ fi });
            // Delete-only path may return null jobId; we still return a placeholder for consistency.
            logInfo('Deploy.Delete', 'Enqueued CMDT delete from LWC',
                new Map<String, Object>{ 'deleteCount' => (customMetadataFullNames == null ? 0 : customMetadataFullNames.size()) },
                CustomMetadataSaver.currentCorrelationId());
            return (ids != null && !ids.isEmpty()) ? ids[0] : null;
        } catch (Exception ex) {
            logError('Deploy.Delete', 'Error enqueuing CMDT delete from LWC',
                new Map<String, Object>{ 'deleteCount' => (customMetadataFullNames == null ? 0 : customMetadataFullNames.size()) },
                ex,
                CustomMetadataSaver.currentCorrelationId());
            throw ex;
        }
    }

    @AuraEnabled
    public static DeploymentStatusResponse getDeploymentStatus(String deploymentJobId) {
        try {
            if (String.isBlank(deploymentJobId)) {
                return null;
            }

            final String deploymentStatusUrl = BASE_URL + '/metadata/deployRequest/' + deploymentJobId + '?includeDetails=true';

            HttpRequest request = new HttpRequest();
            request.setEndpoint(deploymentStatusUrl);
            request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            request.setHeader('Content-Type', 'application/json; charset=utf-8');
            request.setMethod('GET');

            HttpResponse response = new Http().send(request);

            DeploymentStatusResponse deploymentStatusResponse =
                (DeploymentStatusResponse) JSON.deserialize(response.getBody(), DeploymentStatusResponse.class);

            logInfo('Deploy.Status', 'Fetched deployment status',
                new Map<String, Object>{ 'jobId' => deploymentJobId, 'httpStatus' => response.getStatusCode() },
                null);

            return deploymentStatusResponse;
        } catch (Exception ex) {
            logError('Deploy.Status', 'Failed to fetch deployment status',
                new Map<String, Object>{ 'jobId' => deploymentJobId },
                ex,
                null);
            throw ex;
        }
    }

    // DTOs based on the REST API's response for deployments
    // https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_rest_deploy_checkstatus.htm
    public class DeploymentStatusResponse {
        @AuraEnabled public String id;
        @AuraEnabled public String url;
        @AuraEnabled public DeployResult deployResult;
    }
    public class DeployResult {
        @AuraEnabled public String status;
        @AuraEnabled public Integer numberComponentsDeployed;
        @AuraEnabled public Integer numberComponentsTotal;
        @AuraEnabled public Integer numberComponentErrors;
        @AuraEnabled public DeployResultDetails details;
    }
    public class DeployResultDetails {
        @AuraEnabled public List<ComponentResultDetail> allComponentMessages;
        @AuraEnabled public List<ComponentResultDetail> componentFailures;
        @AuraEnabled public List<ComponentResultDetail> componentSuccesses;
    }
    public class ComponentResultDetail {
        @AuraEnabled public String componentType;
        @AuraEnabled public String fullName;
        @AuraEnabled public String problem;
        @AuraEnabled public Boolean success;
        @AuraEnabled public Boolean warning;
        @AuraEnabled public Boolean created;
        @AuraEnabled public Boolean changed;
        @AuraEnabled public Boolean deleted;
        @AuraEnabled public Integer lineNumber;
        @AuraEnabled public Integer columnNumber;
        @AuraEnabled public Boolean requiresProductionTestRun;
        @AuraEnabled public Boolean knownPackagingProblem;
        @AuraEnabled public Boolean forPackageManifestFile;
        @AuraEnabled public String problemType;
    }

    // ----------------------------
    // Logging helpers
    // ----------------------------
    private static void log(String severity, String operation, String message, Object payload, Exception ex, String correlationId) {
        try {
            ErrorLogService.log(
                LOG_CONTEXT,
                message,
                severity,                          // 'DEBUG','INFO','WARN','ERROR','FATAL'
                correlationId,
                ex,
                payload == null ? null : Json.serialize(payload),
                LOG_SOURCE,
                LOG_COMPONENT,
                operation
            );
        } catch (Exception ignore) {
            // Never let logging break functional flow
        }
    }
    private static void logInfo(String operation, String message, Object payload, String correlationId) {
        log('INFO', operation, message, payload, null, correlationId);
    }
    private static void logError(String operation, String message, Object payload, Exception ex, String correlationId) {
        log('ERROR', operation, message, payload, ex, correlationId);
    }
}
