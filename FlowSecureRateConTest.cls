@isTest
private class FlowSecureRateConTest {
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

    @isTest static void testFlowPostToHighway_nonCancel_queuesAndCreatesContentVersion() {
        // Arrange: create minimal data (transportation profile -> account(carrier) -> load -> accepted carrier quote)
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-001');
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
            Name = 'Flow NonCancel Load',
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
            Secure_Rate_Con_Last_Update__c = System.now(),
            rtms__Accepted__c = true
        );
        insert cq;

        // Ensure VF page is present as current page for getContentAsPDF call
        PageReference pr = Page.ORCarrierRateConfirmation3;
        Test.setCurrentPage(pr);

        // Provide a callout mock so the enqueued job can run without external HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));

        // Prepare flow request
        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.fromWho = 'from@t.test';
        req.subject = 'Test Subject';
        req.loadId = String.valueOf(load.Id);
        req.highwayCarrierId = tp.Highway_Carrier_ID__c;
        req.recipients = new List<String>{'a@b.com'};
        req.isCancel = false;
        req.carrierQuoteId = cq.Id;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };

        // Act
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();

        // Assert
        System.assertEquals(1, responses.size());
        System.assertEquals('queued', responses[0].statusCode);
        // responseBody should be a contentVersion id (string) when non-cancel
        System.assertNotEquals(null, responses[0].responseBody);
        // Confirm a ContentDocumentLink was created for this load
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :load.Id];
        System.assert(!links.isEmpty(), 'Expected ContentDocumentLink for non-cancel flow');
    }

    @isTest static void testFlowPostToHighway_cancel_queuesWithoutContentVersion() {
        // Arrange: create transport profile, account, load, accepted quote
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-001');
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
            Name = 'Flow NonCancel Load',
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
            Secure_Rate_Con_Last_Update__c = System.now(),
            rtms__Accepted__c = true
        );
        insert cq;

        // Provide a callout mock so the enqueued job can run if executed
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));

        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.fromWho = 'from@t.test';
        req.subject = 'Cancel Subject';
        req.loadId = String.valueOf(load.Id);
        req.highwayCarrierId = tp.Highway_Carrier_ID__c;
        req.recipients = null;
        req.isCancel = true;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };

        // Act
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();

        // Assert
        System.assertEquals(1, responses.size());
        System.assertEquals('queued', responses[0].statusCode);
        // For cancel, no ContentVersion should be created and responseBody should be 'null'
        System.assertEquals(null, responses[0].responseBody);
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :load.Id];
        System.assert(links.isEmpty(), 'No ContentDocumentLink should be created for cancel flow');
    }

    @isTest
    static void testFlowPostToHighway_triggerDisabled() {
        // Arrange: insert trigger-control record that disables the flow
        ORD_Trigger_Control__c control = new ORD_Trigger_Control__c();
        control.Disable_Flow_Secure_Rate_Con__c = true;
        insert control;

        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.fromWho = 'test@openroad.inc';
        req.subject = 'sub';
        req.loadId = 'dummy'; // value won't be used because trigger control short-circuits
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };

        // Act
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();

        // Assert
        System.assertEquals(1, responses.size());
        System.assertEquals('411', responses[0].statusCode);
        System.assertEquals('disabled by trigger control', responses[0].responseBody);
    }
    
    @isTest static void testCarrierQuoteAlreadyCancelledRejected_returns412() {
        ORD_Trigger_Control__c control = new ORD_Trigger_Control__c();
        control.Disable_Flow_Secure_Rate_Con__c = false;
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-001');
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
            Name = 'Flow NonCancel Load',
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
            Secure_Rate_Con_Last_Update__c = System.now(),
            rtms__Accepted__c = true, 
            Secure_Rate_Con_Cancelled_Rejected__c = System.now()
        );
        insert cq;

        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.loadId = String.valueOf(load.Id);
        req.isCancel = false;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };
    
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();
    
        System.assertEquals(1, responses.size());
        System.assertEquals('412', responses[0].statusCode);
        System.assert(responses[0].responseBody.contains('Carrier Quote Already Cancelled/Rejected'));
    }

    @isTest static void testCarrierQuoteNotFound_returns413() {
        ORD_Trigger_Control__c control = new ORD_Trigger_Control__c();
        control.Disable_Flow_Secure_Rate_Con__c = false;
        insert control;
        Account acc = new Account(Name = 'Flow Carrier');
        insert acc;

        rtms__Load__c load = new rtms__Load__c(Name='Load413', rtms__Carrier__c = acc.Id, rtms__Customer__c = acc.Id, rtms__Total_Weight__c=0);
        insert load;
    
        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.loadId = String.valueOf(load.Id);
        req.isCancel = false;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };
    
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();
    
        System.assertEquals(1, responses.size());
        System.assertEquals('413', responses[0].statusCode);
        System.assert(responses[0].responseBody.contains('CarrierQuoteId Not found'));
    }
    
    @isTest static void testCancelAlreadyCancelled_skipsAndReturnsEmptyResponses() {
        ORD_Trigger_Control__c control = new ORD_Trigger_Control__c();
        control.Disable_Flow_Secure_Rate_Con__c = false;
        insert control;
    
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-001');
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
            Name = 'Flow NonCancel Load',
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
            Secure_Rate_Con_Status__c = 'cancelled',
            rtms__Load__c = load.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id,
            Secure_Rate_Con_Last_Update__c = System.now(),
            rtms__Accepted__c = true
        );
        insert cq;
    
        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.loadId = String.valueOf(load.Id);
        req.isCancel = true;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };
    
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();
    
        System.assertEquals(0, responses.size(), 'Expected no responses when cancel request skipped due to already cancelled status');
    }
    
    @isTest static void testCancelRejected_returns204() {
        ORD_Trigger_Control__c control = new ORD_Trigger_Control__c();
        control.Disable_Flow_Secure_Rate_Con__c = false;
        insert control;
    
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name = 'TP Flow', Highway_Carrier_ID__c = 'HC-001');
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
            Name = 'Flow NonCancel Load',
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
            Secure_Rate_Con_Status__c = 'rejected',
            rtms__Load__c = load.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id,
            Secure_Rate_Con_Last_Update__c = System.now(),
            rtms__Accepted__c = true
        );
        insert cq;
        
        FlowSecureRateCon.FlowPostRequest req = new FlowSecureRateCon.FlowPostRequest();
        req.loadId = String.valueOf(load.Id);
        req.isCancel = true;
        List<FlowSecureRateCon.FlowPostRequest> requests = new List<FlowSecureRateCon.FlowPostRequest>{ req };
    
        Test.startTest();
            List<FlowSecureRateCon.FlowPostResponse> responses = FlowSecureRateCon.flowPostToHighway(requests);
        Test.stopTest();
    
        System.assertEquals(1, responses.size());
        System.assertEquals('204', responses[0].statusCode);
        System.assert(responses[0].responseBody.contains('CarrierQuote is already rejected'));
    }
}