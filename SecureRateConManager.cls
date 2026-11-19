public class SecureRateConManager {
   
    //lwc methods for handling secure rate con
    @AuraEnabled()
    public static Map<String, Object> getLoadDetails(Id loadId){
        rtms__Load__c load = [SELECT rtms__Mode_Name__c, rtms__Load_Status__c, Use_Secure_Rate_Con__c, rtms__Carrier_Load2__c, rtms__Vendor__c, rtms__Carrier__c, rtms__Carrier_Service__c FROM rtms__Load__c WHERE Id = :loadId];
        rtms__CarrierQuote__c cq = getRecentSecureCarrierQuote(loadId);
        if (cq == null){
            return new Map<String, Object>{'modeName' => load.rtms__Mode_Name__c, 'loadStatus' => load.rtms__Load_Status__c, 'requireRateCon' => load.Use_Secure_Rate_Con__c, 'carrierLoad' => load.rtms__Carrier_Load2__c, 'vendor' => load.rtms__Vendor__c, 'carrier' => load.rtms__Carrier__c, 'carrierService' => load.rtms__Carrier_Service__c};
        }
        else{
            return new Map<String, Object>{'modeName' => load.rtms__Mode_Name__c, 'loadStatus' => load.rtms__Load_Status__c, 'requireRateCon' => load.Use_Secure_Rate_Con__c, 'carrierLoad' => load.rtms__Carrier_Load2__c, 'vendor' => load.rtms__Vendor__c, 'carrier' => load.rtms__Carrier__c, 'carrierService' => load.rtms__Carrier_Service__c, 'quoteStatus' => cq.Secure_Rate_Con_Status__c, 'lastUpdated' => cq.Secure_Rate_Con_Last_Update__c};    
        }
    }
    
    @AuraEnabled()
    public static void setSecureRateCon(Id loadId){
        try {
            rtms__Load__c load = [SELECT Use_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :loadId];
            load.Use_Secure_Rate_Con__c = !load.Use_Secure_Rate_Con__c;
            update load;
        } catch (DmlException de) {
            throw new AuraHandledException(de.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    @AuraEnabled()
    public static Map<String, Object> setupUpdateSecureRateCon(Id loadId){
        String fromWho = UserInfo.getUserEmail();
        rtms__Load__c load = [SELECT rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c  FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
        String highwayCarrierId = load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c;
        Map<String, Object> contentVersionMap = saveLoadPdfToFiles(loadId);
        String subject =  'Updated: ' + (String)contentVersionMap.get('fileName');
        Id contentVersionId = (Id)contentVersionMap.get('contentVersionId');
        Id carrierQuoteId = isCarrierQuoteAccepted(loadId).Id;
        Boolean isCancel = false;
        return new Map<String, Object>{
            'contentVersionId' => contentVersionId,
            'fromWho' => fromWho,
            'subject' => subject,
            'loadId' => loadId,
            'highwayCarrierId' => highwayCarrierId,
            'carrierQuoteId' => carrierQuoteId,
            'isCancel' => isCancel
        };
    }

    @AuraEnabled()
    public static Map<String, Object> updateSecureRateConRequest(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel) {
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Blob bodyBlob = buildRequestBody(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);

        List<String> notify = new List<String>{ 'IT@openroad.inc' };
        Http http = new Http();
        try {
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary);
            Integer status = res.getStatusCode();
            return handleStatus(status, res.getBody(), fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel, bodyBlob, boundary);
        } catch (Exception e) {
            handleCalloutError(e, loadId, carrierQuoteId, contentVersionId, fromWho);
            return new Map<String, Object>{'statusCode' => 'ERROR'};
        }
    }

    
    public static Map<String, Object> handleStatus(Integer statusCode, String respBody, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel, Blob bodyBlob, String boundary) {
        if(statusCode == 422 && respBody.contains('Undelivered - user doesn\'t exist')) {
            String body = 'Highway callout failed with status 422.<br>Endpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                + '<br>StatusCode: ' + statusCode
                + '<br>Response: ' + respBody 
                + '<br>LoadId: ' + loadId 
                + '<br>CarrierQuoteId: ' + carrierQuoteId 
                + '<br>ContentVersionId: ' + contentVersionId
                + '<br>From Who: ' + fromWho
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();
            //NOTE: IT@openroad.inc is not a valid user in staging.highway use Takunp@openroad.inc or jeffm@openroad.inc for sandbox testing
            bodyBlob = SecureRateConManager.buildRequestBody('IT@openroad.inc', subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary);
            respBody = res.getBody();
            statusCode = res.getStatusCode();
            //send special email to notify IT to add the user to highway
            String renderedHtml;
            if(!Test.isRunningTest()) {
                EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Secure Rate Con Error' LIMIT 1];
                Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
                renderedHtml = renderedEmail.htmlBody;
            }
            else{
                renderedHtml = 'replaced_In_Apex';
            }
            
            String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'HighwayCalloutJob failed with status 422', newHtml, true);
        }
        if(statusCode < 200 || statusCode >= 300){
            String body = 'Highway callout failed.'
                + '<br>StatusCode: ' + statusCode 
                + '<br>Response: ' + respBody
                + '<br>LoadId: ' + loadId 
                + '<br>CarrierQuoteId: ' + carrierQuoteId 
                + '<br>ContentVersionId: ' + contentVersionId
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();
            String renderedHtml;
            if(!Test.isRunningTest()) {
                EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
                Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
                renderedHtml = renderedEmail.htmlBody;
            }
            else{
                renderedHtml = 'replaced_In_Apex';
            }
            String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            setSecureRateConStatus(carrierQuoteId, 'failed');
        }
        return new Map<String, Object> {'statusCode' => statusCode, 'respBody' => respBody};
    }

    
    public static void handleCalloutError(Exception e, String loadId, String carrierQuoteId, Id contentVersionId, String fromWho) {
        String body = 'Highway callout exception: ' + e.getMessage()
                + '<br>Stack: ' + e.getStackTraceString()
                + '<br>LoadId: ' + loadId
                + '<br>CarrierQuoteId: ' + carrierQuoteId
                + '<br>ContentVersionId: ' + contentVersionId
            	+ '<br>From Who: ' + fromWho
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();
        String renderedHtml;
        if(!Test.isRunningTest()) {
            EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            renderedHtml = renderedEmail.htmlBody;
        }
        else{
            renderedHtml = 'replaced_In_Apex';
        }
        
        String newHtml = renderedHtml.replace('replaced_In_Apex', body);
        sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
        setSecureRateConStatus(carrierQuoteId, 'failed');
    }
	
    public static void setSecureRateConStatus(Id carrierQuoteId, String status) {
        rtms__CarrierQuote__c cq = [SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c FROM rtms__CarrierQuote__c WHERE Id =: carrierQuoteId];
        cq.Secure_Rate_Con_Status__c = status;
        cq.Secure_Rate_Con_Last_Update__c = System.now();
        
        update cq;
    }

    
    //helper method
    public static rtms__CarrierQuote__c getCarrierQuote(Boolean isCancel, Id loadId){
        if(isCancel){
            return getRecentSecureCarrierQuote(loadId);
        }
        else{
            return isCarrierQuoteAccepted(loadId);    
        }
    }
	@TestVisible
    private static rtms__CarrierQuote__c getRecentSecureCarrierQuote(Id loadId){
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c, Secure_Rate_Con_Cancelled_Rejected__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c =: loadId AND Secure_Rate_Con_Last_Update__c != null ORDER BY Secure_Rate_Con_Last_Update__c DESC LIMIT 1];
        if(cqs.isEmpty()){
            return null;
        }
        else{
            return cqs[0];
        }
    }

    private static rtms__CarrierQuote__c isCarrierQuoteAccepted(Id loadId) {
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c, Secure_Rate_Con_Status__c, Secure_Rate_Con_Cancelled_Rejected__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId AND rtms__Accepted__c = true AND CS_Service_Type__c = 'Carrier' LIMIT 2];
        if(!cqs.isEmpty()){
            if(cqs.size() == 1){
                return cqs[0];
            }
            else{
                return null;
            }
        }
        else{
            return null;
        }
    }
    
    
    public static Blob buildRequestBody(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, String boundary, Boolean isCancel) {
        Blob bodyBlob;
        if (isCancel) {
            bodyBlob = buildCancelRateCon(loadId, carrierQuoteId, boundary);
        } else {
            bodyBlob = buildRateCon(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
        }
        return bodyBlob;
    }
    
    
    private static Blob buildCancelRateCon(String loadId, Id carrierQuoteId, String boundary){
        String crlf = '\r\n';
        
        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + carrierQuoteId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[status]"' + crlf + crlf + 'cancelled' + crlf;
        Blob headerBlob = Blob.valueOf(textParts);

        Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + 'cancelled rate con' + '"' + crlf +
        'Content-Type: application/pdf' + crlf + crlf);

        Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);
        
        String hexHeaderBlob = EncodingUtil.convertToHex(headerBlob);
        String hexFileHeader = EncodingUtil.convertToHex(fileHeader);
        String hexClosing = EncodingUtil.convertToHex(closing);
        Blob bodyBlob = EncodingUtil.convertFromHex(hexHeaderBlob + hexFileHeader + hexClosing);
        return bodyBlob;
    }

    private static Blob buildRateCon(String fromWho, String subject, String loadId, String highwayCarrierId,  List<String> recipients, Id contentVersionId, Id carrierQuoteId, String boundary){
        String crlf = '\r\n';
        ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + fromWho + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + carrierQuoteId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf + highwayCarrierId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf + loadId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf + subject + crlf;
        
        Blob headerBlob = Blob.valueOf(textParts);

        Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + cv.Title + '"' + crlf +
        'Content-Type: application/pdf' + crlf + crlf);

        Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);
        String hexHeaderBlob = EncodingUtil.convertToHex(headerBlob);
        String hexFileHeader = EncodingUtil.convertToHex(fileHeader);
        String hexClosing = EncodingUtil.convertToHex(closing);
        String hexFileData = EncodingUtil.convertToHex(cv.VersionData);
        Blob bodyBlob = EncodingUtil.convertFromHex(hexHeaderBlob + hexFileHeader + hexFileData + hexClosing);
        return bodyBlob;
    }
    
 	
    @AuraEnabled()
    public static Map<String, Object> saveLoadPdfToFiles(Id loadId) {
        Blob pdf;
        if (Test.isRunningTest()) {
            pdf = Blob.valueOf('TEST PDF PLACEHOLDER');
        }
        else{
            PageReference pr = Page.ORCarrierRateConfirmation3;
            pr.getParameters().put('id', String.valueOf(loadId));
            pdf = pr.getContentAsPDF();
        }
        
		rtms__Load__c load = [SELECT Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
    	String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';        
        ContentVersion cv = new ContentVersion(
          Title = fileName,
          PathOnClient = fileName,
          VersionData = pdf
        );
        insert cv;
    	
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
          ContentDocumentId = contentDocumentId,
          LinkedEntityId = loadId,
          ShareType = 'V',
          Visibility = 'AllUsers'
        );
        return new Map<String, Object>{'contentVersionId' => cv.Id, 'fileName' => fileName};
  	}
    
    

    public static HttpResponse sendRequest(Blob bodyBlob, String boundary) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Highway_Secure_Rate_Con_Call_Out/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);
        req.setTimeout(25000); // Set timeout to 25 seconds
        Http http = new Http();
        return http.send(req);
    }

    public static void sendErrorEmail(List<String> toAddresses, String subjectLine, String bodyText, Boolean isHtml) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject(subjectLine);
        if(isHtml) {
            mail.setHtmlBody(bodyText);
        } else {
            mail.setPlainTextBody(bodyText);
        }
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}