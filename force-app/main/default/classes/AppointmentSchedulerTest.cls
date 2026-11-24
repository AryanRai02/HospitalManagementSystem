@IsTest(SeeAllData=false)
private class AppointmentSchedulerTest {

    @IsTest
    static void allDaySlotsAreReturnedForAFreeDoctor() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Date tomorrow = Date.today().addDays(1);

        Test.startTest();
        List<Datetime> slots = AppointmentScheduler.findAvailableSlots(doc.Id, tomorrow, tomorrow);
        Test.stopTest();

        System.assertEquals(12, slots.size(), '8 AM to 7 PM gives 12 hourly slots');
    }

    @IsTest
    static void bookedAndCancelledSlotsAreHandled() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Slot Patient', null);
        Date day = Date.today().addDays(2);

        TestDataFactory.createAppointment(pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        Appointment__c cancelled = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 11), 'Requested');
        cancelled.Status__c = 'Cancelled';
        update cancelled;

        Test.startTest();
        List<Datetime> slots = AppointmentScheduler.findAvailableSlots(doc.Id, day, day);
        Test.stopTest();

        Set<Datetime> slotSet = new Set<Datetime>(slots);
        System.assert(!slotSet.contains(TestDataFactory.futureSlot(2, 10)), '10 AM is booked');
        System.assert(slotSet.contains(TestDataFactory.futureSlot(2, 11)), 'A cancelled slot is free');
        System.assertEquals(11, slots.size());
    }

    @IsTest
    static void inactiveOrMissingDoctorHasNoSlots() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c inactive = TestDataFactory.createDoctor(dept.Id, 'Inactive');
        Date tomorrow = Date.today().addDays(1);

        System.assertEquals(0, AppointmentScheduler.findAvailableSlots(inactive.Id, tomorrow, tomorrow).size());
    }

    @IsTest
    static void invalidRangesThrow() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Date today = Date.today();

        Integer failures = 0;
        try {
            AppointmentScheduler.findAvailableSlots(null, today, today);
        } catch (HospitalException e) {
            failures++;
        }
        try {
            AppointmentScheduler.findAvailableSlots(doc.Id, today.addDays(3), today);
        } catch (HospitalException e) {
            failures++;
        }
        try {
            AppointmentScheduler.findAvailableSlots(doc.Id, today, today.addDays(60));
        } catch (HospitalException e) {
            failures++;
        }
        System.assertEquals(3, failures);
    }
}