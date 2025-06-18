

### Step 1: Define the Platform Event

First, we create the "contract" or the message that the integration will send. This is our custom Platform Event.

1.  Go to **Setup** -> **Integrations** -> **Platform Events**.
2.  Click **New Platform Event**.
3.  **Label:** `Prompt Request`
4.  **Plural Label:** `Prompt Requests`
5.  **Object Name:** `PromptRequest` (The API name will be `PromptRequest__e`).
6.  **Publish Behavior:** `Publish After Commit`. This is crucial. It ensures the event is only published if the database transaction that triggered it (the record update from your REST service) is successfully committed. This prevents the event from firing on a rolled-back transaction.
7.  Click **Save**.
8.  In the "Custom Fields & Relationships" section, click **New**.
9.  **Type:** `Text Area (Long)`
10. **Field Label:** `Record Ids JSON`
11. **Length:** `131072` (the maximum)
12. **Field Name:** `RecordIdsJson`
13. Click **Save**.

**Why this design?**
We use a single JSON string field because Platform Events do not support collection types (like `List<Id>`). Serializing the list of record Ids into JSON is the standard and most flexible pattern.

---

### Step 2: Modify the REST Service to Publish the Event

Your existing REST service needs one final step: to create and publish the `PromptRequest__e` event after it has successfully prepared its DML operations.

Let's assume your REST service updates `Account` records.

```apex
/**
 * @description Handles incoming requests from the external integration.
 * This class is an example; adapt it to your actual request structure.
 */
@RestResource(urlMapping='/api/accounts/updateFields/*')
global with sharing class IntegrationRestController {

    @HttpPost
    global static void updateAccounts() {
        // 1. Deserialize the incoming request from the integration
        // This is a simplified example. Your request body might be more complex.
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        List<AccountUpdateRequest> updateRequests = (List<AccountUpdateRequest>) JSON.deserialize(requestBody, List<AccountUpdateRequest>.class);

        // 2. Prepare records for DML in a bulk-safe way
        List<Account> accountsToUpdate = new List<Account>();
        Set<Id> updatedAccountIds = new Set<Id>();

        for (AccountUpdateRequest uReq : updateRequests) {
            accountsToUpdate.add(new Account(
                Id = uReq.accountId,
                Integration_Field_A__c = uReq.fieldA,
                Integration_Field_B__c = uReq.fieldB
            ));
            updatedAccountIds.add(uReq.accountId);
        }

        // 3. Perform DML
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;

                // 4. *** BEST PRACTICE: Publish the event AFTER successful DML ***
                // This code runs only if the `update` statement does not throw an exception.
                publishPromptRequestEvent(updatedAccountIds);

            } catch (DmlException e) {
                // Handle DML errors appropriately (e.g., log them, return an error response)
                RestContext.response.statusCode = 400;
                RestContext.response.responseBody = Blob.valueOf('Error updating accounts: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Encapsulates the logic for creating and publishing the Platform Event.
     */
    private static void publishPromptRequestEvent(Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        // Create the event instance
        PromptRequest__e event = new PromptRequest__e(
            RecordIdsJson__c = JSON.serialize(recordIds)
        );

        // Publish the event.
        // Because the event is 'Publish After Commit', it's held in a queue until the
        // entire REST transaction successfully commits to the database.
        Database.SaveResult sr = EventBus.publish(event);

        // Optional: Check if publishing was successful for logging/debugging
        if (!sr.isSuccess()) {
            for(Database.Error err : sr.getErrors()) {
                System.debug('Error publishing event: ' + err.getStatusCode() + ' - ' + err.getMessage());
                // Consider adding more robust error logging here
            }
        }
    }

    // Inner class to represent the expected JSON structure
    global class AccountUpdateRequest {
        global Id accountId;
        global String fieldA;
        global String fieldB;
    }
}
```

---

### Step 3: Create the Platform Event Trigger

This trigger is the subscriber. Its only job is to catch the event and delegate the work to a handler class. This is the **Trigger Handler Pattern**, a fundamental best practice for keeping your code organized, testable, and reusable.

**Trigger `PromptRequestEventTrigger.trigger`:**

```apex
/**
 * @description Trigger that subscribes to PromptRequest__e events.
 * It follows the handler pattern, delegating all logic to a separate class.
 */
trigger PromptRequestEventTrigger on PromptRequest__e (after insert) {
    // Delegate the processing of events to a dedicated handler class.
    // This keeps the trigger itself logic-less and simple.
    PromptRequestEventHandler.handleEvents(Trigger.new);
}
```

---

### Step 4: Create the Trigger Handler and Service Class

This is where the actual business logic lives. The handler class will parse the events and call your prompt service.

**Handler Class `PromptRequestEventHandler.cls`:**

```apex
/**
 * @description Handles the logic for PromptRequest__e events. It's designed to be
 * called from the trigger and is responsible for parsing and delegating work.
 */
public with sharing class PromptRequestEventHandler {

    /**
     * @description Entry point method to process a list of incoming events.
     * @param events List of PromptRequest__e events from the trigger context.
     */
    public static void handleEvents(List<PromptRequest__e> events) {
        Set<Id> allRecordIds = new Set<Id>();

        // 1. Bulk process all events and collect all unique record Ids.
        for (PromptRequest__e event : events) {
            // Defensive coding: ensure the JSON field is not blank
            if (String.isNotBlank(event.RecordIdsJson__c)) {
                try {
                    // Deserialize the JSON back into a List of Ids
                    List<Id> recordIdsFromEvent = (List<Id>) JSON.deserialize(event.RecordIdsJson__c, List<Id>.class);
                    allRecordIds.addAll(recordIdsFromEvent);
                } catch (JSONParseException e) {
                    // Robust error handling: What if the JSON is malformed?
                    // Log the error, notify an admin, etc.
                    System.debug('Error parsing JSON from PromptRequest__e: ' + e.getMessage());
                }
            }
        }

        // 2. If we have Ids to process, call the service class.
        if (!allRecordIds.isEmpty()) {
            // Delegate to the actual service class in a bulk-safe manner.
            // Using Queueable Apex here is a good practice if the service might
            // perform callouts or heavy processing, to ensure it doesn't fail
            // due to mixed DML or CPU limits within the trigger context.
            System.enqueueJob(new PromptTemplateServiceQueueable(allRecordIds));
        }
    }
}
```

**Service Class (as a Queueable) `PromptTemplateServiceQueueable.cls`:**

Using a Queueable here adds another layer of robustness. It moves the potentially long-running Connect API callout into its own separate, asynchronous transaction with higher governor limits.

```apex
/**
 * @description A Queueable job that executes a Prompt Template for a set of records.
 * Using a Queueable ensures the callout to the Connect API happens in a separate transaction,
 * preventing 'mixed DML' errors and providing higher governor limits.
 */
public with sharing class PromptTemplateServiceQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> recordIds;

    public PromptTemplateServiceQueueable(Set<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        // Since we may be executing prompts for multiple templates or record types,
        // it's good practice to fetch the data needed first.
        List<Account> accounts = [
            SELECT Id, Name, Description // Fetch fields needed for the prompt
            FROM Account
            WHERE Id IN :this.recordIds
        ];

        // This is a simplified example. In a real scenario, you would loop through
        // the accounts and dynamically build the input for the Connect API call.
        // For simplicity, we'll execute one prompt for the first record.
        if (!accounts.isEmpty()) {
            Account firstAccount = accounts[0];
            String promptInput = 'Summarize the following account: ' + firstAccount.Name + '. Description: ' + firstAccount.Description;

            // Prepare the input for the Connect API
            ConnectApi.PromptExecutionInput promptExecutionInput = new ConnectApi.PromptExecutionInput();
            promptExecutionInput.promptNameOrId = 'Your_Prompt_Template_API_Name'; // <-- IMPORTANT: Use your Prompt Template API Name
            promptExecutionInput.inputs = new Map<String, String>{
                'AccountInfo' => promptInput // 'AccountInfo' must match an input variable in your template
            };

            try {
                // Execute the prompt via the Connect API
                ConnectApi.PromptExecutionResult result = ConnectApi.Prompt.execute(promptExecutionInput);
                ConnectApi.PromptOutput promptOutput = result.output;

                // Process the result
                if (result.isSuccess) {
                    // Example: Update the record with the prompt's response
                    String promptResponse = promptOutput.text;
                    System.debug('Prompt Response: ' + promptResponse);
                    // You could perform another DML here to save the response to a field.
                    // e.g., firstAccount.Summary_From_AI__c = promptResponse; update firstAccount;
                    // (Ensure any DML here is also bulkified if you process multiple results)
                } else {
                    // Handle errors from the Connect API
                    System.debug('Error executing prompt: ' + result.errors);
                }

            } catch (Exception e) {
                // Handle exceptions during the callout
                System.debug('An exception occurred during the Connect API call: ' + e.getMessage());
            }
        }
    }
}
```

This complete structure provides a highly robust, scalable, and maintainable solution that correctly separates concerns and respects Salesforce's transaction boundaries and governor limits.
