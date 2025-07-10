/**
 * @description Handler class for the ContentVersion trigger.
 */
public with sharing class ContentVersionTriggerHandler {
  /**
   * @description On before update, validates that a ContentNote has been linked to a Case
   *              before its content is allowed to be modified.
   * @param newVersions The list of updated ContentVersion records from Trigger.new
   * @param oldVersionMap The map of old ContentVersion records from Trigger.oldMap
   */
  public void handleBeforeUpdate(
    List<ContentVersion> newVersions,
    Map<Id, ContentVersion> oldVersionMap
  ) {
    // Sets to collect Ids for processing
    Set<Id> docsToValidate = new Set<Id>();
    Set<Id> noteDocumentIds = new Set<Id>();
    Set<Id> docsLinkedToCases = new Set<Id>();

    //Detect which notes have actually changed using TextPreview ---
    for (ContentVersion newVersion : newVersions) {
      ContentVersion oldVersion = oldVersionMap.get(newVersion.Id);
      if (newVersion.VersionData != null) {
        if (newVersion.ContentDocumentId != null) {
          docsToValidate.add(newVersion.ContentDocumentId);
        }
      }
    }

    //System.debug('DocsToValidate == ' + docsToValidate);

    if (docsToValidate.isEmpty()) {
      return; // No changed notes to validate, exit early.
    }

    //From the changed documents, find which are unlinked Notes ---
    // Filter the changed documents to only include actual Notes ('SNOTE').
    for (ContentDocument doc : [
      SELECT Id
      FROM ContentDocument
      WHERE Id IN :docsToValidate AND FileType = 'SNOTE'
    ]) {
      noteDocumentIds.add(doc.Id);
    }

    if (noteDocumentIds.isEmpty()) {
      newVersions[0].addError('Add some error here.....');
      return; // The changes were not on notes, so we don't need to validate.
    }

    // Find which of the notes are linked to a Case by checking the prefix in Apex.
    System.debug('I get to get the prefix');
    String caseIdPrefix = Case.SObjectType.getDescribe().getKeyPrefix();
    System.debug('I break before the prefix...');
    for (ContentDocumentLink cdl : [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE ContentDocumentId IN :noteDocumentIds
    ]) {
      if (String.valueOf(cdl.LinkedEntityId).startsWith(caseIdPrefix)) {
        docsLinkedToCases.add(cdl.ContentDocumentId);
      }
    }

    // --- Step 3: Apply the error to the unlinked notes that were modified ---
    for (ContentVersion cv : newVersions) {
      // We only care about records we previously identified as needing validation.
      if (docsToValidate.contains(cv.ContentDocumentId)) {
        // Is this a note that is NOT linked to a case?
        if (
          noteDocumentIds.contains(cv.ContentDocumentId) &&
          !docsLinkedToCases.contains(cv.ContentDocumentId)
        ) {
          cv.addError(
            'Error: Note needs to be added to a Case record. Close and open the note to add a Case record to it before making any update.'
          );
        }
      }
    }
  }

  /**
   * @description After a ContentVersion is updated, this syncs the changes to the
   *              corresponding Task record.
   * @param newVersions The list of updated ContentVersion records from Trigger.new
   * @param oldVersionMap The map of old ContentVersion records from Trigger.oldMap
   */
  public void handleAfterUpdate(
    List<ContentVersion> newVersions,
    Map<Id, ContentVersion> oldVersionMap
  ) {
    Set<Id> changedNoteDocIds = new Set<Id>();

    //Find which notes have changed content by comparing VersionData.
    for (ContentVersion newVersion : newVersions) {
      ContentVersion oldVersion = oldVersionMap.get(newVersion.Id);
      if (
        newVersion.VersionData != oldVersion.VersionData ||
        newVersion.Title != oldVersion.Title
      ) {
        changedNoteDocIds.add(newVersion.ContentDocumentId);
      }
    }

    if (changedNoteDocIds.isEmpty()) {
      return; // No relevant notes were changed.
    }

    //Find the corresponding Tasks using our custom external ID field.
    List<Task> tasksToUpdate = [
      SELECT Id, Description, Subject, Originating_Note_Id__c
      FROM Task
      WHERE Originating_Note_Id__c IN :changedNoteDocIds
    ];

    if (tasksToUpdate.isEmpty()) {
      return; // No matching tasks were found so exit.
    }

    //Create a map of NoteId -> Task
    Map<Id, Task> noteIdToTaskMap = new Map<Id, Task>();
    for (Task t : tasksToUpdate) {
      noteIdToTaskMap.put(t.Originating_Note_Id__c, t);
    }

    //Iterate through the changed versions and update the fields on the Task from the map.
    for (ContentVersion version : newVersions) {
      // Check if this version corresponds to a Task we need to update.
      if (noteIdToTaskMap.containsKey(version.ContentDocumentId)) {
        Task taskToUpdate = noteIdToTaskMap.get(version.ContentDocumentId);

        // Update Subject and Description
        taskToUpdate.Subject = 'Note: ' + version.Title;
        if (version.VersionData != null) {
          // Stripping Htlm tags if any
          String plainTextContent = version.VersionData.toString()
            .stripHtmlTags()
            .unescapeHtml4();
          taskToUpdate.Description = plainTextContent.abbreviate(32768);
        } else {
          taskToUpdate.Description = '';
        }
      }
    }

    //Perform a single DML update on all changed tasks.
    try {
      update noteIdToTaskMap.values();
    } catch (DmlException e) {
      System.debug('Error updating Tasks from Note updates: ' + e.getMessage());
    }
  }
}
