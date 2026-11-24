public with sharing class PatientService {

    private static final List<String> MERGE_FIELDS = new List<String>{
        'Full_Name__c', 'Email__c', 'Phone__c', 'Emergency_Contact__c',
        'Blood_Group__c', 'Insurance_Provider__c', 'Insurance_Policy_Number__c'
    };

    // Child (under 13), Teen (13 to 17), Adult (18 to 59), Senior (60 and over)
    public static String calculateAgeGroup(Date dob) {
        if (dob == null) {
            throw new HospitalException('Date of birth is required to calculate an age group.');
        }
        Date today = Date.today();
        if (dob > today) {
            throw new HospitalException('Date of birth cannot be in the future.');
        }
        Integer age = today.year() - dob.year();
        if (today.month() < dob.month()
            || (today.month() == dob.month() && today.day() < dob.day())) {
            age--;
        }
        if (age < 13) {
            return 'Child';
        } else if (age < 18) {
            return 'Teen';
        } else if (age < 60) {
            return 'Adult';
        }
        return 'Senior';
    }

    // Used later by the patientSearchBar LWC
    @AuraEnabled(cacheable=true)
    public static List<Patient__c> searchPatients(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Patient__c>();
        }
        String key = '%' + searchTerm.trim() + '%';
        return [
            SELECT Id, Name, Full_Name__c, DOB__c, Email__c
            FROM Patient__c
            WHERE Name LIKE :key OR Full_Name__c LIKE :key
            ORDER BY Name
            LIMIT 20
        ];
    }

    // Moves the duplicates' records to the master patient, then deletes the duplicates
    public static void mergeDuplicates(Id masterId, List<Id> duplicateIds) {
        if (masterId == null || duplicateIds == null || duplicateIds.isEmpty()) {
            throw new HospitalException('A master patient and at least one duplicate are required.');
        }
        Set<Id> dupIds = new Set<Id>(duplicateIds);
        if (dupIds.contains(masterId)) {
            throw new HospitalException('The master patient cannot also be a duplicate.');
        }

        Map<Id, Patient__c> found = new Map<Id, Patient__c>([
            SELECT Id, Full_Name__c, Email__c, Phone__c, Emergency_Contact__c,
                   Blood_Group__c, Insurance_Provider__c, Insurance_Policy_Number__c
            FROM Patient__c
            WHERE Id = :masterId OR Id IN :dupIds
        ]);
        if (found.size() != dupIds.size() + 1) {
            throw new HospitalException('One or more patients could not be found.');
        }

        // Fill any empty master fields from the duplicates
        Patient__c master = found.get(masterId);
        for (Id dupId : dupIds) {
            Patient__c dup = found.get(dupId);
            for (String fieldName : MERGE_FIELDS) {
                if (master.get(fieldName) == null && dup.get(fieldName) != null) {
                    master.put(fieldName, dup.get(fieldName));
                }
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            List<Appointment__c> appointments = [SELECT Id FROM Appointment__c WHERE Patient__c IN :dupIds];
            for (Appointment__c a : appointments) {
                a.Patient__c = masterId;
            }
            update appointments;

            List<Billing__c> bills = [SELECT Id FROM Billing__c WHERE Patient__c IN :dupIds];
            for (Billing__c b : bills) {
                b.Patient__c = masterId;
            }
            update bills;

            // Master-detail: "Allow reparenting" must be ticked on their Patient field
            List<Medical_Record__c> records = [SELECT Id FROM Medical_Record__c WHERE Patient__c IN :dupIds];
            for (Medical_Record__c r : records) {
                r.Patient__c = masterId;
            }
            update records;

            List<Patient_Procedure__c> links = [SELECT Id FROM Patient_Procedure__c WHERE Patient__c IN :dupIds];
            for (Patient_Procedure__c l : links) {
                l.Patient__c = masterId;
            }
            update links;

            update master;
            delete [SELECT Id FROM Patient__c WHERE Id IN :dupIds];
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new HospitalException('Merge failed: ' + e.getMessage());
        }
    }
}