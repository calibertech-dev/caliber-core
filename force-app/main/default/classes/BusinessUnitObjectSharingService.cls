public with sharing class BusinessUnitObjectSharingService {

    // ===== Test seam =====
    @TestVisible static Boolean skipDmlForTest = false;
    @TestVisible static List<SObject> lastInsertedShares = new List<SObject>();
    @TestVisible static List<SObject> lastDeletedShares  = new List<SObject>();

    /**
     * Generic BU-based sharing:
     *  - records: all same SObject type
     *  - each has Business_Unit__c (lookup)
     * We:
     *  - group records by BU
     *  - look up active Business_Unit_Affiliation__c for those BUs
     *  - recreate manual shares for each (record, user) pair
     */
    public static void recalcForRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) return;

        // All records must be same type
        SObjectType sType  = records[0].getSObjectType();
        String objApiName  = sType.getDescribe().getName(); // e.g. "Service_Relationship__c"

        // Ensure Business_Unit__c exists on this object
        Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();
        if (!fields.containsKey('Business_Unit__c')) {
            return; // object is not BU-aware
        }

        // Collect BU → record IDs and recordIds for cleanup
        Map<Id, List<Id>> buToRecordIds = new Map<Id, List<Id>>();
        Set<Id> recordIds = new Set<Id>();

        for (SObject r : records) {
            if (r == null) continue;

            Id rid = (Id) r.get('Id');
            if (rid == null) continue;
            recordIds.add(rid);

            Id buId = (Id) r.get('Business_Unit__c');
            if (buId == null) continue;

            List<Id> idsForBu = buToRecordIds.get(buId);
            if (idsForBu == null) {
                idsForBu = new List<Id>();
                buToRecordIds.put(buId, idsForBu);
            }
            idsForBu.add(rid);
        }

        if (buToRecordIds.isEmpty()) return;

        // Load active affiliations for all BUs in play
        Map<Id, List<Business_Unit_Affiliation__c>> affilsByBu =
            new Map<Id, List<Business_Unit_Affiliation__c>>();

        for (Business_Unit_Affiliation__c bua : [
            SELECT Id, User__c, Business_Unit__c, Is_Active__c
            FROM Business_Unit_Affiliation__c
            WHERE Business_Unit__c IN :buToRecordIds.keySet()
              AND Is_Active__c = true
        ]) {
            List<Business_Unit_Affiliation__c> listForBu = affilsByBu.get(bua.Business_Unit__c);
            if (listForBu == null) {
                listForBu = new List<Business_Unit_Affiliation__c>();
                affilsByBu.put(bua.Business_Unit__c, listForBu);
            }
            listForBu.add(bua);
        }

        // Resolve the share SObject type
        String shareTypeName;
        if (objApiName.endsWith('__c')) {
            // Custom object: Foo__c → Foo__Share
            shareTypeName = objApiName.substring(0, objApiName.length() - 3) + '__Share';
        } else {
            // Standard object: Opportunity → OpportunityShare
            shareTypeName = objApiName + 'Share';
        }

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType shareSObjectType = gd.get(shareTypeName);
        if (shareSObjectType == null) {
            // No share table for this object (OWD too open or controlled-by-parent)
            return;
        }

        // 1) Find existing manual shares for these records
        String soql =
            'SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause ' +
            'FROM ' + shareTypeName +
            ' WHERE ParentId IN :recordIds ' +
            '   AND RowCause = \'Manual\'';

        List<SObject> existingShares = Database.query(soql);

        // 2) Build new shares (but don't DML yet)
        List<SObject> newShares = new List<SObject>();

        for (Id buId : buToRecordIds.keySet()) {
            List<Business_Unit_Affiliation__c> affs = affilsByBu.get(buId);
            if (affs == null || affs.isEmpty()) continue;

            for (Id recId : buToRecordIds.get(buId)) {
                for (Business_Unit_Affiliation__c aff : affs) {
                    if (aff.User__c == null) continue;

                    SObject share = shareSObjectType.newSObject();
                    share.put('ParentId',      recId);
                    share.put('UserOrGroupId', aff.User__c);
                    share.put('AccessLevel',   'Edit');
                    // RowCause left null → 'Manual' for custom objects

                    newShares.add(share);
                }
            }
        }

        // ===== Test mode: capture intents and bail before DML =====
        if (Test.isRunningTest() && skipDmlForTest) {
            lastDeletedShares  = existingShares.deepClone(true, true, true);
            lastInsertedShares = newShares.deepClone(true, true, true);
            return;
        }

        // ===== Real DML path =====
        if (!existingShares.isEmpty()) {
            delete existingShares;
        }
        if (!newShares.isEmpty()) {
            Database.insert(newShares);
        }
    }
}
