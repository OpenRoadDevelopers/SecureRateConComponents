public class SecureRateConManager {
   
    //lwc methods for handling secure rate con
    @AuraEnabled()
    public static Map<String, Object> getLoadDetails(Id loadId){
        System.debug('getLoadDetails Called');
        rtms__Load__c load = [SELECT rtms__Mode_Name__c, rtms__Load_Status__c, Require_Secure_Rate_Con__c, rtms__Carrier_Load2__c, rtms__Vendor__c, rtms__Carrier__c, rtms__Carrier_Service__c FROM rtms__Load__c WHERE Id = :loadId];
        rtms__CarrierQuote__c cq = getRecentSecureCarrierQuote(loadId);
        if (cq == null){
            return new Map<String, Object>{'modeName' => load.rtms__Mode_Name__c, 'loadStatus' => load.rtms__Load_Status__c, 'requireRateCon' => load.Require_Secure_Rate_Con__c, 'carrierLoad' => load.rtms__Carrier_Load2__c, 'vendor' => load.rtms__Vendor__c, 'carrier' => load.rtms__Carrier__c, 'carrierService' => load.rtms__Carrier_Service__c};
        }
        else{
            return new Map<String, Object>{'modeName' => load.rtms__Mode_Name__c, 'loadStatus' => load.rtms__Load_Status__c, 'requireRateCon' => load.Require_Secure_Rate_Con__c, 'carrierLoad' => load.rtms__Carrier_Load2__c, 'vendor' => load.rtms__Vendor__c, 'carrier' => load.rtms__Carrier__c, 'carrierService' => load.rtms__Carrier_Service__c, 'quoteStatus' => cq.Secure_Rate_Con_Status__c, 'lastUpdated' => cq.Secure_Rate_Con_Last_Update__c};    
        }
    }
    
    @AuraEnabled()
    public static void setSecureRateCon(Id loadId){
        rtms__Load__c load = [SELECT Require_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :loadId];
        load.Require_Secure_Rate_Con__c = !load.Require_Secure_Rate_Con__c;
        UPDATE load;
    }

    @AuraEnabled()
    public static Map<String, Object> setupUpdateSecureRateCon(Id loadId){
        //String fromWho = UserInfo.getUserEmail();
        String fromWho = 'expeditiousteq@gmail.com';
        rtms__Load__c load = [SELECT rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c  FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
        String highwayCarrierId = load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c;
        Map<String, Object> contentVersionMap = saveLoadPdfToFiles(loadId);
        String subject = contentVersionMap.get('fileName') != null ? 'Updated: ' + (String)contentVersionMap.get('fileName') : 'Updated: Carrier Rate and Load Confirmation';
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
        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;

        List<String> notify = new List<String>{ 'IT@openroad.inc' };
        Http http = new Http();
        try {
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary, bearerToken);
            Integer status = res.getStatusCode();
            System.debug('first status code: ' + status + ' response: ' + res.getBody());
            return handleStatus(status, res.getBody(), fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel, bodyBlob, boundary, bearerToken);
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
            //     sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'HighwayCalloutJob failed with status 422', newHtml, true);
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
            //     sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            // }
            // System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
            // return new Map<String, Object> {'statusCode' => res.getStatusCode(), 'respBody' => res.getBody()};
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
            //     sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            // if (fromWho != null) notify.add(fromWho);
            // sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'HighwayCalloutJob exception', body, false);
            // return null; 
            handleCalloutError(e, loadId, carrierQuoteId, contentVersionId, fromWho);
            return null;
        }
    }

    
    public static Map<String, Object> handleStatus(Integer statusCode, String respBody, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel, Blob bodyBlob, String boundary, String bearerToken) {
        if(statusCode == 422 && respBody.contains('Undelivered - user doesn\'t exist')) {
            System.debug('fromwho is a bad email');
            String body = 'Highway callout failed with status 422.<br>Endpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                + '<br>StatusCode: ' + statusCode
                + '<br>Response: ' + respBody 
                + '<br>LoadId: ' + loadId 
                + '<br>CarrierQuoteId: ' + carrierQuoteId 
                + '<br>ContentVersionId: ' + contentVersionId
                + '<br>From Who: ' + fromWho
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();
            bodyBlob = SecureRateConManager.buildRequestBody('jeffm@openroad.inc', subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);//TODO figure out who to send from
            System.debug('retrying with IT email');
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary, bearerToken);
            respBody = res.getBody();
            statusCode = res.getStatusCode();
            System.debug('new status code: ' + statusCode + ' response: ' + res.getBody());
            //send special email to notify IT to add the user to highway
            EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Secure Rate Con Error' LIMIT 1];
            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            String renderedHtml = renderedEmail.htmlBody;
            
            String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            System.debug('sending error email to IT');
            sendErrorEmail(new List<String>{ 'IT@openroad.inc'}, 'HighwayCalloutJob failed with status 422', newHtml, true);
        }
        if(statusCode < 200 || statusCode >= 300){
            String body = 'Highway callout failed.<br>Endpoint: ' +'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                + '<br>StatusCode: ' + statusCode 
                + '<br>Response: ' + respBody
                + '<br>LoadId: ' + loadId 
                + '<br>CarrierQuoteId: ' + carrierQuoteId 
                + '<br>ContentVersionId: ' + contentVersionId
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();

            EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
            Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
            String renderedHtml = renderedEmail.htmlBody;
            
            String newHtml = renderedHtml.replace('replaced_In_Apex', body);
            sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
            setSecureRateConStatus(carrierQuoteId, 'failed');
        }
        System.debug('HighwayCalloutJob: status=' + respBody + ' code=' + statusCode);
        return new Map<String, Object> {'statusCode' => statusCode, 'respBody' => respBody};
    }

    
    public static void handleCalloutError(Exception e, String loadId, String carrierQuoteId, Id contentVersionId, String fromWho) {
        String body = 'Highway callout exception: ' + e.getMessage()
                + '<br>Stack: ' + e.getStackTraceString()
                + '<br>Endpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
                + '<br>LoadId: ' + loadId
                + '<br>CarrierQuoteId: ' + carrierQuoteId
                + '<br>ContentVersionId: ' + contentVersionId
                + '<br>Salesforce/Revenova user name: ' + UserInfo.getName()
                + '<br>Salesforce/Revenova useremail address: ' + UserInfo.getUserEmail();

        EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Failed Send Secure Rate Con' LIMIT 1];
        Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
        String renderedHtml = renderedEmail.htmlBody;
        
        String newHtml = renderedHtml.replace('replaced_In_Apex', body);
        sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'Failed to send Highway Secure Rate Con', newHtml, true);
        setSecureRateConStatus(carrierQuoteId, 'failed');
        //TODO: do we need a highway callout exception or just the same failed to send highway secure rate con? 
        // if (fromWho != null) {
        //     sendErrorEmail(new List<String>{ 'IT@openroad.inc', fromWho}, 'HighwayCalloutJob exception', body, false);
        // }
    }

    private static void setSecureRateConStatus(Id carrierQuoteId, String status) {
        rtms__CarrierQuote__c cq = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id =: carrierQuoteId];
        cq.Secure_Rate_Con_Status__c = status;
        update cq;
    }

    
    //helper method
    

    public static rtms__CarrierQuote__c getCarrierQuote(Boolean isCancel, Id loadId){
        // System.debug('IN getCarrierQuote params: ' + isCancel + ' loadId: ' + loadId);
        if(isCancel){
            // System.debug('calling get recent secure carrier quote');
            return getRecentSecureCarrierQuote(loadId);
        }
        else{
            // System.debug('is carrier quote accepted check');
            return isCarrierQuoteAccepted(loadId);    
        }
    }

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
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c, Secure_Rate_Con_Status__c, Secure_Rate_Con_Cancelled_Rejected__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId AND rtms__Accepted__c = true];
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
            'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf + 'Takun test' + crlf +
            '--' + boundary + crlf + 
            'Content-Disposition: form-data; name="rate_confirmation[targeted_emails]"' + crlf + crlf + 'dot01006144@rates.staging.highway.com' + crlf;
        
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
        PageReference pr = Page.ORCarrierRateConfirmation3;
        pr.getParameters().put('id', String.valueOf(loadId));
        Blob pdf = pr.getContentAsPDF();
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
    
    

    public static HttpResponse sendRequest(Blob bodyBlob, String boundary, String bearerToken) {
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

    public static void sendErrorEmail(List<String> toAddresses, String subjectLine, String bodyText, Boolean isHtml) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject(subjectLine);
        if(isHtml) {
            mail.setHtmlBody(bodyText);
        } else {
            mail.setPlainTextBody(bodyText);
        }
        try {
        	Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception ex) {
    	    System.debug('Failed to send error email: ' + ex);
        }
    }

    



    // @AuraEnabled
    // public static Map<String, String> getHighwayStatus(Id loadId){
    //     rtms__Load__c loadRecord = [SELECT Id, Secure_Rate_Con_Status_Text__c, Secure_Rate_Con_Last_Update__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
    //     if (loadRecord.Secure_Rate_Con_Status_Text__c != null) {
    //     	return new Map<String, String>{'status' => loadRecord.Secure_Rate_Con_Status_Text__c, 'lastUpdated' => loadRecord.Secure_Rate_Con_Last_Update__c.format('yyyy-MM-dd HH:mm:ss')};    
    //     }
    //     else{
    //         return new Map<String, String>{};    
    //     }
    // } 


     // @AuraEnabled
    // public static Map<String,String> postToHighway(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel) {
    //     isCancel = true; 
    //     return doPost(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel);
    // }
    
     // public static Map<String, String> doPost(String fromWho, String subject, String loadId, String highwayCarrierId,  List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel){
    //     System.debug('IN doPost');
    //     System.debug('fromWho: ' + fromWho);
    //     System.debug('subject: ' + subject);
    //     System.debug('loadId: ' + loadId);
    //     System.debug('highwayCarrierId: ' + highwayCarrierId);
    //     System.debug('recipients: ' + recipients); 
    //     System.debug('contentVersionId: ' + contentVersionId);
    //     System.debug('carrierQuoteId: ' + carrierQuoteId);
    //     System.debug('isCancel: ' + isCancel);
    //     String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    //     API_key__mdt ApiKey = [SELECT Api_Credential__c
    //         FROM API_key__mdt
    //         WHERE DeveloperName = 'HighwayStagingAPIKey'
    //         LIMIT 1];
    //     String bearerToken = ApiKey.Api_Credential__c;
    //     Blob bodyBlob = buildRequestBody(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);
    //     try {
    //         HttpResponse res = sendRequest(bodyBlob, boundary, bearerToken);
    //         Integer status = res.getStatusCode();
    //         if(status == 422 && res.getBody().contains('the provided targeted_emails had invalid values')) {
    //             //send special email to notify IT to add the user to highway
    //             EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Secure_Rate_Con_Error' LIMIT 1];
    //             Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, loadId);
    //             String renderedHtml = renderedEmail.htmlBody;
    //             String body = 'Highway callout failed with status 422.\nEndpoint: ' + 'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
    //                 + '\nStatusCode: ' + status 
    //                 + '\nResponse: ' + res.getBody() 
    //                 + '\nLoadId: ' + loadId 
    //                 + '\nCarrierQuoteId: ' + carrierQuoteId 
    //                 + '\nContentVersionId: ' + contentVersionId
    //                 + '\nRecipients: ' + String.join(recipients, ', ');
    //             String newHtml = renderedHtml.replace('Replace_In_Apex', body);
    //             sendErrorEmail('IT@openroad.inc', 'HighwayCalloutJob failed with status 422', newHtml);
    //             bodyBlob = buildRequestBody('jeffm@openroad.inc', subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);//TODO figure out who to send from
    //             res = sendRequest(bodyBlob, boundary, bearerToken);
    //             status = res.getStatusCode();
    //         }
    //         if(status < 200 || status >= 300){
    //             String body = 'Highway callout failed.\nEndpoint: ' +'https://staging.highway.com/core/connect/external_api/v1/rate_confirmations'
    //                 + '\nStatusCode: ' + status 
    //                 + '\nResponse: ' + res.getBody() 
    //                 + '\nLoadId: ' + loadId 
    //                 + '\nCarrierQuoteId: ' + carrierQuoteId 
    //                 + '\nContentVersionId: ' + contentVersionId;
    //             sendErrorEmail('takunp@openroad.inc', 'HighwayCalloutJob failed', body);
    //         }
    //         Map<String, String> result = new Map<String, String>{'statusCode' => String.valueOf(res.getStatusCode()), 'responseBody' => String.valueOf(res.getBody())};
    //         return result;
    //     } catch (Exception e) {
    //         System.debug('Callout error: ' + e.getMessage());
    //         Map<String, String> result = new Map<String, String>{'error' => String.valueOf(e.getMessage())};
    //         return result;
    //     }
    // }    
    
     // @AuraEnabled()
    // public static void setCarrier(Id loadId, Id carrierId, Id quoteId){
    //     System.debug('setCarrier Called');
    //     System.debug('carrierId: ' + carrierId);
    //     rtms__Load__c load = [SELECT rtms__Carrier__c, rtms__Load_Status__c FROM rtms__Load__c WHERE Id =: loadId];
    //     if(carrierId != load.rtms__Carrier__c ){
    //     	load.rtms__Carrier__c = carrierId;
    //     	update load;    
    //     }
    //     List<rtms__CarrierQuote__c> toUpdate = new List<rtms__CarrierQuote__c>();
    //     List<rtms__CarrierQuote__c> quotes = [SELECT rtms__Accepted__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c =: loadId];
    //     for(rtms__CarrierQuote__c q : quotes){
    //         if(q.Id != quoteId && q.rtms__Accepted__c == true){
    //             q.rtms__Accepted__c = false;
    //             toUpdate.add(q);
    //         }
    //         else if(q.Id == quoteId && q.rtms__Accepted__c == false){
    //             q.rtms__Accepted__c = true;
    //             toUpdate.add(q);
    //         }
    //     }
    //     update toUpdate;
    // }

     // @AuraEnabled()
    // public static List<rtms__CarrierQuote__c> getCarrierQuotes(Id loadId){
    //     System.debug('getCarrierQuotes Called');
    //     List<rtms__CarrierQuote__c> cQuotes = [SELECT Name, 
    //                                            rtms__Carrier_Service__r.Name, 
    //                                            rtms__Carrier_Service__r.MC__c, 
    //                                            rtms__Carrier_Service__r.rtms__Carrier__c, 
    //                                            rtms__Carrier_Service__r.UD_DOT__c, 
    //                                            rtms__Carrier_Total__c, 
    //                                            rtms__Accepted__c 
    //                                            FROM rtms__CarrierQuote__c 
    //                                            WHERE rtms__Load__c = :loadId];
    //     return cQuotes;
    // }

    // @AuraEnabled()
    // public static Id isOnlyOneCarrierQuote(Id loadId) {
    //     List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c, rtms__Carrier_Service__r.rtms__Carrier__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId];
    //     if(cqs.size() == 1){
    //         if (cqs[0].rtms__Accepted__c != true){
    //             setCarrier(loadId, cqs[0].rtms__Carrier_Service__r.rtms__Carrier__c, cqs[0].Id);
    //         }
    //         return cqs[0].Id;
    //     }
    //     else{
    //         return null;
    //     }
    // }

//  public class FlowPostRequest {
//         @InvocableVariable(required=true) public String fromWho;
//         @InvocableVariable public String subject;
//         @InvocableVariable public String loadId;
//         @InvocableVariable public String highwayCarrierId;
//         @InvocableVariable public List<String> recipients;
//         @InvocableVariable public Boolean isCancel;
//     }

//     public class FlowPostResponse {
//         @InvocableVariable public String statusCode;
//         @InvocableVariable public String responseBody;
//         public FlowPostResponse(String code, String body){ statusCode = code; responseBody = body; }
//     }

//     @InvocableMethod(label='Post Rate Con to Highway')
//     public static List<FlowPostResponse> flowPostToHighway(List<FlowPostRequest> requests){ 
//         List<FlowPostResponse> responses = new List<FlowPostResponse>();
//         for(FlowPostRequest r : requests){
//             Id carrierQuoteId = isCarrierQuoteAccepted('a0jEa00000EXvVhIAL');
//             System.debug('carrierQuoteId: ' + carrierQuoteId);
//             if(carrierQuoteId == null){
//                 System.debug('carrier quote not found');
//                 responses.add(new FlowPostResponse('444', 'CarrierQuoteId Not found for ' + r.loadId));
//                 return responses;
//             }
//             Id contentVersionId = saveLoadPdfToFiles('a0jEa00000EXvVhIAL');
//             if(contentVersionId == null){
//                 responses.add(new FlowPostResponse('444', 'contentVersionId Not found for ' + r.loadId));
//                     return responses;
//             }
//             // Map<String, String> res = doPost(r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, contentVersionId, carrierQuoteId, r.isCancel);
//             Map<String, String> res = doPost('takunp@openroad.inc', 'test subject', 'a0jEa00000EXvVhIAL', '468462', null, contentVersionId, carrierQuoteId, false);
//             responses.add(new FlowPostResponse(res.get('statusCode'), res.get('responseBody')));
//         }
//        return responses;
//     }public class FlowPdfRequest {
//         @InvocableVariable(required=true) public Id loadId;
//     }

//     public class FlowPdfResponse {
//         @InvocableVariable public Id contentVersionId;
//         public FlowPdfResponse(String contentVersionId){ contentVersionId = contentVersionId; }
//     }
    
//     @InvocableMethod(label='save load pdf to files')
//     public static List<FlowPdfResponse> saveLoadPdfToFiles(List<FlowPdfRequest> requests) {
//         System.debug('Invocable method called');
//         List<FlowPdfResponse> responses = new List<FlowPdfResponse>();
//         for(FlowPdfRequest r : requests){
//             Id carrierQuoteId = isCarrierQuoteAccepted(r.loadId);
//             System.debug('carrier quote id: ' + carrierQuoteId);
//             System.debug('LoadId: ' + r.loadId);
//             PageReference pr = Page.ORCarrierRateConfirmation3;
//             pr.getParameters().put('id', String.valueOf(r.loadId));
//             pr.getParameters().put('isSecureRateCon', 'true');
//             pr.getParameters().put('carrierQuoteId', String.valueOf(carrierQuoteId));
//             Blob pdf = pr.getContentAsPDF();
//             rtms__Load__c load = [SELECT Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :r.loadId LIMIT 1];
//             System.debug('LoadName: ' + load.Name + ' carrier name: ' + load.Carrier_Name__c + ' modeName: ' + load.rtms__Mode_Name__c);
//             String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';        
//             System.debug('fileName: ' + fileName);
//             ContentVersion cv = new ContentVersion(
//               Title = fileName,
//               PathOnClient = fileName,
//               VersionData = pdf
//             );
            
//             insert cv;
            
//             Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
//             System.debug('contentDocumentId: ' + contentDocumentId);
//             insert new ContentDocumentLink(
//               ContentDocumentId = contentDocumentId,
//               LinkedEntityId = r.loadId,
//               ShareType = 'V',
//               Visibility = 'AllUsers'
//             );
//             System.debug('cv Id: ' + cv.Id);
//             responses.add(new FlowPdfResponse(cv.Id));
//         }
//         return responses;
//   	}


// @AuraEnabled()
    // public static rtms__CarrierQuote__c getCarrierQuote(String carrierQuoteId) {
    //     List<rtms__CarrierQuote__c> cqs = [SELECT Name, 
    //                                            rtms__Carrier_Service__r.Name, 
    //                                            rtms__Carrier_Service__r.MC__c, 
    //                                            rtms__Carrier_Service__r.rtms__Carrier__c, 
    //                                            rtms__Carrier_Service__r.UD_DOT__c, 
    //                                            rtms__Carrier_Total__c  FROM rtms__CarrierQuote__c WHERE Id = :carrierQuoteId LIMIT 1];
    //    	return cqs[0];
    // }
    
    // @AuraEnabled()
    // public static Map<String, String> getCarrierRateCon(Id loadId) {
    //     Id carrierQuoteId = isOnlyOneCarrierQuote(loadId) != null ? isOnlyOneCarrierQuote(loadId) : isCarrierQuoteAccepted(loadId).Id;
    //     //TODO: need to figure out a way to gaurentee creation of the document 
    //     if(carrierQuoteId != null){
    //         rtms__Load__c load = [SELECT Name, rtms__Carrier__c, rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c  FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
    //         Id contentVersionId = saveLoadPdfToFiles(loadId);
    //         return new Map<String, String>{'contentVersionId' => contentVersionId, 'carrierId' => load.rtms__Carrier__c, 'carrierQuoteId' => carrierQuoteId, 'highwayCarrierId' => load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c};
    //     }
    //     else{
    //         return new Map<String, String>{};
    //     }
    // }
    
    // @AuraEnabled
    // public static List<User> getValidUsers() {
    //     List<User> users = [
    //     	SELECT Name, FirstName, LastName, Email
    //         FROM User
    //         WHERE IsActive = true
    //         AND (Email LIKE '%@openroad.inc' OR Email LIKE '%@openroadtrans.com' OR Email LIKE '%@openroadfs.com')
    //         ORDER BY Name
    //     ];
    //     Set<String> seen = new Set<String>();
    //     List<User> uniqueUsers = new List<User>();
    //     for (User u : users) {
    //         if (u.Email == null) continue;
    //         String key = u.Email.trim().toLowerCase();
    //         if (!seen.contains(key)) {
    //             seen.add(key);
    //             uniqueUsers.add(u);
    //         }
    //     }
    //     return uniqueUsers;
    // }
    
    // public static void setRateConStatus(Id loadId, String status){
    //     rtms__Load__c loadRecord = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
    //     loadRecord.Secure_Rate_Con_Status__c = status;
    //     loadRecord.Secure_Rate_Con_Last_Update__c = System.now();
    //     UPDATE loadRecord;
    // }

}