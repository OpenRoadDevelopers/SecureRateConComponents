public class SecureRateConManager {
   
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
        return cv.Id;
  	}

	@AuraEnabled()
    public static Id isOnlyOneCarrierQuote(Id loadId) {
        List<rtms__CarrierQuote__c> cqs = [SELECT Id, rtms__Accepted__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :loadId];
        if(cqs.size() == 1){
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
            rtms__Load__c load = [SELECT Name, rtms__Carrier__c, rtms__Carrier__r.Name, rtms__Mode_Name__c, rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c  FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
            if(load.rtms__Carrier__c == null || load.Name == null || load.rtms__Mode_Name__c == null){
                return new Map<String, String>{'message: ' => 'No carrier id/ load name/ mode name available'};
            }
            else{
                String fileName = load.Name +  ' - ' + load.rtms__Carrier__r.Name + ' - ' + 'Carrier Rate and Load Confirmation.pdf';
                System.debug('fileName: ' + fileName);
                List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title = :fileName ORDER BY CreatedDate DESC LIMIT 1]; //TOOD may not need check this
                if(cvs.isEmpty()){
                    return new Map<String, String>{'message: ' => 'No file available'};
                }
                else{
                    return new Map<String, String>{'contentVersionId' => cvs[0].Id, 'carrierId' => load.rtms__Carrier__c, 'carrierQuoteId' => carrierQuoteId, 'highwayCarrierId' => load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c};
                }
            }
        }
        else{
            return new Map<String, String>{'message: ' => 'No Quote accepted'};
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
    
    
    
    @AuraEnabled
    public static String highwayRateConAPI(String fromWho, String subject, String loadId, String highwayCarrierId,  List<String> recipients, Id contentVersionId){
        
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String crlf = '\r\n';
        API_key__mdt ApiKey = [SELECT Api_Credential__c
            FROM API_key__mdt
            WHERE DeveloperName = 'HighwayStagingAPIKey'
            LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;
        ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + 'takunp@openroad.inc' + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + '51661' + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf + highwayCarrierId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf + loadId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf + subject + crlf +
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
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Authorization','Bearer ' + bearerToken);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('status code: ' + String.valueOf(res.getStatusCode()) + ':' + res.getBody());
            return (String.valueOf(res.getStatusCode()) + ':' + res.getBody());
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
            return ('Callout error: ' + e.getMessage());
        }
    }
    
    
}