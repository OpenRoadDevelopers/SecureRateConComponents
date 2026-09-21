@RestResource(urlMapping='/api/highway/ratecon')
global with sharing class HighwayRateConWeb {
	@HttpPost
    global static void updateRateConStatus(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        try{
            Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(body);
            String status = (String) bodyMap.get('status');
            String external_id = (String) bodyMap.get('external_id');
            rtms__CarrierQuote__c cq = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c, Secure_Rate_Con_Cancelled_Rejected__c FROM rtms__CarrierQuote__c WHERE Id = :external_id LIMIT 1];
            if(cq == null){
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => false, 'error' => 'Carrier Quote not found for external_id: ' + external_id }));
                return;
            }
            cq.Secure_Rate_Con_Status__c = status;
            cq.Secure_Rate_Con_Last_Update__c = System.now();
            if(status == 'rejected' && cq.Secure_Rate_Con_Cancelled_Rejected__c == null){
                cq.Secure_Rate_Con_Cancelled_Rejected__c = Datetime.now();
            }
            update cq;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => true }));
        }
        catch(Exception e){
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => false, 'error' => e.getMessage() }));
        }
    }
}