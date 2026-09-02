public class FlowSecureRateCon {
	public class FlowPostRequest {
        @InvocableVariable(required=true) public String fromWho;
        @InvocableVariable public String subject;
        @InvocableVariable public String loadId;
        @InvocableVariable public String highwayCarrierId;
        @InvocableVariable public List<String> recipients;
        @InvocableVariable public Boolean isCancel;
    }

    public class FlowPostResponse {
        @InvocableVariable public String statusCode;
        @InvocableVariable public String responseBody;
        public FlowPostResponse(String code, String body){ statusCode = code; responseBody = body; }
    }
    
    public static Map<String,String> doPostWithPdf(String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Blob pdfBlob, String fileName, Id carrierQuoteId, Boolean isCancel){
        System.debug('IN doPostWithPdf');
        System.debug('fromWho: ' + fromWho);
        System.debug('subject: ' + subject);
        System.debug('loadId: ' + loadId);
        System.debug('highwayCarrierId: ' + highwayCarrierId);
        System.debug('recipients: ' + recipients); 
        System.debug('pdfBlob: ' + pdfBlob);
        System.debug('fileName: ' + fileName);
        System.debug('carrierQuoteId: ' + carrierQuoteId);
        System.debug('isCancel: ' + isCancel);
        String crlf = '\r\n';
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        String textParts = '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[broker_load_owner_email]"' + crlf + crlf + fromWho + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_id]"' + crlf + crlf + carrierQuoteId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[carrier_id]"' + crlf + crlf + highwayCarrierId + crlf +
            '--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[external_load_id]"' + crlf + crlf + loadId + crlf;

        if (!String.isBlank(subject)) {
            textParts += '--' + boundary + crlf +
                'Content-Disposition: form-data; name="rate_confirmation[subject]"' + crlf + crlf + subject + crlf;
        }
        if (recipients != null && recipients.size() > 0) {
            // join recipients by comma (adjust if API expects different format)
            textParts += '--' + boundary + crlf +
                'Content-Disposition: form-data; name="rate_confirmation[targeted_emails]"' + crlf + crlf + String.join(recipients, ',') + crlf;
        }
        if (isCancel) {
            textParts += '--' + boundary + crlf +
                'Content-Disposition: form-data; name="rate_confirmation[status]"' + crlf + crlf + 'cancelled' + crlf;
        }

        Blob headerBlob = Blob.valueOf(textParts);

        Blob fileHeader = Blob.valueOf('--' + boundary + crlf +
            'Content-Disposition: form-data; name="rate_confirmation[attachments][]"; filename="' + fileName + '"' + crlf +
            'Content-Type: application/pdf' + crlf + crlf);

        Blob closing = Blob.valueOf(crlf + '--' + boundary + '--' + crlf);

        String hexHeader = EncodingUtil.convertToHex(headerBlob);
        String hexFileHeader = EncodingUtil.convertToHex(fileHeader);
        String hexPdf = EncodingUtil.convertToHex(pdfBlob);
        String hexClosing = EncodingUtil.convertToHex(closing);
        Blob bodyBlob = EncodingUtil.convertFromHex(hexHeader + hexFileHeader + hexPdf + hexClosing);

        // Get bearer token (same metadata lookup used elsewhere)
        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;
		System.debug('blob built');
        System.debug('starting request');
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Authorization','Bearer ' + bearerToken);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);

        Http http = new Http();
        HttpResponse res = null;
        try {
            System.debug('doPostWithPdf: endpoint=' + req.getEndpoint());
            System.debug('doPostWithPdf: Content-Type=' + req.getHeader('Content-Type'));
            System.debug('doPostWithPdf: pdfBlob size (bytes)=' + (pdfBlob == null ? 0 : pdfBlob.size()));
            req.setTimeout(120000);
            res = http.send(req);
            if (res == null) {
                System.debug('doPostWithPdf: http.send returned NULL response');
                return new Map<String,String>{ 'error' => 'http.send returned null response' };
            }
            System.debug('doPostWithPdf: statusCode=' + String.valueOf(res.getStatusCode()));
            System.debug('doPostWithPdf: status=' + res.getStatus());
            // log response headers
            for (String h : res.getHeaderKeys()) {
                System.debug('doPostWithPdf: resp header ' + h + ' = ' + res.getHeader(h));
            }
            String respBody = null;
            try { respBody = res.getBody(); } catch(Exception be) { System.debug('doPostWithPdf: getting body threw: ' + be); }
            System.debug('doPostWithPdf: response body length = ' + (respBody == null ? 0 : respBody.length()));
        } catch (Exception e) {
            System.debug('doPostWithPdf: callout exception: ' + e);
            return new Map<String,String>{ 'error' => e.getMessage() };
        }

        // After callout completes, insert ContentVersion and link (DML now allowed)
        System.debug('content version creating');
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = pdfBlob
        );
        insert cv;
        System.debug('cv id created: ' + cv.Id);

        Id contentVersionId = cv.Id;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId].ContentDocumentId;
        System.debug('creating new content document link...');
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = (Id)loadId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        System.debug('created new contentDocumentLink: ');

        String statusCode = (res == null) ? null : String.valueOf(res.getStatusCode());
        String responseBody = (res == null) ? null : (res.getBody() == null ? null : res.getBody());

        return new Map<String,String>{
            'statusCode' => statusCode,
            'responseBody' => responseBody,
            'contentVersionId' => String.valueOf(contentVersionId)
        };
    }

    @InvocableMethod(label='Post Rate Con to Highway')
    public static List<FlowPostResponse> flowPostToHighway(List<FlowPostRequest> requests){ 
        List<FlowPostResponse> responses = new List<FlowPostResponse>();
        for(FlowPostRequest r : requests){
            Id carrierQuoteId = SecureRateConManager.isCarrierQuoteAccepted(r.loadId);
            System.debug('carrierQuoteId: ' + carrierQuoteId);
            if(carrierQuoteId == null){
                System.debug('carrier quote not found');
                responses.add(new FlowPostResponse('444', 'CarrierQuoteId Not found for ' + r.loadId));
                return responses;
            }
            PageReference pr = Page.ORCarrierRateConfirmation3;
            pr.getParameters().put('id', String.valueOf(r.loadId));
            pr.getParameters().put('isSecureRateCon', 'true');
            pr.getParameters().put('carrierQuoteId', String.valueOf(carrierQuoteId));
            Blob pdf = pr.getContentAsPDF();

            rtms__Load__c load = [SELECT Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Id = :r.loadId LIMIT 1];
            String fileName = load.Name +  ' - ' + load.Carrier_Name__c +  ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf';
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = pdf
            );
            insert cv;
			System.debug('doPostWithPDF called');
            //Map<String, String> res = doPostWithPdf(r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, pdf, fileName, carrierQuoteId, r.isCancel);
            highwayCallout(cv.Id, r.fromWho, r.subject, r.loadId, r.highwayCarrierId, r.recipients, carrierQuoteId, r.isCancel);
            responses.add(new FlowPostResponse('queued', String.valueOf(cv.Id)));
            // System.debug('res status code: ' + res.get('statusCode') + ' responsebody: ' + res.get('responseBody'));
            // responses.add(new FlowPostResponse(res.get('statusCode'), res.get('responseBody')));
        }
       return responses;
    }
    
    @future(callout=true)
    private static void highwayCallout(Id contentVersionId, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id carrierQuoteId, Boolean isCancel) {
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Blob bodyBlob;
        if (isCancel) {
            bodyBlob = SecureRateConManager.buildCancelRateCon(fromWho, loadId, highwayCarrierId, contentVersionId, carrierQuoteId, boundary);
        } else {
            bodyBlob = SecureRateConManager.buildRateCon(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary);
        }

        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://staging.highway.com/core/connect/external_api/v1/rate_confirmations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Accept', 'application/json');
        req.setBodyAsBlob(bodyBlob);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = (Id)loadId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        } catch (Exception e) {
            System.debug('HighwayCalloutJob callout error: ' + e);
        }
    }
}