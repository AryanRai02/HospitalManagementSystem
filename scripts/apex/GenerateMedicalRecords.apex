Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

try {

    // ======================================
    // VERIFY EXISTING DATA
    // ======================================

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Medical_Record__c]
    );

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Patient_Procedure__c]
    );

    System.assertEquals(
        20,
        [SELECT COUNT() FROM Patient__c]
    );

    System.assertEquals(
        8,
        [SELECT COUNT() FROM Procedure__c]
    );

    System.assertEquals(
        30,
        [SELECT COUNT() FROM Appointment__c]
    );

    System.assertEquals(
        15,
        [SELECT COUNT() FROM Billing__c]
    );

    // ======================================
    // PREPARE DEMO CLINICAL SCENARIOS
    // ======================================

    List<String> patientNumbers = new List<String>{
        'PAT-0020', 'PAT-0021', 'PAT-0022',
        'PAT-0023', 'PAT-0024', 'PAT-0025',
        'PAT-0026', 'PAT-0027', 'PAT-0028',
        'PAT-0029', 'PAT-0030', 'PAT-0031',
        'PAT-0032', 'PAT-0033', 'PAT-0034'
    };

    List<String> diagnoses = new List<String>{
        'Routine health examination',
        'Cardiovascular assessment',
        'Respiratory assessment',
        'General health follow-up',
        'Musculoskeletal assessment',
        'Emergency respiratory assessment',
        'General diagnostic assessment',
        'Neurological assessment',
        'Emergency injury assessment',
        'Orthopedic follow-up',
        'Cardiac assessment',
        'Emergency diagnostic assessment',
        'Inpatient health review',
        'Rehabilitation assessment',
        'Emergency diagnostic review'
    };

    List<String> labStatuses = new List<String>{
        'No results',
        'Processed',
        'Processed',
        'No results',
        'Processed',
        'Processed',
        'Pending',
        'Processed',
        'Processed',
        'No results',
        'Processed',
        'Pending',
        'Pending',
        'No results',
        'Lab unavailable'
    };

    // ======================================
    // RETRIEVE EXISTING PATIENTS
    // ======================================

    Map<String, Patient__c> patientsByNumber =
        new Map<String, Patient__c>();

    for (Patient__c patient : [
        SELECT Id, Name, Full_Name__c, Email__c
        FROM Patient__c
        WHERE Name IN :patientNumbers
    ]) {

        System.assert(
            patient.Full_Name__c.startsWith('HMS-DEMO')
        );

        System.assert(
            String.isBlank(patient.Email__c)
        );

        patientsByNumber.put(
            patient.Name,
            patient
        );
    }

    System.assertEquals(
        15,
        patientsByNumber.size()
    );

    // ======================================
    // VERIFY COMPLETED APPOINTMENTS
    // ======================================

    Set<Id> completedPatientIds = new Set<Id>();

    for (Appointment__c appointment : [
        SELECT Id, Patient__c
        FROM Appointment__c
        WHERE Status__c = 'Completed'
    ]) {

        completedPatientIds.add(
            appointment.Patient__c
        );
    }

    System.assertEquals(
        15,
        completedPatientIds.size()
    );

    // ======================================
    // CREATE MEDICAL RECORDS
    // ======================================

    List<Medical_Record__c> medicalRecords =
        new List<Medical_Record__c>();

    for (
        Integer i = 0;
        i < patientNumbers.size();
        i++
    ) {

        Patient__c patient =
            patientsByNumber.get(patientNumbers[i]);

        System.assert(
            completedPatientIds.contains(patient.Id),
            'Patient has no completed demo appointment.'
        );

        Medical_Record__c record =
            new Medical_Record__c(
                Name =
                    'HMS-DEMO MR-' +
                    patientNumbers[i],

                Patient__c = patient.Id,

                Diagnosis__c =
                    'Synthetic demonstration: ' +
                    diagnoses[i],

                Prescription__c =
                    'Demo clinical review and follow-up. ' +
                    'No actual medication prescribed.',

                Lab_Status__c = labStatuses[i],

                Report_URL__c = null
            );

        medicalRecords.add(record);

        System.debug(
            'MEDICAL RECORD: ' +
            patientNumbers[i] +
            ' | ' + diagnoses[i] +
            ' | Lab: ' + labStatuses[i]
        );
    }

    insert medicalRecords;

    // ======================================
    // RETRIEVE PROCEDURE MASTER RECORDS
    // ======================================

    Map<String, Id> procedureIds =
        new Map<String, Id>();

    for (Procedure__c procedure : [
        SELECT Id, Name
        FROM Procedure__c
    ]) {

        System.assert(
            !procedureIds.containsKey(procedure.Name),
            'Duplicate procedure master name.'
        );

        procedureIds.put(
            procedure.Name,
            procedure.Id
        );
    }

    System.assertEquals(8, procedureIds.size());

    // ======================================
    // DEFINE PATIENT-PROCEDURE ASSOCIATIONS
    // ======================================

    Map<String, List<String>> procedureAssignments =
        new Map<String, List<String>>{

            'PAT-0020' => new List<String>{
                'General Consultation',
                'Blood Test'
            },

            'PAT-0021' => new List<String>{
                'Electrocardiogram (ECG)',
                'Echocardiography'
            },

            'PAT-0022' => new List<String>{
                'Blood Test',
                'X-Ray'
            },

            'PAT-0023' => new List<String>{
                'General Consultation'
            },

            'PAT-0024' => new List<String>{
                'Physiotherapy',
                'MRI Scan'
            },

            'PAT-0025' => new List<String>{
                'CT Scan',
                'Blood Test'
            },

            'PAT-0026' => new List<String>{
                'General Consultation'
            },

            'PAT-0028' => new List<String>{
                'X-Ray'
            },

            'PAT-0029' => new List<String>{
                'Physiotherapy'
            },

            'PAT-0030' => new List<String>{
                'Electrocardiogram (ECG)'
            }
        };

    List<Patient_Procedure__c> links =
        new List<Patient_Procedure__c>();

    Set<String> uniquePairs = new Set<String>();

    // ======================================
    // CREATE JUNCTION RECORDS
    // ======================================

    for (
        String patientNumber :
        procedureAssignments.keySet()
    ) {

        Id patientId =
            patientsByNumber.get(patientNumber).Id;

        for (
            String procedureName :
            procedureAssignments.get(patientNumber)
        ) {

            System.assert(
                procedureIds.containsKey(procedureName),
                'Procedure not found: ' + procedureName
            );

            Id procedureId =
                procedureIds.get(procedureName);

            String pairKey =
                String.valueOf(patientId) +
                ':' +
                String.valueOf(procedureId);

            System.assert(
                !uniquePairs.contains(pairKey),
                'Duplicate patient-procedure association.'
            );

            uniquePairs.add(pairKey);

            links.add(
                new Patient_Procedure__c(
                    Patient__c = patientId,
                    Procedure__c = procedureId
                )
            );

            System.debug(
                'PATIENT PROCEDURE: ' +
                patientNumber +
                ' | ' + procedureName
            );
        }
    }

    System.assertEquals(15, links.size());

    insert links;

    // ======================================
    // VERIFY MEDICAL RECORD DISTRIBUTION
    // ======================================

    Integer medicalCount = [
        SELECT COUNT()
        FROM Medical_Record__c
    ];

    Integer procedureLinkCount = [
        SELECT COUNT()
        FROM Patient_Procedure__c
    ];

    Map<String, Integer> statusCounts =
        new Map<String, Integer>();

    for (AggregateResult ar : [
        SELECT Lab_Status__c, COUNT(Id) total
        FROM Medical_Record__c
        GROUP BY Lab_Status__c
    ]) {

        String status =
            (String) ar.get('Lab_Status__c');

        Integer total =
            (Integer) ar.get('total');

        statusCounts.put(status, total);

        System.debug(
            'LAB STATUS: ' +
            status + ' = ' + total
        );
    }

    System.assertEquals(
        7, statusCounts.get('Processed')
    );

    System.assertEquals(
        4, statusCounts.get('No results')
    );

    System.assertEquals(
        3, statusCounts.get('Pending')
    );

    System.assertEquals(
        1, statusCounts.get('Lab unavailable')
    );

    // ======================================
    // VERIFY PROCEDURE DISTRIBUTION
    // ======================================

    Map<String, Integer> expectedProcedureCounts =
        new Map<String, Integer>{
            'General Consultation' => 3,
            'Blood Test' => 3,
            'Electrocardiogram (ECG)' => 2,
            'X-Ray' => 2,
            'Physiotherapy' => 2,
            'MRI Scan' => 1,
            'CT Scan' => 1,
            'Echocardiography' => 1
        };

    Map<Id, Integer> expectedCountsById =
        new Map<Id, Integer>();

    for (
        String procedureName :
        expectedProcedureCounts.keySet()
    ) {

        expectedCountsById.put(
            procedureIds.get(procedureName),
            expectedProcedureCounts.get(procedureName)
        );
    }

    Integer distinctProcedures = 0;

    for (AggregateResult ar : [
        SELECT Procedure__c, COUNT(Id) total
        FROM Patient_Procedure__c
        GROUP BY Procedure__c
    ]) {

        Id procedureId =
            (Id) ar.get('Procedure__c');

        Integer total =
            (Integer) ar.get('total');

        System.assertEquals(
            expectedCountsById.get(procedureId),
            total
        );

        distinctProcedures++;
    }

    // ======================================
    // VERIFY MANY-TO-MANY RELATIONSHIP
    // ======================================

    Set<Id> linkedPatients = new Set<Id>();
    Set<String> persistedPairs = new Set<String>();

    for (Patient_Procedure__c link : [
        SELECT Patient__c, Procedure__c
        FROM Patient_Procedure__c
    ]) {

        linkedPatients.add(link.Patient__c);

        String pairKey =
            String.valueOf(link.Patient__c) +
            ':' +
            String.valueOf(link.Procedure__c);

        persistedPairs.add(pairKey);
    }

    System.assertEquals(10, linkedPatients.size());

    System.assertEquals(
        uniquePairs,
        persistedPairs
    );

    // ======================================
    // VERIFY EXISTING FINANCIAL DATA
    // ======================================

    AggregateResult billingSummary = [
        SELECT SUM(Amount_Due__c) due,
               SUM(Insurance_Amount__c) insurance
        FROM Billing__c
    ];

    AggregateResult patientSummary = [
        SELECT SUM(Total_Billed_Amount__c) total
        FROM Patient__c
    ];

    System.assertEquals(
        4357000,
        (Decimal) billingSummary.get('due')
    );

    System.assertEquals(
        4350000,
        (Decimal) billingSummary.get('insurance')
    );

    System.assertEquals(
        4357000,
        (Decimal) patientSummary.get('total')
    );

    System.assertEquals(
        10,
        [SELECT COUNT() FROM ProcessInstance]
    );

    System.assertEquals(
        4,
        [SELECT COUNT()
         FROM ProcessInstanceWorkitem]
    );

    // ======================================
    // FINAL VALIDATIONS
    // ======================================

    System.assertEquals(15, medicalCount);
    System.assertEquals(15, procedureLinkCount);
    System.assertEquals(8, distinctProcedures);

    System.assertEquals(0, Limits.getCallouts());
    System.assertEquals(0, Limits.getFutureCalls());
    System.assertEquals(0, Limits.getQueueableJobs());
    System.assertEquals(0, Limits.getEmailInvocations());

    System.debug('========== FINAL SUMMARY ==========');

    System.debug(
        'Medical records: ' + medicalCount
    );

    System.debug(
        'Patient procedure records: ' +
        procedureLinkCount
    );

    System.debug(
        'Distinct linked patients: ' +
        linkedPatients.size()
    );

    System.debug(
        'Distinct procedures: ' +
        distinctProcedures
    );

    System.debug(
        'Unique patient-procedure pairs: ' +
        persistedPairs.size()
    );

    System.debug(
        'SOQL queries: ' + Limits.getQueries()
    );

    System.debug(
        'DML statements: ' +
        Limits.getDmlStatements()
    );

    System.debug(
        'Email invocations: ' +
        Limits.getEmailInvocations()
    );

    System.debug(
        'Callouts: ' + Limits.getCallouts()
    );

    System.debug(
        'Future calls: ' + Limits.getFutureCalls()
    );

    System.debug(
        'Queueable jobs: ' +
        Limits.getQueueableJobs()
    );

    System.debug(
        'ALL MEDICAL DATA CHECKS PASSED.'
    );

    if (dryRun) {

        Database.rollback(sp);

        System.debug(
            'ROLLBACK COMPLETED: No changes committed.'
        );

    } else {

        System.debug(
            'MEDICAL DATA SAVED PERMANENTLY.'
        );
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('MEDICAL DATA GENERATION FAILED.');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());
    System.debug('ROLLBACK COMPLETED.');
}

