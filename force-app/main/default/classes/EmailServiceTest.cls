@IsTest(SeeAllData=false)
private class EmailServiceTest {

    @IsTest
    static void renderTemplateMergesPlaceholders() {
        String result = EmailService.renderTemplate(
            'Hi {{Name}}, your ID is {{PatientId}}. {{Missing}}',
            new Map<String, String>{ 'Name' => 'Asha', 'PatientId' => 'PAT-1', 'Missing' => null });
        System.assertEquals('Hi Asha, your ID is PAT-1. ', result);
        System.assertEquals('', EmailService.renderTemplate(null, null));
        System.assertEquals('Plain text', EmailService.renderTemplate('Plain text', null));
    }

    @IsTest
    static void genericEmailIsSent() {
        Test.startTest();
        EmailService.sendEmail(new List<String>{ 'someone@example.com' }, 'Subject', 'Body');
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();
        System.assertEquals(1, sent);
    }

    @IsTest
    static void emailWithoutRecipientsThrows() {
        Boolean failed = false;
        try {
            EmailService.sendEmail(new List<String>(), 'Subject', 'Body');
        } catch (HospitalException e) {
            failed = true;
        }
        System.assert(failed);
    }

    @IsTest
    static void patientEmailsAreSentOnlyToPatientsWithAddresses() {
        Patient__c withEmail = TestDataFactory.createPatient('Has Email', 'has.email@example.com');
        Patient__c noEmail = TestDataFactory.createPatient('No Email', null);

        Test.startTest();
        EmailService.sendPatientEmails(
            new Set<Id>{ withEmail.Id, noEmail.Id }, 'Hello', 'Dear {{Name}} ({{PatientId}})');
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, sent, 'One bulk send call');
    }

    @IsTest
    static void doctorEmailUsesTheGenericSender() {
        Test.startTest();
        EmailService.sendDoctorEmail(new List<String>{ 'doctor@example.com' }, 'Subject', 'Body');
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();
        System.assertEquals(1, sent);
    }

    @IsTest
    static void cancellationEmailIsSentForPatientsWithEmail() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Cancel Patient', 'cancel@example.com');
        Appointment__c appt = TestDataFactory.createAppointment(
            pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');

        Test.startTest();
        EmailService.sendCancellationEmails(new Set<Id>{ appt.Id });
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, sent);
    }
}