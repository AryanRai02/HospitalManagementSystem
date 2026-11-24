@IsTest(SeeAllData=false)
private class PatientRestServiceTest {

    private static void callGet(String idPart) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/HMS/patient/' + idPart;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        PatientRestService.getPatient();
    }

    @IsTest
    static void patientIsReturnedById() {
        Department__c dept = TestDataFactory.createDepartment('Cardiology');
        Doctor__c doc = TestDataFactory.createDoctor(dept.Id, 'Active');
        Patient__c pat = TestDataFactory.createPatient('Rest Patient', 'rest@example.com');
        TestDataFactory.createAppointment(pat.Id, doc.Id, TestDataFactory.futureSlot(2, 10), 'Requested');

        Test.startTest();
        callGet(pat.Id);
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>)
            JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('Rest Patient', body.get('fullName'));
        System.assertEquals('Adult', body.get('ageGroup'));
        System.assertEquals(1, ((List<Object>) body.get('appointments')).size());
    }

     @IsTest
    static void patientIsReturnedByPatientNumber() {
        Patient__c pat = TestDataFactory.createPatient('Rest Patient', null);
        String patientNumber = [SELECT Name FROM Patient__c WHERE Id = :pat.Id].Name;

        Test.startTest();
        callGet(patientNumber);
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void unknownPatientReturns404() {
        Test.startTest();
        callGet('a00000000000000AAA');
        Test.stopTest();
        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void missingIdReturns400() {
        Test.startTest();
        callGet('');
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
    }
}