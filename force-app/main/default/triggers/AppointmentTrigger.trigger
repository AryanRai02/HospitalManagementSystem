trigger AppointmentTrigger on Appointment__c (
    before insert, before update, after insert, after update, after delete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            AppointmentTriggerHandler.afterDelete(Trigger.old);
        }
    }
}