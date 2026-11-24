public with sharing class BillingCalculator {

    public static final Decimal MAX_DISCOUNT_PERCENT = 50;

    public class BillResult {
        public Decimal subtotal = 0;
        public Decimal discountAmount = 0;
        public Decimal insuranceCoverage = 0;
        public Decimal amountDue = 0;
    }

    // Pure calculation, no DML, so it is easy to test
    public static BillResult calculate(
        List<Decimal> procedureCharges,
        Decimal discountPercent,
        Decimal insuranceCoveragePercent
    ) {
        Decimal discount = discountPercent == null ? 0 : discountPercent;
        Decimal coverage = insuranceCoveragePercent == null ? 0 : insuranceCoveragePercent;

        if (discount < 0 || coverage < 0 || coverage > 100) {
            throw new HospitalException(
                'Discount must be 0 or more, and insurance coverage must be between 0 and 100.'
            );
        }
        discount = Math.min(discount, MAX_DISCOUNT_PERCENT);

        BillResult result = new BillResult();
        if (procedureCharges != null) {
            for (Decimal charge : procedureCharges) {
                if (charge == null) {
                    continue;
                }
                if (charge < 0) {
                    throw new HospitalException('Procedure charges cannot be negative.');
                }
                result.subtotal += charge;
            }
        }

        result.discountAmount = (result.subtotal * discount / 100).setScale(2);
        Decimal afterDiscount = result.subtotal - result.discountAmount;
        result.insuranceCoverage = (afterDiscount * coverage / 100).setScale(2);
        result.amountDue = (afterDiscount - result.insuranceCoverage).setScale(2);
        return result;
    }

    // Writes the result onto a Billing record (the caller does the DML)
    public static void applyToBilling(
        Billing__c bill,
        List<Decimal> procedureCharges,
        Decimal discountPercent,
        Decimal insuranceCoveragePercent
    ) {
        BillResult result = calculate(procedureCharges, discountPercent, insuranceCoveragePercent);
        bill.Amount_Due__c = result.amountDue;
bill.Insurance_Amount__c = result.insuranceCoverage;    }
}