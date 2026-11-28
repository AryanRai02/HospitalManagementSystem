Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

try {

    // Verify the existing dataset
    System.assertEquals(
        15,
        [SELECT COUNT() FROM Billing__c]
    );

    System.assertEquals(
        20,
        [SELECT COUNT() FROM Patient__c]
    );

    // Target payable amounts for high-value bills
    Map<String, Decimal> targetAmounts =
        new Map<String, Decimal>{
            'PAT-0025' => 120000,
            'PAT-0026' => 250000,
            'PAT-0027' => 600000,
            'PAT-0028' => 750000,
            'PAT-0029' => 150000,
            'PAT-0030' => 300000,
            'PAT-0031' => 550000,
            'PAT-0032' => 800000,
            'PAT-0033' => 180000,
            'PAT-0034' => 650000
        };

    List<Billing__c> bills = [
        SELECT Id, Name, Patient__c,
               Patient__r.Name,
               Patient__r.Full_Name__c,
               Patient__r.Email__c,
               Patient__r.Insurance_Policy_Number__c,
               Appointment__r.Status__c,
               Amount_Due__c,
               Insurance__c,
               Insurance_Amount__c,
               Claim_Submitted__c,
               Claim_Reference__c,
               Status__c
        FROM Billing__c
        ORDER BY Patient__r.Name
    ];

    List<Billing__c> billsToUpdate =
        new List<Billing__c>();

    Decimal originalTotal = 0;
    Decimal expectedTotal = 0;
    Decimal expectedInsurance = 0;
    Decimal expectedDiscount = 0;
    Decimal grossCharges = 0;

    Integer modifiedBills = 0;
    Integer unchangedBills = 0;

    Set<String> processedPatients = new Set<String>();

    System.debug('========== BILLING CALCULATIONS ==========');

    for (Billing__c bill : bills) {

        System.assertEquals(
            'Draft',
            bill.Status__c
        );

        System.assertEquals(
            'Completed',
            bill.Appointment__r.Status__c
        );

        System.assert(
            bill.Patient__r.Full_Name__c.startsWith(
                'HMS-DEMO'
            )
        );

        System.assert(
            String.isBlank(bill.Patient__r.Email__c)
        );

        System.assertEquals(
            false,
            bill.Claim_Submitted__c
        );

        System.assert(
            String.isBlank(bill.Claim_Reference__c)
        );

        String patientNumber = bill.Patient__r.Name;

        System.assert(
            !processedPatients.contains(patientNumber),
            'Unexpected duplicate patient billing.'
        );

        processedPatients.add(patientNumber);

        originalTotal += bill.Amount_Due__c;

        if (!targetAmounts.containsKey(patientNumber)) {

            unchangedBills++;

            expectedTotal += bill.Amount_Due__c;
            grossCharges += bill.Amount_Due__c;

            continue;
        }

        System.assert(
            !String.isBlank(
                bill.Patient__r.Insurance_Policy_Number__c
            )
        );

        Decimal targetDue =
            targetAmounts.get(patientNumber);

        Decimal discountPercent = 20;
        Decimal coveragePercent = 50;

        // Reverse calculation:
        // Amount Due = Gross * 0.8 * 0.5
        // Therefore Gross = Target Due / 0.4

        Decimal treatmentCharge = targetDue / 0.4;

        List<Decimal> charges =
            new List<Decimal>{ treatmentCharge };

        BillingCalculator.BillResult result =
            BillingCalculator.calculate(
                charges,
                discountPercent,
                coveragePercent
            );

        BillingCalculator.applyToBilling(
            bill,
            charges,
            discountPercent,
            coveragePercent
        );

        System.assertEquals(
            targetDue.setScale(2),
            bill.Amount_Due__c,
            'Calculated amount mismatch.'
        );

        bill.Insurance__c =
            'HMS-DEMO Insurance Provider';

        // No actual external claim has been submitted
        bill.Claim_Submitted__c = false;
        bill.Claim_Reference__c = null;

        expectedTotal += result.amountDue;
        expectedInsurance += result.insuranceCoverage;
        expectedDiscount += result.discountAmount;
        grossCharges += result.subtotal;

        modifiedBills++;

        billsToUpdate.add(bill);

        System.debug(
            'PATIENT: ' + patientNumber +
            ' | Gross: ' + result.subtotal +
            ' | Discount: ' + result.discountAmount +
            ' | Insurance: ' + result.insuranceCoverage +
            ' | Amount Due: ' + result.amountDue
        );
    }

    System.assertEquals(25000, originalTotal);
    System.assertEquals(10, modifiedBills);
    System.assertEquals(5, unchangedBills);

    // Bulk update the billing records
    update billsToUpdate;

    // Recalculate patient balances from existing bills
    Map<Id, Decimal> patientTotals =
        new Map<Id, Decimal>();

    for (AggregateResult ar : [
        SELECT Patient__c patientId,
               SUM(Amount_Due__c) total
        FROM Billing__c
        WHERE Patient__c != null
        GROUP BY Patient__c
    ]) {

        patientTotals.put(
            (Id) ar.get('patientId'),
            (Decimal) ar.get('total')
        );
    }

    List<Patient__c> patientsToUpdate =
        new List<Patient__c>();

    for (Patient__c patient : [
        SELECT Id, Name, Full_Name__c,
               Total_Billed_Amount__c
        FROM Patient__c
    ]) {

        System.assert(
            patient.Full_Name__c.startsWith('HMS-DEMO')
        );

        Decimal expectedBalance =
            patientTotals.containsKey(patient.Id)
            ? patientTotals.get(patient.Id)
            : 0;

        if (
            patient.Total_Billed_Amount__c
            != expectedBalance
        ) {

            patientsToUpdate.add(
                new Patient__c(
                    Id = patient.Id,
                    Total_Billed_Amount__c =
                        expectedBalance
                )
            );
        }
    }

    if (!patientsToUpdate.isEmpty()) {
        update patientsToUpdate;
    }

    // Verify individual patient balances
    Integer balanceMismatches = 0;

    for (Patient__c patient : [
        SELECT Id, Total_Billed_Amount__c
        FROM Patient__c
    ]) {

        Decimal expectedBalance =
            patientTotals.containsKey(patient.Id)
            ? patientTotals.get(patient.Id)
            : 0;

        if (
            patient.Total_Billed_Amount__c
            != expectedBalance
        ) {
            balanceMismatches++;
        }
    }

    AggregateResult billingSummary = [
        SELECT COUNT(Id) billCount,
               SUM(Amount_Due__c) amountDue,
               SUM(Insurance_Amount__c) insurance
        FROM Billing__c
    ];

    AggregateResult patientSummary = [
        SELECT SUM(Total_Billed_Amount__c) total
        FROM Patient__c
    ];

    Decimal actualBillingTotal =
        (Decimal) billingSummary.get('amountDue');

    Decimal actualInsurance =
        (Decimal) billingSummary.get('insurance');

    Decimal actualPatientTotal =
        (Decimal) patientSummary.get('total');

    Integer approvalEligible = [
        SELECT COUNT()
        FROM Billing__c
        WHERE Amount_Due__c > 100000
    ];

    Integer twoStepEligible = [
        SELECT COUNT()
        FROM Billing__c
        WHERE Amount_Due__c > 500000
    ];

    Integer draftCount = [
        SELECT COUNT()
        FROM Billing__c
        WHERE Status__c = 'Draft'
    ];

    Integer submittedClaims = [
        SELECT COUNT()
        FROM Billing__c
        WHERE Claim_Submitted__c = true
    ];

    System.debug('========== FINAL SUMMARY ==========');

    System.debug('Original billing total: ' +
        originalTotal);

    System.debug('Modified bills: ' +
        modifiedBills);

    System.debug('Unchanged bills: ' +
        unchangedBills);

    System.debug('Gross charges: ' +
        grossCharges);

    System.debug('Total discount: ' +
        expectedDiscount);

    System.debug('Expected insurance: ' +
        expectedInsurance);

    System.debug('Actual insurance: ' +
        actualInsurance);

    System.debug('Expected billing total: ' +
        expectedTotal);

    System.debug('Actual billing total: ' +
        actualBillingTotal);

    System.debug('Patient billing total: ' +
        actualPatientTotal);

    System.debug('Patient balances updated: ' +
        patientsToUpdate.size());

    System.debug('Patient balance mismatches: ' +
        balanceMismatches);

    System.debug('Approval eligible bills: ' +
        approvalEligible);

    System.debug('Two-step approval eligible: ' +
        twoStepEligible);

    System.debug('Draft bills: ' +
        draftCount);

    System.debug('Submitted claims: ' +
        submittedClaims);

    System.debug('SOQL queries: ' +
        Limits.getQueries());

    System.debug('DML statements: ' +
        Limits.getDmlStatements());

    System.debug('Email invocations: ' +
        Limits.getEmailInvocations());

    System.debug('Callouts: ' +
        Limits.getCallouts());

    System.debug('Future calls: ' +
        Limits.getFutureCalls());

    System.debug('Queueable jobs: ' +
        Limits.getQueueableJobs());

    if (
        dryRun ||
        actualBillingTotal != expectedTotal ||
        actualInsurance != expectedInsurance ||
        actualPatientTotal != expectedTotal ||
        balanceMismatches != 0 ||
        approvalEligible != 10 ||
        twoStepEligible != 5 ||
        draftCount != 15 ||
        submittedClaims != 0 ||
        Limits.getCallouts() != 0 ||
        Limits.getFutureCalls() != 0 ||
        Limits.getQueueableJobs() != 0
    ) {

        Database.rollback(sp);

        System.debug(
            'ROLLBACK COMPLETED: No changes committed.'
        );

    } else {

        System.debug(
            'BILLING SCENARIOS SAVED PERMANENTLY.'
        );
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());
    System.debug('ROLLBACK COMPLETED.');
}
