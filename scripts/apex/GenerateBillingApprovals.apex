Boolean dryRun = false;

Savepoint sp = Database.setSavepoint();

try {

    // Verify existing dataset
    System.assertEquals(
        15,
        [SELECT COUNT() FROM Billing__c]
    );

    System.assertEquals(
        15,
        [SELECT COUNT()
         FROM Billing__c
         WHERE Status__c = 'Draft']
    );

    System.assertEquals(
        0,
        [SELECT COUNT() FROM ProcessInstance]
    );

    // Expected final billing statuses

    Map<String, String> targetStatuses =
        new Map<String, String>{
            'PAT-0025' => 'Pending Approval',
            'PAT-0026' => 'Pending Approval',
            'PAT-0027' => 'Pending Approval',
            'PAT-0028' => 'Pending Approval',
            'PAT-0029' => 'Approved',
            'PAT-0030' => 'Approved',
            'PAT-0031' => 'Approved',
            'PAT-0032' => 'Approved',
            'PAT-0033' => 'Rejected',
            'PAT-0034' => 'Rejected'
        };

    Map<String, Decimal> expectedAmounts =
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

    Set<String> patientNumbers =
        targetStatuses.keySet();

    List<Billing__c> bills = [
        SELECT Id, Name, Amount_Due__c,
               Status__c,
               Patient__r.Name,
               Patient__r.Full_Name__c,
               Patient__r.Email__c,
               Claim_Submitted__c
        FROM Billing__c
        WHERE Patient__r.Name IN :patientNumbers
        ORDER BY Patient__r.Name
    ];

    System.assertEquals(10, bills.size());

    Set<Id> billingIds = new Set<Id>();

    List<Approval.ProcessRequest> submissions =
        new List<Approval.ProcessRequest>();

    Map<Id, String> billToPatient =
        new Map<Id, String>();

    Integer originalTasks = [
        SELECT COUNT()
        FROM Task
        WHERE Subject = 'Revise rejected bill'
    ];

    // =======================================
    // PREPARE APPROVAL SUBMISSIONS
    // =======================================

    for (Billing__c bill : bills) {

        String patientNumber =
            bill.Patient__r.Name;

        System.assertEquals(
            'Draft',
            bill.Status__c
        );

        System.assertEquals(
            expectedAmounts.get(patientNumber),
            bill.Amount_Due__c
        );

        System.assert(
            bill.Patient__r.Full_Name__c
                .startsWith('HMS-DEMO')
        );

        System.assert(
            String.isBlank(
                bill.Patient__r.Email__c
            )
        );

        System.assertEquals(
            false,
            bill.Claim_Submitted__c
        );

        System.assertEquals(
            false,
            Approval.isLocked(bill.Id)
        );

        billingIds.add(bill.Id);

        billToPatient.put(
            bill.Id,
            patientNumber
        );

        Approval.ProcessSubmitRequest request =
            new Approval.ProcessSubmitRequest();

        request.setObjectId(bill.Id);

        request.setProcessDefinitionNameOrId(
            'Emergency_Billing_Approval'
        );

        request.setSkipEntryCriteria(false);

        request.setComments(
            'HMS-DEMO billing approval submission'
        );

        submissions.add(request);
    }

    // =======================================
    // SUBMIT ALL TEN RECORDS
    // =======================================

    System.debug(
        '========== APPROVAL SUBMISSION =========='
    );

    List<Approval.ProcessResult> submissionResults =
        Approval.process(submissions, true);

    System.assertEquals(
        10,
        submissionResults.size()
    );

    Integer submittedCount = 0;

    for (
        Approval.ProcessResult result :
        submissionResults
    ) {

        System.assert(
            result.isSuccess(),
            JSON.serialize(result.getErrors())
        );

        System.assertEquals(
            'Pending',
            result.getInstanceStatus()
        );

        submittedCount++;
    }

    List<Billing__c> pendingBills = [
        SELECT Id, Status__c
        FROM Billing__c
        WHERE Id IN :billingIds
    ];

    for (Billing__c bill : pendingBills) {

        System.assertEquals(
            'Pending Approval',
            bill.Status__c
        );

        System.assertEquals(
            true,
            Approval.isLocked(bill.Id)
        );
    }

    System.debug(
        'Submitted successfully: ' +
        submittedCount
    );

    // =======================================
    // FIRST-LEVEL APPROVAL ACTIONS
    // =======================================

    Set<String> approveAtFirst =
        new Set<String>{
            'PAT-0028',
            'PAT-0029',
            'PAT-0030',
            'PAT-0031',
            'PAT-0032',
            'PAT-0034'
        };

    Set<String> rejectAtFirst =
        new Set<String>{
            'PAT-0033'
        };

    List<Approval.ProcessRequest> firstActions =
        new List<Approval.ProcessRequest>();

    List<ProcessInstanceWorkitem> firstItems = [
        SELECT Id, ActorId,
               ProcessInstance.TargetObjectId
        FROM ProcessInstanceWorkitem
        WHERE ProcessInstance.TargetObjectId
            IN :billingIds
    ];

    System.assertEquals(10, firstItems.size());

    for (
        ProcessInstanceWorkitem item :
        firstItems
    ) {

        String patientNumber =
            billToPatient.get(
                item.ProcessInstance.TargetObjectId
            );

        System.assertEquals(
            UserInfo.getUserId(),
            item.ActorId
        );

        String action;

        if (
            approveAtFirst.contains(patientNumber)
        ) {
            action = 'Approve';

        } else if (
            rejectAtFirst.contains(patientNumber)
        ) {
            action = 'Reject';

        } else {
            continue;
        }

        Approval.ProcessWorkitemRequest request =
            new Approval.ProcessWorkitemRequest();

        request.setWorkitemId(item.Id);
        request.setAction(action);

        request.setComments(
            'HMS-DEMO Department Head: ' + action
        );

        firstActions.add(request);
    }

    System.assertEquals(7, firstActions.size());

    List<Approval.ProcessResult> firstResults =
        Approval.process(firstActions, true);

    for (
        Approval.ProcessResult result :
        firstResults
    ) {

        System.assert(
            result.isSuccess(),
            JSON.serialize(result.getErrors())
        );

        System.debug(
            'FIRST STEP RESULT: ' +
            result.getInstanceStatus()
        );
    }

    // =======================================
    // VERIFY FIRST-LEVEL ROUTING
    // =======================================

    Map<String, String> firstExpected =
        new Map<String, String>{
            'PAT-0025' => 'Pending Approval',
            'PAT-0026' => 'Pending Approval',
            'PAT-0027' => 'Pending Approval',
            'PAT-0028' => 'Pending Approval',
            'PAT-0029' => 'Approved',
            'PAT-0030' => 'Approved',
            'PAT-0031' => 'Pending Approval',
            'PAT-0032' => 'Pending Approval',
            'PAT-0033' => 'Rejected',
            'PAT-0034' => 'Pending Approval'
        };

    for (Billing__c bill : [
        SELECT Id, Status__c
        FROM Billing__c
        WHERE Id IN :billingIds
    ]) {

        System.assertEquals(
            firstExpected.get(
                billToPatient.get(bill.Id)
            ),
            bill.Status__c
        );
    }

    // =======================================
    // SECOND-LEVEL APPROVAL ACTIONS
    // =======================================

    Set<String> approveAtSecond =
        new Set<String>{
            'PAT-0031',
            'PAT-0032'
        };

    Set<String> rejectAtSecond =
        new Set<String>{
            'PAT-0034'
        };

    List<Approval.ProcessRequest> secondActions =
        new List<Approval.ProcessRequest>();

    List<ProcessInstanceWorkitem> remainingItems = [
        SELECT Id, ActorId,
               ProcessInstance.TargetObjectId
        FROM ProcessInstanceWorkitem
        WHERE ProcessInstance.TargetObjectId
            IN :billingIds
    ];

    System.assertEquals(
        7,
        remainingItems.size()
    );

    // Ensure second-step work items are new
    Set<Id> originalWorkItems =
        new Set<Id>();

    for (
        ProcessInstanceWorkitem item :
        firstItems
    ) {
        originalWorkItems.add(item.Id);
    }

    Integer secondLevelItems = 0;

    for (
        ProcessInstanceWorkitem item :
        remainingItems
    ) {

        String patientNumber =
            billToPatient.get(
                item.ProcessInstance.TargetObjectId
            );

        Boolean isSecondLevel =
            patientNumber == 'PAT-0028' ||
            approveAtSecond.contains(patientNumber) ||
            rejectAtSecond.contains(patientNumber);

        if (isSecondLevel) {

            System.assert(
                !originalWorkItems.contains(item.Id),
                'Second-level work item was not created.'
            );

            secondLevelItems++;
        }

        System.assertEquals(
            UserInfo.getUserId(),
            item.ActorId
        );

        String action;

        if (
            approveAtSecond.contains(patientNumber)
        ) {
            action = 'Approve';

        } else if (
            rejectAtSecond.contains(patientNumber)
        ) {
            action = 'Reject';

        } else {
            continue;
        }

        Approval.ProcessWorkitemRequest request =
            new Approval.ProcessWorkitemRequest();

        request.setWorkitemId(item.Id);
        request.setAction(action);

        request.setComments(
            'HMS-DEMO Hospital Admin: ' + action
        );

        secondActions.add(request);
    }

    System.assertEquals(4, secondLevelItems);
    System.assertEquals(3, secondActions.size());

    List<Approval.ProcessResult> secondResults =
        Approval.process(secondActions, true);

    for (
        Approval.ProcessResult result :
        secondResults
    ) {

        System.assert(
            result.isSuccess(),
            JSON.serialize(result.getErrors())
        );

        System.debug(
            'SECOND STEP RESULT: ' +
            result.getInstanceStatus()
        );
    }

    // =======================================
    // VERIFY FINAL BILLING STATUSES
    // =======================================

    Integer lockedCount = 0;
    Integer statusMismatches = 0;

    Set<Id> rejectedIds = new Set<Id>();

    for (Billing__c bill : [
        SELECT Id, Status__c, Amount_Due__c
        FROM Billing__c
        WHERE Id IN :billingIds
    ]) {

        String patientNumber =
            billToPatient.get(bill.Id);

        String expected =
            targetStatuses.get(patientNumber);

        Boolean locked =
            Approval.isLocked(bill.Id);

        if (bill.Status__c != expected) {
            statusMismatches++;
        }

        System.assertEquals(
            expectedAmounts.get(patientNumber),
            bill.Amount_Due__c
        );

        Boolean expectedLock =
            expected != 'Rejected';

        System.assertEquals(
            expectedLock,
            locked,
            'Unexpected record lock status.'
        );

        if (locked) {
            lockedCount++;
        }

        if (bill.Status__c == 'Rejected') {
            rejectedIds.add(bill.Id);
        }

        System.debug(
            patientNumber +
            ' | Status: ' + bill.Status__c +
            ' | Locked: ' + locked
        );
    }

    // =======================================
    // VERIFY APPROVAL INSTANCE COUNTS
    // =======================================

    Map<String, Integer> instanceCounts =
        new Map<String, Integer>();

    for (AggregateResult ar : [
        SELECT Status, COUNT(Id) total
        FROM ProcessInstance
        WHERE TargetObjectId IN :billingIds
        GROUP BY Status
    ]) {

        String status = (String) ar.get('Status');

        Integer total = (Integer) ar.get('total');

        instanceCounts.put(status, total);

        System.debug(
            'APPROVAL INSTANCE: ' +
            status + ' = ' + total
        );
    }

    System.assertEquals(
        4,
        instanceCounts.get('Pending')
    );

    System.assertEquals(
        4,
        instanceCounts.get('Approved')
    );

    System.assertEquals(
        2,
        instanceCounts.get('Rejected')
    );

    Integer pendingItems = [
        SELECT COUNT()
        FROM ProcessInstanceWorkitem
        WHERE ProcessInstance.TargetObjectId
            IN :billingIds
    ];

    // =======================================
    // VERIFY REJECTION TASKS
    // =======================================

    Integer finalTasks = [
        SELECT COUNT()
        FROM Task
        WHERE Subject = 'Revise rejected bill'
    ];

    Integer generatedTasks =
        finalTasks - originalTasks;

    Integer relatedRejectionTasks = [
        SELECT COUNT()
        FROM Task
        WHERE Subject = 'Revise rejected bill'
        AND WhatId IN :rejectedIds
    ];

    // =======================================
    // VERIFY FINANCIAL DATA INTEGRITY
    // =======================================

    AggregateResult billSummary = [
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
        (Decimal) billSummary.get('due')
    );

    System.assertEquals(
        4350000,
        (Decimal) billSummary.get('insurance')
    );

    System.assertEquals(
        4357000,
        (Decimal) patientSummary.get('total')
    );

    Map<String, Integer> finalStatuses =
        new Map<String, Integer>();

    for (AggregateResult ar : [
        SELECT Status__c, COUNT(Id) total
        FROM Billing__c
        GROUP BY Status__c
    ]) {

        String status =
            (String) ar.get('Status__c');

        Integer total =
            (Integer) ar.get('total');

        finalStatuses.put(status, total);

        System.debug(
            'BILLING STATUS: ' +
            status + ' = ' + total
        );
    }

    System.assertEquals(
        5,
        finalStatuses.get('Draft')
    );

    System.assertEquals(
        4,
        finalStatuses.get('Pending Approval')
    );

    System.assertEquals(
        4,
        finalStatuses.get('Approved')
    );

    System.assertEquals(
        2,
        finalStatuses.get('Rejected')
    );

    System.assertEquals(8, lockedCount);
    System.assertEquals(4, pendingItems);
    System.assertEquals(2, generatedTasks);
    System.assertEquals(2, relatedRejectionTasks);
    System.assertEquals(0, statusMismatches);

    System.assertEquals(
        0,
        [SELECT COUNT()
         FROM Billing__c
         WHERE Claim_Submitted__c = true
         OR Claim_Reference__c != null]
    );

    System.assertEquals(0, Limits.getCallouts());
    System.assertEquals(0, Limits.getFutureCalls());
    System.assertEquals(0, Limits.getQueueableJobs());

    // =======================================
    // FINAL SUMMARY
    // =======================================

    System.debug(
        '========== FINAL SUMMARY =========='
    );

    System.debug(
        'Submitted: ' + submittedCount
    );

    System.debug(
        'First-level actions: ' +
        firstActions.size()
    );

    System.debug(
        'Second-level work items created: ' +
        secondLevelItems
    );

    System.debug(
        'Second-level actions: ' +
        secondActions.size()
    );

    System.debug(
        'Locked bills: ' + lockedCount
    );

    System.debug(
        'Pending work items: ' + pendingItems
    );

    System.debug(
        'Rejection tasks created: ' + generatedTasks
    );

    System.debug(
        'Related rejection tasks: ' +
        relatedRejectionTasks
    );

    System.debug(
        'Status mismatches: ' + statusMismatches
    );

    System.debug(
        'SOQL queries: ' + Limits.getQueries()
    );

    System.debug(
        'DML statements: ' +
        Limits.getDmlStatements()
    );

    System.debug(
        'Apex email invocations: ' +
        Limits.getEmailInvocations()
    );

    System.debug(
        'Callouts: ' + Limits.getCallouts()
    );

    System.debug(
        'ALL APPROVAL CHECKS PASSED.'
    );

    if (dryRun) {

        Database.rollback(sp);

        System.debug(
            'ROLLBACK COMPLETED: No changes committed.'
        );

    } else {

        System.debug(
            'APPROVAL SCENARIOS SAVED PERMANENTLY.'
        );
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('APPROVAL SCENARIOS FAILED.');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());
    System.debug('ROLLBACK COMPLETED.');
}
