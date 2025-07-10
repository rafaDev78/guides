/**
 * @description Trigger for ContentVersion object.
 *              Delegates all logic to the ContentVersionTriggerHandler class.
 */
trigger ContentVersionTrigger on ContentVersion(before update, after update) {
  // Instantiating the handler once for the transaction
  ContentVersionTriggerHandler handler = new ContentVersionTriggerHandler();

  if (Trigger.isBefore) {
    if (Trigger.isUpdate) {
      handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
  }
  if (Trigger.isAfter) {
    if (Trigger.isUpdate) {
      handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
  }
}
