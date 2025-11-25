trigger BusinessUnitAffiliationTrigger on Business_Unit_Affiliation__c (
    after insert, after update, after delete, after undelete
) {
    BusinessUnitAffiliationTriggerHandler.afterAll(
        Trigger.new,
        Trigger.oldMap
    );
}
