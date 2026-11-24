public with sharing class AppointmentReminderBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime tomorrowStart = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));
        Datetime tomorrowEnd = tomorrowStart.addDays(1);
        return Database.getQueryLocator([
            SELECT Id, Patient__c, Reminder_Sent__c
            FROM Appointment__c
            WHERE Slot__c >= :tomorrowStart
              AND Slot__c < :tomorrowEnd
              AND Status__c = 'Confirmed'
              AND Reminder_Sent__c = false
              AND Patient__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Appointment__c> scope) {
        Set<Id> patientIds = new Set<Id>();
        for (Appointment__c appt : scope) {
            patientIds.add(appt.Patient__c);
        }

        EmailService.sendPatientEmails(
            patientIds,
            'Appointment Reminder - MedCare Hospital',
            'Dear {{Name}},\n\nThis is a reminder that you have an appointment at MedCare Hospital tomorrow.\n'
            + 'Please arrive 15 minutes early.\n\nThank you,\nMedCare Hospital'
        );

        for (Appointment__c appt : scope) {
            appt.Reminder_Sent__c = true;
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
    }
}