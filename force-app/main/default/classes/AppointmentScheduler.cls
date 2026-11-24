public with sharing class AppointmentScheduler {

    private static final Integer FIRST_HOUR = 8;
    private static final Integer LAST_HOUR = 19; // last slot starts at 7 PM and ends at 8 PM
    private static final Integer MAX_RANGE_DAYS = 31;

    // Free hourly slots for a doctor between two dates (8 AM to 8 PM)
    @AuraEnabled
    public static List<Datetime> findAvailableSlots(Id doctorId, Date startDate, Date endDate) {
        if (doctorId == null || startDate == null || endDate == null) {
            throw new HospitalException('Doctor, start date and end date are required.');
        }
        if (endDate < startDate) {
            throw new HospitalException('End date cannot be before start date.');
        }
        if (startDate.daysBetween(endDate) > MAX_RANGE_DAYS) {
            throw new HospitalException('Please search a range of 31 days or less.');
        }

        List<Doctor__c> doctors = [SELECT Id, Status__c FROM Doctor__c WHERE Id = :doctorId LIMIT 1];
        if (doctors.isEmpty() || doctors[0].Status__c == 'Inactive') {
            return new List<Datetime>();
        }

        Datetime rangeStart = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime rangeEnd = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        // One query for the whole range
        Set<Long> booked = new Set<Long>();
        for (Appointment__c appt : [
            SELECT Slot__c
            FROM Appointment__c
            WHERE Doctor__c = :doctorId
              AND Slot__c >= :rangeStart
              AND Slot__c < :rangeEnd
              AND (Status__c != 'Cancelled' OR Status__c = null)
        ]) {
            booked.add(appt.Slot__c.getTime());
        }

        List<Datetime> available = new List<Datetime>();
        Datetime now = System.now();
        Date current = startDate;
        while (current <= endDate) {
            for (Integer hour = FIRST_HOUR; hour <= LAST_HOUR; hour++) {
                Datetime slot = Datetime.newInstance(current, Time.newInstance(hour, 0, 0, 0));
                if (slot > now && !booked.contains(slot.getTime())) {
                    available.add(slot);
                }
            }
            current = current.addDays(1);
        }
        return available;
    }
}