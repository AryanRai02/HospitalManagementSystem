public with sharing class LabResultProcessor implements Queueable, Database.AllowsCallouts {

    private final List<Id> medicalRecordIds;
    private static final Integer CHUNK_SIZE = 10;

    public LabResultProcessor(List<Id> medicalRecordIds) {
        this.medicalRecordIds = medicalRecordIds;
    }

    public void execute(QueueableContext context) {
        if (medicalRecordIds == null || medicalRecordIds.isEmpty()) {
            return;
        }

        // Take the next chunk, queue the rest as a new job (chaining)
        List<Id> current = new List<Id>();
        List<Id> remaining = new List<Id>();
        for (Integer i = 0; i < medicalRecordIds.size(); i++) {
            if (i < CHUNK_SIZE) {
                current.add(medicalRecordIds[i]);
            } else {
                remaining.add(medicalRecordIds[i]);
            }
        }

        List<Medical_Record__c> records = [
            SELECT Id, Lab_Status__c, Patient__c
            FROM Medical_Record__c
            WHERE Id IN :current
        ];

        // One callout per patient (not per record) keeps callouts well under the limit
        Map<Id, String> statusByPatient = new Map<Id, String>();
        for (Medical_Record__c rec : records) {
            if (!statusByPatient.containsKey(rec.Patient__c)) {
                statusByPatient.put(rec.Patient__c, fetchLabStatus(rec.Patient__c));
            }
        }

        for (Medical_Record__c rec : records) {
            rec.Lab_Status__c = statusByPatient.get(rec.Patient__c);
        }
        update records;

        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new LabResultProcessor(remaining));
        }
    }

    private String fetchLabStatus(Id patientId) {
        try {
            List<LabSystemService.LabResult> results = LabSystemService.getLabResults(patientId);
            return results.isEmpty() ? 'No results' : 'Processed';
        } catch (Exception e) {
            return 'Lab unavailable';
        }
    }
}