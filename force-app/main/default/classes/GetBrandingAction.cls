public with sharing class GetBrandingAction {

    public class Input {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    public class Output {
        @InvocableVariable public Id businessUnitId;
        @InvocableVariable public String businessUnitName;
        @InvocableVariable public String businessUnitShortName;
        @InvocableVariable public String businessUnitShortCode;
        @InvocableVariable public String website;

        @InvocableVariable public String supportEmail;
        @InvocableVariable public String supportPhone;
        @InvocableVariable public String customerServiceEmail;
        @InvocableVariable public String customerServicePhone;
        @InvocableVariable public String noReplyEmail;

        @InvocableVariable public Id brandingId;
        @InvocableVariable public String logoUrl;
        @InvocableVariable public String primaryColor;
        @InvocableVariable public String accentColor;
    }

    @InvocableMethod(
        label='Get Branding Context for Record'
        description='Resolve Business Unit branding (logo, colors, emails) for a given record using Relationship Context.'
    )
    public static List<Output> getBranding(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }

        // Bulk-friendly: group by SObjectType and query only what we need.
        Map<Id, SObject> recordsById = fetchRecords(inputs);

        for (Input inParam : inputs) {
            Output out = new Output();

            SObject rec = recordsById.get(inParam.recordId);
            if (rec == null) {
                results.add(out);
                continue;
            }

            ServiceRelationshipBrandingService.BrandingContext bc =
                ServiceRelationshipBrandingService.forRecord(rec);

            out.businessUnitId        = bc.businessUnitId;
            out.businessUnitName      = bc.businessUnitName;
            out.businessUnitShortName = bc.businessUnitShortName;
            out.businessUnitShortCode = bc.businessUnitShortCode;
            out.website               = bc.website;

            out.supportEmail          = bc.supportEmail;
            out.supportPhone          = bc.supportPhone;
            out.customerServiceEmail  = bc.customerServiceEmail;
            out.customerServicePhone  = bc.customerServicePhone;
            out.noReplyEmail          = bc.noReplyEmail;

            out.brandingId            = bc.brandingId;
            out.logoUrl               = bc.logoUrl;
            out.primaryColor          = bc.primaryColor;
            out.accentColor           = bc.accentColor;

            results.add(out);
        }

        return results;
    }

    /**
     * Fetch records needed for branding resolution.
     * We only need enough fields for RelationshipContextService to work:
     * - AccountId / Account__c
     * - Business_Unit__c
     * - Service_Relationship__c (if present)
     *
     * We build dynamic SOQL per object type and only select fields that exist.
     */
    @TestVisible
    private static Map<Id, SObject> fetchRecords(List<Input> inputs) {
        Map<Id, SObject> results = new Map<Id, SObject>();
        Map<SObjectType, Set<Id>> idsByType = new Map<SObjectType, Set<Id>>();

        for (Input inParam : inputs) {
            if (inParam == null || inParam.recordId == null) continue;
            SObjectType type = inParam.recordId.getSObjectType();
            if (!idsByType.containsKey(type)) {
                idsByType.put(type, new Set<Id>());
            }
            idsByType.get(type).add(inParam.recordId);
        }

        for (SObjectType type : idsByType.keySet()) {
            Set<Id> ids = idsByType.get(type);
            if (ids.isEmpty()) continue;

            Map<String, Schema.SObjectField> fieldMap =
                type.getDescribe().fields.getMap();

            // Always select Id
            List<String> selectFields = new List<String>{ 'Id' };

            // Add fields that might be useful for RelationshipContextService
            if (fieldMap.containsKey('AccountId')) {
                selectFields.add('AccountId');
            }
            if (fieldMap.containsKey('Account__c')) {
                selectFields.add('Account__c');
            }
            if (fieldMap.containsKey('Business_Unit__c')) {
                selectFields.add('Business_Unit__c');
            }
            if (fieldMap.containsKey('Service_Relationship__c')) {
                selectFields.add('Service_Relationship__c');
            }

            String soql = 'SELECT ' + String.join(selectFields, ',') +
                          ' FROM ' + String.valueOf(type) +
                          ' WHERE Id IN :ids';

            for (SObject rec : Database.query(soql)) {
                results.put((Id)rec.get('Id'), rec);
            }
        }

        return results;
    }
}
