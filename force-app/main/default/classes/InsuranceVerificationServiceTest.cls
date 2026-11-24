@IsTest(SeeAllData=false)
private class InsuranceVerificationServiceTest {

    private class VerificationMock implements WebServiceMock {
        private final Boolean covered;
        VerificationMock(Boolean covered) {
            this.covered = covered;
        }
        public void doInvoke(
            Object stub, Object request, Map<String, Object> response,
            String endpoint, String soapAction, String requestName,
            String responseNS, String responseName, String responseType
        ) {
            insuranceMedcareExampleVerification.verifyCoverageResponse_element reply =
                new insuranceMedcareExampleVerification.verifyCoverageResponse_element();
            reply.covered = covered;
            reply.coveragePercent = covered ? 80 : 0;
            reply.message = covered ? 'Policy active' : 'Policy not found';
            response.put('response_x', reply);
        }
    }

    @IsTest
    static void activePolicyIsCovered() {
        Test.setMock(WebServiceMock.class, new VerificationMock(true));

        Test.startTest();
        InsuranceVerificationService.CoverageResult r =
            InsuranceVerificationService.verify('POL-1234', 'Asha Test');
        Test.stopTest();

        System.assertEquals(true, r.covered);
        System.assertEquals(80, r.coveragePercent);
    }

    @IsTest
    static void unknownPolicyIsNotCovered() {
        Test.setMock(WebServiceMock.class, new VerificationMock(false));

        Test.startTest();
        InsuranceVerificationService.CoverageResult r =
            InsuranceVerificationService.verify('POL-0000', 'Asha Test');
        Test.stopTest();

        System.assertEquals(false, r.covered);
    }

    @IsTest
    static void blankPolicyIsRejected() {
        Boolean failed = false;
        try {
            InsuranceVerificationService.verify('', 'Asha Test');
        } catch (HospitalException e) {
            failed = true;
        }
        System.assert(failed);
    }

    @IsTest
    static void patientVerificationUsesStoredPolicy() {
        Patient__c pat = new Patient__c(
            DOB__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Policy Patient',
            Insurance_Policy_Number__c = 'POL-5555'
        );
        insert pat;
        Test.setMock(WebServiceMock.class, new VerificationMock(true));

        Test.startTest();
        InsuranceVerificationService.CoverageResult r = InsuranceVerificationService.verifyPatient(pat.Id);
        Test.stopTest();

        System.assertEquals(true, r.covered);
    }

    @IsTest
    static void missingPatientIsRejected() {
        Boolean failed = false;
        try {
            InsuranceVerificationService.verifyPatient(null);
        } catch (HospitalException e) {
            failed = true;
        }
        System.assert(failed);
    }
}