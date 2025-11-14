public class PolymorphicRecordNameInvocable {
    public class Input {
        @InvocableVariable(required=true)
        public Id recordId;
        @InvocableVariable(required=true)
        public String recordType;
    }
    public class Output {
        @InvocableVariable
        public String recordName;
    }
    
    @InvocableMethod(label='Get Record Name From Id and Type')
    public static List<Output> getRecordNames(List<Input> inputs) {
        // Bulk grouping for SOQL
        Map<String, Set<Id>> typeToIds = new Map<String, Set<Id>>();
        for (Input inp : inputs) {
            if (!String.isBlank(inp.recordType) && inp.recordId != null) {
                if (!typeToIds.containsKey(inp.recordType)) {
                    typeToIds.put(inp.recordType, new Set<Id>());
                }
                typeToIds.get(inp.recordType).add(inp.recordId);
            }
        }
        // Query all Names
        Map<String, String> idTypeToName = new Map<String, String>();
        for (String objType : typeToIds.keySet()) {
            Set<Id> ids = typeToIds.get(objType);
            String soql = 'SELECT Id, Name FROM ' + objType + ' WHERE Id IN :ids';
            List<SObject> records = Database.query(soql);
            for (SObject r : records) {
                idTypeToName.put(objType + ':' + (String)r.get('Id'), (String)r.get('Name'));
            }
        }

        // Return output
        List<Output> outputs = new List<Output>();
        for (Input inp : inputs) {
            Output outp = new Output();
            if (!String.isBlank(inp.recordType) && inp.recordId != null) {
                outp.recordName = idTypeToName.get(inp.recordType + ':' + (String)inp.recordId);
            } else {
                outp.recordName = null;
            }
            outputs.add(outp);
        }
        return outputs;
    }
}
