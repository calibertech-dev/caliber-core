public interface IRelationshipContextPlugin {

    /**
     * Given a record and the baseline context (AccountId / BusinessUnitId),
     * return an updated context.
     *
     * Implementations can:
     * - Set serviceRelationshipId
     * - Override businessUnitId (e.g., from Service_Relationship__c.Business_Unit__c)
     * - Create or find Service Relationship records
     */
    RelationshipContextService.RelationshipContext enrichContext(
        SObject record,
        RelationshipContextService.RelationshipContext ctx
    );
}
