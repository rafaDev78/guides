// === TOOLING API SCRIPT - RUN ONCE ===
// This script configures the user for the platform event trigger subscription.

// 1. Find the user and the trigger. Use precise names.
User integrationUser = [SELECT Id FROM User WHERE Username = 'your.integration.user@example.com' AND IsActive = true LIMIT 1];
ApexTrigger eventTrigger = [SELECT Id, Name FROM ApexTrigger WHERE Name = 'PromptRequestEventTrigger' LIMIT 1];

// 2. Prepare the JSON body for the request.
// The DeveloperName for the config record can be what you want, but often matches the trigger.
String jsonBody = JSON.serialize(new Map<String, Object>{
    'DeveloperName' => 'PromptRequestEventTriggerConfig',
    'MasterLabel' => 'Prompt Request Event Trigger Config',
    'ApexTriggerId' => eventTrigger.Id,
    'UserId' => integrationUser.Id
});

// 3. Build and send the HTTP request to the Tooling API endpoint.
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v60.0/tooling/sobjects/PlatformEventSubscriberConfig/');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');
req.setBody(jsonBody);

HttpResponse res = new Http().send(req);
System.debug('Configuration Result: ' + res.getStatusCode() + ' ' + res.getBody());
