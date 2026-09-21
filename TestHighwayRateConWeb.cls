@isTest
private class HighwayRateConWebTest {

    @testSetup
    static void setupData() {
        // Adjust required fields based on your org's validation rules
        Account acc = new Account(Name='Test Account');
        insert acc;
        rtms__Load__c load = new rtms__Load__c(Name='Test Load', rtms__Customer__c=acc.Id, rtms__Total_Weight__c = 1000);
        insert load;
        rtms__TransportationProfile__c tp = new rtms__TransportationProfile__c(
            Name='Test Transportation Profile',
            RecordTypeId = '0123g0000001X7yAAE'
        );
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
        rtms__CarrierQuote__c cq = new rtms__CarrierQuote__c(
            Secure_Rate_Con_Status__c = 'pending',
            rtms__Load__c = load.Id,
            rtms__Vendor__c = acc.Id,
            rtms__Carrier_Service__c = carrierService.Id
        );
        insert cq;
    }

    @isTest
    static void testUpdateRateConStatus_success() {
        rtms__CarrierQuote__c cq = [SELECT Id FROM rtms__CarrierQuote__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'accepted',
            'external_id' => cq.Id
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        rtms__CarrierQuote__c updatedCq = [
            SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Last_Update__c, Secure_Rate_Con_Cancelled_Rejected__c
            FROM rtms__CarrierQuote__c
            WHERE Id = :cq.Id
        ];

        String respString = RestContext.response.responseBody.toString();
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(respString);
        System.assertEquals(true, respMap.get('success'), 'Handler should return success for existing record');
        System.assertEquals('accepted', updatedCq.Secure_Rate_Con_Status__c, 'Status should be updated to accepted');
        System.assertNotEquals(null, updatedCq.Secure_Rate_Con_Last_Update__c, 'Last update timestamp should be set');
        System.assertEquals(null, updatedCq.Secure_Rate_Con_Cancelled_Rejected__c, 'Cancelled/Rejected date should remain null for non-rejected status');
    }

    @isTest
    static void testUpdateRateConStatus_rejected_setsCancelledRejectedDate() {
        rtms__CarrierQuote__c cq = [SELECT Id FROM rtms__CarrierQuote__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'rejected',
            'external_id' => cq.Id
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        rtms__CarrierQuote__c updatedCq = [
            SELECT Secure_Rate_Con_Status__c, Secure_Rate_Con_Cancelled_Rejected__c
            FROM rtms__CarrierQuote__c
            WHERE Id = :cq.Id
        ];

        System.assertEquals('rejected', updatedCq.Secure_Rate_Con_Status__c, 'Status should be updated to rejected');
        System.assertNotEquals(null, updatedCq.Secure_Rate_Con_Cancelled_Rejected__c, 'Cancelled/Rejected date should be set when status is rejected');
    }

    @isTest
    static void testUpdateRateConStatus_rejected_doesNotOverwriteExistingCancelledRejectedDate() {
        rtms__CarrierQuote__c cq = [SELECT Id FROM rtms__CarrierQuote__c LIMIT 1];
        Datetime existingDate = System.now().addDays(-1);
        cq.Secure_Rate_Con_Cancelled_Rejected__c = existingDate;
        update cq;

        Map<String, Object> bodyMap = new Map<String, Object>{
            'status' => 'rejected',
            'external_id' => cq.Id
        };
        String jsonBody = JSON.serialize(bodyMap);

        RestRequest req = new RestRequest();
        req.requestUri = '/api/highway/ratecon';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        HighwayRateConWeb.updateRateConStatus();
        Test.stopTest();

        rtms__CarrierQuote__c updatedCq = [
            SELECT Secure_Rate_Con_Cancelled_Rejected__c
            FROM rtms__CarrierQuote__c
            WHERE Id = :cq.Id
        ];

        System.assertEquals(existingDate, updatedCq.Secure_Rate_Con_Cancelled_Rejected__c, 'Existing Cancelled/Rejected date should not be overwritten');
    }
}