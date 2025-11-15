public with sharing class PolymorphicRecordNameService {

    /**
     * Generic helper for before-insert/before-update.
     * newList: Trigger.new
     * oldMap:  Trigger.oldMap (or null for inserts)
     */
    public static void updateParentRecordNames(List<SObject> newList,
                                               Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        List<SObject> toProcess = new List<SObject>();

        // Insert: oldMap == null
        if (oldMap == null) {
            for (SObject rec : newList) {
                String parentType = (String)rec.get('Parent_Record_Type__c');
                String parentId   = (String)rec.get('Parent_Record_Id__c');

                // If either is set, let the util decide what to do
                if (!String.isBlank(parentType) || !String.isBlank(parentId)) {
                    toProcess.add(rec);
                }
            }
        } else {
            // Update: only process records whose parent Type/Id changed
            for (SObject rec : newList) {
                SObject oldRec = oldMap.get((Id)rec.get('Id'));

                String parentType    = (String)rec.get('Parent_Record_Type__c');
                String parentId      = (String)rec.get('Parent_Record_Id__c');
                String oldParentType = (String)oldRec.get('Parent_Record_Type__c');
                String oldParentId   = (String)oldRec.get('Parent_Record_Id__c');

                Boolean changedType = parentType != oldParentType;
                Boolean changedId   = parentId   != oldParentId;

                if (changedType || changedId) {
                    toProcess.add(rec);
                }
            }
        }

        if (!toProcess.isEmpty()) {
            // This calls the core class from caliber-core
            PolymorphicRecordNameUtil.updateRecordNames(toProcess);
        }
    }
}
