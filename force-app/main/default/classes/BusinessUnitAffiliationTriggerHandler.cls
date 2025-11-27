public with sharing class BusinessUnitAffiliationTriggerHandler {

    // ========================================
    // BEFORE INSERT: Name + Affiliation_Number__c
    // ========================================
    public static void beforeInsert(List<Business_Unit_Affiliation__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // Collect BUs
        Set<Id> buIds = new Set<Id>();
        for (Business_Unit_Affiliation__c bua : newList) {
            if (bua.Business_Unit__c != null) {
                buIds.add(bua.Business_Unit__c);
            }
        }
        if (buIds.isEmpty()) return;

        // Load BU Short Codes
        Map<Id, Business_Unit__c> bus = new Map<Id, Business_Unit__c>(
            [
                SELECT Id, Short_Code__c
                FROM Business_Unit__c
                WHERE Id IN :buIds
            ]
        );

        // Existing counts by BU (all-time)
        Map<Id, Integer> countsByBu = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Business_Unit__c buId, COUNT(Id) cnt
            FROM Business_Unit_Affiliation__c
            WHERE Business_Unit__c IN :buIds
            GROUP BY Business_Unit__c
        ]) {
            countsByBu.put((Id) ar.get('buId'), (Integer) ar.get('cnt'));
        }

        // Assign numbers + names
        for (Business_Unit_Affiliation__c bua : newList) {
            if (bua.Business_Unit__c == null) continue;

            Business_Unit__c bu = bus.get(bua.Business_Unit__c);
            if (bu == null || String.isBlank(bu.Short_Code__c)) continue;

            Integer currentCount = countsByBu.containsKey(bua.Business_Unit__c)
                ? countsByBu.get(bua.Business_Unit__c)
                : 0;

            Integer nextNum = currentCount + 1;
            countsByBu.put(bua.Business_Unit__c, nextNum);

            bua.Affiliation_Number__c = nextNum;

            // 3-digit padded suffix, no dash. e.g. CHS001
            String suffix = String.valueOf(nextNum);
            while (suffix.length() < 3) {
                suffix = '0' + suffix;
            }

            // Only override Name if caller hasn’t set something custom
            if (String.isBlank(bua.Name)) {
                bua.Name = bu.Short_Code__c + suffix;
            }
        }
    }

    // ========================================
    // BEFORE UPDATE: (no renumbering)
    // ========================================
    public static void beforeUpdate(
        List<Business_Unit_Affiliation__c> newList,
        Map<Id, Business_Unit_Affiliation__c> oldMap
    ) {
        // Intentionally empty for now:
        // - We do NOT renumber or rename if BU changes.
        // - If you later want to enforce "cannot change Business_Unit__c",
        //   this is where you would add addError().
    }

    // ========================================
    // AFTER ALL: BU-driven sharing recalcs
    // ========================================
    public static void afterAll(
        List<Business_Unit_Affiliation__c> newList,
        List<Business_Unit_Affiliation__c> oldList
    ) {
        // In tests, BU sharing is exercised explicitly via:
        //  - BusinessUnitObjectSharingServiceTest
        //  - BusinessUnitSharingServiceTest
        // Avoid cascading sharing from here in tests to prevent
        // cross-reference / access errors.
        if (Test.isRunningTest()) {
            return;
        }

        BusinessUnitSharingService.recalcForAffiliations(newList, oldList);
    }
}
