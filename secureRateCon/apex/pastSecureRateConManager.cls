public class SecureRateConManager {
   
    
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
    public static void emailLoadPdf(String toAddress, Id loadId) {
      PageReference pr = Page.ORCarrierRateConfirmation3;
      pr.getParameters().put('id', String.valueOf(loadId));
      Blob pdf = pr.getContentAsPDF();
    
      Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
      efa.setFileName('Load2.pdf');
      efa.setBody(pdf);
    
      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new String[]{ toAddress });
      mail.setSubject('Load PDF');
      mail.setPlainTextBody('See attached');
      mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ efa });
      Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
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
    public static rtms__CarrierQuote__c getCarrierQuote(Id carrierQuoteId) {
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
        if(carrierQuoteId != null){
            rtms__Load__c load = [SELECT Name, rtms__Carrier__c, rtms__Carrier__r.Name, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :loadId LIMIT 1];
            if(load.rtms__Carrier__c == null || load.Name == null || load.rtms__Mode_Name__c == null){
                return new Map<String, String>();
            }
            else{
                String fileName = load.Name +  ' - ' + load.rtms__Carrier__r.Name +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';
                List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title = :fileName ORDER BY CreatedDate DESC LIMIT 1];
                if(cvs.isEmpty()){
                    return new Map<String, String>();
                }
                else{
                    return new Map<String, String>{'contentVersionId' => cvs[0].Id, 'carrierId' => load.rtms__Carrier__c, 'carrierQuoteId' => carrierQuoteId};
                }
                
            }
        }
        else{
            return new Map<String, String>();
        }
    }


    @AuraEnabled()
    public static List<String> getCarrierEmails(Id accountId){
        List<AggregateResult> ars = [
          SELECT Email
          FROM Contact
          WHERE AccountId = :accountId
            AND rtms__Transportation_Role__c INCLUDES ('Quoting')
            AND Email != null
          GROUP BY Email
        ];
        List<String> uniqueEmails = new List<String>();
        for (AggregateResult ar : ars) {
          uniqueEmails.add(((String) ar.get('Email')).trim().toLowerCase());
        }
        return uniqueEmails;
    }
    
    @AuraEnabled(cacheable=true)
    public static EmailTemplate getTenderTemplate(Id recordId){
        EmailTemplate emailTemp = [SELECT Id, Name, Subject, TemplateType, Body From EmailTemplate WHERE Name='Load Tender'];       	
        List<rtms__Stop__c> stops = [SELECT rtms__Is_Pickup__c, rtms__Location2__r.Shipping_City_and_State__c, rtms__Appointment_Time__c, rtms__Expected_Date__c FROM rtms__Stop__c WHERE rtms__Load__c = :recordId];
        Messaging.SingleEmailMessage renderedEmail = Messaging.renderStoredEmailTemplate(emailTemp.Id, null, recordId);//contact id should be the carriers contact id
        String renderedSubject = renderedEmail.getSubject();
        emailTemp.Subject = renderedSubject;
        emailTemp.Body = renderedEmail.htmlBody; 
        return emailTemp;
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
    public static String launchEmailFlow(String fromWho, String subject, String loadId, Id highwayCarrierId,  List<String> recipients, Id contentVersionId){
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String crlf = '\r\n';
        string bearerToken = 'eyJraWQiOiJmYmE1ZDA2ZmM5MzIxMTYxOGNjYmMyNGU1MjA0YjNiNTNlYzhlODNlNTdjYzBkNWE1NmQ4NTY4MjY0OWE5MmUxIiwiYWxnIjoiUlMyNTYifQ.eyJVSWQiOiIyNzU0NCIsImlzX2FjdGl2ZSI6dHJ1ZSwiaXNfYXBpX2tleSI6dHJ1ZSwiaWF0IjoxNzg2MTMzMDEzLCJyYW5kIjoiNzQ2YjI2ZDVjOGRhNmFmZDA0OGRhMzU0ZjA3ZDE0YmMiLCJleHAiOjE4NDkyMDUwMTMsImlzcyI6Imh0dHBzOi8vc3RhZ2luZy5oaWdod2F5LmNvbSIsImV4dGVybmFsX3Byb3ZpZGVyIjpudWxsLCJjb25uZWN0X2ludGVncmF0aW9uX2lkIjpudWxsfQ.Bweby57-SBAgQ1ocxqmtY-_1rov6E40NI3wDF1_sra631gM9P02XEeEZSHD9bo04w9zhU3FNhGuuGPjtKee5YpsU7mHCe6FbA7u2SXcejyln9PYAu9SfLQyOKqW4ypZ71TjRjy1NNDskEJtiq-uE0cw3GxXtkCxsDpBXF-cT7ZDSF5w-Q5coDJw6BSac0bPMkIvuJv2L1BarRUuSuDBOgkOLzAPsIkk9RISAOIdQwy3tAfOJHmxZ-bZILZ5tMhVFOX3lhDjGrGaHbcwskdkFR8FSAs2kB_BvNuF8BeZaEqayFVs3KveFgoFDtn7beLbDiogct_JyY07fXHWKu88nGpmHmaQETarRVXYpUCbCk7GY0yIrKTKkEOsscep83Edzxdo6q4_87oZW5fItNLl48qpnRQQI7PCmqGE78OI3wZft47lAgNHo731_LR-iC1lgoFdW7z9E3IyDj99WCmqORg59U-i5Xd6DNMZL5eRUXyAno_sW62IzHOhIQyzWIS_dytQ0DpU-QAWHCfTJrOm4aiDTz_oC6RloI18VMoCG3rTaO-yGC7dXtKk5Mom80kO1xD5eutclLj1moWrbgPNc5Ud0TfoJaigJZ1e0ClTGn0ZZEwA0GrF0tfnZxg7l7y0TnAaDfxx1JdssaS6NLahELuQyqlOqhQrhbv9Yvv1lQE4';
        ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        String textParts = '--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + fromWho + crlf +
        '--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + '51661' + crlf +
        '--' + boundary + crlf;
        Blob headerBlob = Blob.valueOf(textParts);

        Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
        'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + cv.Title + '"' + crlf +
        'Content-Type: application/pdf' + crlf + crlf);

        Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);

        // assemble: header + file bytes + closing
        // Blob bodyBlob = Blob.concat(Blob.concat(headerBlob, fileHeader), Blob.concat(cv.VersionData, closing) );
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














 
System.debug('test');
ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = '068Ea00000K8UzyIAF' LIMIT 1];
rtms__Load__c load = [SELECT rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c FROM rtms__Load__c WHERE Id = 'a0jNr000002mqmLIAQ'];
String highwayCarrierId = load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c;
String fileName = cv.Title;
String fileBase64 = EncodingUtil.base64Encode(cv.VersionData);
String boundary = '------------------------' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
String crlf = '\r\n';
string bearerToken = 'eyJraWQiOiJmYmE1ZDA2ZmM5MzIxMTYxOGNjYmMyNGU1MjA0YjNiNTNlYzhlODNlNTdjYzBkNWE1NmQ4NTY4MjY0OWE5MmUxIiwiYWxnIjoiUlMyNTYifQ.eyJVSWQiOiIyNzU0NCIsImlzX2FjdGl2ZSI6dHJ1ZSwiaXNfYXBpX2tleSI6dHJ1ZSwiaWF0IjoxNzg2MTMzMDEzLCJyYW5kIjoiNzQ2YjI2ZDVjOGRhNmFmZDA0OGRhMzU0ZjA3ZDE0YmMiLCJleHAiOjE4NDkyMDUwMTMsImlzcyI6Imh0dHBzOi8vc3RhZ2luZy5oaWdod2F5LmNvbSIsImV4dGVybmFsX3Byb3ZpZGVyIjpudWxsLCJjb25uZWN0X2ludGVncmF0aW9uX2lkIjpudWxsfQ.Bweby57-SBAgQ1ocxqmtY-_1rov6E40NI3wDF1_sra631gM9P02XEeEZSHD9bo04w9zhU3FNhGuuGPjtKee5YpsU7mHCe6FbA7u2SXcejyln9PYAu9SfLQyOKqW4ypZ71TjRjy1NNDskEJtiq-uE0cw3GxXtkCxsDpBXF-cT7ZDSF5w-Q5coDJw6BSac0bPMkIvuJv2L1BarRUuSuDBOgkOLzAPsIkk9RISAOIdQwy3tAfOJHmxZ-bZILZ5tMhVFOX3lhDjGrGaHbcwskdkFR8FSAs2kB_BvNuF8BeZaEqayFVs3KveFgoFDtn7beLbDiogct_JyY07fXHWKu88nGpmHmaQETarRVXYpUCbCk7GY0yIrKTKkEOsscep83Edzxdo6q4_87oZW5fItNLl48qpnRQQI7PCmqGE78OI3wZft47lAgNHo731_LR-iC1lgoFdW7z9E3IyDj99WCmqORg59U-i5Xd6DNMZL5eRUXyAno_sW62IzHOhIQyzWIS_dytQ0DpU-QAWHCfTJrOm4aiDTz_oC6RloI18VMoCG3rTaO-yGC7dXtKk5Mom80kO1xD5eutclLj1moWrbgPNc5Ud0TfoJaigJZ1e0ClTGn0ZZEwA0GrF0tfnZxg7l7y0TnAaDfxx1JdssaS6NLahELuQyqlOqhQrhbv9Yvv1lQE4';

String bodyString = '';
bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf;
bodyString += 'Takunp@openroad.inc' + crlf;



bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[targeted_emails][]"' + crlf + crlf;
bodyString += 'dot01006144@rates.staging.highway.com' + crlf;


bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf;
bodyString += 'test subject' + crlf;

bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf;
bodyString +=  '15161' + crlf;

bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf;
bodyString += (highwayCarrierId == null ? '' : String.valueOf(highwayCarrierId)) + crlf;

bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf;
bodyString += '068Ea00000K8UzyIAF' + crlf;

// file part as base64
bodyString += '--' + boundary + crlf;
bodyString += 'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + fileName + '"' + crlf;
bodyString += 'Content-Type: application/pdf' + crlf;
bodyString += 'Content-Transfer-Encoding: base64' + crlf + crlf;
bodyString += fileBase64 + crlf;

bodyString += '--' + boundary + '--' + crlf;

HttpRequest req = new HttpRequest();
req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + bearerToken);
req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
req.setHeader('Accept', 'application/json');
req.setBody(bodyString);

Http http = new Http();
try {
    HttpResponse res = http.send(req);
    System.debug('status code: ' + String.valueOf(res.getStatusCode()) + ':' + res.getBody());
} catch (Exception e) {
    System.debug('Callout error: ' + e.getMessage());
}












   // try{
        //     String status = '';
        //     String replacedBody = body;
        //     //make sure this is set as first
        //     Map<String, Object> flowInputs = new Map<String, Object>{
        //         'FromWho' => fromWho,
        //         'ToList' => new List<String>{'takunp@openroad.inc', 'dot2232591@rates.staging.highway.com', 'dot2232591@secure.highway.com', 'dot2232591@highway.com'},
        //         'CCList' => null,
        //         'BCCList' => null,
        //         'EmailSubject' => subject != null ? subject : 'OpenRoad Rate Con',
        //         'EmailBody' => replacedBody,
        //         'TemplateName' => templateName,
        //         'ContentVersionId' => contentVersionId
        //     };
        //     if(Test.isRunningTest()){
        //         status = 'MOCK_STATUS ' + flowInputs.get('EmailBody');//have this returned for a test to check the email Body
        //     }
        //     else{
        //         Flow.Interview.OR_Custom_LWC_Email flowInterview = new Flow.Interview.OR_Custom_LWC_Email(flowInputs);
        //         flowInterview.start();
        //         status = (String)flowInterview.getVariableValue('Status');  
        //     }
        //     return status != null ? status : 'SUCCESS';
        // }catch (Exception e){
        //     System.debug('Flow error: ' + e.getMessage());
        //     return 'Flow error: ' + e.getMessage();
        // }










ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = '068Ea00000K8UzyIAF' LIMIT 1];
rtms__Load__c load = [SELECT rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c FROM rtms__Load__c WHERE Id = 'a0jNr000002mqmLIAQ'];
String highwayCarrierId = load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c;
String fileName = cv.Title;
String base64Pdf = EncodingUtil.base64Encode(cv.VersionData);
String bearerToken = 'eyJraWQiOiJmYmE1ZDA2ZmM5MzIxMTYxOGNjYmMyNGU1MjA0YjNiNTNlYzhlODNlNTdjYzBkNWE1NmQ4NTY4MjY0OWE5MmUxIiwiYWxnIjoiUlMyNTYifQ.eyJVSWQiOiIyNzU0NCIsImlzX2FjdGl2ZSI6dHJ1ZSwiaXNfYXBpX2tleSI6dHJ1ZSwiaWF0IjoxNzg2MTMzMDEzLCJyYW5kIjoiNzQ2YjI2ZDVjOGRhNmFmZDA0OGRhMzU0ZjA3ZDE0YmMiLCJleHAiOjE4NDkyMDUwMTMsImlzcyI6Imh0dHBzOi8vc3RhZ2luZy5oaWdod2F5LmNvbSIsImV4dGVybmFsX3Byb3ZpZGVyIjpudWxsLCJjb25uZWN0X2ludGVncmF0aW9uX2lkIjpudWxsfQ.Bweby57-SBAgQ1ocxqmtY-_1rov6E40NI3wDF1_sra631gM9P02XEeEZSHD9bo04w9zhU3FNhGuuGPjtKee5YpsU7mHCe6FbA7u2SXcejyln9PYAu9SfLQyOKqW4ypZ71TjRjy1NNDskEJtiq-uE0cw3GxXtkCxsDpBXF-cT7ZDSF5w-Q5coDJw6BSac0bPMkIvuJv2L1BarRUuSuDBOgkOLzAPsIkk9RISAOIdQwy3tAfOJHmxZ-bZILZ5tMhVFOX3lhDjGrGaHbcwskdkFR8FSAs2kB_BvNuF8BeZaEqayFVs3KveFgoFDtn7beLbDiogct_JyY07fXHWKu88nGpmHmaQETarRVXYpUCbCk7GY0yIrKTKkEOsscep83Edzxdo6q4_87oZW5fItNLl48qpnRQQI7PCmqGE78OI3wZft47lAgNHo731_LR-iC1lgoFdW7z9E3IyDj99WCmqORg59U-i5Xd6DNMZL5eRUXyAno_sW62IzHOhIQyzWIS_dytQ0DpU-QAWHCfTJrOm4aiDTz_oC6RloI18VMoCG3rTaO-yGC7dXtKk5Mom80kO1xD5eutclLj1moWrbgPNc5Ud0TfoJaigJZ1e0ClTGn0ZZEwA0GrF0tfnZxg7l7y0TnAaDfxx1JdssaS6NLahELuQyqlOqhQrhbv9Yvv1lQE4';

Map<String, Object> rc = new Map<String, Object>{};
rc.put('attachments', new List<String>{ base64Pdf });
rc.put('external_id', '15161');
rc.put('carrier_id', highwayCarrierId);
rc.put('external_load_id', '068Ea00000K8UzyIAF');
rc.put('broker_load_owner_email', 'Takunp@openroad.inc');
rc.put('subject', 'test subject');

Map<String, Object> payload = new Map<String, Object>{};
payload.put('rate_confirmation', rc);
String jsonBody = JSON.serialize(payload);

HttpRequest req = new HttpRequest();
req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
req.setMethod('POST');
req.setHeader('Accept', 'application/json');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Authorization', 'Bearer ' + bearerToken);
req.setBody(jsonBody);

Http http = new Http();
HttpResponse res = http.send(req);
System.debug(res.getStatusCode() + ':' + res.getBody());









String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
String crlf = '\r\n';
string bearerToken = 'eyJraWQiOiJmYmE1ZDA2ZmM5MzIxMTYxOGNjYmMyNGU1MjA0YjNiNTNlYzhlODNlNTdjYzBkNWE1NmQ4NTY4MjY0OWE5MmUxIiwiYWxnIjoiUlMyNTYifQ.eyJVSWQiOiIyNzU0NCIsImlzX2FjdGl2ZSI6dHJ1ZSwiaXNfYXBpX2tleSI6dHJ1ZSwiaWF0IjoxNzg2MTMzMDEzLCJyYW5kIjoiNzQ2YjI2ZDVjOGRhNmFmZDA0OGRhMzU0ZjA3ZDE0YmMiLCJleHAiOjE4NDkyMDUwMTMsImlzcyI6Imh0dHBzOi8vc3RhZ2luZy5oaWdod2F5LmNvbSIsImV4dGVybmFsX3Byb3ZpZGVyIjpudWxsLCJjb25uZWN0X2ludGVncmF0aW9uX2lkIjpudWxsfQ.Bweby57-SBAgQ1ocxqmtY-_1rov6E40NI3wDF1_sra631gM9P02XEeEZSHD9bo04w9zhU3FNhGuuGPjtKee5YpsU7mHCe6FbA7u2SXcejyln9PYAu9SfLQyOKqW4ypZ71TjRjy1NNDskEJtiq-uE0cw3GxXtkCxsDpBXF-cT7ZDSF5w-Q5coDJw6BSac0bPMkIvuJv2L1BarRUuSuDBOgkOLzAPsIkk9RISAOIdQwy3tAfOJHmxZ-bZILZ5tMhVFOX3lhDjGrGaHbcwskdkFR8FSAs2kB_BvNuF8BeZaEqayFVs3KveFgoFDtn7beLbDiogct_JyY07fXHWKu88nGpmHmaQETarRVXYpUCbCk7GY0yIrKTKkEOsscep83Edzxdo6q4_87oZW5fItNLl48qpnRQQI7PCmqGE78OI3wZft47lAgNHo731_LR-iC1lgoFdW7z9E3IyDj99WCmqORg59U-i5Xd6DNMZL5eRUXyAno_sW62IzHOhIQyzWIS_dytQ0DpU-QAWHCfTJrOm4aiDTz_oC6RloI18VMoCG3rTaO-yGC7dXtKk5Mom80kO1xD5eutclLj1moWrbgPNc5Ud0TfoJaigJZ1e0ClTGn0ZZEwA0GrF0tfnZxg7l7y0TnAaDfxx1JdssaS6NLahELuQyqlOqhQrhbv9Yvv1lQE4';
ContentVersion cv = [SELECT Title, VersionData FROM ContentVersion WHERE Id = '068Ea00000K8UzyIAF' LIMIT 1];
rtms__Load__c load = [SELECT rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c FROM rtms__Load__c WHERE Id = 'a0jNr000002mqmLIAQ'];
String highwayCarrierId = load.rtms__Carrier__r.rtms__Transportation_Profile__r.Highway_Carrier_ID__c;
String textParts = '--' + boundary + crlf +
    'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + 'takunp@openroad.inc' + crlf +
    '--' + boundary + crlf +
    'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + '51661' + crlf +
    '--' + boundary + crlf +
    'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf + String.valueOf(highwayCarrierId) + crlf +
    '--' + boundary + crlf +
    'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf + '068Ea00000K8UzyIAF' + crlf +
    '--' + boundary + crlf +
    'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf + 'test subject' + crlf +
    '--' + boundary + crlf + 
    'Content-Disposition: form-data; name="rate_confirmation[targeted_emails]"' + crlf + crlf + 'dot01006144@rates.staging.highway.com' + crlf;
	
Blob headerBlob = Blob.valueOf(textParts);

Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
                               'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + cv.Title + '"' + crlf +
                               'Content-Type: application/pdf' + crlf + crlf);

Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);

// assemble: header + file bytes + closing
// Blob bodyBlob = Blob.concat(Blob.concat(headerBlob, fileHeader), Blob.concat(cv.VersionData, closing) );
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
    System.debug(String.valueOf(res.getStatusCode()) + ':' + res.getBody());
} catch (Exception e) {
    System.debug('Callout error: ' + e.getMessage());
    System.debug('Callout error: ' + e.getMessage());
}