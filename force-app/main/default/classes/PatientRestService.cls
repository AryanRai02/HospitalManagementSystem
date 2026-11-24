@RestResource(urlMapping='/HMS/patient/*')
global with sharing class PatientRestService {

    global class PatientInfo {
        public String id;
        public String patientId;
        public String fullName;
        public Date dateOfBirth;
        public Integer age;
        public String ageGroup;
        public String bloodGroup;
        public String email;
        public String phone;
        public String emergencyContact;
        public String insuranceProvider;
        public List<AppointmentInfo> appointments = new List<AppointmentInfo>();
    }

    global class AppointmentInfo {
        public String appointmentId;
        public Datetime slot;
        public String status;
        public String doctor;
    }

    @HttpGet
    global static void getPatient() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // The id is the last part of /services/apexrest/HMS/patient/{id}
        String key = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        if (String.isBlank(key) || key == 'patient') {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => 'A patient ID is required: /HMS/patient/{id}'
            }));
            return;
        }

        List<Patient__c> patients = [
            SELECT Id, Name, Full_Name__c, DOB__c, Age__c, Blood_Group__c, Email__c, Phone__c,
                   Emergency_Contact__c, Insurance_Provider__c,
                   (SELECT Id, Name, Slot__c, Status__c, Doctor__r.Name
                    FROM Appointments__r ORDER BY Slot__c DESC LIMIT 10)
            FROM Patient__c
            WHERE Id = :key OR Name = :key
            LIMIT 1
        ];

        if (patients.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => 'Patient not found: ' + key
            }));
            return;
        }

        Patient__c p = patients[0];
        PatientInfo info = new PatientInfo();
        info.id = p.Id;
        info.patientId = p.Name;
        info.fullName = p.Full_Name__c;
        info.dateOfBirth = p.DOB__c;
        info.age = p.Age__c == null ? null : Integer.valueOf(p.Age__c);
        info.ageGroup = p.DOB__c == null ? null : PatientService.calculateAgeGroup(p.DOB__c);
        info.bloodGroup = p.Blood_Group__c;
        info.email = p.Email__c;
        info.phone = p.Phone__c;
        info.emergencyContact = p.Emergency_Contact__c;
        info.insuranceProvider = p.Insurance_Provider__c;

        for (Appointment__c a : p.Appointments__r) {
            AppointmentInfo ai = new AppointmentInfo();
            ai.appointmentId = a.Name;
            ai.slot = a.Slot__c;
            ai.status = a.Status__c;
            ai.doctor = a.Doctor__r == null ? null : a.Doctor__r.Name;
            info.appointments.add(ai);
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(info));
    }
}