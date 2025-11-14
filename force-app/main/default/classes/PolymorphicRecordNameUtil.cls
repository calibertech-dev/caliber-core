public class PolymorphicRecordNameUtil {
    /**
     * Given an sObject Id and sObject API name, returns the Name field of the referenced record.
     * @param recordId Id of the referenced record
     * @param recordType sObject type (API name, e.g., 'Account', 'Contact')
     * @return String Name field of the referenced record, or null if not found
     */
    public static String getRecordName(Id recordId, String recordType) {
        if (String.isBlank(recordType) || recordId == null) {
            return null;
        }

        // Build SOQL dynamically to query the Name field (safe since user controls type, not fields)
        String soql = 'SELECT Name FROM ' + recordType + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> results = Database.query(soql);
        if (!results.isEmpty()) {
            return (String)results[0].get('Name');
        }
        return null;
    }

    /**
     * Utility method to bulk update Parent_Record_Name__c for custom objects with Parent_Record_Id__c and Parent_Record_Type__c.
     * Call this in triggers or automation after populating Parent_Record_Id__c and Parent_Record_Type__c.
     */
    public static void updateRecordNames(List<SObject> customRecords) {
        // Collect all recordIds by type for bulk SOQL
        Map<String, Set<Id>> typeToIds = new Map<String, Set<Id>>();
        for (SObject obj : customRecords) {
            String recordType = (String)obj.get('Parent_Record_Type__c');
            Id recordId = (Id)obj.get('Parent_Record_Id__c');
            if (!String.isBlank(recordType) && recordId != null) {
                if (!typeToIds.containsKey(recordType)) {
                    typeToIds.put(recordType, new Set<Id>());
                }
                typeToIds.get(recordType).add(recordId);
            }
        }
        // Build a map: type+id -> name
        Map<String, String> idTypeToName = new Map<String, String>();
        for (String recordType : typeToIds.keySet()) {
            Set<Id> ids = typeToIds.get(recordType); // CORRECT - assign before query!
            String soql = 'SELECT Id, Name FROM ' + recordType + ' WHERE Id IN :ids';
            List<SObject> records = Database.query(soql);
            for (SObject r : records) {
                idTypeToName.put(recordType + ':' + (String)r.get('Id'), (String)r.get('Name'));
            }
        }
        // Set the names on the target records
        for (SObject obj : customRecords) {
            String recordType = (String)obj.get('Parent_Record_Type__c');
            Id recordId = (Id)obj.get('Parent_Record_Id__c');
            if (!String.isBlank(recordType) && recordId != null) {
                String recName = idTypeToName.get(recordType + ':' + (String)recordId);
                obj.put('Parent_Record_Name__c', recName);
            } else {
                obj.put('Parent_Record_Name__c', null);
            }
        }
    }

}
