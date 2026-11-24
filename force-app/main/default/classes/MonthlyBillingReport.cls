public with sharing class MonthlyBillingReport implements Database.Batchable<SObject>, Database.Stateful {

    // Running totals across batches (Database.Stateful keeps them)
    private Decimal totalBilled = 0;
    private Decimal totalInsurance = 0;
    private Integer billCount = 0;
    private Map<String, Decimal> totalsByStatus = new Map<String, Decimal>();

    private final Date periodStart;
    private final Date periodEnd;

    public MonthlyBillingReport() {
        // Previous calendar month
        Date firstOfThisMonth = Date.today().toStartOfMonth();
        this.periodEnd = firstOfThisMonth.addDays(-1);
        this.periodStart = firstOfThisMonth.addMonths(-1);
    }
    // Lets you run the report for any period (used for testing and ad hoc reports)
	public MonthlyBillingReport(Date startDate, Date endDate) {
    this.periodStart = startDate;
    this.periodEnd = endDate;
}

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Amount_Due__c, Insurance_Amount__c, Status__c
            FROM Billing__c
            WHERE CreatedDate >= :periodStart
              AND CreatedDate < :periodEnd.addDays(1)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Billing__c> scope) {
        for (Billing__c bill : scope) {
            Decimal due = bill.Amount_Due__c == null ? 0 : bill.Amount_Due__c;
            Decimal insurance = bill.Insurance_Amount__c == null ? 0 : bill.Insurance_Amount__c;
            totalBilled += due;
            totalInsurance += insurance;
            billCount++;

            String status = String.isBlank(bill.Status__c) ? 'No status' : bill.Status__c;
            Decimal current = totalsByStatus.containsKey(status) ? totalsByStatus.get(status) : 0;
            totalsByStatus.put(status, current + due);
        }
    }

    public void finish(Database.BatchableContext bc) {
        String body = 'Monthly Billing Report - MedCare Hospital\n'
            + 'Period: ' + periodStart.format() + ' to ' + periodEnd.format() + '\n\n'
            + 'Total bills: ' + billCount + '\n'
            + 'Total amount due: Rs. ' + totalBilled.setScale(2) + '\n'
            + 'Total insurance amount: Rs. ' + totalInsurance.setScale(2) + '\n\n'
            + 'Amount due by status:\n';
        for (String status : totalsByStatus.keySet()) {
            body += ' - ' + status + ': Rs. ' + totalsByStatus.get(status).setScale(2) + '\n';
        }

        // The data model has no Finance team record, so the recipient is a custom label
        // you can change without code. Falls back to the running user.
        String recipient = UserInfo.getUserEmail();
        try {
            recipient = Label.Finance_Team_Email;
        } catch (Exception e) {
            // label not created: keep the fallback
        }
        EmailService.sendEmail(
            new List<String>{ recipient },
            'Monthly Billing Report',
            body
        );
    }

       // Schedules the report for 2:00 AM on the 1st of every month
    public static String scheduleMonthly() {
        return scheduleMonthly('Monthly Billing Report');
    }

    // Same schedule with a custom job name (a job name must be unique, so tests use their own)
    public static String scheduleMonthly(String jobName) {
        return System.schedule(
            jobName,
            '0 0 2 1 * ?',
            new MonthlyBillingReportScheduler()
        );
    }
}