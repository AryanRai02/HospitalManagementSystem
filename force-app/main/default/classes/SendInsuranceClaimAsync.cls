public with sharing class SendInsuranceClaimAsync {

    @future(callout=true)
    public static void submitClaim(Id billingId) {
        List<Billing__c> bills = [
            SELECT Id, Amount_Due__c, Insurance__c, Insurance_Amount__c, Patient__r.Name
            FROM Billing__c
            WHERE Id = :billingId
            LIMIT 1
        ];
        if (bills.isEmpty()) {
            return;
        }
        Billing__c bill = bills[0];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:LabSystem_NC/insurance/claims'); // Named Credential, created in 6.5
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'billingId' => bill.Id,
            'patient' => bill.Patient__r.Name,
            'provider' => bill.Insurance__c,
            'claimAmount' => bill.Insurance_Amount__c
        }));

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                bill.Claim_Submitted__c = true;
                bill.Claim_Reference__c = res.getBody().left(255);
                update bill;
            } else {
                System.debug(LoggingLevel.ERROR, 'Claim failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (CalloutException e) {
            System.debug(LoggingLevel.ERROR, 'Claim callout failed: ' + e.getMessage());
        }
    }
}