/**
 * @description Handler for the ContentDocumentLink trigger.
 *              Responsible for creating a Task when a Note is linked to a Case.
 */
public with sharing class ContentDocumentLinkTriggerHandler {
  /**
   * @description After a link is inserted, check if it's a Note being linked
   *              to a Case. If so, create a corresponding Task.
   * @param newLinks The list of new ContentDocumentLink records from Trigger.new
   */
  public void handleAfterInsert(List<ContentDocumentLink> newLinks) {
    Set<Id> noteDocIds = new Set<Id>();
    Map<Id, Id> noteIdToCaseIdMap = new Map<Id, Id>();
    String caseIdPrefix = Case.SObjectType.getDescribe().getKeyPrefix();

    //Filter for links that connect a document to a Case.
    for (ContentDocumentLink cdl : newLinks) {
      // We only care about links to Cases and where the sharing is direct (not via a library, etc.)
      if (
        String.valueOf(cdl.LinkedEntityId).startsWith(caseIdPrefix) &&
        cdl.ShareType == 'V'
      ) {
        noteDocIds.add(cdl.ContentDocumentId);
        noteIdToCaseIdMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
      }
    }

    if (noteDocIds.isEmpty()) {
      return; // No links to Cases, so we exit.
    }

    //Query the documents to ensure they are Notes ('SNOTE').
    //Exclude notes that already have a Task to prevent duplicates
    Set<Id> docsThatNeedTasks = new Set<Id>();
    Set<Id> docsThatAlreadyHaveTasks = new Set<Id>();

    for (Task existingTask : [
      SELECT Originating_Note_Id__c
      FROM Task
      WHERE Originating_Note_Id__c IN :noteDocIds
    ]) {
      docsThatAlreadyHaveTasks.add(existingTask.Originating_Note_Id__c);
    }

    for (ContentDocument doc : [
      SELECT Id
      FROM ContentDocument
      WHERE Id IN :noteDocIds AND FileType = 'SNOTE'
    ]) {
      if (!docsThatAlreadyHaveTasks.contains(doc.Id)) {
        docsThatNeedTasks.add(doc.Id);
      }
    }

    if (docsThatNeedTasks.isEmpty()) {
      return; // All notes found were either not SNOTEs or already had tasks so exit.
    }

    //Get the content of the notes that need a Task.
    List<Task> tasksToInsert = new List<Task>();
    for (ContentVersion version : [
      SELECT Title, VersionData, ContentDocumentId
      FROM ContentVersion
      WHERE ContentDocumentId IN :docsThatNeedTasks AND IsLatest = TRUE
    ]) {
      Task newTask = new Task();
      newTask.WhatId = noteIdToCaseIdMap.get(version.ContentDocumentId);
      newTask.OwnerId = UserInfo.getUserId(); // Defaults to the running user
      newTask.Subject = 'Note: ' + version.Title;
      newTask.Status = 'Not Started'; // Required field
      newTask.Priority = 'Normal'; // Required field
      newTask.Type = 'Case Note';
      newTask.Originating_Note_Id__c = version.ContentDocumentId;

      if (version.VersionData != null) {
        String plainTextContent = version.VersionData.toString()
          .stripHtmlTags()
          .unescapeHtml4();
        newTask.Description = plainTextContent.abbreviate(32768);
      }
      tasksToInsert.add(newTask);
    }

    //Insert the new Tasks.
    if (!tasksToInsert.isEmpty()) {
      try {
        insert tasksToInsert;
      } catch (DmlException e) {
        // Basic error log
        System.debug('Error creating Tasks from Notes: ' + e.getMessage());
      }
    }
  }
}
