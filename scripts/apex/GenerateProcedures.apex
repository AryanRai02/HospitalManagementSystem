Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

List<String> procedureNames = new List<String>{
    'General Consultation',
    'Electrocardiogram (ECG)',
    'Blood Test',
    'X-Ray',
    'MRI Scan',
    'CT Scan',
    'Physiotherapy',
    'Echocardiography'
};

Set<String> existingNames = new Set<String>();

for (Procedure__c p : [
    SELECT Name
    FROM Procedure__c
    WHERE Name IN :procedureNames
]) {
    existingNames.add(p.Name);
}

List<Procedure__c> procedures = new List<Procedure__c>();

for (String procedureName : procedureNames) {
    if (!existingNames.contains(procedureName)) {
        procedures.add(new Procedure__c(
            Name = procedureName
        ));
    }
}

Integer successCount = 0;
Integer failureCount = 0;

if (!procedures.isEmpty()) {

    Database.SaveResult[] results =
        Database.insert(procedures, false);

    for (Integer i = 0; i < results.size(); i++) {

        if (results[i].isSuccess()) {
            successCount++;

            System.debug(
                'SUCCESS: ' + procedures[i].Name
            );
        } else {
            failureCount++;

            for (Database.Error err : results[i].getErrors()) {
                System.debug(
                    'FAILED: ' + procedures[i].Name
                    + ' | ' + err.getMessage()
                );
            }
        }
    }
}

System.debug('========== PROCEDURE SUMMARY ==========');
System.debug('Requested: ' + procedureNames.size());
System.debug('Already Existing: ' + existingNames.size());
System.debug('Successful: ' + successCount);
System.debug('Failed: ' + failureCount);
System.debug('Email Invocations: ' + Limits.getEmailInvocations());
System.debug('Callouts: ' + Limits.getCallouts());

if (dryRun || failureCount > 0) {
    Database.rollback(sp);
    System.debug('ROLLBACK COMPLETED: No records committed.');
} else {
    System.debug('INSERT COMPLETED: Records saved permanently.');
}
