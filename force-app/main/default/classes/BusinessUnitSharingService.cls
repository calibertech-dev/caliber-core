public with sharing class BusinessUnitSharingService {

    /**
     * Recalculate sharing for a specific set of Service Relationships.
     */
    public static void recalcForServiceRelationships(Set<Id> serviceRelationshipIds) {
        if (serviceRelationshipIds == null || serviceRelationshipIds.isEmpty()) return;

        List<Service_Relationship__c> srs = [
            SELECT Id, Business_Unit__c
            FROM Service_Relationship__c
            WHERE Id IN :serviceRelationshipIds
        ];

        if (srs.isEmpty()) return;

        // Convert List<Service_Relationship__c> → List<SObject>
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(srs);

        BusinessUnitObjectSharingService.recalcForRecords(sobjs);
    }

    /**
     * Recalculate sharing for all Service Relationships whose Business Units
     * were impacted by changes to Business Unit Affiliations.
     */
    public static void recalcForAffiliations(
        List<Business_Unit_Affiliation__c> newRows,
        List<Business_Unit_Affiliation__c> oldRows
    ) {
        Set<Id> buIds = new Set<Id>();

        if (newRows != null) {
            for (Business_Unit_Affiliation__c bua : newRows) {
                if (bua.Business_Unit__c != null) {
                    buIds.add(bua.Business_Unit__c);
                }
            }
        }
        if (oldRows != null) {
            for (Business_Unit_Affiliation__c bua : oldRows) {
                if (bua.Business_Unit__c != null) {
                    buIds.add(bua.Business_Unit__c);
                }
            }
        }

        if (buIds.isEmpty()) return;

        // All SRs for impacted BUs
        List<Service_Relationship__c> srs = [
            SELECT Id, Business_Unit__c
            FROM Service_Relationship__c
            WHERE Business_Unit__c IN :buIds
        ];
        if (srs.isEmpty()) return;

        // Convert List<Service_Relationship__c> → List<SObject>
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(srs);

        BusinessUnitObjectSharingService.recalcForRecords(sobjs);
    }
}
