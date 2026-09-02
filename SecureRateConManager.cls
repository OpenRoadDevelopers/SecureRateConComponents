public class SecureRateConManager {
   
    @AuraEnabled()
    public static Map<String, Object> getLoadDetails(Id loadId){
        System.debug('getLoadDetails Called');
        rtms__Load__c load = [SELECT Require_Secure_Rate_Con__c, rtms__Carrier_Load2__c, rtms__Vendor__c, rtms__Carrier__c, rtms__Carrier_Service__c FROM rtms__Load__c WHERE Id = :loadId];
        List<rtms__CarrierQuote__c> cqs = [SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId ORDER BY Secure_Rate_Con_Last_Update__c DESC LIMIT 1];
        if (load.Require_Secure_Rate_Con__c == false && load.rtms__Carrier_Load2__c == true && load.rtms__Vendor__c == null && load.rtms__Carrier__c == null && load.rtms__Carrier_Service__c == null){
            return new Map<String, Object>{'RateConOptional' => true};
        }
        else{
            if (cqs.isEmpty()){
                return new Map<String, Object>{'requireRateCon' => false};
            }
            else{
            	return new Map<String, Object>{'requireRateCon' => false, 'quoteStatus' => cqs[0].Secure_Rate_Con_Status__c, 'lastUpdated' => cqs[0].Secure_Rate_Con_Last_Update__c};    
            }
        }
    }
    
    @AuraEnabled()
    public static void setSecureRateCon(Id loadId){
        rtms__Load__c load = [SELECT Require_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :loadId];
        load.Require_Secure_Rate_Con__c = !load.Require_Secure_Rate_Con__c;
        UPDATE load;
    }
    
    @AuraEnabled()
    public static List<rtms__CarrierQuote__c> getCarrierQuotes(Id loadId){
        System.debug('getCarrierQuotes Called');
        List<rtms__CarrierQuote__c> cQuotes = [SELECT Name, 
                                               rtms__Carrier_Service__r.Name, 
                                               rtms__Carrier_Service__r.MC__c, 
                                               rtms__Carrier_Service__r.rtms__Carrier__c, 
                                               rtms__Carrier_Service__r.UD_DOT__c, 
                                               rtms__Carrier_Total__c, 
                                               rtms__Accepted__c 
                                               FROM rtms__CarrierQuote__c 
                                               WHERE rtms__Load__c = :loadId];
        return cQuotes;
    }
    
    @AuraEnabled
    public static Map<String, String> getHighwayStatus(Id loadId){
        rtms__Load__c loadRecord = [SELECT Id, Secure_Rate_Con_Status_Text__c, Secure_Rate_Con_Last_Update__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
        if (loadRecord.Secure_Rate_Con_Status_Text__c != null) {
        	return new Map<String, String>{'status' => loadRecord.Secure_Rate_Con_Status_Text__c, 'lastUpdated' => loadRecord.Secure_Rate_Con_Last_Update__c.format('yyyy-MM-dd HH:mm:ss')};    
        }
        else{
            return new Map<String, String>{};    
        }
        
    } 
    
    @AuraEnabled()
    public static void setCarrier(Id loadId, Id carrierId, Id quoteId){
        System.debug('setCarrier Called');
        System.debug('carrierId: ' + carrierId);
        rtms__Load__c load = [SELECT rtms__Carrier__c, rtms__Load_Status__c FROM rtms__Load__c WHERE Id =: loadId];
        if(carrierId != load.rtms__Carrier__c ){
        	load.rtms__Carrier__c = carrierId;
        	update load;    
        }
        List<rtms__CarrierQuote__c> toUpdate = new List<rtms__CarrierQuote__c>();
        List<rtms__CarrierQuote__c> quotes = [SELECT rtms__Accepted__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c =: loadId];
        for(rtms__CarrierQuote__c q : quotes){
            if(q.Id != quoteId && q.rtms__Accepted__c == true){
                q.rtms__Accepted__c = false;
                toUpdate.add(q);
            }
            else if(q.Id == quoteId && q.rtms__Accepted__c == false){
                q.rtms__Accepted__c = true;
                toUpdate.add(q);
            }
        }
        update toUpdate;
    }
    
    @AuraEnabled()
    public static Id saveLoadPdfToFiles(Id loadId) {
        System.debug('LoadId: ' + loadId);
        PageReference pr = Page.ORCarrierRateConfirmation3;
        pr.getParameters().put('id', String.valueOf(loadId));
        Blob pdf = pr.getContentAsPDF();
		rtms__Load__c load = [SELECT Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
        System.debug('LoadName: ' + load.Name + ' carrier name: ' + load.Carrier_Name__c + ' modeName: ' + load.rtms__Mode_Name__c);
    	String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';        
        System.debug('fileName: ' + fileName);
        ContentVersion cv = new ContentVersion(
          Title = fileName,
          PathOnClient = fileName,
          VersionData = pdf
        );
        
        insert cv;
    	
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        System.debug('contentDocumentId: ' + contentDocumentId);
        insert new ContentDocumentLink(
          ContentDocumentId = contentDocumentId,
          LinkedEntityId = loadId,
          ShareType = 'V',
          Visibility = 'AllUsers'
        );
        System.debug('cv Id: ' + cv.Id);
        return cv.Id;
  	}

	@AuraEnabled()
    public static Id isOnlyOneCarrierQuote(Id loadId) {
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c, rtms__Carrier_Service__r.rtms__Carrier__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId];
        if(cqs.size() == 1){
            if (cqs[0].rtms__Accepted__c != true){
                setCarrier(loadId, cqs[0].rtms__Carrier_Service__r.rtms__Carrier__c, cqs[0].Id);
            }
            return cqs[0].Id;
        }
        else{
            return null;
        }
    }
	@AuraEnabled()
    public static Id isCarrierQuoteAccepted(Id loadId) {
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId AND rtms__Accepted__c = true];
        if(!cqs.isEmpty()){
            if(cqs.size() == 1){
                return cqs[0].Id;
            }
            else{
                return null;
            }
        }
        else{
            return null;
        }
    }
    
    @AuraEnabled()
    public static rtms__CarrierQuote__c getCarrierQuote(String carrierQuoteId) {
        List<rtms__CarrierQuote__c> cqs = [SELECT Name, 
                                               rtms__Carrier_Service__r.Name, 
                                               rtms__Carrier_Service__r.MC__c, 
                                               rtms__Carrier_Service__r.rtms__Carrier__c, 
                                               rtms__Carrier_Service__r.UD_DOT__c, 
                                               rtms__Carrier_Total__c  FROM rtms__CarrierQuote__c WHERE Id = :carrierQuoteId LIMIT 1];
       	return cqs[0];
    }
    
    @AuraEnabled()
    public static Map<String, String> getCarrierRateCon(Id loadId) {
        Id carrierQuoteId = isOnlyOneCarrierQuote(loadId) != null ? isOnlyOneCarrierQuote(loadId) : isCarrierQuoteAccepted(loadId);
        //TODO: need to figure out a way to gaurentee creation of the document 
        if(carrierQuoteId != null){
            rtms__Load__c load = [SELECT Name, rtms__Carrier__c, rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c  FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
            Id contentVersionId = saveLoadPdfToFiles(loadId);
            return new Map<String, String>{'contentVersionId' => contentVersionId, 'carrierId' => load.rtms__Carrier__c, 'carrierQuoteId' => carrierQuoteId, 'highwayCarrierId' => load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c};
        }
        else{
            return new Map<String, String>{};
        }
    }
    
    @AuraEnabled
    public static List<User> getValidUsers() {
        List<User> users = [
        	SELECT Name, FirstName, LastName, Email
            FROM User
            WHERE IsActive = true
            AND (Email LIKE '%@openroad.inc' OR Email LIKE '%@openroadtrans.com' OR Email LIKE '%@openroadfs.com')
            ORDER BY Name
        ];
        Set<String> seen = new Set<String>();
        List<User> uniqueUsers = new List<User>();
        for (User u : users) {
            if (u.Email == null) continue;
            String key = u.Email.trim().toLowerCase();
            if (!seen.contains(key)) {
                seen.add(key);
                uniqueUsers.add(u);
            }
        }
        return uniqueUsers;
    }
    
    public static void setRateConStatus(Id loadId, String status){
        rtms__Load__c loadRecord = [SELECT Id, Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
        loadRecord.Secure_Rate_Con_Status__c = status;
        loadRecord.Secure_Rate_Con_Last_Update__c = System.now();
        UPDATE loadRecord;
    }

    public static Blob buildCancelRateCon(String fromWho, String loadId, String highwayCarrierId, Id contentVersionId, Id carrierQuoteId, String boundary){
        String crlf = '\r\n';
        ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        // String textParts = '--' + boundary + crlf +
        //     'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + fromWho + crlf +
        //     '--' + boundary + crlf +
        //     'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + carrierQuoteId + crlf +
        //     '--' + boundary + crlf +
        //     'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf + highwayCarrierId + crlf +
        //     '--' + boundary + crlf +
        //     'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf + loadId + crlf +
        //     '--' + boundary + crlf +
        //     'Content-Disposition: form-data; name="rate_confirmation[status]"' + crlf + crlf + 'cancelled' + crlf;
        
        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + carrierQuoteId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[status]"' + crlf + crlf + 'cancelled' + crlf;
        Blob headerBlob = Blob.valueOf(textParts);

        Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + cv.Title + '"' + crlf +
        'Content-Type: application/pdf' + crlf + crlf);

        Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);
        
        String hexHeaderBlob = EncodingUtil.convertToHex(headerBlob);
        String hexFileHeader = EncodingUtil.convertToHex(fileHeader);
        String hexClosing = EncodingUtil.convertToHex(closing);
        //String hexFileData = EncodingUtil.convertToHex(cv.VersionData);
        //Blob bodyBlob = EncodingUtil.convertFromHex(hexHeaderBlob + hexFileHeader + hexFileData + hexClosing);
        Blob bodyBlob = EncodingUtil.convertFromHex(hexHeaderBlob + hexFileHeader + hexClosing);
        return bodyBlob;
    }

    public static Blob buildRateCon(String fromWho, String subject, String loadId, String highwayCarrierId,  List<String> recipients, Id contentVersionId, Id carrierQuoteId, String boundary){
        String crlf = '\r\n';
        System.debug('in build rate con, querying for cv');
        ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        System.debug('Got cv');
        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + 'takunp@openroad.inc' + crlf +
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
        System.debug('combining blobs');
        String hexHeaderBlob = EncodingUtil.convertToHex(headerBlob);
        String hexFileHeader = EncodingUtil.convertToHex(fileHeader);
        String hexClosing = EncodingUtil.convertToHex(closing);
        String hexFileData = EncodingUtil.convertToHex(cv.VersionData);
        Blob bodyBlob = EncodingUtil.convertFromHex(hexHeaderBlob + hexFileHeader + hexFileData + hexClosing);
        System.debug('combined blobs');
        return bodyBlob;
    }
    
    @AuraEnabled
    public static Map<String,String> postToHighway(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel) {
        isCancel = true; //TODO: remove this line when testing is complete
        return doPost(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel);
    }

    
    public static Map<String, String> doPost(String fromWho, String subject, String loadId, String highwayCarrierId,  List<String> recipients, Id contentVersionId, Id carrierQuoteId, Boolean isCancel){
        System.debug('IN doPost');
        System.debug('fromWho: ' + fromWho);
        System.debug('subject: ' + subject);
        System.debug('loadId: ' + loadId);
        System.debug('highwayCarrierId: ' + highwayCarrierId);
        System.debug('recipients: ' + recipients); 
        System.debug('contentVersionId: ' + contentVersionId);
        System.debug('carrierQuoteId: ' + carrierQuoteId);
        System.debug('isCancel: ' + isCancel);
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        API_key__mdt ApiKey = [SELECT Api_Credential__c
            FROM API_key__mdt
            WHERE DeveloperName = 'HighwayStagingAPIKey'
            LIMIT 1];
        System.debug('got api key');
        String bearerToken = ApiKey.Api_Credential__c;
        Blob bodyBlob = null;
        if(isCancel){
            bodyBlob = buildCancelRateCon(fromWho, loadId, highwayCarrierId, contentVersionId, carrierQuoteId, boundary);
        }
        else{
            System.debug('building body');
            bodyBlob = buildRateCon(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
            System.debug('built body');
        }
        System.debug('building request');
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Authorization','Bearer ' + bearerToken);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);
        Http http = new Http();
        System.debug('built request');
        try {
            System.debug('sending request');
            HttpResponse res = http.send(req);
            System.debug('status code: ' + String.valueOf(res.getStatusCode()) + ':' + res.getBody());
            Map<String, String> result = new Map<String, String>{'statusCode' => String.valueOf(res.getStatusCode()), 'responseBody' => String.valueOf(res.getBody())};
            return result;
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
            Map<String, String> result = new Map<String, String>{'error' => String.valueOf(e.getMessage())};
            return result;
        }
    }    
    
    

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
}