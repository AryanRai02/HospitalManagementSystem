public with sharing class InsuranceVerificationService {

    public class CoverageResult {
        @AuraEnabled public Boolean covered;
        @AuraEnabled public Decimal coveragePercent;
        @AuraEnabled public String message;
    }

    // Verifies a patient's coverage with the insurance provider (SOAP)
    public static CoverageResult verify(String policyNumber, String patientName) {
        if (String.isBlank(policyNumber)) {
            throw new HospitalException('An insurance policy number is required.');
        }

        insuranceMedcareExampleVerification.InsuranceVerificationPort port =
            new insuranceMedcareExampleVerification.InsuranceVerificationPort();
        port.timeout_x = 20000;

        insuranceMedcareExampleVerification.verifyCoverageResponse_element response;
        try {
            response = port.verifyCoverage(policyNumber, patientName);
        } catch (Exception e) {
            throw new HospitalException('Insurance provider is unreachable: ' + e.getMessage());
        }

        CoverageResult result = new CoverageResult();
        result.covered = response.covered;
        result.coveragePercent = response.coveragePercent;
        result.message = response.message;
        return result;
    }

    // Convenience: verify the insurance recorded on a patient
    public static CoverageResult verifyPatient(Id patientId) {
        List<Patient__c> patients = [
            SELECT Id, Full_Name__c, Insurance_Policy_Number__c
            FROM Patient__c
            WHERE Id = :patientId
            LIMIT 1
        ];
        if (patients.isEmpty()) {
            throw new HospitalException('Patient not found.');
        }
        return verify(patients[0].Insurance_Policy_Number__c, patients[0].Full_Name__c);
    }
}