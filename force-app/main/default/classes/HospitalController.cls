public with sharing class HospitalController {

    public class AppointmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime slot;
        @AuraEnabled public String status;
        @AuraEnabled public Id patientId;
        @AuraEnabled public String patientName;
    }

    public class TodayStats {
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer requested = 0;
        @AuraEnabled public Integer confirmed = 0;
        @AuraEnabled public Integer completed = 0;
        @AuraEnabled public Integer cancelled = 0;
    }

    public class RevenueSummary {
        @AuraEnabled public Decimal monthRevenue = 0;
        @AuraEnabled public Integer billCount = 0;
        @AuraEnabled public Integer pendingApprovals = 0;
    }

    public class DepartmentSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal bedCount;
        @AuraEnabled public Integer doctorCount = 0;
        @AuraEnabled public Integer appointmentsToday = 0;
    }

    private static Datetime startOf(Date day) {
        return Datetime.newInstance(day, Time.newInstance(0, 0, 0, 0));
    }

    // Used by doctorScheduleCard (wire)
    @AuraEnabled(cacheable=true)
    public static List<AppointmentRow> getAppointmentsByDoctor(Id doctorId, Date selectedDate) {
        List<AppointmentRow> rows = new List<AppointmentRow>();
        if (doctorId == null) {
            return rows;
        }
        Datetime dayStart = startOf(selectedDate == null ? Date.today() : selectedDate);
        Datetime dayEnd = dayStart.addDays(1);

        for (Appointment__c a : [
            SELECT Id, Name, Slot__c, Status__c, Patient__c, Patient__r.Full_Name__c, Patient__r.Name
            FROM Appointment__c
            WHERE Doctor__c = :doctorId AND Slot__c >= :dayStart AND Slot__c < :dayEnd
            ORDER BY Slot__c
        ]) {
            AppointmentRow row = new AppointmentRow();
            row.id = a.Id;
            row.name = a.Name;
            row.slot = a.Slot__c;
            row.status = a.Status__c;
            row.patientId = a.Patient__c;
            row.patientName = a.Patient__r == null ? null
                : (String.isBlank(a.Patient__r.Full_Name__c) ? a.Patient__r.Name : a.Patient__r.Full_Name__c);
            rows.add(row);
        }
        return rows;
    }

    // Used by appointmentForm (wire): doctors who can take bookings
    @AuraEnabled(cacheable=true)
    public static List<Doctor__c> getAvailableDoctors() {
        return [
            SELECT Id, Name, Specialization__c, Active_Appointments__c
            FROM Doctor__c
            WHERE Status__c = 'Active'
            ORDER BY Name
            LIMIT 200
        ];
    }

    // Used by hospitalDashboard (imperative calls, so refreshes get fresh data)
    @AuraEnabled
    public static TodayStats getTodayStats(Date selectedDate) {
        Datetime dayStart = startOf(selectedDate == null ? Date.today() : selectedDate);
        Datetime dayEnd = dayStart.addDays(1);

        TodayStats stats = new TodayStats();
        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) total
            FROM Appointment__c
            WHERE Slot__c >= :dayStart AND Slot__c < :dayEnd
            GROUP BY Status__c
        ]) {
            Integer count = (Integer) ar.get('total');
            String status = (String) ar.get('status');
            stats.total += count;
            if (status == 'Requested') {
                stats.requested += count;
            } else if (status == 'Confirmed') {
                stats.confirmed += count;
            } else if (status == 'Completed') {
                stats.completed += count;
            } else if (status == 'Cancelled') {
                stats.cancelled += count;
            }
        }
        return stats;
    }

    @AuraEnabled
    public static RevenueSummary getRevenueSummary() {
        Datetime monthStart = startOf(Date.today().toStartOfMonth());
        RevenueSummary summary = new RevenueSummary();

        AggregateResult total = [
            SELECT SUM(Amount_Due__c) revenue, COUNT(Id) bills
            FROM Billing__c
            WHERE CreatedDate >= :monthStart AND (Status__c != 'Rejected' OR Status__c = null)
        ];
        summary.monthRevenue = total.get('revenue') == null ? 0 : (Decimal) total.get('revenue');
        summary.billCount = (Integer) total.get('bills');
        summary.pendingApprovals = [SELECT COUNT() FROM Billing__c WHERE Status__c = 'Pending Approval'];
        return summary;
    }

    @AuraEnabled
    public static List<DepartmentSummary> getDepartmentSummary(Date selectedDate) {
        Datetime dayStart = startOf(selectedDate == null ? Date.today() : selectedDate);
        Datetime dayEnd = dayStart.addDays(1);

        Map<Id, DepartmentSummary> byId = new Map<Id, DepartmentSummary>();
        for (Department__c d : [SELECT Id, Name, Bed_Count__c FROM Department__c ORDER BY Name]) {
            DepartmentSummary s = new DepartmentSummary();
            s.id = d.Id;
            s.name = d.Name;
            s.bedCount = d.Bed_Count__c;
            byId.put(d.Id, s);
        }

        for (AggregateResult ar : [
            SELECT Department__c dept, COUNT(Id) doctors
            FROM Doctor__c
            WHERE Department__c != null
            GROUP BY Department__c
        ]) {
            DepartmentSummary s = byId.get((Id) ar.get('dept'));
            if (s != null) {
                s.doctorCount = (Integer) ar.get('doctors');
            }
        }

        for (AggregateResult ar : [
            SELECT Doctor__r.Department__c dept, COUNT(Id) appts
            FROM Appointment__c
            WHERE Slot__c >= :dayStart AND Slot__c < :dayEnd
              AND Doctor__r.Department__c != null
              AND (Status__c != 'Cancelled' OR Status__c = null)
            GROUP BY Doctor__r.Department__c
        ]) {
            DepartmentSummary s = byId.get((Id) ar.get('dept'));
            if (s != null) {
                s.appointmentsToday = (Integer) ar.get('appts');
            }
        }
        return byId.values();
    }
}