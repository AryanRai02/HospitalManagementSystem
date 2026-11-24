public with sharing class LabSystemService {

    public class LabResult {
        @AuraEnabled public String testName;
        @AuraEnabled public String result;
        @AuraEnabled public String status;
    }

    // HTTP GET to the lab system: /results?patientId=<id>
    public static List<LabResult> getLabResults(String patientId) {
        if (String.isBlank(patientId)) {
            throw new HospitalException('A patient ID is required to fetch lab results.');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:LabSystem_NC/results?patientId=' + EncodingUtil.urlEncode(patientId, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            throw new HospitalException('Lab system is unreachable: ' + e.getMessage());
        }

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new HospitalException('Lab system returned status ' + res.getStatusCode());
        }

        return (List<LabResult>) JSON.deserialize(res.getBody(), List<LabResult>.class);
    }

    // Used by the doctor portal LWC (section 7)
    @AuraEnabled
    public static List<LabResult> fetchForPatient(String patientId) {
        try {
            return getLabResults(patientId);
        } catch (HospitalException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}