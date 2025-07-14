public with sharing class QueryRetrieverAction {
  //Request (Input) Class
  // The input variable MUST be of the type that the Flow provides.
  // This is the key change.
  public class Request {
    @InvocableVariable(
      label='Retriever Results'
      description='The structured Apex output from a Flow Retriever Action.'
      required=true
    )
    public ConnectApi.MlRetrieverQueryResultRepresentation retrieverResults;
  }

  //Response (Output) Class
  // This remains the same. We want to return a simple list of Case sObjects.
  public class Response {
    @InvocableVariable(
      label='Accesible Cases'
      description='Permissions-filtered list of case records.'
    )
    public List<Case> accessibleCases;
    @InvocableVariable
    public String casesAsJson;
  }

  //The Invocable Method
  //single entry point for Flow.
  @InvocableMethod(
    label='Process and Secure Flow Retriever Results'
    description='Takes structured retriever results from a Flow and returns secure records.'
  )
  public static List<Response> processResults(List<Request> requests) {
    ConnectApi.MlRetrieverQueryResultRepresentation retrieverData = requests[0]
      .retrieverResults;

    Log__c logOfRetriever = new Log__c();
    logOfRetriever.Message__c = JSON.serializePretty(retrieverData);
    insert logOfRetriever;

    Set<Id> idsToQuery = new Set<Id>();
    if (retrieverData != null && retrieverData.searchResults != null) {
      for (
        ConnectApi.MlRetrieverQueryResultDocumentRepresentation searchResult : retrieverData.searchResults
      ) {
        for (
          ConnectApi.MlRetrieverQueryResultDocumentContentRepresentation result : searchResult.result
        ) {
          if (result.fieldApiKey == 'ssot__Id__c') {
            idsToQuery.add((Id) result.value);
          }
        }
      }
    }

    // Getting Cases within SF with Sharing settings to respect User permissions.

    List<Case> secureCases = new List<Case>();
    if (!idsToQuery.isEmpty()) {
      secureCases = [
        SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate
        FROM Case
        WHERE Id IN :idsToQuery
      ];
    }

    Response finalResponse = new Response();
    finalResponse.accessibleCases = secureCases;
    finalResponse.casesAsJson = JSON.serializePretty(secureCases);

    return new List<Response>{ finalResponse };
  }
}
