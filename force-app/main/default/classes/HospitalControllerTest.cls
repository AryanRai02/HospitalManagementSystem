@IsTest(SeeAllData=false)
private class HospitalControllerTest {

    @IsTest
    static void scheduleAndStatsAreReturned() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Lwc Patient', 'lwc@example.com');
        Date day = Date.today().addDays(2);
        Appointment__c a1 = TestDataFactory.createAppointment(pat.Id, doc.Id, TestDataFactory.futureSlot(2, 9), 'Requested');
        Appointment__c a2 = TestDataFactory.createAppointment(pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Confirmed');
        TestDataFactory.createBilling(a1.Id, pat.Id, 1500, 'Pending Approval');

        Test.startTest();
        List<HospitalController.AppointmentRow> rows = HospitalController.getAppointmentsByDoctor(doc.Id, day);
        HospitalController.TodayStats stats = HospitalController.getTodayStats(day);
        HospitalController.RevenueSummary revenue = HospitalController.getRevenueSummary();
        List<HospitalController.DepartmentSummary> departments = HospitalController.getDepartmentSummary(day);
        List<Doctor__c> doctors = HospitalController.getAvailableDoctors();
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assertEquals('Lwc Patient', rows[0].patientName);
        System.assertEquals(2, stats.total);
        System.assertEquals(1, stats.requested);
        System.assertEquals(1, stats.confirmed);
        System.assertEquals(1500, revenue.monthRevenue);
        System.assertEquals(1, revenue.pendingApprovals);
        System.assertEquals(1, departments.size());
        System.assertEquals(1, departments[0].doctorCount);
        System.assertEquals(2, departments[0].appointmentsToday);
        System.assertEquals(1, doctors.size());
    }

    @IsTest
    static void emptyInputsAreHandled() {
        System.assertEquals(0, HospitalController.getAppointmentsByDoctor(null, null).size());
        System.assertEquals(0, HospitalController.getTodayStats(null).total);
        System.assertEquals(0, HospitalController.getRevenueSummary().monthRevenue);
        System.assertEquals(0, HospitalController.getDepartmentSummary(null).size());
    }
}