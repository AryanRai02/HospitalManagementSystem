@IsTest(SeeAllData=false)
private class AsyncJobsTest {

    // Returns a fixed insurance-provider response
    private class ClaimMock implements HttpCalloutMock {
        private final Integer statusCode;
        ClaimMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('CLAIM-REF-123');
            return res;
        }
    }

    @IsTest
    static void reminderBatchMarksTomorrowsConfirmedAppointments() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Reminder Patient', 'reminder@example.com');
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(1, 10), 'Confirmed');

        Test.startTest();
        Database.executeBatch(new AppointmentReminderBatch(), 100);
        Test.stopTest();

        System.assertEquals(true,
            [SELECT Reminder_Sent__c FROM Appointment__c WHERE Id = :appt.Id].Reminder_Sent__c);
    }

    @IsTest
    static void dailySchedulableStartsTheReminderBatch() {
        Test.startTest();
        new DailyAppointmentReminder().execute(null);
        Test.stopTest();

        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'AppointmentReminderBatch'] > 0);
    }

    @IsTest
    static void dailyScheduleIsCreated() {
        Test.startTest();
        String cronId = System.schedule('Daily Reminder Test Job', '0 0 6 * * ?', new DailyAppointmentReminder());
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression FROM CronTrigger WHERE Id = :cronId];
        System.assertEquals('0 0 6 * * ?', job.CronExpression);
    }

       @IsTest
    static void labProcessorMarksRecordsAsProcessed() {
        Patient__c pat = TestDataFactory.createPatient('Lab Patient', null);
        List<Medical_Record__c> records = TestDataFactory.createMedicalRecords(pat.Id, 3);
        List<Id> ids = new List<Id>(new Map<Id, Medical_Record__c>(records).keySet());

        // ClaimMock returns a plain string body, so use a JSON list for the lab service
        Test.setMock(HttpCalloutMock.class, new LabJsonMock());

        Test.startTest();
        System.enqueueJob(new LabResultProcessor(ids));
        Test.stopTest();

        System.assertEquals(3,
            [SELECT COUNT() FROM Medical_Record__c WHERE Lab_Status__c = 'Processed']);
    }

    private class LabJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"testName":"Blood Sugar","result":"95","status":"Normal"}]');
            return res;
        }
    }

    @IsTest
    static void labProcessorIgnoresAnEmptyList() {
        Test.startTest();
        System.enqueueJob(new LabResultProcessor(new List<Id>()));
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Medical_Record__c]);
    }

    @IsTest
    static void insuranceClaimIsSubmittedOnSuccess() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Claim Patient', null);
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        Billing__c bill = TestDataFactory.createBilling(appt.Id, pat.Id, 5000, 'Draft');

        Test.setMock(HttpCalloutMock.class, new ClaimMock(200));
        Test.startTest();
        SendInsuranceClaimAsync.submitClaim(bill.Id);
        Test.stopTest();

        Billing__c after = [SELECT Claim_Submitted__c, Claim_Reference__c FROM Billing__c WHERE Id = :bill.Id];
        System.assertEquals(true, after.Claim_Submitted__c);
        System.assertEquals('CLAIM-REF-123', after.Claim_Reference__c);
    }

    @IsTest
    static void insuranceClaimFailureLeavesTheBillUnsubmitted() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Claim Patient', null);
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        Billing__c bill = TestDataFactory.createBilling(appt.Id, pat.Id, 5000, 'Draft');

        Test.setMock(HttpCalloutMock.class, new ClaimMock(500));
        Test.startTest();
        SendInsuranceClaimAsync.submitClaim(bill.Id);
        Test.stopTest();

        System.assertEquals(false,
            [SELECT Claim_Submitted__c FROM Billing__c WHERE Id = :bill.Id].Claim_Submitted__c);
    }

    @IsTest
    static void insuranceClaimIgnoresAMissingBill() {
        Test.setMock(HttpCalloutMock.class, new ClaimMock(200));
        Test.startTest();
        SendInsuranceClaimAsync.submitClaim(null);
        Test.stopTest();
        System.assert(true, 'No exception expected');
    }
}