trigger BusinessUnitAffiliationTrigger on Business_Unit_Affiliation__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            BusinessUnitAffiliationTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            BusinessUnitAffiliationTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        // Convert to simple lists for the handler
        List<Business_Unit_Affiliation__c> newList =
            (Trigger.isDelete ? null : Trigger.new);
        List<Business_Unit_Affiliation__c> oldList =
            (Trigger.isInsert ? null : Trigger.old);

        BusinessUnitAffiliationTriggerHandler.afterAll(newList, oldList);
    }
}
