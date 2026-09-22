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

    @InvocableMethod(label='Post Rate Con to Highway')
    public static List<FlowPostResponse> flowPostToHighway(List<FlowPostRequest> requests){ 
        if(ORD_Trigger_Control__c.getOrgDefaults().Disable_Flow_Secure_Rate_Con__c){
            List<FlowPostResponse> responses = new List<FlowPostResponse>();
            responses.add(new FlowPostResponse('411', 'disabled by trigger control'));
            return responses;
        }
        List<FlowPostResponse> responses = new List<FlowPostResponse>();
        for(FlowPostRequest r : requests){
            if(r.carrierQuoteId == null){
                rtms__CarrierQuote__c cq = SecureRateConManager.getCarrierQuote(r.isCancel, r.loadId);
                 if(cq == null){
                    responses.add(new FlowPostResponse('413', 'CarrierQuoteId Not found for ' + r.loadId));
                    return responses;
                }
                if(cq.Secure_Rate_Con_Cancelled_Rejected__c != null){
                    responses.add(new FlowPostResponse('412', 'Carrier Quote Already Cancelled/Rejected'));
            		return responses;
                }
                if(r.isCancel){
                    if(cq.Secure_Rate_Con_Status__c == 'cancelled'){
                        continue; //skip if already cancelled
                    }
                    if(cq.Secure_Rate_Con_Status__c == 'rejected'){
                        responses.add(new FlowPostResponse('204', 'CarrierQuote is already rejected no cancel request sent' + r.loadId));
                        continue; 
                    }
                }
                
                r.carrierQuoteId = cq.Id;
            }
            Id contentVersionId;
            if(!r.isCancel){
               Blob pdf = null;
               try{
                if (Test.isRunningTest()) {
                    pdf = Blob.valueOf('TEST PDF PLACEHOLDER');
                }
                else{
                    PageReference pr = Page.ORCarrierRateConfirmation3;
                    pr.getParameters().put('id', String.valueOf(r.loadId));
                    pr.getParameters().put('isSecureRateCon', 'true');
                    pr.getParameters().put('carrierQuoteId', String.valueOf(r.carrierQuoteId));
                    pdf = pr.getContentAsPDF();
                    if (pdf == null || pdf.size() < 200) {
                        responses.add(new FlowPostResponse('415', 'Empty or too-small PDF for ' + r.loadId));
                        return responses;
                    }
                }
                
                } catch (Exception ex) {
                    if (ex instanceof ORCarrierRateConfirmationController.CarrierQuoteNotFoundException) {
                        responses.add(new FlowPostResponse('413', 'CarrierQuoteId Not found for ' + r.loadId));
                        return responses; // or continue, depending on desired flow
                    }
                    responses.add(new FlowPostResponse('416', 'Failed to generate rate confirmation PDF for ' + r.loadId));
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
                Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
                insert new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = (Id)r.loadId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                contentVersionId = cv.Id;
            }
            System.enqueueJob(new HighwayCalloutJob(contentVersionId, r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, r.carrierQuoteId, r.isCancel));
            responses.add(new FlowPostResponse('queued', String.valueOf(contentVersionId)));
        }
       return responses;
    }
}