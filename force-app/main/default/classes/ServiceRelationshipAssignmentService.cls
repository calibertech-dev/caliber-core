public with sharing class ServiceRelationshipAssignmentService {

    /**
     * Generic assignment:
     * - Only acts on records that:
     *     - have a Service_Relationship__c field,
     *     - that field is currently null,
     *     - and have both an Account (Account__c / AccountId) and Business_Unit__c.
     * - Finds or creates Service_Relationship__c records per (Account, BU) pair.
     * - Sets Service_Relationship__c on the in-memory records (Trigger.new).
     *
     * Supports:
     * - Any Caliber object with those fields (Invoice__c, Contract__c, etc.)
     * - Any custom object that follows the same field conventions.
     */
    public static void assign(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        // Map key: "<AccountId>:<BusinessUnitId>" -> records needing SR
        Map<String, List<SObject>> recordsByKey = new Map<String, List<SObject>>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> buIds = new Set<Id>();

        for (SObject rec : records) {
            if (rec == null) continue;

            // Must have an SR field to participate
            if (!hasField(rec, 'Service_Relationship__c')) continue;

            // Skip if SR already set
            if (rec.get('Service_Relationship__c') != null) continue;

            // Resolve Account
            Id accountId = null;
            if (hasField(rec, 'Account__c')) {
                accountId = (Id) rec.get('Account__c');
            } else if (hasField(rec, 'AccountId')) {
                accountId = (Id) rec.get('AccountId');
            }

            // Resolve Business Unit
            Id buId = null;
            if (hasField(rec, 'Business_Unit__c')) {
                buId = (Id) rec.get('Business_Unit__c');
            }

            if (accountId == null || buId == null) {
                // Not enough info to assign SR
                continue;
            }

            String key = makeKey(accountId, buId);

            if (!recordsByKey.containsKey(key)) {
                recordsByKey.put(key, new List<SObject>());
            }
            recordsByKey.get(key).add(rec);

            accountIds.add(accountId);
            buIds.add(buId);
        }

        if (recordsByKey.isEmpty()) {
            return;
        }

        // Query existing Service Relationships for the (Account, BU) pairs
        Map<String, Service_Relationship__c> srByKey = new Map<String, Service_Relationship__c>();

        if (!accountIds.isEmpty() && !buIds.isEmpty()) {
            for (Service_Relationship__c sr : [
                SELECT Id, Account__c, Business_Unit__c
                FROM Service_Relationship__c
                WHERE Account__c IN :accountIds
                  AND Business_Unit__c IN :buIds
            ]) {
                String key = makeKey(sr.Account__c, sr.Business_Unit__c);
                if (!srByKey.containsKey(key)) {
                    srByKey.put(key, sr);
                }
            }
        }

        // Create missing Service Relationships
        List<Service_Relationship__c> toInsert = new List<Service_Relationship__c>();
        for (String key : recordsByKey.keySet()) {
            if (!srByKey.containsKey(key)) {
                List<String> parts = key.split(':');
                Id accId = (Id) parts[0];
                Id buId  = (Id) parts[1];

                Service_Relationship__c newSr = new Service_Relationship__c(
                    Account__c       = accId,
                    Business_Unit__c = buId
                );
                toInsert.add(newSr);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (Service_Relationship__c sr : toInsert) {
                String key = makeKey(sr.Account__c, sr.Business_Unit__c);
                srByKey.put(key, sr);
            }
        }

        // Assign SR Ids back onto the records
        for (String key : recordsByKey.keySet()) {
            Service_Relationship__c sr = srByKey.get(key);
            if (sr == null) continue;

            for (SObject rec : recordsByKey.get(key)) {
                rec.put('Service_Relationship__c', sr.Id);
            }
        }
    }

    // --- Helpers ---

    private static Boolean hasField(SObject record, String fieldName) {
        return record.getSObjectType()
                     .getDescribe()
                     .fields
                     .getMap()
                     .containsKey(fieldName);
    }

    private static String makeKey(Id accountId, Id buId) {
        return String.valueOf(accountId) + ':' + String.valueOf(buId);
    }
}
