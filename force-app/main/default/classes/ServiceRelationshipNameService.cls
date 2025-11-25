public with sharing class ServiceRelationshipNameService {

    /**
     * Populate Service_Relationship__c.Name as:
     *   Business_Unit__r.Short_Code__c + Account__r.AccountNumber
     *
     * Rules:
     * - Only runs on records that have BOTH Account__c and Business_Unit__c.
     * - Only sets Name if it is currently blank.
     * - If either Short_Code__c or AccountNumber is blank, leaves Name alone.
     */
    public static void populateNames(List<Service_Relationship__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        // Collect Account and BU Ids for a single bulk query each
        Set<Id> accountIds = new Set<Id>();
        Set<Id> buIds = new Set<Id>();

        for (Service_Relationship__c sr : records) {
            if (sr == null) continue;

            if (sr.Account__c != null) {
                accountIds.add(sr.Account__c);
            }
            if (sr.Business_Unit__c != null) {
                buIds.add(sr.Business_Unit__c);
            }
        }

        Map<Id, Account> accountsById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, AccountNumber
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                accountsById.put(acc.Id, acc);
            }
        }

        Map<Id, Business_Unit__c> buById = new Map<Id, Business_Unit__c>();
        if (!buIds.isEmpty()) {
            for (Business_Unit__c bu : [
                SELECT Id, Short_Code__c
                FROM Business_Unit__c
                WHERE Id IN :buIds
            ]) {
                buById.put(bu.Id, bu);
            }
        }

        // Set Name where we have enough info
        for (Service_Relationship__c sr : records) {
            if (sr == null) continue;

            // Don't overwrite if Name is already set
            if (!String.isBlank(sr.Name)) continue;

            Account acc = (sr.Account__c == null)
                ? null
                : accountsById.get(sr.Account__c);
            Business_Unit__c bu = (sr.Business_Unit__c == null)
                ? null
                : buById.get(sr.Business_Unit__c);

            if (acc == null || bu == null) {
                continue;
            }

            String acctNum   = acc.AccountNumber;
            String shortCode = bu.Short_Code__c;

            if (String.isBlank(shortCode) || String.isBlank(acctNum)) {
                // Not enough to build a nice ID; leave Name blank
                continue;
            }

            sr.Name = shortCode + acctNum;
        }
    }
}
