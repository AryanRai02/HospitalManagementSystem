@IsTest(SeeAllData=false)
private class LabSystemServiceTest {

    private class LabMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        LabMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/results?patientId='), 'Endpoint should include the patient');
            System.assertEquals('GET', req.getMethod());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void resultsAreParsedOnSuccess() {
        String json = '[{"testName":"Blood Sugar","result":"95 mg/dL","status":"Normal"},'
            + '{"testName":"Cholesterol","result":"210 mg/dL","status":"High"}]';
        Test.setMock(HttpCalloutMock.class, new LabMock(200, json));

        Test.startTest();
        List<LabSystemService.LabResult> results = LabSystemService.getLabResults('PAT-0001');
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('Blood Sugar', results[0].testName);
        System.assertEquals('High', results[1].status);
    }

    @IsTest
    static void errorStatusThrowsHospitalException() {
        Test.setMock(HttpCalloutMock.class, new LabMock(500, 'error'));

        Boolean failed = false;
        Test.startTest();
        try {
            LabSystemService.getLabResults('PAT-0001');
        } catch (HospitalException e) {
            failed = e.getMessage().contains('500');
        }
        Test.stopTest();

        System.assert(failed, 'A 500 response should raise a HospitalException');
    }

    @IsTest
    static void blankPatientIsRejected() {
        Boolean failed = false;
        try {
            LabSystemService.getLabResults('');
        } catch (HospitalException e) {
            failed = true;
        }
        System.assert(failed);
    }

    @IsTest
    static void auraMethodWrapsErrors() {
        Test.setMock(HttpCalloutMock.class, new LabMock(404, 'not found'));

        Boolean wrapped = false;
        Test.startTest();
        try {
            LabSystemService.fetchForPatient('PAT-0001');
        } catch (AuraHandledException e) {
            wrapped = true;
        }
        Test.stopTest();

        System.assert(wrapped, 'Errors should be wrapped for the LWC');
    }
}