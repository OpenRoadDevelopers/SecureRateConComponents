@isTest
private class HighwayCalloutJobTest {
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        MockHttpResponseGenerator(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    private static void createBasicData() {
       rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-TEST');
        insert tp;

        Account acc = new Account(Name = 'Flow Carrier', rtms__Transportation_Profile__c = tp.Id);
        insert acc;

        rtms__Mode__c truckLoadRecord = new rtms__Mode__c(
            Name = 'TruckLoad',
            rtms__Order__c = 1,
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0
        );
        insert truckLoadRecord;

        rtms__Load__c load = new rtms__Load__c(
            Name = 'HC Job Load',
            rtms__Customer__c=acc.Id, 
            rtms__Carrier__c = acc.Id,
            rtms__Total_Weight__c = 0,
            rtms__Mode__c = truckLoadRecord.Id,
            rtms__Load_Status__c = 'Quotes Received',
            Require_Secure_Rate_Con__c = false
        );
        insert load;

        rtms__CarrierService__c carrierService = new rtms__CarrierService__c(
            Name='Test Carrier Service',
            rtms__Carrier__c = acc.Id,
            rtms__Transportation_Profile__c = tp.Id,
            rtms__Mode__c = truckLoadRecord.Id,
            rtms__Service_Type__c = 'Carrier',
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0,
            rtms__Weight_Units__c = 'kg',
            rtms__Quote_Method__c = 'Email',
            rtms__Tender_Method__c = 'Email'
        );
        insert carrierService;

        rtms__CarrierQuote__c cq = new rtms__CarrierQuote__c(
            Secure_Rate_Con_Status__c = 'delivered',
            rtms__Load__c = load.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id,
            rtms__Accepted__c = true
        );
        insert cq;

        // create a ContentVersion to pass to the job
        ContentVersion cv = new ContentVersion(
            Title = 'Test.pdf',
            PathOnClient = 'Test.pdf',
            VersionData = Blob.valueOf('PDF-DUMMY')
        );
        insert cv;
    }

    @isTest static void testExecute_successfulCallout_keepsCarrierQuoteStatus() {
        createBasicData();

        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c, Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        // Mock a successful HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));

        // Enqueue the job
        Test.startTest();
            System.enqueueJob(new HighwayCalloutJob(cv.Id, 'from@test.com', 'sub', String.valueOf(cq.rtms__Load__c), 'HC-TEST', new List<String>{'a@b.com'}, cq.Id, false));
        Test.stopTest();

        // CarrierQuote status should remain unchanged for 200
        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('delivered', updated.Secure_Rate_Con_Status__c, 'CarrierQuote status should remain delivered on 200 response');
    }

    @isTest static void testExecute_non2xx_updatesCarrierQuoteToFailed() {
        createBasicData();

        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c, Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        // Mock a server error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'server error'));

        // Enqueue the job
        Test.startTest();
            System.enqueueJob(new HighwayCalloutJob(cv.Id, 'from@test.com', 'sub', String.valueOf(cq.rtms__Load__c), 'HC-TEST', new List<String>{'a@b.com'}, cq.Id, false));
        Test.stopTest();

        // CarrierQuote status should be set to 'failed' by handleStatus
        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('failed', updated.Secure_Rate_Con_Status__c, 'CarrierQuote status should be set to failed on non-2xx response');
    }
}