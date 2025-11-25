trigger ReviewRequestTrigger on Review_Request__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ReviewRequestTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ReviewRequestTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        ReviewRequestTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
