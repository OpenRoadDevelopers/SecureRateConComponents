@RestResource(urlMapping='/api/highway/ratecon')
global with sharing class HighwayRateConWeb {
	@HttpPost
    global static void updateRateConStatus(){
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(body);
        String status = (String) bodyMap.get('status');
        if(status != 'accepted' && status != 'viewed' && status != 'cancelled' && status != 'rejected'){
            return;
        }
        String external_load_id = (String) bodyMap.get('external_load_id');
        rtms__Load__c loadRecord = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Updated__c FROM rtms__Load__c WHERE Id = :external_load_id LIMIT 1];
        loadRecord.Secure_Rate_Con_Status__c = status;
        loadRecord.Secure_Rate_Con_Last_Updated__c = System.now();
        update loadRecord;
    }
}