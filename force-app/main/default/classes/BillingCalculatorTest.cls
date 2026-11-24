@IsTest(SeeAllData=false)
private class BillingCalculatorTest {

    private static void assertDecimal(Decimal expected, Decimal actual, String message) {
        System.assertEquals(expected.setScale(2), actual.setScale(2), message);
    }

    private static Boolean throwsHospitalException(List<Decimal> charges, Decimal discount, Decimal coverage) {
        try {
            BillingCalculator.calculate(charges, discount, coverage);
        } catch (HospitalException e) {
            return true;
        }
        return false;
    }

    @IsTest
    static void standardBillWithDiscountAndInsurance() {
        Test.startTest();
        BillingCalculator.BillResult r = BillingCalculator.calculate(new List<Decimal>{ 500, 1500 }, 10, 50);
        Test.stopTest();

        assertDecimal(2000, r.subtotal, 'subtotal');
        assertDecimal(200, r.discountAmount, 'discount');
        assertDecimal(900, r.insuranceCoverage, 'insurance');
        assertDecimal(900, r.amountDue, 'amount due');
    }

    @IsTest
    static void zeroProceduresGivesZeroBill() {
        Test.startTest();
        BillingCalculator.BillResult emptyList = BillingCalculator.calculate(new List<Decimal>(), 10, 10);
        BillingCalculator.BillResult nullList = BillingCalculator.calculate(null, 10, 10);
        Test.stopTest();

        assertDecimal(0, emptyList.amountDue, 'empty list');
        assertDecimal(0, nullList.amountDue, 'null list');
    }

    @IsTest
    static void nullChargesAreIgnored() {
        BillingCalculator.BillResult r = BillingCalculator.calculate(new List<Decimal>{ 1000, null }, 0, 0);
        assertDecimal(1000, r.amountDue, 'null charge ignored');
    }

    @IsTest
    static void nullDiscountAndCoverageCountAsZero() {
        BillingCalculator.BillResult r = BillingCalculator.calculate(new List<Decimal>{ 800 }, null, null);
        assertDecimal(800, r.amountDue, 'no discount or insurance');
    }

    @IsTest
    static void discountIsCappedAtTheMaximum() {
        BillingCalculator.BillResult r = BillingCalculator.calculate(new List<Decimal>{ 1000 }, 80, 0);
        assertDecimal(500, r.discountAmount, '80% is capped at 50%');
        assertDecimal(500, r.amountDue, 'amount due after the cap');
    }

    @IsTest
    static void fullInsuranceCoverageLeavesNothingToPay() {
        BillingCalculator.BillResult r = BillingCalculator.calculate(new List<Decimal>{ 2000 }, 0, 100);
        assertDecimal(2000, r.insuranceCoverage, 'insurance');
        assertDecimal(0, r.amountDue, 'amount due');
    }

    @IsTest
    static void invalidInputsThrowHospitalException() {
        System.assert(throwsHospitalException(new List<Decimal>{ 100 }, -5, 0), 'negative discount');
        System.assert(throwsHospitalException(new List<Decimal>{ 100 }, 0, 101), 'coverage above 100');
        System.assert(throwsHospitalException(new List<Decimal>{ 100 }, 0, -1), 'negative coverage');
        System.assert(throwsHospitalException(new List<Decimal>{ -100 }, 0, 0), 'negative charge');
    }

    @IsTest
    static void applyToBillingWritesTheFields() {
        Billing__c bill = new Billing__c();
        BillingCalculator.applyToBilling(bill, new List<Decimal>{ 1000, 1000 }, 0, 25);

        assertDecimal(1500, bill.Amount_Due__c, 'Amount_Due__c');
        assertDecimal(500, bill.Insurance_Amount__c, 'Insurance_Amount__c');
    }
}