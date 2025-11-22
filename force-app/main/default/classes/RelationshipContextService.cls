public with sharing class RelationshipContextService {

    // Represents the "who are we dealing with?" context for a record.
    public class RelationshipContext {
        public Id accountId;
        public Id businessUnitId;
        public Id serviceRelationshipId;
    }

    /**
     * Given any SObject, resolve the Account / Business Unit context.
     *
     * For now, this only uses fields directly on the record:
     * - AccountId (standard objects)
     * - Account__c (custom objects like Invoice__c)
     * - Business_Unit__c
     *
     * serviceRelationshipId will always be null until we wire in
     * the Multi-Entity expansion later.
     */
    public static RelationshipContext resolve(SObject record) {
        if (record == null) {
            return null;
        }

        RelationshipContext ctx = new RelationshipContext();

        // --- Account from common patterns ---
        if (hasField(record, 'AccountId')) {
            Object accVal = record.get('AccountId');
            if (accVal instanceof Id) {
                ctx.accountId = (Id)accVal;
            }
        }

        if (ctx.accountId == null && hasField(record, 'Account__c')) {
            Object accVal = record.get('Account__c');
            if (accVal instanceof Id) {
                ctx.accountId = (Id)accVal;
            }
        }

        // --- Business Unit ---
        if (hasField(record, 'Business_Unit__c')) {
            Object buVal = record.get('Business_Unit__c');
            if (buVal instanceof Id) {
                ctx.businessUnitId = (Id)buVal;
            }
        }

        // NOTE: no plugin hook yet; serviceRelationshipId stays null.
        return ctx;
    }

    private static Boolean hasField(SObject record, String fieldName) {
        return record.getSObjectType()
                     .getDescribe()
                     .fields
                     .getMap()
                     .containsKey(fieldName);
    }
}
