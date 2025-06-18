
#### Step 1: Create a Dedicated Permission Set

First, create a Permission Set that contains all the permissions needed for the prompt to execute successfully. This is far better than adding permissions to an existing profile or a broad permission set.

1.  Go to **Setup** -> **Users** -> **Permission Sets**.
2.  Click **New**.
3.  **Label:** `Execute AI Prompt on Account` (or something descriptive).
4.  **API Name:** `Execute_AI_Prompt_on_Account`.
5.  **License:** Leave as `--None--` unless you know it needs a specific one.
6.  Click **Save**.

#### Step 2: Assign the Necessary Permissions to the New Permission Set

Now, edit this new Permission Set to grant it three types of access:

1.  **System Permissions (For AI):**
    *   In the Permission Set overview, click on **System Permissions**.
    *   Click **Edit**.
    *   Enable the following permissions:
        *   `Use Generative AI`: This is the parent permission, often required.
        *   `Run Generative AI Prompt Templates`: This is the specific permission that is causing your error.
    *   Click **Save**.

2.  **Object Permissions (For Data Access):**
    *   Go back to the Permission Set overview and click on **Object Settings**.
    *   Find the object your prompt is reading from (e.g., `Account`).
    *   Click **Edit**.
    *   Ensure it has at least **Read** access on the object itself.

3.  **Field-Level Security (For Data Access):**
    *   While still editing the object permissions, ensure you grant **Read Access** to every single field that your prompt template uses as an input. For example, if your prompt uses `Account.Name` and `Account.Description`, both fields must have read access.
    *   If your process will later *update* a field with the prompt's result (e.g., `Account.AI_Summary__c`), you must also grant **Edit Access** to that specific field.
    *   Click **Save**.

#### Step 3: Associate the Permission Set with the Prompt Template

This is the final, crucial step that solves your problem.

1.  Go to **Setup** -> **AI** -> **Prompt Builder**.
2.  Open your specific Prompt Template for editing.
3.  On the Prompt Template's record page, look for a field or setting related to access or execution. This is typically labeled **"Run As"** or might be in an "Access" section.
4.  Set this lookup to be **Permission Set**.
5.  In the field that appears, select the Permission Set you just created (`Execute AI Prompt on Account`).
6.  **Save** the Prompt Template.

