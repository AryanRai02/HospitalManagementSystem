@IsTest(SeeAllData=false)
private class MonthlyBillingReportTest {

    private static void createBills() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Report Patient', 'report.patient@example.com');
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        TestDataFactory.createBilling(appt.Id, pat.Id, 1000, 'Draft');
        TestDataFactory.createBilling(appt.Id, pat.Id, 2500, 'Rejected');
    }

    private static void assertJobCompleted(Id jobId) {
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Batch should complete');
        System.assertEquals(0, job.NumberOfErrors, 'Batch should have no errors');
    }

    @IsTest
    static void batchRunsForTheCurrentMonth() {
        createBills();

        Test.startTest();
        Id jobId = Database.executeBatch(
            new MonthlyBillingReport(Date.today().toStartOfMonth(), Date.today()), 200);
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void defaultConstructorCoversThePreviousMonth() {
        createBills();

        Test.startTest();
        Id jobId = Database.executeBatch(new MonthlyBillingReport(), 200);
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void batchWithNoBillsStillFinishes() {
        Test.startTest();
        Id jobId = Database.executeBatch(
            new MonthlyBillingReport(Date.today().addYears(-5), Date.today().addYears(-5)), 200);
        Test.stopTest();

        assertJobCompleted(jobId);
    }

    @IsTest
    static void schedulerStartsTheBatch() {
        createBills();

        Test.startTest();
        new MonthlyBillingReportScheduler().execute(null);
        Test.stopTest();

        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'MonthlyBillingReport'] > 0);
    }

    @IsTest
    static void monthlyScheduleIsCreated() {
        Test.startTest();
        String cronId = MonthlyBillingReport.scheduleMonthly('Monthly Billing Report Test Job');
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression FROM CronTrigger WHERE Id = :cronId];
        System.assertEquals('0 0 2 1 * ?', job.CronExpression);
    }
}