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
            String externalLoadId = (String) bodyMap.get('external_load_id');
            rtms__CarrierQuote__c cq = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c, Secure_Rate_Con_Cancelled_Rejected__c, name FROM rtms__CarrierQuote__c WHERE Id = :external_id LIMIT 1];
            if(cq == null){
                String emailBody = 'Highway Webhook Carrier Quote not found for external_id: ' + external_id
                + '\nstatus: ' + status
                + '\nexternal_id: ' + external_id
                + '\n\nResponse: ' + body;
                
                SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'Highway Webhook Carrier Quote not found', body, false);
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => false, 'error' => 'Carrier Quote not found for external_id: ' + external_id }));
                return;
            }
            cq.Secure_Rate_Con_Status__c = status;
            cq.Secure_Rate_Con_Last_Update__c = System.now();
            if(status == 'rejected' && cq.Secure_Rate_Con_Cancelled_Rejected__c == null){
                cq.Secure_Rate_Con_Cancelled_Rejected__c = Datetime.now();
            }
            update cq;
            if(status == 'rejected'){
                rtms__Load__c load = [SELECT name, rtms__Carrier_Sales_Rep__c, rtms__Carrier_Sales_Rep__r.email FROM rtms__Load__c WHERE Id = :externalLoadId LIMIT 1];
                List<Object> activities = (List<Object>) bodyMap.get('recent_rate_confirmation_activities');
                String notifyEmail;
                if (activities != null) {
                    for (Object a : activities) {
                        Map<String,Object> act = (Map<String,Object>) a;
                        String type = (String) act.get('is_type');
                        if (type == 'delivered') {
                            Map<String,Object> user = (Map<String,Object>) act.get('user');
                            notifyEmail = (String) user.get('email');
                            break;
                        }
                    }
                }
                if (notifyEmail == null) {
                    notifyEmail = (load != null && load.rtms__Carrier_Sales_Rep__r != null && load.rtms__Carrier_Sales_Rep__r.email != null)
                        ? load.rtms__Carrier_Sales_Rep__r.email
                        : 'IT@openroad.inc';
                }
                Map<String,Object> carrier = (Map<String,Object>) bodyMap.get('carrier');
                String carrierName = (carrier != null) ? (String) carrier.get('name') : null;
                String base = URL.getOrgDomainUrl().toExternalForm();
                String loadRecordUrl = base + '/' + externalLoadId;
                String cqRecordUrl = base + '/' + external_id;
                String htmlBody = '<p>Carrier ' + carrierName + ' rejected the Secure Rate Con in Highway</p>'
                    + '<p>Load: <a href="' + loadRecordUrl + '">' + load.Name + '</a></p>'
                    + '<p>Carrier Quote: <a href="' + cqRecordUrl + '">' + cq.Name + '</a></p>';
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { notifyEmail });
                mail.setSubject('Carrier ' + carrierName + ' rejected the Secure Rate Con in Highway');
                mail.setHtmlBody(htmlBody);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => true }));
        }
        catch(Exception e){
            String emailBody = 'Highway Webhook failed'
                + '\nResponse: ' + body
                + '\n\nException: ' + e.getMessage() + '<br>Stack Trace: ' + e.getStackTraceString();
            SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'Highway Webhook Error', body, false);
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{ 'success' => false, 'error' => e.getMessage() }));
        }
    }
}