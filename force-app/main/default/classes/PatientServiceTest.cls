@IsTest(SeeAllData=false)
private class PatientServiceTest {

    @IsTest
    static void ageGroupsAreCalculatedCorrectly() {
        Date today = Date.today();
        System.assertEquals('Child', PatientService.calculateAgeGroup(today.addYears(-5)));
        System.assertEquals('Child', PatientService.calculateAgeGroup(today.addYears(-12).addDays(-30)));
        System.assertEquals('Teen', PatientService.calculateAgeGroup(today.addYears(-15)));
        System.assertEquals('Adult', PatientService.calculateAgeGroup(today.addYears(-18)));
        System.assertEquals('Adult', PatientService.calculateAgeGroup(today.addYears(-40)));
        System.assertEquals('Senior', PatientService.calculateAgeGroup(today.addYears(-60)));
        System.assertEquals('Senior', PatientService.calculateAgeGroup(today.addYears(-85)));
    }

    @IsTest
    static void birthdayNotYetReachedThisYearLowersTheAge() {
        // Turns 18 tomorrow, so still a Teen today
        Date dob = Date.today().addYears(-18).addDays(1);
        System.assertEquals('Teen', PatientService.calculateAgeGroup(dob));
    }

    @IsTest
    static void ageGroupRejectsMissingOrFutureDates() {
        Boolean blankFailed = false;
        try {
            PatientService.calculateAgeGroup(null);
        } catch (HospitalException e) {
            blankFailed = true;
        }
        Boolean futureFailed = false;
        try {
            PatientService.calculateAgeGroup(Date.today().addDays(5));
        } catch (HospitalException e) {
            futureFailed = true;
        }
        System.assert(blankFailed, 'Null date should throw');
        System.assert(futureFailed, 'Future date should throw');
    }

    @IsTest
    static void searchFindsPatientsByNameAndId() {
        Patient__c pat = TestDataFactory.createPatient('Zelda Searchable', 'zelda@example.com');
        Patient__c saved = [SELECT Name FROM Patient__c WHERE Id = :pat.Id];

        Test.startTest();
        List<Patient__c> byName = PatientService.searchPatients('Searchable');
        List<Patient__c> byId = PatientService.searchPatients(saved.Name);
        List<Patient__c> tooShort = PatientService.searchPatients('a');
        List<Patient__c> blank = PatientService.searchPatients('');
        Test.stopTest();

        System.assertEquals(1, byName.size());
        System.assertEquals(1, byId.size());
        System.assertEquals(0, tooShort.size());
        System.assertEquals(0, blank.size());
    }

    @IsTest
    static void mergeMovesRecordsAndDeletesDuplicates() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c master = TestDataFactory.createPatient('Master Patient', null);
        Patient__c dup = TestDataFactory.createPatient('Duplicate Patient', 'dup@example.com');
        Appointment__c appt = TestDataFactory.createAppointment(
            dup.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');
        TestDataFactory.createBilling(appt.Id, dup.Id, 500, 'Draft');
        TestDataFactory.createMedicalRecords(dup.Id, 2);

        Test.startTest();
        PatientService.mergeDuplicates(master.Id, new List<Id>{ dup.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Patient__c WHERE Id = :dup.Id], 'Duplicate deleted');
        System.assertEquals(1, [SELECT COUNT() FROM Appointment__c WHERE Patient__c = :master.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Billing__c WHERE Patient__c = :master.Id]);
        System.assertEquals(2, [SELECT COUNT() FROM Medical_Record__c WHERE Patient__c = :master.Id]);
        System.assertEquals('dup@example.com',
            [SELECT Email__c FROM Patient__c WHERE Id = :master.Id].Email__c, 'Empty email copied');
    }

    @IsTest
    static void mergeRejectsBadInput() {
        Patient__c pat = TestDataFactory.createPatient('Only Patient', null);

        Integer failures = 0;
        try {
            PatientService.mergeDuplicates(null, new List<Id>{ pat.Id });
        } catch (HospitalException e) {
            failures++;
        }
        try {
            PatientService.mergeDuplicates(pat.Id, new List<Id>());
        } catch (HospitalException e) {
            failures++;
        }
        try {
            PatientService.mergeDuplicates(pat.Id, new List<Id>{ pat.Id });
        } catch (HospitalException e) {
            failures++;
        }
        System.assertEquals(3, failures, 'Each bad call should throw');
    }
}