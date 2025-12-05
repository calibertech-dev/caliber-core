public with sharing class BusinessUnitAccessService {

    public class Affiliation {
        public Id id;
        public Id userId;
        public Id businessUnitId;
        public String role;
        public Boolean isActive;
        public Boolean isPrimary;
        public Boolean canViewAll;
        public Boolean canManageBilling;
    }

    public static List<Affiliation> getAffiliationsForUser(Id userId) {
        if (userId == null) return new List<Affiliation>();

        List<Affiliation> out = new List<Affiliation>();
        for (Business_Unit_Affiliation__c bua : [
            SELECT Id,
                   User__c,
                   Business_Unit__c,
                   Role__c,
                   Is_Active__c,
                   Is_Primary__c,
                   Can_View_All_Records__c,
                   Can_Manage_Billing__c
            FROM Business_Unit_Affiliation__c
            WHERE User__c = :userId
        ]) {
            out.add(fromSObject(bua));
        }
        return out;
    }

    public static Boolean userHasAccessToBusinessUnit(Id userId, Id businessUnitId) {
        if (userId == null || businessUnitId == null) return false;

        Integer countAffils = [
            SELECT COUNT()
            FROM Business_Unit_Affiliation__c
            WHERE User__c = :userId
              AND Business_Unit__c = :businessUnitId
              AND Is_Active__c = true
        ];
        return countAffils > 0;
    }

    /************************************************
     * All *active* Business Units for a given user. *
     *************************************************/  
    public static Set<Id> getActiveBusinessUnitsForUser(Id userId) {
        Set<Id> buIds = new Set<Id>();
        if (userId == null) return buIds;

        for (Affiliation a : getAffiliationsForUser(userId)) {
            if (a.isActive && a.businessUnitId != null) {
                buIds.add(a.businessUnitId);
            }
        }
        return buIds;
    }

    /************************************************
     * Convenience for the current user.            *
     ************************************************/  
    public static Set<Id> getActiveBusinessUnitsForCurrentUser() {
        return getActiveBusinessUnitsForUser(UserInfo.getUserId());
    }

    @TestVisible
    private static Affiliation fromSObject(Business_Unit_Affiliation__c bua) {
        Affiliation a = new Affiliation();
        a.id              = bua.Id;
        a.userId          = bua.User__c;
        a.businessUnitId  = bua.Business_Unit__c;
        a.role            = bua.Role__c;
        a.isActive        = bua.Is_Active__c;
        a.isPrimary       = bua.Is_Primary__c;
        a.canViewAll      = bua.Can_View_All_Records__c;
        a.canManageBilling = bua.Can_Manage_Billing__c;
        return a;
    }
}
