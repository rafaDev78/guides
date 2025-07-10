/**
 * @description Handler for the ContentDocument trigger.
 *              Responsible for deleting a related Task when a Note is deleted.
 */
public with sharing class ContentDocumentTriggerHandler {
  /**
   * @description After a document is deleted, check if it was a Note ('SNOTE').
   *              If so, find and delete the corresponding Task.
   * @param oldDocs The list of deleted ContentDocument records from Trigger.old
   */
  public void handleAfterDelete(List<ContentDocument> oldDocs) {
    Set<Id> deletedNoteIds = new Set<Id>();

    //Filter the deleted documents to find only Notes.
    for (ContentDocument doc : oldDocs) {
      if (doc.FileType == 'SNOTE') {
        deletedNoteIds.add(doc.Id);
      }
    }

    if (deletedNoteIds.isEmpty()) {
      return; // No notes were deleted, so exit.
    }

    //Find any Tasks that were created from these deleted notes.
    List<Task> tasksToDelete = [
      SELECT Id
      FROM Task
      WHERE Originating_Note_Id__c IN :deletedNoteIds
    ];

    //Delete the found tasks.
    if (!tasksToDelete.isEmpty()) {
      try {
        delete tasksToDelete;
      } catch (DmlException e) {
        // Basic error logging for the admin
        System.debug(
          'Error deleting Tasks after Note deletion: ' + e.getMessage()
        );
      }
    }
  }
}
