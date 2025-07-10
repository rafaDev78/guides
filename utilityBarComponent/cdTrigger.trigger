/**
 * @description Trigger on ContentDocument to handle business logic when
 *              a document is deleted.
 */
trigger ContentDocumentTrigger on ContentDocument(after delete) {
  if (Trigger.isAfter) {
    if (Trigger.isDelete) {
      new ContentDocumentTriggerHandler().handleAfterDelete(Trigger.old);
    }
  }
}
