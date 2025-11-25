trigger ServiceRelationshipTrigger on Service_Relationship__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    ServiceRelationshipTriggerHandler.run(Trigger.isBefore, Trigger.isAfter, Trigger.new, Trigger.oldMap);
}
