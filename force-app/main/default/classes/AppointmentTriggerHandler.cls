public with sharing class AppointmentTriggerHandler {

    private static final String STATUS_CANCELLED = 'Cancelled';

    // ---------- BEFORE ----------

    public static void beforeInsert(List<Appointment__c> newList) {
        validateNotInPast(newList, null);
        checkDoctorConflicts(newList, null);
    }

    public static void beforeUpdate(List<Appointment__c> newList, Map<Id, Appointment__c> oldMap) {
        validateNotInPast(newList, oldMap);
        checkDoctorConflicts(newList, oldMap);
    }

    // Runs only when the slot is new or changed, so status updates on older
    // appointments (for example Completed) are not blocked.
    private static void validateNotInPast(List<Appointment__c> newList, Map<Id, Appointment__c> oldMap) {
        for (Appointment__c appt : newList) {
            if (appt.Slot__c == null) {
                continue;
            }
            Boolean slotChanged = oldMap == null || appt.Slot__c != oldMap.get(appt.Id).Slot__c;
            if (slotChanged && appt.Slot__c < System.now()) {
                appt.Slot__c.addError('Appointment date cannot be in the past.');
            }
        }
    }

    // The same doctor cannot have two non-cancelled appointments at the same slot,
    // including inside the same batch.
    private static void checkDoctorConflicts(List<Appointment__c> newList, Map<Id, Appointment__c> oldMap) {
        List<Appointment__c> toCheck = new List<Appointment__c>();
        Set<Id> doctorIds = new Set<Id>();
        Set<Datetime> slots = new Set<Datetime>();

        for (Appointment__c appt : newList) {
            if (appt.Doctor__c == null || appt.Slot__c == null || appt.Status__c == STATUS_CANCELLED) {
                continue;
            }
            if (oldMap != null) {
                Appointment__c oldAppt = oldMap.get(appt.Id);
                Boolean unchanged = appt.Doctor__c == oldAppt.Doctor__c
                    && appt.Slot__c == oldAppt.Slot__c
                    && oldAppt.Status__c != STATUS_CANCELLED;
                if (unchanged) {
                    continue;
                }
            }
            toCheck.add(appt);
            doctorIds.add(appt.Doctor__c);
            slots.add(appt.Slot__c);
        }

        if (toCheck.isEmpty()) {
            return;
        }

        Set<Id> selfIds = oldMap == null ? new Set<Id>() : oldMap.keySet();
        Set<String> booked = new Set<String>();

        // One query, outside any loop
        for (Appointment__c existing : [
            SELECT Id, Doctor__c, Slot__c
            FROM Appointment__c
            WHERE Doctor__c IN :doctorIds
              AND Slot__c IN :slots
              AND (Status__c != :STATUS_CANCELLED OR Status__c = null)
        ]) {
            if (!selfIds.contains(existing.Id)) {
                booked.add(slotKey(existing.Doctor__c, existing.Slot__c));
            }
        }

        for (Appointment__c appt : toCheck) {
            String key = slotKey(appt.Doctor__c, appt.Slot__c);
            if (booked.contains(key)) {
                appt.addError('This doctor is already booked for the selected slot.');
            } else {
                booked.add(key);
            }
        }
    }

    private static String slotKey(Id doctorId, Datetime slot) {
        return doctorId + '|' + slot.getTime();
    }

    // ---------- AFTER ----------

    public static void afterInsert(List<Appointment__c> newList) {
        createConfirmationTasks(newList);
    }

    public static void afterUpdate(List<Appointment__c> newList, Map<Id, Appointment__c> oldMap) {
        Set<Id> cancelledIds = new Set<Id>();
        Map<Id, Integer> counterChange = new Map<Id, Integer>();

        for (Appointment__c appt : newList) {
            Appointment__c oldAppt = oldMap.get(appt.Id);
            if (appt.Status__c == STATUS_CANCELLED && oldAppt.Status__c != STATUS_CANCELLED) {
                cancelledIds.add(appt.Id);
                // Cancelling frees the doctor's slot: lower the workload counter
                if (appt.Doctor__c != null) {
                    addChange(counterChange, appt.Doctor__c, -1);
                }
            }
        }

        adjustDoctorCounters(counterChange);

        if (!cancelledIds.isEmpty()) {
            EmailService.sendCancellationEmails(cancelledIds);
        }
    }

    public static void afterDelete(List<Appointment__c> oldList) {
        Map<Id, Integer> counterChange = new Map<Id, Integer>();
        for (Appointment__c appt : oldList) {
            // Cancelled appointments were already subtracted when cancelled
            if (appt.Doctor__c != null && appt.Status__c != STATUS_CANCELLED) {
                addChange(counterChange, appt.Doctor__c, -1);
            }
        }
        adjustDoctorCounters(counterChange);
    }

    // ---------- HELPERS ----------

    private static void createConfirmationTasks(List<Appointment__c> newList) {
        Id ownerId = getReceptionistUserId();
        List<Task> tasks = new List<Task>();
        for (Appointment__c appt : newList) {
            tasks.add(new Task(
                WhatId = appt.Id,
                OwnerId = ownerId,
                Subject = 'Confirm appointment with patient by phone',
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(1)
            ));
        }
        if (!tasks.isEmpty()) {
            insert tasks; // one DML for the whole batch
        }
    }

    private static Id getReceptionistUserId() {
        List<User> receptionists = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserRole.Name = 'Receptionist'
            LIMIT 1
        ];
        return receptionists.isEmpty() ? UserInfo.getUserId() : receptionists[0].Id;
    }

    private static void addChange(Map<Id, Integer> changes, Id doctorId, Integer delta) {
        Integer current = changes.containsKey(doctorId) ? changes.get(doctorId) : 0;
        changes.put(doctorId, current + delta);
    }

    private static void adjustDoctorCounters(Map<Id, Integer> changes) {
        if (changes.isEmpty()) {
            return;
        }
        List<Doctor__c> doctors = [
            SELECT Id, Active_Appointments__c
            FROM Doctor__c
            WHERE Id IN :changes.keySet()
        ];
        for (Doctor__c doc : doctors) {
            Decimal current = doc.Active_Appointments__c == null ? 0 : doc.Active_Appointments__c;
            doc.Active_Appointments__c = Math.max(0, current + changes.get(doc.Id));
        }
        update doctors;
    }
}