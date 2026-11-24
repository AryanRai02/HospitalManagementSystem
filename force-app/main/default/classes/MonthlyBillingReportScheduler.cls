public with sharing class MonthlyBillingReportScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new MonthlyBillingReport(), 200);
    }
}