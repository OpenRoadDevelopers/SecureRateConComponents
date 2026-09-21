public class FlowSecureRateCon {
	public class FlowPostRequest {
        @InvocableVariable public String fromWho;
        @InvocableVariable public String subject;
        @InvocableVariable public String loadId;
        @InvocableVariable public String highwayCarrierId;
        @InvocableVariable public List<String> recipients;
        @InvocableVariable public Boolean isCancel;
        @InvocableVariable public Id carrierQuoteId;
    }

    public class FlowPostResponse {
        @InvocableVariable public String statusCode;
        @InvocableVariable public String responseBody;
        public FlowPostResponse(String code, String body){ statusCode = code; responseBody = body; }
    }
    
    // public static rtms__CarrierQuote__c getCarrierQuote(Boolean isCancel, Id loadId){
    //     // System.debug('IN getCarrierQuote params: ' + isCancel + ' loadId: ' + loadId);
    //     if(isCancel){
    //         // System.debug('calling get recent secure carrier quote');
    //         return SecureRateConManager.getRecentSecureCarrierQuote(loadId);
    //     }
    //     else{
    //         // System.debug('is carrier quote accepted check');
    //         return SecureRateConManager.isCarrierQuoteAccepted(loadId);    
    //     }
    // }

    @InvocableMethod(label='Post Rate Con to Highway')
    public static List<FlowPostResponse> flowPostToHighway(List<FlowPostRequest> requests){ 
        // System.debug('IN flowPostToHighway');
        // System.debug('requests: ' + requests);
        if(ORD_Trigger_Control__c.getOrgDefaults().Disable_Flow_Secure_Rate_Con__c){
            List<FlowPostResponse> responses = new List<FlowPostResponse>();
            responses.add(new FlowPostResponse('444', 'disabled by trigger control'));
            return responses;
        }
        List<FlowPostResponse> responses = new List<FlowPostResponse>();
        for(FlowPostRequest r : requests){
            // System.debug('request: ' + requests);
            // System.debug('carrier quote id: ' + r.carrierQuoteId);
            if(r.carrierQuoteId == null){
                // System.debug('did not find the carrier quote id looking for now...');
                rtms__CarrierQuote__c cq = SecureRateConManager.getCarrierQuote(r.isCancel, r.loadId);
                // System.debug('got cq: ' + cq);
                // System.debug('cq rate con status: ' + cq.Secure_Rate_Con_Status__c);
                // System.debug('cq secure rate con cancelled date time: ' + cq.Secure_Rate_Con_Cancelled_Rejected__c);
                if(cq.Secure_Rate_Con_Cancelled_Rejected__c != null){
                    // System.debug('Found this case: Carrier Quote Already Cancelled/Rejected');
                    responses.add(new FlowPostResponse('444', 'Carrier Quote Already Cancelled/Rejected'));
            		return responses;
                }
                if(cq == null || cq.Id == null){
                    // System.debug('carrier quote not found');
                    responses.add(new FlowPostResponse('444', 'CarrierQuoteId Not found for ' + r.loadId));
                    return responses;
                }
                if(r.isCancel){
                    if(cq.Secure_Rate_Con_Status__c == 'cancelled'){
                        continue; //skip if already cancelled
                    }
                    if(cq.Secure_Rate_Con_Status__c == 'rejected'){
                        // System.debug('status is rejected skip sending to highway.');
                        responses.add(new FlowPostResponse('204', 'CarrierQuote is already rejected no cancel request sent' + r.loadId));
                        continue; //skip if already rejected
                    }
                }
                
                r.carrierQuoteId = cq.Id;
            }
            Id contentVersionId;
            if(!r.isCancel){
               Blob pdf = null;
               try{
                    PageReference pr = Page.ORCarrierRateConfirmation3;
                    pr.getParameters().put('id', String.valueOf(r.loadId));
                    pr.getParameters().put('isSecureRateCon', 'true');
                    pr.getParameters().put('carrierQuoteId', String.valueOf(r.carrierQuoteId));
                    pdf = pr.getContentAsPDF();
                   	// System.debug('pdf: ' + pdf);
                   if (pdf == null || pdf.size() < 200) {
                       	// System.debug('PDF is too small or null');
                        responses.add(new FlowPostResponse('444', 'Empty or too-small PDF for ' + r.loadId));
                        return responses;
                    }
                } catch (Exception ex) {
                    // System.debug('*** message: ' + ex.getMessage());
                    // System.debug('*** stack: ' + ex.getStackTraceString());
                    if (ex instanceof ORCarrierRateConfirmationController.CarrierQuoteNotFoundException) {
                        // System.debug('Failed to generate rate confirmation PDF: ' + ex);
                        responses.add(new FlowPostResponse('444', 'CarrierQuoteId Not found for ' + r.loadId));
                        return responses; // or continue, depending on desired flow
                    }
                    // System.debug('Failed to generate rate confirmation PDF: ' + ex);
                    responses.add(new FlowPostResponse('444', 'Failed to generate rate confirmation PDF for ' + r.loadId));
                    return responses;
                }
    
                rtms__Load__c load = [SELECT Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :r.loadId LIMIT 1];
                String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';
                ContentVersion cv = new ContentVersion(
                    Title = fileName,
                    PathOnClient = fileName,
                    VersionData = pdf
                );
                insert cv;
                // Create ContentDocumentLink so file is attached to the Load
                Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
                insert new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = (Id)r.loadId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                contentVersionId = cv.Id;
            }
           
            //Map<String, String> res = doPostWithPdf(r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, pdf, fileName, carrierQuoteId, r.isCancel);
            System.enqueueJob(new HighwayCalloutJob(contentVersionId, r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, r.carrierQuoteId, r.isCancel));
            //highwayCallout(cv.Id, r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, carrierQuoteId, r.isCancel);
            responses.add(new FlowPostResponse('queued', String.valueOf(contentVersionId)));
            //System.debug('res status code: ' + res.get('statusCode') + ' responsebody: ' + res.get('responseBody'));
            // responses.add(new FlowPostResponse(res.get('statusCode'), res.get('responseBody')));
        }
       return responses;
    }
    
    // @future(callout=true)
//     private static void highwayCallout(Id contentVersionId, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id carrierQuoteId, Boolean isCancel) {
//         String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
//         Blob bodyBlob;
//         if (isCancel) {
//             bodyBlob = SecureRateConManager.buildCancelRateCon(fromWho, loadId, highwayCarrierId, contentVersionId, carrierQuoteId, boundary);
//         } else {
//             bodyBlob = SecureRateConManager.buildRateCon(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
//         }

//         API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
//         String bearerToken = ApiKey.Api_Credential__c;

//         HttpRequest req = new HttpRequest();
//         req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
//         req.setMethod('POST');
//         req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
//         req.setHeader('Authorization', 'Bearer ' + bearerToken);
//         req.setHeader('Accept', 'application/json');
//         req.setBodyAsBlob(bodyBlob);

//         Http http = new Http();
//         try {
//             HttpResponse res = http.send(req);
//             System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
//             Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1].ContentDocumentId;
//             insert new ContentDocumentLink(
//                 ContentDocumentId = contentDocumentId,
//                 LinkedEntityId = (Id)loadId,
//                 ShareType = 'V',
//                 Visibility = 'AllUsers'
//             );
//         } catch (Exception e) {
//             System.debug('HighwayCalloutJob callout error: ' + e);
//         }
//     }
}