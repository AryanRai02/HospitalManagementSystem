Boolean dryRun = false;

System.assertEquals(
    '00Dg500000N7NYvEAN',
    UserInfo.getOrganizationId(),
    'Wrong destination organization!'
);

Savepoint sp = Database.setSavepoint();

try {

    List<String> patientNames = new List<String>{
        'Aarav Malhotra',
        'Ananya Singh',
        'Vivaan Shah',
        'Diya Sharma',
        'Aditya Verma',
        'Isha Gupta',
        'Kabir Patel',
        'Meera Joshi',
        'Rohan Desai',
        'Kavya Mehta',
        'Arjun Kulkarni',
        'Saanvi Kapoor',
        'Rahul Sinha',
        'Priya Rao',
        'Dev Agarwal',
        'Neha Mishra',
        'Reyansh Jain',
        'Aditi Nair',
        'Rudra Pandey',
        'Riya Bansal'
    };

    List<String> bloodGroups = new List<String>{
        'A+', 'B+', 'O+', 'AB+',
        'A-', 'B-', 'O-', 'AB-'
    };

    List<String> departments = new List<String>{
        'Cardiology',
        'Neurology',
        'Orthopedics'
    };

    List<String> insuranceProviders = new List<String>{
        'Demo Health Insurance',
        'Demo Medical Assurance',
        'Demo Family Healthcare'
    };

    Set<String> names = new Set<String>();

    for (String patientName : patientNames) {
        names.add('HMS-DEMO ' + patientName);
    }

    System.assertEquals(
        0,
        [SELECT COUNT()
         FROM Patient__c
         WHERE Full_Name__c IN :names],
        'Demo patients already exist. Stopping.'
    );

    Map<String, Schema.RecordTypeInfo> recordTypes =
        Patient__c.SObjectType.getDescribe()
        .getRecordTypeInfosByDeveloperName();

    List<Patient__c> patients = new List<Patient__c>();

    for (Integer i = 0; i < patientNames.size(); i++) {

        Patient__c patient = new Patient__c(
            Full_Name__c = 'HMS-DEMO ' + patientNames[i],
            DOB__c = Date.today().addYears(-(8 + i * 3)),
            Blood_Group__c = bloodGroups[Math.mod(i, 8)],
            Department__c = departments[Math.mod(i, 3)],
            Insurance_Provider__c =
                insuranceProviders[Math.mod(i, 3)],
            Insurance_Policy_Number__c =
                'DEMO-POL-' + String.valueOf(1001 + i),
            Total_Appointments__c = 0,
            Total_Billed_Amount__c = 0
        );

        String rtName = 'Outpatient';

        if (i >= 12 && i < 17) {
            rtName = 'Inpatient';
        } else if (i >= 17) {
            rtName = 'Emergency';
        }

        Schema.RecordTypeInfo rt = recordTypes.get(rtName);

        System.assert(
            rt != null && rt.isAvailable(),
            'Record type unavailable: ' + rtName
        );

        patient.RecordTypeId = rt.getRecordTypeId();

        patients.add(patient);
    }

    insert patients;

    System.debug('PATIENTS CREATED: ' + patients.size());

    if (dryRun) {
        Database.rollback(sp);
        System.debug('DRY RUN SUCCESS - RECORDS ROLLED BACK');
    } else {
        System.debug('SEED SUCCESS - PATIENTS SAVED');
    }

} catch (Exception e) {

    Database.rollback(sp);
    System.debug('SEED FAILED: ' + e.getMessage());
    throw e;
}

