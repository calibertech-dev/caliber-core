public with sharing class ServiceRelationshipTriggerHandler {

    public static void run(Boolean isBefore, Boolean isAfter,
                           List<Service_Relationship__c> newList,
                           Map<Id, Service_Relationship__c> oldMap) {

        if (isBefore) {
            handleBefore(newList, oldMap);
        } else if (isAfter) {
            handleAfter(newList, oldMap);
        }
    }

    // ------------------------------------------------------------
    // BEFORE: record mutation (naming, assignment, defaults)
    // ------------------------------------------------------------
    private static void handleBefore(List<Service_Relationship__c> newList,
                                     Map<Id, Service_Relationship__c> oldMap) {

        if (Trigger.isInsert || Trigger.isUpdate) {
            ServiceRelationshipNameService.populateNames(newList);
        }

        // if later you create:
        // ServiceRelationshipAssignmentService.assign(newList);
        // …this is where it goes.
    }

    // ------------------------------------------------------------
    // AFTER: recalculations affecting other records (sharing)
    // ------------------------------------------------------------
    private static void handleAfter(List<Service_Relationship__c> newList,
                                    Map<Id, Service_Relationship__c> oldMap) {

        Set<Id> srIds = new Set<Id>();

        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            for (Service_Relationship__c sr : newList) {
                srIds.add(sr.Id);
            }
        }

        if (Trigger.isUpdate || Trigger.isDelete) {
            for (Service_Relationship__c sr : oldMap.values()) {
                srIds.add(sr.Id);
            }
        }

        if (!srIds.isEmpty()) {
            BusinessUnitSharingService.recalcForServiceRelationships(srIds);
        }
    }
}
