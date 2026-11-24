@IsTest
public class TestDataFactory {

    private static Integer sequence = 0;

    private static Integer nextSequence() {
        sequence++;
        return sequence;
    }

    // Sets Name only when it is a writable text field (not an auto-number)
    private static void setName(SObject record, String value) {
        Schema.DescribeFieldResult nameField =
            record.getSObjectType().getDescribe().fields.getMap().get('Name').getDescribe();
        if (!nameField.isAutoNumber() && nameField.isCreateable()) {
            record.put('Name', value);
        }
    }

    // A slot in the user's local time (India time in this org)
    public static Datetime futureSlot(Integer daysAhead, Integer hour) {
        return Datetime.newInstance(Date.today().addDays(daysAhead), Time.newInstance(hour, 0, 0, 0));
    }

    public static Department__c createDepartment(String name) {
        Department__c dept = new Department__c(Floor__c = 2, Bed_Count__c = 40);
        setName(dept, name);
        insert dept;
        return dept;
    }

    public static Doctor__c createDoctor(Id departmentId, String status) {
        Integer n = nextSequence();
        Doctor__c doc = new Doctor__c(
            License_No__c = 'MCI-' + String.valueOf(100000 + n),
            Department__c = departmentId,
            Status__c = status,
            Active_Appointments__c = 0
        );
        setName(doc, 'Dr. Test ' + n);
        insert doc;
        return doc;
    }

    public static Patient__c createPatient(String fullName, String email) {
        Patient__c pat = new Patient__c(
            DOB__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = fullName,
            Email__c = email
        );
        insert pat;
        return pat;
    }

    public static Appointment__c buildAppointment(Id patientId, Id doctorId, Datetime slot, String status) {
        Appointment__c appt = new Appointment__c(
            Patient__c = patientId,
            Doctor__c = doctorId,
            Slot__c = slot,
            Status__c = status
        );
        setName(appt, 'Appt ' + nextSequence());
        return appt;
    }

    public static Appointment__c createAppointment(Id patientId, Id doctorId, Datetime slot, String status) {
        Appointment__c appt = buildAppointment(patientId, doctorId, slot, status);
        insert appt;
        return appt;
    }

    public static Billing__c createBilling(Id appointmentId, Id patientId, Decimal amount, String status) {
        Billing__c bill = new Billing__c(
            Appointment__c = appointmentId,
            Patient__c = patientId,
            Amount_Due__c = amount,
            Insurance_Amount__c = 0,
            Status__c = status
        );
        setName(bill, 'Bill ' + nextSequence());
        insert bill;
        return bill;
    }

    public static List<Medical_Record__c> createMedicalRecords(Id patientId, Integer count) {
        List<Medical_Record__c> records = new List<Medical_Record__c>();
        for (Integer i = 0; i < count; i++) {
            Medical_Record__c rec = new Medical_Record__c(Patient__c = patientId, Diagnosis__c = 'Test diagnosis');
            setName(rec, 'Record ' + nextSequence());
            records.add(rec);
        }
        insert records;
        return records;
    }
}