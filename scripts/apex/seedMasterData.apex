Boolean dryRun = false;

System.assertEquals(
    '00Dg500000N7NYvEAN',
    UserInfo.getOrganizationId(),
    'Wrong destination organization!'
);

Savepoint sp = Database.setSavepoint();

try {
    List<String> specialties = new List<String>{
        'Cardiology',
        'Neurology',
        'Orthopedics',
        'Pediatrics',
        'General Medicine'
    };

    List<Integer> occupancy = new List<Integer>{
        65, 48, 72, 35, 80
    };

    List<String> doctorNames = new List<String>{
        'Dr. Aarav Sharma',
        'Dr. Meera Kapoor',
        'Dr. Rohan Mehta',
        'Dr. Ananya Verma',
        'Dr. Vikram Joshi',
        'Dr. Kavya Patel',
        'Dr. Aditya Desai',
        'Dr. Priya Shah',
        'Dr. Arjun Gupta',
        'Dr. Neha Kulkarni'
    };

    Set<String> departmentNames = new Set<String>();

    for (String specialty : specialties) {
        departmentNames.add('HMS-DEMO ' + specialty);
    }

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Department__c
         WHERE Name IN :departmentNames],
        'Demo departments already exist. Stopping.'
    );

    Set<String> licenses = new Set<String>();

    for (Integer i = 0; i < 10; i++) {
        licenses.add('MCI-' + String.valueOf(910001 + i));
    }

    System.assertEquals(
        0,
        [SELECT COUNT() FROM Doctor__c
         WHERE License_No__c IN :licenses],
        'Demo doctor licenses already exist. Stopping.'
    );

    List<Department__c> departments =
        new List<Department__c>();

    for (Integer i = 0; i < specialties.size(); i++) {

        departments.add(new Department__c(
            Name = 'HMS-DEMO ' + specialties[i],
            Bed_Count__c = 100,
            Floor__c = i + 1,
            Occupied_Beds__c = occupancy[i]
        ));
    }

    insert departments;

    List<Doctor__c> doctors = new List<Doctor__c>();

    for (Integer i = 0; i < departments.size(); i++) {

        for (Integer j = 0; j < 2; j++) {

            Integer idx = i * 2 + j;

            doctors.add(new Doctor__c(
                Name = 'HMS-DEMO ' + doctorNames[idx],
                Department__c = departments[i].Id,
                Specialization__c = specialties[i],
                License_No__c =
                    'MCI-' + String.valueOf(910001 + idx),
                Availability__c =
                    'Morning;Afternoon;Evening',
                Status__c = 'Active',
                Active_Appointments__c = 0
            ));
        }
    }

    insert doctors;

    List<Doctor__c> juniorDoctors =
        new List<Doctor__c>();

    for (Integer i = 0; i < departments.size(); i++) {

        departments[i].HOD__c = doctors[i * 2].Id;

        juniorDoctors.add(new Doctor__c(
            Id = doctors[i * 2 + 1].Id,
            Manager__c = doctors[i * 2].Id
        ));
    }

    update departments;
    update juniorDoctors;

    System.debug('DEPARTMENTS CREATED: ' +
        departments.size());

    System.debug('DOCTORS CREATED: ' +
        doctors.size());

    if (dryRun) {
        Database.rollback(sp);
        System.debug('DRY RUN SUCCESS - RECORDS ROLLED BACK');
    } else {
        System.debug('SEED SUCCESS - RECORDS SAVED');
    }

} catch (Exception e) {

    Database.rollback(sp);

    System.debug('SEED FAILED: ' + e.getMessage());

    throw e;
}


