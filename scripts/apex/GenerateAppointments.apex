Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

try {

    // Prevent accidental duplicate dataset generation
    System.assertEquals(
        0,
        [SELECT COUNT() FROM Appointment__c],
        'Appointments already exist.'
    );

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Billing__c],
        'Billing records already exist.'
    );

    // Retrieve active dummy doctors
    List<Doctor__c> doctors = [
        SELECT Id, Name, Active_Appointments__c
        FROM Doctor__c
        WHERE Status__c = 'Active'
        AND Name LIKE 'HMS-DEMO%'
        ORDER BY Name
    ];

    // Retrieve dummy patients
    List<Patient__c> patients = [
        SELECT Id, Name, Full_Name__c,
               Total_Billed_Amount__c,
               Total_Appointments__c
        FROM Patient__c
        WHERE Full_Name__c LIKE 'HMS-DEMO%'
        ORDER BY Name
    ];

    System.assertEquals(10, doctors.size());
    System.assertEquals(20, patients.size());

    // Retrieve appointment record types
    Map<String, Id> recordTypes = new Map<String, Id>();

    for (RecordType rt : [
        SELECT Id, Name
        FROM RecordType
        WHERE SObjectType = 'Appointment__c'
        AND IsActive = true
    ]) {
        recordTypes.put(rt.Name, rt.Id);
    }

    List<String> appointmentTypes = new List<String>{
        'General Consultation',
        'Specialist Consultation',
        'Emergency'
    };

    Map<String, Decimal> charges = new Map<String, Decimal>{
        'General Consultation' => 500,
        'Specialist Consultation' => 1500,
        'Emergency' => 3000
    };

    for (String appointmentType : appointmentTypes) {
        System.assert(
            recordTypes.containsKey(appointmentType),
            'Missing record type: ' + appointmentType
        );
    }

    List<Appointment__c> appointments =
        new List<Appointment__c>();

    Map<Id, Integer> expectedWorkload =
        new Map<Id, Integer>();

    Map<Id, Decimal> expectedPatientTotals =
        new Map<Id, Decimal>();

    // Store original doctor workload
    for (Doctor__c doctor : doctors) {

        Integer baseline =
            doctor.Active_Appointments__c == null
            ? 0
            : doctor.Active_Appointments__c.intValue();

        expectedWorkload.put(doctor.Id, baseline);
    }

    // Store original patient billing totals
    for (Patient__c patient : patients) {

        expectedPatientTotals.put(
            patient.Id,
            patient.Total_Billed_Amount__c == null
            ? 0
            : patient.Total_Billed_Amount__c
        );
    }

    // Generate 30 appointments
    for (Integer i = 0; i < 30; i++) {

        Doctor__c doctor =
            doctors[Math.mod(i, doctors.size())];

        Patient__c patient =
            patients[Math.mod(i, patients.size())];

        String appointmentType =
            appointmentTypes[Math.mod(i, 3)];

        // Three separate days, avoiding past slots
        Integer dayOffset = 1 + (i / 10);

        // Appointment time: 10 AM IST
        Datetime slot = Datetime.newInstanceGmt(
            Date.today().addDays(dayOffset),
            Time.newInstance(4, 30, 0, 0)
        );

        appointments.add(new Appointment__c(

            Doctor__c = doctor.Id,
            Patient__c = patient.Id,

            RecordTypeId =
                recordTypes.get(appointmentType),

            Appointment_Type__c = appointmentType,
            Status__c = appointmentType == 'Emergency' ? 'Confirmed' : 'Requested',
            Slot__c = slot,

            Specialist_Required__c =
                appointmentType == 'Specialist Consultation'
                ? 'Yes'
                : 'No',

            Reminder_Sent__c = false
        ));

        expectedWorkload.put(
            doctor.Id,
            expectedWorkload.get(doctor.Id) + 1
        );
    }

    // Single bulk DML operation
    List<Appointment__c> batch1 = new List<Appointment__c>();
List<Appointment__c> batch2 = new List<Appointment__c>();
List<Appointment__c> batch3 = new List<Appointment__c>();

for (Integer i = 0; i < appointments.size(); i++) {
    if (i < 10) {
        batch1.add(appointments[i]);
    } else if (i < 20) {
        batch2.add(appointments[i]);
    } else {
        batch3.add(appointments[i]);
    }
}

insert batch1;
insert batch2;
insert batch3;

    Set<Id> appointmentIds =
        new Map<Id, Appointment__c>(appointments).keySet();

    System.debug('========== INSERT SUMMARY ==========');
    System.debug('Appointments inserted: ' +
        appointments.size());

    System.debug('Confirmation tasks: ' + [
        SELECT COUNT()
        FROM Task
        WHERE WhatId IN :appointmentIds
    ]);

    System.debug('Bills before completion: ' + [
        SELECT COUNT()
        FROM Billing__c
        WHERE Appointment__c IN :appointmentIds
    ]);

    // Verify doctor workload
    Integer workloadMismatches = 0;

    Set<Id> doctorIds = expectedWorkload.keySet();

    for (Doctor__c doctor : [
        SELECT Id, Name, Active_Appointments__c
        FROM Doctor__c
        WHERE Id IN :doctorIds
    ]) {

        Integer expected =
            expectedWorkload.get(doctor.Id);

        System.debug(
            'DOCTOR: ' + doctor.Name
            + ' | Expected: ' + expected
            + ' | Actual: ' +
            doctor.Active_Appointments__c
        );

        if (doctor.Active_Appointments__c != expected) {
            workloadMismatches++;
        }
    }

    // Prepare 15 status transitions
    List<Appointment__c> completedAppointments =
        new List<Appointment__c>();

    Decimal expectedBillingTotal = 0;

    for (Integer i = 0; i < 15; i++) {

        Appointment__c appt = appointments[i];

        appt.Status__c = 'Completed';

        completedAppointments.add(appt);

        Decimal charge =
            charges.get(appt.Appointment_Type__c);

        expectedBillingTotal += charge;

        expectedPatientTotals.put(
            appt.Patient__c,
            expectedPatientTotals.get(appt.Patient__c)
            + charge
        );
    }

    // Activate Billing Auto Create Flow
    update completedAppointments;

    System.debug('========== BILLING SUMMARY ==========');

    List<Billing__c> bills = [
        SELECT Id, Appointment__c,
               Patient__c, Amount_Due__c, Status__c
        FROM Billing__c
        WHERE Appointment__c IN :appointmentIds
    ];

    Decimal actualBillingTotal = 0;

    for (Billing__c bill : bills) {
        actualBillingTotal += bill.Amount_Due__c;
    }

    System.debug('Completed appointments: ' +
        completedAppointments.size());

    System.debug('Bills generated: ' + bills.size());
    System.debug('Expected billing total: ' +
        expectedBillingTotal);
    System.debug('Actual billing total: ' +
        actualBillingTotal);

    // Verify patient billing totals
    Integer patientTotalMismatches = 0;

    Set<Id> patientIds =
        expectedPatientTotals.keySet();

    for (Patient__c patient : [
        SELECT Id, Name, Total_Billed_Amount__c,
               Total_Appointments__c
        FROM Patient__c
        WHERE Id IN :patientIds
    ]) {

        Decimal actualTotal =
            patient.Total_Billed_Amount__c == null
            ? 0
            : patient.Total_Billed_Amount__c;

        Decimal expectedTotal =
            expectedPatientTotals.get(patient.Id);

        if (actualTotal != expectedTotal) {
            patientTotalMismatches++;

            System.debug(
                'PATIENT TOTAL MISMATCH: ' +
                patient.Name
                + ' | Expected: ' + expectedTotal
                + ' | Actual: ' + actualTotal
            );
        }
    }

    System.debug('========== FINAL SUMMARY ==========');

    System.debug('Appointments: ' +
        appointments.size());

    System.debug('Completed: 15');
    System.debug('Requested: 10'); System.debug('Confirmed: 5');
    System.debug('Billing records: ' + bills.size());

    System.debug('Doctor workload mismatches: ' +
        workloadMismatches);

    System.debug('Patient billing mismatches: ' +
        patientTotalMismatches);

    System.debug('SOQL queries: ' +
        Limits.getQueries());

    System.debug('DML statements: ' +
        Limits.getDmlStatements());

    System.debug('CPU time: ' +
        Limits.getCpuTime());

    System.debug('Email invocations: ' +
        Limits.getEmailInvocations());

    System.debug('Callouts: ' +
        Limits.getCallouts());

    if (
        dryRun ||
        workloadMismatches > 0 ||
        patientTotalMismatches > 0 ||
        bills.size() != 15 ||
        actualBillingTotal != expectedBillingTotal
    ) {

        Database.rollback(sp);

        System.debug(
            'ROLLBACK COMPLETED: No records committed.'
        );

    } else {

        System.debug(
            'INSERT COMPLETED: Records saved permanently.'
        );
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());
    System.debug(e.getStackTraceString());

    System.debug('ROLLBACK COMPLETED.');
}


