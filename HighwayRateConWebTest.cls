@isTest
private class HighwayRateConWebTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name='Test Account');
        insert acc;

        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(Name='Test Transportation Profile');
        insert tp;

        rtms__Mode__c mode = new rtms__Mode__c(
            Name = 'Truckload',
            rtms__Order__c = 1,
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0
        );
        insert mode;

        rtms__CarrierService__c carrierService = new rtms__CarrierService__c(
            Name='Test Carrier Service',
            rtms__Carrier__c = acc.Id,
            rtms__Transportation_Profile__c = tp.Id,
            rtms__Mode__c = mode.Id,
            rtms__Service_Type__c = 'Carrier',
            rtms__Maximum_Weight__c = 0,
            rtms__Minimum_Weight__c = 0,
            rtms__Weight_Units__c = 'kg',
            rtms__Quote_Method__c = 'Email',
            rtms__Tender_Method__c = 'Email'
        );
        insert carrierService;

        rtms__Load__c load = new rtms__Load__c(
            Name='Test Load',
            rtms__Customer__c = acc.Id,
            rtms__Total_Weight__c = 1000
        );
        insert load;

        rtms__CarrierQuote__c cq = new rtms__CarrierQuote__c(
            Secure_Rate_Con_Status__c = 'pending',
            rtms__Load__c = load.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id,
            rtms__Carrier_Total__c   = 500,
            rtms__Accepted__c = true,
            Name = 'TestCQ'
        );
        insert cq;
    }

    @isTest
    static void test_updateRateConStatus_success_updatesRecord() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        rtms__Load__c load = [SELECT Id, Name FROM rtms__Load__c WHERE Id = :cq.rtms__Load__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'accepted',
            'external_id' => cq.Id,
            'external_load_id' => load.Id
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        String respString = RestContext.response.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(respString);
        System.assertEquals(true, respMap.get('success'));

        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('accepted', updated.Secure_Rate_Con_Status__c);
        System.assertNotEquals(null, updated.Secure_Rate_Con_Last_Update__c);
    }

    @isTest
    static void test_updateRateConStatus_missingRecord_returnsError() {
        rtms__Load__c load = [SELECT Id FROM rtms__Load__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'accepted',
            'external_id' => '000000000000000', // non-existent
            'external_load_id' => load.Id
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        String respString = RestContext.response.responseBody.toString();
        Map<String,Object> respMap = (Map<String,Object>) JSON.deserializeUntyped(respString);
        System.assertEquals(false, respMap.get('success'));
        System.assert(respMap.get('error') != null);
    }

    @isTest
    static void test_updateRateConStatus_rejected_setsCancelledAndSendsEmail() {
        rtms__CarrierQuote__c cq = [SELECT Id, rtms__Load__c FROM rtms__CarrierQuote__c LIMIT 1];
        rtms__Load__c load = [SELECT Id, Name FROM rtms__Load__c WHERE Id = :cq.rtms__Load__c LIMIT 1];

        // Build activities: rejected then delivered (delivered contains our target email)
        Map<String, Object> rejectedAct = new Map<String, Object>{
            'id' => 34071,
            'is_type' => 'rejected',
            'user_id' => 76798,
            'user' => new Map<String, Object>{ 'id' => 76798, 'full_name' => 'ALEX', 'email' => 'kenna.valentine+takun@gohighway.com' }
        };
        Map<String, Object> deliveredAct = new Map<String, Object>{
            'id' => 34070,
            'is_type' => 'delivered',
            'user_id' => 76831,
            'user' => new Map<String, Object>{ 'id' => 76831, 'full_name' => 'Takun Purba', 'email' => 'takunp@openroad.inc' }
        };
        List<Object> activities = new List<Object>{ rejectedAct, deliveredAct };

        Map<String, Object> carrier = new Map<String, Object>{ 'id' => 96271, 'name' => 'OPENROAD TRANSPORTATION INC dba OPENROAD GLOBAL' };

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'rejected',
            'external_id' => cq.Id,
            'external_load_id' => load.Id,
            'recent_rate_confirmation_activities' => activities,
            'carrier' => carrier
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        String respString = RestContext.response.responseBody.toString();
        Map<String,Object> respMap = (Map<String,Object>) JSON.deserializeUntyped(respString);
        System.assertEquals(true, respMap.get('success'));

        rtms__CarrierQuote__c updated = [SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Cancelled_Rejected__c FROM rtms__CarrierQuote__c WHERE Id = :cq.Id];
        System.assertEquals('rejected', updated.Secure_Rate_Con_Status__c);
        System.assertNotEquals(null, updated.Secure_Rate_Con_Cancelled_Rejected__c);
    }
}