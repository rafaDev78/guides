public class CaseJsonGenerator {

    /**
     * @description Queries Case records and dynamically builds a JSON string based on the fields
     *              returned in the query, respecting the running user's Field-Level Security (FLS).
     * @param caseIds A List of Case Ids to include in the JSON.
     * @return A JSON string representing an array of Case objects.
     */
    public static String getCasesAsJson(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return '[]'; // Return an empty JSON array if no Ids are provided
        }

        // 1. Define the list of fields you are interested in.
        List<String> desiredFields = new List<String>{
            'Id', 'CaseNumber', 'Subject', 'Status', 'Priority', 'Origin', 'CreatedDate'
        };

        // 2. Check FLS and build a list of accessible fields for the dynamic query.
        List<String> accessibleFields = new List<String>();
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();

        for (String fieldName : desiredFields) {
            // Use isAccessible() to check if the current user has read permission.
            if (caseFieldMap.get(fieldName).getDescribe().isAccessible()) {
                accessibleFields.add(fieldName);
            }
        }

        // If the user can't access any of the desired fields, we can't query anything.
        // We'll return an empty array, though in a real scenario you might add 'Id'
        // by default if it's always needed and accessible.
        if (accessibleFields.isEmpty()) {
            return '[]';
        }
        
        // 3. Construct and execute the dynamic SOQL query.
        String soqlQuery = 'SELECT ' + String.join(accessibleFields, ', ') +
                           ' FROM Case WHERE Id IN :caseIds';
        
        List<Case> cases = Database.query(soqlQuery);

        // 4. Use JSONGenerator to efficiently build the JSON string.
        JSONGenerator gen = JSON.createGenerator(true); // 'true' for pretty print

        gen.writeStartArray(); // Start JSON array: [

        for (Case myCase : cases) {
            gen.writeStartObject(); // Start JSON object: {

            // 5. THE CORE LOGIC: Get only the fields that were populated by the SOQL query.
            Map<String, Object> populatedFields = myCase.getPopulatedFieldsAsMap();

            // Iterate over the keys (field API names) of the populated fields map.
            for (String fieldName : populatedFields.keySet()) {
                Object fieldValue = populatedFields.get(fieldName);
                
                // Write the field name and its value to the JSON.
                // gen.writeObject handles all data types (String, Datetime, Number, etc.) correctly.
                gen.writeFieldName(fieldName);
                gen.writeObject(fieldValue);
            }

            gen.writeEndObject(); // End JSON object: }
        }

        gen.writeEndArray(); // End JSON array: ]

        // Return the complete JSON string.
        return gen.getAsString();
    }
}
