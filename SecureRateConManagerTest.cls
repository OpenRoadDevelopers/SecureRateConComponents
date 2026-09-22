@isTest
private class SecureRateConManagerTest {

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
    private class SimulatedException extends Exception {}



    @testSetup
    static void setupData() {
        // Adjust required fields based on your org's validation rules
        Account acc = new Account(Name='Test Account');
        insert acc;
        //rtms__Mode__c modeRecord = [SELECT rtms__Mode__c FROM rtms__Load__c WHERE rtms__Mode_Name__c = 'TruckLoad' LIMIT 1];
        rtms__Mode__c truckLoadRecord = new rtms__Mode__c(
            Name = 'TruckLoad',
            rtms__Order__c = 1,
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0
        );
        insert truckLoadRecord;
        rtms__Load__c load = new rtms__Load__c(
            Name='Test Load', 
            rtms__Customer__c=acc.Id, 
            rtms__Total_Weight__c = 1000, 
            rtms__Mode__c = truckLoadRecord.Id,
            rtms__Load_Status__c = 'Quotes Received',
            Require_Secure_Rate_Con__c = false,
            rtms__Carrier__c = acc.Id
            );
        insert load;
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(
            Name='Test Transportation Profile', 
            Highway_Carrier_ID__c = 'HC-TEST'
        );
        insert tp;
        acc.rtms__Transportation_Profile__c = tp.id;
        update acc;
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

        rtms__Load__c loadWithNoStatusQuote = new rtms__Load__c(
            Name='Load With No Status Quote', 
            rtms__Customer__c=acc.Id, 
            rtms__Total_Weight__c = 1000, 
            rtms__Mode__c = truckLoadRecord.Id,
            rtms__Load_Status__c = 'Quotes Received',
            Require_Secure_Rate_Con__c = false
            );
        insert loadWithNoStatusQuote;

        rtms__CarrierQuote__c cqNoStatus = new rtms__CarrierQuote__c(
            Secure_Rate_Con_Status__c = null,
            rtms__Load__c = loadWithNoStatusQuote.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id,
            rtms__Accepted__c = true
        );
        insert cqNoStatus;

        //rtms__Mode__c railRecord = [SELECT rtms__Mode__c FROM rtms__Load__c WHERE rtms__Mode_Name__c = 'Rail' LIMIT 1];
        rtms__Mode__c railRecord = new rtms__Mode__c(
            Name = 'Rail',
            rtms__Order__c = 1,
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0
        );
        insert railRecord;
        rtms__Load__c loadNoQuote = new rtms__Load__c(
            Name='loadNoQuote', 
            rtms__Customer__c=acc.Id, 
            rtms__Total_Weight__c = 1000, 
            rtms__Mode__c = railRecord.Id,
            rtms__Load_Status__c = 'Unassigned',
            Require_Secure_Rate_Con__c = false
            );
        insert loadNoQuote;

        ContentVersion cv = new ContentVersion(
            Title = 'TestFile.pdf',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('PDF-DUMMY')
        );
        insert cv;

    }

    @isTest static void testGetLoadDetails_withAndWithoutCarrierQuote() {

       rtms__Load__c loadWithQuote = [SELECT Id FROM rtms__Load__c WHERE name = 'Test Load' LIMIT 1];

        Map<String, Object> detailsWithQuote = SecureRateConManager.getLoadDetails(loadWithQuote.Id);

        System.assertEquals('TruckLoad', (String)detailsWithQuote.get('modeName'), 'modeName should match');
        System.assertEquals('Quotes Received', (String)detailsWithQuote.get('loadStatus'), 'loadStatus should match');
        System.assertEquals(false, (Boolean)detailsWithQuote.get('requireRateCon'), 'requireRateCon should match');
        System.assertEquals('delivered', (String)detailsWithQuote.get('quoteStatus'), 'quoteStatus should be returned when quote exists');
        System.assertNotEquals(null, detailsWithQuote.get('lastUpdated'), 'lastUpdated should be present when quote exists');

        // Now test a load with no CarrierQuote
        rtms__Load__c loadNoQuote = [SELECT Id FROM rtms__Load__c WHERE name = 'loadNoQuote' LIMIT 1];

        
        Map<String, Object> detailsNoQuote = SecureRateConManager.getLoadDetails(loadNoQuote.Id);
        

        System.assertEquals('Rail', (String)detailsNoQuote.get('modeName'));
        System.assertEquals('Unassigned', (String)detailsNoQuote.get('loadStatus'));
        System.assertEquals(false, (Boolean)detailsNoQuote.get('requireRateCon'));
        System.assertEquals(false, detailsNoQuote.containsKey('quoteStatus'), 'quoteStatus should not be present when no quote');
    }

    @isTest static void testSetSecureRateCon_toggle() {
        // Create load with initial boolean value
        rtms__Load__c load = new rtms__Load__c(
            Name = 'Toggle Load',
            Require_Secure_Rate_Con__c = false,
            rtms__Total_Weight__c = 0
            // add other required fields here if necessary
        );
        insert load;

        // Verify initial state
        rtms__Load__c loaded = [SELECT Id, Require_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :load.Id];
        System.assertEquals(false, loaded.Require_Secure_Rate_Con__c);

        
        SecureRateConManager.setSecureRateCon(load.Id);
        

        rtms__Load__c toggled = [SELECT Id, Require_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :load.Id];
        System.assertEquals(true, toggled.Require_Secure_Rate_Con__c, 'Require_Secure_Rate_Con__c should be toggled to true');

        // toggle back
        
        SecureRateConManager.setSecureRateCon(load.Id);
        

        rtms__Load__c toggledBack = [SELECT Id, Require_Secure_Rate_Con__c FROM rtms__Load__c WHERE Id = :load.Id];
        System.assertEquals(false, toggledBack.Require_Secure_Rate_Con__c, 'Require_Secure_Rate_Con__c should be toggled back to false');
    }

    @isTest static void testBuildRequestBody_cancelAndNonCancel() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];
        String boundary = '----TESTBOUNDARY';

        Blob nonCancel = SecureRateConManager.buildRequestBody('from@test.com', 'subject', String.valueOf(cq.rtms__Load__c), '1234', new List<String>{'a@b.com'}, cv.Id, cq.Id, boundary, false);
        System.assertNotEquals(null, nonCancel);

        Blob cancelBlob = SecureRateConManager.buildRequestBody('from@test.com', 'subject', String.valueOf(cq.rtms__Load__c), '1234', null, cv.Id, cq.Id, boundary, true);
        System.assertNotEquals(null, cancelBlob);
    }

    @isTest static void testSetSecureRateConStatus_updatesCarrierQuote() {
        rtms__CarrierQuote__c cq = [SELECT Id, Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c LIMIT 1];
        SecureRateConManager.setSecureRateConStatus(cq.Id, 'failed');
        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('failed', updated.Secure_Rate_Con_Status__c);
    }

    @isTest static void testGetCarrierQuote_helpers() {
        // create an accepted carrier quote to exercise isCarrierQuoteAccepted
        rtms__Load__c load = [SELECT Id FROM rtms__Load__c WHERE Name = 'Load With No Status Quote' LIMIT 1];

        rtms__CarrierQuote__c cq1 = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :load.Id AND rtms__Accepted__c = true LIMIT 1];

        rtms__CarrierQuote__c accepted = SecureRateConManager.getCarrierQuote(false, load.Id);
        System.assertEquals(cq1.Id, accepted.Id);

        // getRecentSecureCarrierQuote: ensure null when none
        rtms__CarrierQuote__c recent = SecureRateConManager.getRecentSecureCarrierQuote(load.Id);
        // secure rate con last update is null => method returns null
        System.assertEquals(null, recent);
    }

    @isTest static void testUpdateSecureRateConRequest_callout_success() {
        // Use callout mock to return 200
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));

        // Prepare args
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        Test.startTest();
            Map<String, Object> res = SecureRateConManager.updateSecureRateConRequest('from@test.com', 'sub', String.valueOf(cq.rtms__Load__c), '1234', new List<String>{'a@b.com'}, cv.Id, cq.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(200, (Integer)res.get('statusCode'));
    }

    @isTest static void testHandleStatus_successPath() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        Map<String, Object> result = SecureRateConManager.handleStatus(200, 'OK', 'from@test.com', 's', String.valueOf(cq.rtms__Load__c), '1234', null, null, cq.Id, false, Blob.valueOf('b'), 'b', 'token');
        System.assertEquals(200, (Integer)result.get('statusCode'));
    }
    @isTest
    static void testHandleStatus_422_resendsAndReturnsNewStatus() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        // Mock the resend callout invoked inside the 422 branch
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));
        Test.startTest();
        Integer beforeEmails = Limits.getEmailInvocations();
        Map<String, Object> result = SecureRateConManager.handleStatus(
            422,
            'Undelivered - user doesn\'t exist',
            'from@test.com',
            'subj',
            String.valueOf(cq.rtms__Load__c),
            '1234',
            null,
            cv.Id,
            cq.Id,
            false,
            Blob.valueOf('b'),
            'boundary',
            'token'
        );
        Integer afterEmails = Limits.getEmailInvocations();
        System.assertEquals(beforeEmails + 1, afterEmails, 'sendErrorEmail should increment email invocations in test mode');
        Test.stopTest();

        System.assertEquals(200, (Integer) result.get('statusCode'), 'handleStatus should return the resend response status');
        System.assertNotEquals(null, result.get('respBody'), 'respBody should be present after resend');
    }

    @isTest
    static void testHandleStatus_non2xx_updatesCarrierQuoteAndReturns() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];
        Integer beforeEmails = Limits.getEmailInvocations();
        Map<String, Object> result = SecureRateConManager.handleStatus(
            500,
            'server error',
            'from@test.com',
            'subj',
            String.valueOf(cq.rtms__Load__c),
            '1234',
            null,
            cv.Id,
            cq.Id,
            false,
            Blob.valueOf('b'),
            'boundary',
            'token'
        );

        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('failed', updated.Secure_Rate_Con_Status__c, 'CarrierQuote status should be set to failed for non-2xx response');
        System.assertEquals(500, (Integer) result.get('statusCode'));
        Integer afterEmails = Limits.getEmailInvocations();
        System.assertEquals(beforeEmails + 1, afterEmails, 'sendErrorEmail should increment email invocations in test mode');
    }

    @isTest static void testSendErrorEmail_incrementsEmailInvocation() {
        Integer before = Limits.getEmailInvocations();
        SecureRateConManager.sendErrorEmail(new List<String>{'test@openroad.inc'}, 'Subject', '<b>body</b>', true);
        Integer after = Limits.getEmailInvocations();
        System.assertEquals(before + 1, after, 'sendEmail should increment email invocations');
        SecureRateConManager.sendErrorEmail(new List<String>{'test@openroad.inc'}, 'Subject', 'body', false);
        Integer finalAfter = Limits.getEmailInvocations();
        System.assertEquals(before + 2, finalAfter, 'sendEmail should increment email invocations for both calls');
    }

    @isTest
    static void testSaveLoadPdfToFiles_createsContentVersionAndLink() {
        // create minimal supporting data
        rtms__Load__c load = [SELECT Id, Name, Carrier_Name__c, rtms__Mode_Name__c FROM rtms__Load__c WHERE Name = 'Load With No Status Quote' LIMIT 1];

        // Ensure the Visualforce page is the current page (the page must exist in the org)
        PageReference pr = Page.ORCarrierRateConfirmation3;
        Test.setCurrentPage(pr);

        Test.startTest();
            Map<String, Object> result = SecureRateConManager.saveLoadPdfToFiles(load.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'result should not be null');
        System.assert(result.containsKey('contentVersionId'), 'result must contain contentVersionId');
        System.assert(result.containsKey('fileName'), 'result must contain fileName');

        Id cvId = (Id) result.get('contentVersionId');
        String fileName = (String) result.get('fileName');
        System.assertNotEquals(null, cvId, 'contentVersionId should not be null');
        System.assertEquals(load.Name + ' - ' + load.Carrier_Name__c + ' - ' + load.rtms__Mode_Name__c + ' - ' + 'Carrier Rate and Load Confirmation.pdf', fileName);

        ContentVersion cv = [SELECT Id, Title, VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];
        System.assertEquals(fileName, cv.Title, 'ContentVersion title should match fileName');

        List<ContentDocumentLink> links = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :load.Id];
        System.assert(!links.isEmpty(), 'ContentDocumentLink should be created and linked to the load');
    }

    @isTest
    static void testHandleCalloutError_updatesStatusAndSendsEmail() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        Integer beforeEmails = Limits.getEmailInvocations();
        Id contentVersionId = [SELECT Id FROM ContentVersion LIMIT 1].Id;
        SimulatedException simulated = new SimulatedException('Simulated callout failure');
        SecureRateConManager.handleCalloutError(simulated, String.valueOf(cq.rtms__Load__c), String.valueOf(cq.Id), contentVersionId, 'tester@openroad.inc');

        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('failed', updated.Secure_Rate_Con_Status__c);
        
        Integer afterEmails = Limits.getEmailInvocations();
        System.assertEquals(beforeEmails + 1, afterEmails, 'sendErrorEmail should increment email invocations in test mode');
    }

    @isTest
    static void testSetupUpdateSecureRateCon_returnsExpectedMap() {
        rtms__Load__c load = [SELECT Id FROM rtms__Load__c WHERE Name = 'Test Load' LIMIT 1];
        rtms__CarrierQuote__c cq = [SELECT Id FROM rtms__CarrierQuote__c WHERE rtms__Load__c = :load.Id LIMIT 1];
        

        // Act
        Test.startTest();
            Map<String, Object> result = SecureRateConManager.setupUpdateSecureRateCon(load.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'result map should not be null');
        System.assertNotEquals(null, result.get('contentVersionId'), 'contentVersionId must be returned');
        System.assertEquals(load.Id, (Id) result.get('loadId'));
        System.assertEquals('HC-TEST', (String) result.get('highwayCarrierId'));
        System.assertEquals(cq.Id, (Id) result.get('carrierQuoteId'));
        System.assertEquals(false, (Boolean) result.get('isCancel'));
        System.assertEquals(UserInfo.getUserEmail(), (String) result.get('fromWho'));
        System.assert(((String) result.get('subject')).startsWith('Updated:'), 'subject should start with "Updated:"');
    }
}