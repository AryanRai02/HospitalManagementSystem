@IsTest(SeeAllData=false)
private class AppointmentTriggerTest {

    private static Doctor__c newDoctor() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        return TestDataFactory.createDoctor(dept.Id, 'Active');
    }

    private static Patient__c newPatient() {
        return TestDataFactory.createPatient('Test Patient', 'test.patient@example.com');
    }

    private static Boolean hasError(Database.SaveResult result, String fragment) {
        for (Database.Error err : result.getErrors()) {
            if (err.getMessage().containsIgnoreCase(fragment)) {
                return true;
            }
        }
        return false;
    }

    // ---------- positive ----------

    @IsTest
    static void insertCreatesConfirmationTask() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();

        Test.startTest();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        Test.stopTest();

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :appt.Id];
        System.assertEquals(1, tasks.size(), 'One task should be created');
        System.assertEquals('Confirm appointment with patient by phone', tasks[0].Subject);
    }

    @IsTest
    static void statusUpdateOnExistingAppointmentIsNotBlocked() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');

        Test.startTest();
        appt.Status__c = 'Cancelled'; // slot unchanged, so the past-date check does not run
        Database.SaveResult result = Database.update(appt, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Status update should succeed');
    }

    @IsTest
    static void cancelledSlotCanBeBookedAgain() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Datetime slot = TestDataFactory.futureSlot(3, 11);
        Appointment__c first = TestDataFactory.createAppointment(pat.Id, doc.Id, slot, 'Requested');
        first.Status__c = 'Cancelled';
        update first;

        Test.startTest();
        Appointment__c second = TestDataFactory.buildAppointment(pat.Id, doc.Id, slot, 'Requested');
        Database.SaveResult result = Database.insert(second, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'A cancelled slot is free again');
    }

    // ---------- negative ----------

    @IsTest
    static void doctorConflictIsBlocked() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Datetime slot = TestDataFactory.futureSlot(2, 10);
        TestDataFactory.createAppointment(pat.Id, doc.Id, slot, 'Requested');

        Test.startTest();
        Appointment__c clash = TestDataFactory.buildAppointment(pat.Id, doc.Id, slot, 'Requested');
        Database.SaveResult result = Database.insert(clash, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Second booking must fail');
        System.assert(hasError(result, 'already booked'), 'Conflict message expected');
    }

    @IsTest
    static void pastDateIsBlocked() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();

        Test.startTest();
        Appointment__c past = TestDataFactory.buildAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(-1, 10), 'Requested');
        Database.SaveResult result = Database.insert(past, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Past appointment must fail');
        System.assert(hasError(result, 'past'), 'Past-date message expected');
    }

    @IsTest
    static void movingSlotIntoThePastIsBlocked() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');

        Test.startTest();
        appt.Slot__c = TestDataFactory.futureSlot(-2, 10);
        Database.SaveResult result = Database.update(appt, false);
        Test.stopTest();

        System.assert(!result.isSuccess());
        System.assert(hasError(result, 'past'));
    }

    @IsTest
    static void movingToABookedSlotIsBlocked() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c first = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        Appointment__c second = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 12), 'Requested');

        Test.startTest();
        second.Slot__c = first.Slot__c;
        Database.SaveResult result = Database.update(second, false);
        Test.stopTest();

        System.assert(!result.isSuccess());
        System.assert(hasError(result, 'already booked'));
    }

    // ---------- cancellation and delete ----------

    @IsTest
    static void cancellingLowersDoctorCounterAndSendsEmail() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        doc.Active_Appointments__c = 5;
        update doc;

        Test.startTest();
        appt.Status__c = 'Cancelled';
        update appt;
        Integer emailCalls = Limits.getEmailInvocations();
        Test.stopTest();

        Doctor__c after = [SELECT Active_Appointments__c FROM Doctor__c WHERE Id = :doc.Id];
        System.assertEquals(4, after.Active_Appointments__c, 'Counter should drop by one');
        System.assert(emailCalls >= 1, 'A cancellation email should be sent');
    }

    @IsTest
    static void deletingLowersDoctorCounter() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        doc.Active_Appointments__c = 5;
        update doc;

        Test.startTest();
        delete appt;
        Test.stopTest();

        Doctor__c after = [SELECT Active_Appointments__c FROM Doctor__c WHERE Id = :doc.Id];
        System.assertEquals(4, after.Active_Appointments__c);
    }

    @IsTest
    static void deletingACancelledAppointmentDoesNotLowerCounterAgain() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        doc.Active_Appointments__c = 5;
        update doc;
        appt.Status__c = 'Cancelled';
        update appt; // counter is now 4

        Test.startTest();
        delete appt;
        Test.stopTest();

        Doctor__c after = [SELECT Active_Appointments__c FROM Doctor__c WHERE Id = :doc.Id];
        System.assertEquals(4, after.Active_Appointments__c, 'No second decrement');
    }

    // ---------- bulk ----------

    @IsTest
    static void bulkInsertOf50AppointmentsWorks() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();

        List<Appointment__c> appts = new List<Appointment__c>();
        for (Integer day = 2; day < 7; day++) {
            for (Integer hour = 8; hour < 18; hour++) {
                appts.add(TestDataFactory.buildAppointment(
                    pat.Id, doc.Id, TestDataFactory.futureSlot(day, hour), 'Requested'));
            }
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(appts, false);
        Test.stopTest();

        Integer successes = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                successes++;
            }
        }
        System.assertEquals(50, successes, 'All 50 appointments should save');
        System.assertEquals(50, [SELECT COUNT() FROM Task WHERE Subject = 'Confirm appointment with patient by phone']);
    }

    @IsTest
    static void duplicateSlotsInsideOneBatchAllowOnlyOne() {
        Doctor__c doc = newDoctor();
        Patient__c pat = newPatient();
        Datetime slot = TestDataFactory.futureSlot(2, 14);

        List<Appointment__c> appts = new List<Appointment__c>{
            TestDataFactory.buildAppointment(pat.Id, doc.Id, slot, 'Requested'),
            TestDataFactory.buildAppointment(pat.Id, doc.Id, slot, 'Requested')
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(appts, false);
        Test.stopTest();

        Integer successes = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                successes++;
            }
        }
        System.assertEquals(1, successes, 'Only one of the two can be booked');
    }
}