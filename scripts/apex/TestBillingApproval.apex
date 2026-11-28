Savepoint sp = Database.setSavepoint();

try {

    System.assertEquals(
        0,
        [SELECT COUNT() FROM ProcessInstance],
        'Existing approval requests detected.'
    );

    Billing__c bill = [
        SELECT Id, Name, Amount_Due__c,
               Status__c,
               Patient__r.Name,
               Patient__r.Full_Name__c,
               Patient__r.Email__c
        FROM Billing__c
        WHERE Id = 'a01g500000qniIFAAY'
    ];

    System.assertEquals('Draft', bill.Status__c);
    System.assertEquals(150000, bill.Amount_Due__c);

    System.assertEquals(
        'PAT-0029',
        bill.Patient__r.Name
    );

    System.assert(
        bill.Patient__r.Full_Name__c
            .startsWith('HMS-DEMO')
    );

    System.assert(
        String.isBlank(bill.Patient__r.Email__c)
    );

    System.assertEquals(
        false,
        Approval.isLocked(bill.Id)
    );

    System.debug('========== BEFORE SUBMISSION ==========');
    System.debug('Billing ID: ' + bill.Id);
    System.debug('Status: ' + bill.Status__c);
    System.debug('Amount Due: ' + bill.Amount_Due__c);
    System.debug('Locked: ' + Approval.isLocked(bill.Id));

    // Submit the billing record for approval

    Approval.ProcessSubmitRequest submitRequest =
        new Approval.ProcessSubmitRequest();

    submitRequest.setObjectId(bill.Id);

    submitRequest.setComments(
        'HMS-DEMO: Testing billing approval.'
    );

    submitRequest.setProcessDefinitionNameOrId(
        'Emergency_Billing_Approval'
    );

    // Do not bypass the entry criteria
    submitRequest.setSkipEntryCriteria(false);

    Approval.ProcessResult submitResult =
        Approval.process(submitRequest);

    System.assert(
        submitResult.isSuccess(),
        'Submission failed: ' +
        JSON.serialize(submitResult.getErrors())
    );

    System.assertEquals(
        'Pending',
        submitResult.getInstanceStatus()
    );

    Billing__c submittedBill = [
        SELECT Id, Status__c, Amount_Due__c
        FROM Billing__c
        WHERE Id = :bill.Id
    ];

    System.debug('========== AFTER SUBMISSION ==========');

    System.debug(
        'Process Instance ID: ' +
        submitResult.getInstanceId()
    );

    System.debug(
        'Approval Instance Status: ' +
        submitResult.getInstanceStatus()
    );

    System.debug(
        'Billing Status: ' +
        submittedBill.Status__c
    );

    System.debug(
        'Locked: ' +
        Approval.isLocked(bill.Id)
    );

    System.assertEquals(
        'Pending Approval',
        submittedBill.Status__c
    );

    System.assertEquals(
        true,
        Approval.isLocked(bill.Id)
    );

    // Retrieve the pending approval work item

    List<Id> workItemIds =
        submitResult.getNewWorkitemIds();

    System.assertEquals(
        1,
        workItemIds.size()
    );

    ProcessInstanceWorkitem workItem = [
        SELECT Id, ActorId, OriginalActorId
        FROM ProcessInstanceWorkitem
        WHERE Id = :workItemIds[0]
    ];

    System.debug(
        'Work Item ID: ' + workItem.Id
    );

    System.debug(
        'Assigned Approver: ' + workItem.ActorId
    );

    System.assertEquals(
        UserInfo.getUserId(),
        workItem.ActorId,
        'Current user is not the assigned approver.'
    );

    // Approve the pending request

    Approval.ProcessWorkitemRequest approveRequest =
        new Approval.ProcessWorkitemRequest();

    approveRequest.setWorkitemId(workItem.Id);
    approveRequest.setAction('Approve');

    approveRequest.setComments(
        'HMS-DEMO: Department Head approval test.'
    );

    Approval.ProcessResult approveResult =
        Approval.process(approveRequest);

    System.assert(
        approveResult.isSuccess(),
        'Approval failed: ' +
        JSON.serialize(approveResult.getErrors())
    );

    Billing__c approvedBill = [
        SELECT Id, Status__c, Amount_Due__c
        FROM Billing__c
        WHERE Id = :bill.Id
    ];

    System.debug('========== AFTER APPROVAL ==========');

    System.debug(
        'Approval Instance Status: ' +
        approveResult.getInstanceStatus()
    );

    System.debug(
        'Billing Status: ' +
        approvedBill.Status__c
    );

    System.debug(
        'Locked: ' +
        Approval.isLocked(bill.Id)
    );

    System.assertEquals(
        'Approved',
        approveResult.getInstanceStatus()
    );

    System.assertEquals(
        'Approved',
        approvedBill.Status__c
    );

    System.assertEquals(
        true,
        Approval.isLocked(bill.Id)
    );

    System.assertEquals(
        150000,
        approvedBill.Amount_Due__c
    );

    System.assertEquals(
        0,
        Limits.getCallouts()
    );

    System.debug('========== FINAL SUMMARY ==========');

    System.debug('Submission: PASSED');
    System.debug('Pending status update: PASSED');
    System.debug('Record locking: PASSED');
    System.debug('Work item creation: PASSED');
    System.debug('Final approval: PASSED');
    System.debug('Final status update: PASSED');
    System.debug('Final record lock: PASSED');

    System.debug(
        'SOQL queries: ' + Limits.getQueries()
    );

    System.debug(
        'DML statements: ' + Limits.getDmlStatements()
    );

    System.debug(
        'Apex email invocations: ' +
        Limits.getEmailInvocations()
    );

    System.debug(
        'Callouts: ' + Limits.getCallouts()
    );

    System.debug('APPROVAL PILOT PASSED.');

} catch (Exception e) {

    System.debug('APPROVAL PILOT FAILED.');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR LINE: ' + e.getLineNumber());

} finally {

    Database.rollback(sp);

    System.debug(
        'ROLLBACK COMPLETED: No changes committed.'
    );
}