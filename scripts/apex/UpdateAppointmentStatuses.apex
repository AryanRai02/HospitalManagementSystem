Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

try {

    // Verify baseline dataset
    System.assertEquals(
        30,
        [SELECT COUNT() FROM Appointment__c]
    );

    System.assertEquals(
        15,
        [SELECT COUNT() FROM Billing__c]
    );

    // Selected appointments to confirm
    Set<Id> confirmIds = new Set<Id>{
        'a00g500001GXg2DAAT',
        'a00g500001GXg2EAAT',
        'a00g500001GXg2GAAT'
    };

    // Selected appointments to cancel
    Set<Id> cancelIds = new Set<Id>{
        'a00g500001GXg2HAAT',
        'a00g500001GXg2JAAT',
        'a00g500001GXg2KAAT'
    };

    Set<Id> selectedIds = new Set<Id>();
    selectedIds.addAll(confirmIds);
    selectedIds.addAll(cancelIds);

    List<Appointment__c> appointments = [
        SELECT Id, Name, Status__c, Slot__c,
               Doctor__c, Doctor__r.Name,
               Patient__c,
               Patient__r.Full_Name__c,
               Patient__r.Email__c
        FROM Appointment__c
        WHERE Id IN :selectedIds
    ];

    System.assertEquals(6, appointments.size());

    List<Appointment__c> toConfirm =
        new List<Appointment__c>();

    List<Appointment__c> toCancel =
        new List<Appointment__c>();

    Set<Id> confirmedPatientIds = new Set<Id>();
    Set<Id> cancelledDoctorIds = new Set<Id>();

    for (Appointment__c appt : appointments) {

        System.assertEquals(
            'Requested',
            appt.Status__c,
            'Unexpected appointment status.'
        );

        System.assert(
            appt.Patient__r.Full_Name__c.startsWith(
                'HMS-DEMO'
            ),
            'Non-demo patient detected.'
        );

        System.assert(
            String.isBlank(appt.Patient__r.Email__c),
            'Email recipient detected. Stop execution.'
        );

        if (confirmIds.contains(appt.Id)) {

            appt.Status__c = 'Confirmed';
            toConfirm.add(appt);
            confirmedPatientIds.add(appt.Patient__c);

        } else {

            appt.Status__c = 'Cancelled';
            toCancel.add(appt);
            cancelledDoctorIds.add(appt.Doctor__c);
        }
    }

    // Capture doctor workload before cancellation
    Map<Id, Doctor__c> doctorsBefore =
        new Map<Id, Doctor__c>([
            SELECT Id, Name, Active_Appointments__c
            FROM Doctor__c
            WHERE Id IN :cancelledDoctorIds
        ]);

    System.debug('========== CONFIRMATION TEST ==========');

    Database.SaveResult[] confirmationResults =
        Database.update(toConfirm, false);

    Integer confirmedCount = 0;
    Integer cancelledCount = 0;
    Integer failureCount = 0;

    for (Integer i = 0;
         i < confirmationResults.size(); i++) {

        if (confirmationResults[i].isSuccess()) {

            confirmedCount++;

            System.debug(
                'CONFIRMED: ' +
                toConfirm[i].Patient__r.Full_Name__c
            );

        } else {

            failureCount++;

            for (Database.Error err :
                 confirmationResults[i].getErrors()) {

                System.debug(
                    'CONFIRMATION FAILED: ' +
                    err.getStatusCode() + ' | ' +
                    err.getMessage()
                );
            }
        }
    }

    System.debug('========== CANCELLATION TEST ==========');

    Database.SaveResult[] cancellationResults =
        Database.update(toCancel, false);

    for (Integer i = 0;
         i < cancellationResults.size(); i++) {

        if (cancellationResults[i].isSuccess()) {

            cancelledCount++;

            System.debug(
                'CANCELLED: ' +
                toCancel[i].Patient__r.Full_Name__c
            );

        } else {

            failureCount++;

            for (Database.Error err :
                 cancellationResults[i].getErrors()) {

                System.debug(
                    'CANCELLATION FAILED: ' +
                    err.getStatusCode() + ' | ' +
                    err.getMessage()
                );
            }
        }
    }

    System.debug('========== PATIENT VERIFICATION ==========');

    for (Patient__c patient : [
        SELECT Name, Full_Name__c,
               Last_Appointment_Date__c
        FROM Patient__c
        WHERE Id IN :confirmedPatientIds
    ]) {

        System.debug(
            'PATIENT: ' + patient.Full_Name__c +
            ' | Last appointment: ' +
            patient.Last_Appointment_Date__c
        );
    }

    System.debug('========== DOCTOR VERIFICATION ==========');

    Integer workloadMismatches = 0;

    for (Doctor__c doctor : [
        SELECT Id, Name, Active_Appointments__c
        FROM Doctor__c
        WHERE Id IN :cancelledDoctorIds
    ]) {

        Decimal beforeValue =
            doctorsBefore.get(doctor.Id)
                         .Active_Appointments__c;

        Decimal expectedValue =
            Math.max(0, beforeValue - 1);

        System.debug(
            'DOCTOR: ' + doctor.Name +
            ' | Before: ' + beforeValue +
            ' | Expected: ' + expectedValue +
            ' | Actual: ' +
            doctor.Active_Appointments__c
        );

        if (doctor.Active_Appointments__c !=
            expectedValue) {

            workloadMismatches++;
        }
    }

    System.debug('========== STATUS DISTRIBUTION ==========');

    for (AggregateResult ar : [
        SELECT Status__c, COUNT(Id) total
        FROM Appointment__c
        GROUP BY Status__c
    ]) {

        System.debug(
            ar.get('Status__c') + ': ' +
            ar.get('total')
        );
    }

    Integer billCount = [
        SELECT COUNT() FROM Billing__c
    ];

    System.debug('========== FINAL SUMMARY ==========');
    System.debug('Confirmed successfully: ' +
        confirmedCount);

    System.debug('Cancelled successfully: ' +
        cancelledCount);

    System.debug('Failed updates: ' + failureCount);
    System.debug('Workload mismatches: ' +
        workloadMismatches);

    System.debug('Billing records: ' + billCount);
    System.debug('SOQL queries: ' + Limits.getQueries());
    System.debug('DML statements: ' +
        Limits.getDmlStatements());

    System.debug('Email invocations: ' +
        Limits.getEmailInvocations());

    System.debug('Callouts: ' + Limits.getCallouts());

    if (
        dryRun ||
        failureCount > 0 ||
        confirmedCount != 3 ||
        cancelledCount != 3 ||
        workloadMismatches > 0 ||
        billCount != 15
    ) {

        Database.rollback(sp);

        System.debug(
            'ROLLBACK COMPLETED: No changes committed.'
        );

    } else {

        System.debug(
            'STATUS UPDATES COMPLETED.'
        );
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());

    System.debug('ROLLBACK COMPLETED.');
}
