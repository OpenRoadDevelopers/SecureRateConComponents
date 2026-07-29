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
        load.rtms__Carrier__c = carrierId;
        update load;
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
    	String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load ConfirmationTesting123.pdf';        
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
    public static String launchEmailFlow(String fromWho, String subject, String body, String templateName, String loadId, String userId, Id carrierId,  List<String> recipients, Id contentVersionId){
        try{
            String status = '';
            String replacedBody = body;
            //make sure this is set as first
            Map<String, Object> flowInputs = new Map<String, Object>{
                'FromWho' => fromWho,
                'ToList' => 'takunp@openroad.inc',
                'CCList' => null,
                'BCCList' => null,
                'EmailSubject' => subject,
                'EmailBody' => replacedBody,
                'TemplateName' => templateName,
                'ContentVersionId' => contentVersionId
            };
            if(Test.isRunningTest()){
                status = 'MOCK_STATUS ' + flowInputs.get('EmailBody');//have this returned for a test to check the email Body
            }
            else{
                Flow.Interview.OR_Custom_LWC_Email flowInterview = new Flow.Interview.OR_Custom_LWC_Email(flowInputs);
                flowInterview.start();
                status = (String)flowInterview.getVariableValue('Status');  
            }
            // if(status == 'SUCCESS' || Test.isRunningTest()){
            //     OpenRoad_Message__c newORMessage = new OpenRoad_Message__c();
            //     newORMessage.Message_Type__c = 'Carrier Secure Rate Con'; 
            //     newORMessage.Quote_Received__c = null; 
            //     newORMessage.Related_Load__c = loadId; 
            //     newORMessage.Sent_By__c = userId;
            //     newORMessage.Sent_Date_Time__c = Datetime.now();
            //     newORMessage.Sent_To_Account__c = carrierId; 
            //     newORMessage.Sent_To_Email__c = recipient;
            //     newORMessage.Sent_To_Phone_Number__c = null;
            //     newORMessage.Sent_Via__c = 'Email';   
            //     try{
            //         insert newORMessage;
            //     } catch (DMLException e){
            //         System.debug('Error creating Contact: ' + e.getMessage());
            //         return 'FAIL: Error creating Contact: ' + e.getMessage();
            //     }
            // }
            // else{//failed 
            //     System.debug('The flow has failed');
            //     return 'The flow has failed';
            // }
            return status != null ? status : 'SUCCESS';
        }catch (Exception e){
            System.debug('Flow error: ' + e.getMessage());
            return 'Flow error: ' + e.getMessage();
        }
    }
    
    
}