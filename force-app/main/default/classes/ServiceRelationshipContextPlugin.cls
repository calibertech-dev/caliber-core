public with sharing class ServiceRelationshipContextPlugin
    implements IRelationshipContextPlugin {

    public RelationshipContextService.RelationshipContext enrichContext(
        SObject record,
        RelationshipContextService.RelationshipContext ctx
    ) {
        if (record == null) {
            return ctx;
        }

        // If the record already has a direct Service Relationship lookup, prefer that.
        if (hasField(record, 'Service_Relationship__c')) {
            Object srVal = record.get('Service_Relationship__c');
            if (srVal instanceof Id) {
                ctx.serviceRelationshipId = (Id)srVal;

                List<Service_Relationship__c> srs = [
                    SELECT Id, Account__c, Business_Unit__c
                    FROM Service_Relationship__c
                    WHERE Id = :ctx.serviceRelationshipId
                    LIMIT 1
                ];

                if (!srs.isEmpty()) {
                    Service_Relationship__c sr = srs[0];

                    ctx.accountId      = sr.Account__c;
                    ctx.businessUnitId = sr.Business_Unit__c;

                    return ctx;
                } else {
                    // Stale SR Id on the record – clear it from context
                    ctx.serviceRelationshipId = null;
                }
            }
        }


        // If we don't have a direct Service Relationship lookup yet,
        // but we know Account + Business Unit, we can find/create one.
        if (ctx.accountId != null && ctx.businessUnitId != null) {
            Service_Relationship__c sr = findOrCreateServiceRelationship(
                ctx.accountId,
                ctx.businessUnitId
            );

            ctx.serviceRelationshipId = sr.Id;
            ctx.accountId             = sr.Account__c;
            ctx.businessUnitId        = sr.Business_Unit__c;
        }

        return ctx;
    }

    private static Service_Relationship__c findOrCreateServiceRelationship(
        Id accountId,
        Id businessUnitId
    ) {
        List<Service_Relationship__c> existing = [
            SELECT Id, Account__c, Business_Unit__c
            FROM Service_Relationship__c
            WHERE Account__c = :accountId
              AND Business_Unit__c = :businessUnitId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = accountId,
            Business_Unit__c = businessUnitId,
            Start_Date__c    = Date.today()
        );
        insert sr;
        return sr;
    }

    private static Boolean hasField(SObject record, String fieldName) {
        return record.getSObjectType()
                     .getDescribe()
                     .fields
                     .getMap()
                     .containsKey(fieldName);
    }
}
