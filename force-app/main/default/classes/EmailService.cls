public without sharing class EmailService {

    private static final String SENDER_ADDRESS = 'notifications@example.com';

    private static Id getSenderId() {
        List<OrgWideEmailAddress> senders = [
            SELECT Id FROM OrgWideEmailAddress WHERE Address = :SENDER_ADDRESS LIMIT 1
        ];
        return senders.isEmpty() ? null : senders[0].Id;
    }

    private static void send(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) {
            return;
        }
        List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false);
        for (Messaging.SendEmailResult r : results) {
            if (!r.isSuccess()) {
                for (Messaging.SendEmailError e : r.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Email failed: ' + e.getMessage());
                }
            }
        }
    }

    private static Messaging.SingleEmailMessage buildMail(
        Id senderId, List<String> to, String subject, String body
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (senderId != null) {
            mail.setOrgWideEmailAddressId(senderId);
        }
        mail.setToAddresses(to);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);
        return mail;
    }

    // Used by AppointmentTriggerHandler
    public static void sendCancellationEmails(Set<Id> appointmentIds) {
        Id senderId = getSenderId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Appointment__c appt : [
            SELECT Id, Slot__c, Patient__r.Email__c, Patient__r.Full_Name__c
            FROM Appointment__c
            WHERE Id IN :appointmentIds AND Patient__r.Email__c != null
        ]) {
            String patientName = String.isBlank(appt.Patient__r.Full_Name__c)
                ? 'Patient' : appt.Patient__r.Full_Name__c;
            String slotText = appt.Slot__c == null
                ? '' : ' scheduled for ' + appt.Slot__c.format('dd MMM yyyy, hh:mm a');
            String body = 'Dear ' + patientName + ',\n\n'
                + 'Your appointment' + slotText + ' at MedCare Hospital has been cancelled.\n'
                + 'Please contact us to book a new slot.\n\n'
                + 'Thank you,\nMedCare Hospital';
            emails.add(buildMail(senderId, new List<String>{ appt.Patient__r.Email__c },
                'Your appointment has been cancelled', body));
        }
        send(emails);
    }

    // Replaces {{Key}} placeholders in a template with the supplied values
    public static String renderTemplate(String template, Map<String, String> values) {
        if (String.isBlank(template)) {
            return '';
        }
        String result = template;
        if (values != null) {
            for (String key : values.keySet()) {
                String value = values.get(key) == null ? '' : values.get(key);
                result = result.replace('{{' + key + '}}', value);
            }
        }
        return result;
    }

    // Generic reusable sender (patients, doctors, or any address list)
    public static void sendEmail(List<String> toAddresses, String subject, String body) {
        if (toAddresses == null || toAddresses.isEmpty()) {
            throw new HospitalException('At least one recipient is required.');
        }
        send(new List<Messaging.SingleEmailMessage>{
            buildMail(getSenderId(), toAddresses, subject, body)
        });
    }

    // Templated email to many patients; {{Name}} and {{PatientId}} are merged
    public static void sendPatientEmails(Set<Id> patientIds, String subject, String bodyTemplate) {
        Id senderId = getSenderId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Patient__c p : [
            SELECT Id, Name, Full_Name__c, Email__c
            FROM Patient__c
            WHERE Id IN :patientIds AND Email__c != null
        ]) {
            Map<String, String> values = new Map<String, String>{
                'Name' => String.isBlank(p.Full_Name__c) ? 'Patient' : p.Full_Name__c,
                'PatientId' => p.Name
            };
            emails.add(buildMail(senderId, new List<String>{ p.Email__c },
                subject, renderTemplate(bodyTemplate, values)));
        }
        send(emails);
    }

    // Templated email to doctors; {{Name}} is merged. Doctors have no email field in the
    // data model, so the caller passes the addresses.
    public static void sendDoctorEmail(List<String> doctorAddresses, String subject, String body) {
        sendEmail(doctorAddresses, subject, body);
    }
}