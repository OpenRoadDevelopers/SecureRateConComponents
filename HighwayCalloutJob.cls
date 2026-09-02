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
    
    private void sendErrorEmail(String toAddress, String subjectLine, String bodyText) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { toAddress });
        mail.setSubject(subjectLine);
        mail.setPlainTextBody(bodyText);
        try {
        	Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception ex) {
    	    System.debug('Failed to send error email: ' + ex);
        }
    }
    
    private Blob buildRequestBody(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, String boundary) {
        Blob bodyBlob;
        if (isCancel) {
            bodyBlob = SecureRateConManager.buildCancelRateCon(loadId, carrierQuoteId, boundary);
        } else {
            bodyBlob = SecureRateConManager.buildRateCon(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
        }
        return bodyBlob;
    }
    
    private HttpResponse sendRequest(Blob bodyBlob, String boundary, String bearerToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);

        Http http = new Http();
        return http.send(req);
    }

    public void execute(QueueableContext ctx) {
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Blob bodyBlob = buildRequestBody(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
        
        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;

        Http http = new Http();
        try {
            HttpResponse res = sendRequest(bodyBlob, boundary, bearerToken);
            Integer status = res.getStatusCode();
            if(status == 422 && res.getBody().contains('the provided targeted_emails had invalid values')) {
                //send special email to notify IT to add the user to highway
                EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Secure_Rate_Con_Error' LIMIT 1];
                Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
                String renderedHtml = renderedEmail.htmlBody;
                String body = 'Highway callout failed with status 422.\nEndpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                    + '\nStatusCode: ' + status 
                    + '\nResponse: ' + res.getBody() 
                    + '\nLoadId: ' + loadId 
                    + '\nCarrierQuoteId: ' + carrierQuoteId 
                    + '\nContentVersionId: ' + contentVersionId
                    + '\nRecipients: ' + String.join(recipients, ', ');
                String newHtml = renderedHtml.replace('Replace_In_Apex', body);
                sendErrorEmail('IT@openroad.inc', 'HighwayCalloutJob failed with status 422', newHtml);
                bodyBlob = buildRequestBody('takunp@openroad.inc', subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);//TODO figure out who to send from
                res = sendRequest(bodyBlob, boundary, bearerToken);
                status = res.getStatusCode();
            }
            if(status < 200 || status >= 300){
                String body = 'Highway callout failed.\nEndpoint: ' +'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                    + '\nStatusCode: ' + status 
                    + '\nResponse: ' + res.getBody() 
                    + '\nLoadId: ' + loadId 
                    + '\nCarrierQuoteId: ' + carrierQuoteId 
                    + '\nContentVersionId: ' + contentVersionId;
                sendErrorEmail('takunp@openroad.inc', 'HighwayCalloutJob failed', body);
            }
            System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
            // Create ContentDocumentLink so file is attached to the Load
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = (Id)loadId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        } catch (Exception e) {
            String body = 'Highway callout exception: ' + e.getMessage()
                + '\nStack: ' + e.getStackTraceString()
                + '\nEndpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                + '\nLoadId: ' + loadId
                + '\nCarrierQuoteId: ' + carrierQuoteId
                + '\nContentVersionId: ' + contentVersionId;
            sendErrorEmail('takunp@openroad.inc', 'HighwayCalloutJob exception', body);
        }
    }
}