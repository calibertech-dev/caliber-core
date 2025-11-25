public with sharing class ReviewRequestTriggerHandler {

    public static void beforeInsert(List<Review_Request__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing review request logic (dates, counts, links to configs, etc.)
    }

    public static void beforeUpdate(List<Review_Request__c> newList, Map<Id, Review_Request__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing review request update logic
    }

    public static void afterAll(
        List<Review_Request__c> newList,
        Map<Id, Review_Request__c> oldMap
    ) {
        // Placeholder for:
        // - BU firewall
        // - Event creation, etc., if you ever want it here
    }
}
