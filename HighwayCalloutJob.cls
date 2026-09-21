public class HighwayCalloutJob implements Queueable, Database.AllowsCallouts {
    private Id contentVersionId;
    private String fromWho;
    private String subject;
    private String loadId;
    private String highwayCarrierId;
    private List<String> recipients;
    private Id carrierQuoteId;
    private Boolean isCancel;

    public HighwayCalloutJob(Id contentVersionId, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id carrierQuoteId, Boolean isCancel) {
        this.contentVersionId = contentVersionId;
        this.fromWho = fromWho;
        this.subject = subject;
        this.loadId = loadId;
        this.highwayCarrierId = highwayCarrierId;
        this.recipients = recipients;
        this.carrierQuoteId = carrierQuoteId;
        this.isCancel = isCancel;
    }

    public void execute(QueueableContext ctx) {
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Blob bodyBlob = SecureRateConManager.buildRequestBody(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);
        
        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;
        List<String> notify = new List<String>{ 'IT@openroad.inc' };
        Http http = new Http();
        try {
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary, bearerToken);
            Integer status = res.getStatusCode();
            // System.debug('first status code: ' + status + ' response: ' + res.getBody());
            SecureRateConManager.handleStatus(status, res.getBody(), fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel, bodyBlob, boundary, bearerToken);
            // if(status == 422 && res.getBody().contains('Undelivered - user doesn\'t exist')) {
            //     System.debug('fromwho is a bad email');
            //     String body = 'Highway callout failed with status 422.<br>Endpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
            //         + '<br>StatusCode: ' + status 
            //         + '<br>Response: ' + res.getBody() 
            //         + '<br>LoadId: ' + loadId 
            //         + '<br>CarrierQuoteId: ' + carrierQuoteId 
            //         + '<br>ContentVersionId: ' + contentVersionId
            //         + '<br>From Who: ' + fromWho
            //         + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
            //         + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();
            //     bodyBlob = SecureRateConManager.buildRequestBody('jeffm@openroad.inc', subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);//TODO figure out who to send from
            //     System.debug('retrying with Jeffs email');
            //     res = SecureRateConManager.sendRequest(bodyBlob, boundary, bearerToken);
            //     status = res.getStatusCode();
            //     System.debug('new status code: ' + status + ' response: ' + res.getBody());
            //     //send special email to notify IT to add the user to highway
            //     EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Secure Rate Con Error' LIMIT 1];
            //     Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            //     String renderedHtml = renderedEmail.htmlBody;
               
            //     String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            //     System.debug('sending error email to IT');
            //     SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'HighwayCalloutJob failed with status 422', newHtml, true);
            // }
            // if(status < 200 || status >= 300){
            //     String body = 'Highway callout failed.<br>Endpoint: ' +'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
            //         + '<br>StatusCode: ' + status 
            //         + '<br>Response: ' + res.getBody() 
            //         + '<br>LoadId: ' + loadId 
            //         + '<br>CarrierQuoteId: ' + carrierQuoteId 
            //         + '<br>ContentVersionId: ' + contentVersionId
            //         + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
            //         + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();

            //     EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
            //     Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            //     String renderedHtml = renderedEmail.htmlBody;
               
            //     String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            //     SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc', this.fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            // }
            System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
        } catch (Exception e) {
            // String body = 'Highway callout exception: ' + e.getMessage()
            //     + '<br>Stack: ' + e.getStackTraceString()
            //     + '<br>Endpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
            //     + '<br>LoadId: ' + loadId
            //     + '<br>CarrierQuoteId: ' + carrierQuoteId
            //     + '<br>ContentVersionId: ' + contentVersionId
            //     + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
            //     + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();

            //     EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
            //     Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            //     String renderedHtml = renderedEmail.htmlBody;
               
            //     String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            //     SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc', this.fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            // if (this.fromWho != null) notify.add(this.fromWho);
            // SecureRateConManager.sendErrorEmail(new List<String>{ 'IT@openroad.inc', this.fromWho}, 'HighwayCalloutJob exception', body, false);
            SecureRateConManager.handleCalloutError(e, loadId, carrierQuoteId, contentVersionId, this.fromWho);
        }
    }
}