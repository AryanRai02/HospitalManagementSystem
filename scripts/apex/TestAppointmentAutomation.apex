Savepoint sp = Database.setSavepoint();

try {

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Appointment__c],
        'Expected an empty appointment dataset.'
    );

    // Retrieve one active dummy doctor
    Doctor__c doctor = [
        SELECT Id, Name, Active_Appointments__c
        FROM Doctor__c
        WHERE Status__c = 'Active'
        AND Name LIKE 'HMS-DEMO%'
        ORDER BY Name
        LIMIT 1
    ];

    // Retrieve one dummy outpatient
    Patient__c patient = [
        SELECT Id, Name, Full_Name__c,
               Total_Billed_Amount__c,
               Total_Appointments__c
        FROM Patient__c
        WHERE Full_Name__c LIKE 'HMS-DEMO%'
        AND RecordType.Name = 'Outpatient'
        ORDER BY Name
        LIMIT 1
    ];

    RecordType rt = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Appointment__c'
        AND Name = 'General Consultation'
        AND IsActive = true
        LIMIT 1
    ];

    System.debug('========== BEFORE INSERT ==========');
    System.debug('Doctor: ' + doctor.Name);
    System.debug('Patient: ' + patient.Full_Name__c);
    System.debug('Doctor workload: ' +
        doctor.Active_Appointments__c);
    System.debug('Patient billed total: ' +
        patient.Total_Billed_Amount__c);
    System.debug('Patient appointment count: ' +
        patient.Total_Appointments__c);

    // Tomorrow at 10 AM IST (04:30 UTC)
    Datetime slot = Datetime.newInstanceGmt(
        Date.today().addDays(1),
        Time.newInstance(4, 30, 0, 0)
    );

    Appointment__c appt = new Appointment__c(
        Patient__c = patient.Id,
        Doctor__c = doctor.Id,
        RecordTypeId = rt.Id,
        Appointment_Type__c = 'General Consultation',
        Slot__c = slot,
        Status__c = 'Requested',
        Specialist_Required__c = 'No',
        Reminder_Sent__c = false
    );

    insert appt;

    System.debug('========== AFTER INSERT ==========');
    System.debug('Appointment created: ' + appt.Id);
    System.debug('Slot IST: ' +
        slot.format('dd MMM yyyy HH:mm', 'Asia/Kolkata'));

    List<Task> tasks = [
        SELECT Id, Subject, Status, OwnerId
        FROM Task
        WHERE WhatId = :appt.Id
    ];

    System.debug('Tasks created: ' + tasks.size());

    for (Task t : tasks) {
        System.debug('Task subject: ' + t.Subject);
    }

    Doctor__c updatedDoctor = [
        SELECT Active_Appointments__c
        FROM Doctor__c
        WHERE Id = :doctor.Id
    ];

    System.debug('Updated doctor workload: ' +
        updatedDoctor.Active_Appointments__c);

    System.debug('Bills before completion: ' + [
        SELECT COUNT()
        FROM Billing__c
        WHERE Appointment__c = :appt.Id
    ]);

    // Activate the billing Flow
    appt.Status__c = 'Completed';
    update appt;

    System.debug('========== AFTER COMPLETION ==========');

    List<Billing__c> bills = [
        SELECT Id, Name, Amount_Due__c,
               Status__c, Patient__c
        FROM Billing__c
        WHERE Appointment__c = :appt.Id
    ];

    System.debug('Bills generated: ' + bills.size());

    for (Billing__c bill : bills) {
        System.debug('Bill amount: ' + bill.Amount_Due__c);
        System.debug('Bill status: ' + bill.Status__c);
        System.debug('Correct patient: ' +
            (bill.Patient__c == patient.Id));
    }

    Patient__c updatedPatient = [
        SELECT Total_Billed_Amount__c,
               Total_Appointments__c
        FROM Patient__c
        WHERE Id = :patient.Id
    ];

    System.debug('Updated patient billed total: ' +
        updatedPatient.Total_Billed_Amount__c);

    System.debug('Updated patient appointment count: ' +
        updatedPatient.Total_Appointments__c);

    System.debug('========== GOVERNOR LIMITS ==========');
    System.debug('SOQL queries: ' + Limits.getQueries());
    System.debug('DML statements: ' +
        Limits.getDmlStatements());
    System.debug('Email invocations: ' +
        Limits.getEmailInvocations());
    System.debug('Callouts: ' + Limits.getCallouts());
    System.debug('Future calls: ' + Limits.getFutureCalls());
    System.debug('Queueable jobs: ' +
        Limits.getQueueableJobs());

} catch (Exception e) {

    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());
    System.debug(e.getStackTraceString());

} finally {

    Database.rollback(sp);

    System.debug('========== ROLLBACK COMPLETED ==========');
    System.debug('All transactional test records rolled back.');
}