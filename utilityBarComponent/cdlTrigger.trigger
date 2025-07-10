/**
 * @description Trigger on ContentDocumentLink to handle business logic when a
 *              file or note is linked to a record.
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink(after insert) {
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      new ContentDocumentLinkTriggerHandler().handleAfterInsert(Trigger.new);
    }
  }
}
