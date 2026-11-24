global with sharing class DailyAppointmentReminder implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new AppointmentReminderBatch(), 100);
    }

    // Schedules the job for 6:00 AM every day
    public static String scheduleDaily() {
        return System.schedule('Daily Appointment Reminder', '0 0 6 * * ?', new DailyAppointmentReminder());
    }
}