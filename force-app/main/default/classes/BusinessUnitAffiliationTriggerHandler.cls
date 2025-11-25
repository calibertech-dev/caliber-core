public with sharing class BusinessUnitAffiliationTriggerHandler {

    public static void afterAll(
        List<Business_Unit_Affiliation__c> newList,
        Map<Id, Business_Unit_Affiliation__c> oldMap
    ) {
        List<Business_Unit_Affiliation__c> newRows = null;
        List<Business_Unit_Affiliation__c> oldRows = null;

        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            newRows = newList;
        }
        if (Trigger.isUpdate || Trigger.isDelete) {
            oldRows = (oldMap == null)
                ? null
                : new List<Business_Unit_Affiliation__c>(oldMap.values());
        }

        BusinessUnitSharingService.recalcForAffiliations(newRows, oldRows);
    }
}
