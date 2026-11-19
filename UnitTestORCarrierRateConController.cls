/**
* Copyright 2020 Revenova, LLC. All rights reserved.
*/
@isTest
private class UnitTestORCarrierRateConController {
    
    @isTest static void testConstructor_secureTrue_validQuote() {
        insertTestData();
        List<rtms__CarrierQuote__c> cqList = [select Id from rtms__CarrierQuote__c];
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        ApexPages.currentPage().getParameters().put('isSecureRateCon','true');
        ApexPages.currentPage().getParameters().put('carrierQuoteId', cqList[0].Id);

        Test.startTest();
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            ORCarrierRateConfirmationController ctrl = new ORCarrierRateConfirmationController(sc);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.getQuote());
        System.assertEquals(cqList[0].Id, ctrl.getQuote().Id);
    }

    @isTest static void testConstructor_throwsWhenSecureAndNoQuote() {
        insertTestData();
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        ApexPages.currentPage().getParameters().put('isSecureRateCon','true');
        ApexPages.currentPage().getParameters().put('carrierQuoteId', null);

        Boolean thrown = false;
        Test.startTest();
            try {
                ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
                new ORCarrierRateConfirmationController(sc);
            } catch (ORCarrierRateConfirmationController.CarrierQuoteNotFoundException ex) {
                thrown = true;
            }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected CarrierQuoteNotFoundException when secure and no quote found');
    }
    
    @isTest static void testNullId_returnsNull() {
        System.assertEquals(null, ORCarrierRateConfirmationController.grabAcceptedCarrierQuote(null));
    }
    @isTest static void testNonMatchingServiceType_returnsNull() {
        
        insertTestData();
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        rtms__Load__c load = lList[0];
        load.Use_Secure_Rate_Con__c = false;
        update load;
        List<rtms__CarrierQuote__c> cqList = [select Id, rtms__Carrier_Service__c from rtms__CarrierQuote__c WHERE rtms__Load__c = :load.Id LIMIT 1];
        rtms__CarrierQuote__c cq = cqList[0];
        List<rtms__CarrierService__c> csList = [select Id from rtms__CarrierService__c WHERE Id = :cq.rtms__Carrier_Service__c LIMIT 1];
        rtms__CarrierService__c cs = csList[0];
        cs.rtms__Service_Type__c = 'Broker';
        update cs;

        Test.startTest();
        rtms__CarrierQuote__c result = ORCarrierRateConfirmationController.grabAcceptedCarrierQuote(cq.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }
    @isTest static void testQuoteWithCarrierService_returnsQuote() {
        insertTestData();
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        rtms__Load__c load = lList[0];
        load.Use_Secure_Rate_Con__c = false;
        update load;
        List<rtms__CarrierQuote__c> cqList = [select Id, rtms__Carrier_Service__c from rtms__CarrierQuote__c WHERE rtms__Load__c = :load.Id LIMIT 1];
        rtms__CarrierQuote__c cq = cqList[0];
        cq.Secure_Rate_Con_Status__c = 'delivered';
        cq.rtms__Accepted__c = true;
        update cq;
        List<rtms__CarrierService__c> csList = [select Id from rtms__CarrierService__c WHERE Id = :cq.rtms__Carrier_Service__c LIMIT 1];
        rtms__CarrierService__c cs = csList[0];
        cs.rtms__Service_Type__c = 'Carrier';
        update cs;

        Test.startTest();
        rtms__CarrierQuote__c result = ORCarrierRateConfirmationController.grabAcceptedCarrierQuote(cq.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(cq.Id, result.Id);
    }
    static testMethod void testORCarrierRateConController0() {

        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);
        Test.startTest();

        //try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);

            ApexPages.currentPage().getParameters().put('maskIdentity', String.valueOf(false));
            
            try {
                Account a = newc.getShipFrom();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipFrom e' + e);
            }

            try {
                Account a = newc.getShipTo();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipTo e' + e);
            }

            try {
                rtms__Stop__c s = newc.getFirstStop();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstStop e' + e);
            }

            try {
                rtms__Stop__c s = newc.getLastStop();
            }
            catch(Exception e){
                System.debug('********************* Exception getLastStop e' + e);
            }

            try {
                Map<Id,Account> m = newc.getStopLocations();
            }
            catch(Exception e){
                System.debug('********************* Exception getStopLocations e' + e);
            }

            try {
                Map<Id,Contact> m = newc.getStopContacts();
            }
            catch(Exception e){
                System.debug('********************* Exception getStopContacts e' + e);
            }

            try {
                rtms__CarrierQuote__c q = newc.getQuote();
            }
            catch(Exception e){
                System.debug('********************* Exception getQuote e' + e);
            }

            try {
                List<rtms__LoadAccessorial__c> t = newc.getCarrierProvidedAccessorials();
            }
            catch(Exception e){
                System.debug('********************* Exception getCarrierProvidedAccessorials e' + e);
            }

            try {
                Boolean b = newc.getHasCarrierProvidedAccessorials();
            }
            catch(Exception e){
                System.debug('********************* Exception getHasCarrierProvidedAccessorials e' + e);
            }

            try {
                List<rtms__CarrierQuoteAccessorial__c> t = newc.getCarrierQuoteAccessorials();
            }
            catch(Exception e){
                System.debug('********************* Exception getCarrierQuoteAccessorials e' + e);
            }

            try {
                Boolean b = newc.getHasAccessorialCharges();
            }
            catch(Exception e){
                System.debug('********************* Exception getHasAccessorialCharges e' + e);
            }

            try {
                String s = newc.getCurrencySymbol();
            }
            catch(Exception e){
                System.debug('********************* Exception getCurrencySymbol e' + e);
            }

            try {
                List<ORCarrierRateConfirmationController.CurrencyAmount> t = newc.getChargesByCurrency();
            }
            catch(Exception e){
                System.debug('********************* Exception getChargesByCurrency e' + e);
            }

            try {
                rtms__Load__c d = newc.getLoad();
            }
            catch(Exception e){
                System.debug('********************* Exception getLoad e' + e);
            }

            try {
                rtms__Load__c d = newc.getAdjacentOceanLoad();
            }
            catch(Exception e){
                System.debug('********************* Exception getAdjacentOceanLoad e' + e);
            }

            try {
                List<rtms__Stop__c> t = newc.getStops();
            }
            catch(Exception e){
                System.debug('********************* Exception getStops e' + e);
            }

            try {
                Map<Id, List<rtms__LoadReference__c>> m = newc.getLoadReferencesByStop();
            }
            catch(Exception e){
                System.debug('********************* Exception getLoadReferencesByStop e' + e);
            }

            try {
                List<rtms__LoadReference__c> t = newc.getLoadReferences();
            }
            catch(Exception e){
                System.debug('********************* Exception getLoadReferences e' + e);
            }

            try {
                Account a = newc.getCarrier();
            }
            catch(Exception e){
                System.debug('********************* Exception getCarrier e' + e);
            }

            try {
                String s = newc.getMcNumber();
            }
            catch(Exception e){
                System.debug('********************* Exception getMcNumber e' + e);
            }

            try {
                Contact c = newc.getQuoteContact();
            }
            catch(Exception e){
                System.debug('********************* Exception getQuoteContact e' + e);
            }

            try {
                List<rtms__LineItem__c> t = newc.getLineItems();
            }
            catch(Exception e){
                System.debug('********************* Exception getLineItems e' + e);
            }

            try {
                List<Contact> t = newc.getHazMatContacts();
            }
            catch(Exception e){
                System.debug('********************* Exception getHazMatContacts e' + e);
            }

            try {
                Boolean b = newc.getHasNMFCInformation();
            }
            catch(Exception e){
                System.debug('********************* Exception getHasNMFCInformation e' + e);
            }

            try {
                rtms__DocumentOptions__c d = newc.getDocumentOptions();
            }
            catch(Exception e){
                System.debug('********************* Exception getDocumentOptions e' + e);
            }

            try {
                Account a = newc.getDocumentAccount();
            }
            catch(Exception e){
                System.debug('********************* Exception getDocumentAccount e' + e);
            }

            try {
                List<rtms__TMSDocumentField__c> t = newc.getExtraLoadFields();
            }
            catch(Exception e){
                System.debug('********************* Exception getExtraLoadFields e' + e);
            }

            try {
                List<rtms__TMSDocumentField__c> t = newc.getExtraStopFields();
            }
            catch(Exception e){
                System.debug('********************* Exception getExtraStopFields e' + e);
            }

            try {
                List<rtms__TMSDocumentField__c> t = newc.getExtraLineItemFields();
            }
            catch(Exception e){
                System.debug('********************* Exception getExtraLineItemFields e' + e);
            }

            try {
                Integer c = newc.getExtraLineItemFieldCount();
            }
            catch(Exception e){
                System.debug('********************* Exception getExtraLineItemFieldCount e' + e);
            }

            try {
                Boolean b = newc.getIsMultiCurrencyOrganization();
            }
            catch(Exception e){
                System.debug('********************* Exception getIsMultiCurrencyOrganization e' + e);
            }

            try {
                Boolean b = newc.getSuppressLogo();
            }
            catch(Exception e){
                System.debug('********************* Exception getSuppressLogo e' + e);
            }

            try {
                String s = newc.getDocumentLogoUrl();
            }
            catch(Exception e){
                System.debug('********************* Exception getDocumentLogoUrl e' + e);
            }

            try {
                List<rtms__Voyage__c> t = newc.getVoyageList();
            }
            catch(Exception e){
                System.debug('********************* Exception getVoyageList e' + e);
            }

            try {
                Boolean b = newc.getHasVoyages();
            }
            catch(Exception e){
                System.debug('********************* Exception getHasVoyages e' + e);
            }

            try {
                rtms__Voyage__c v = newc.getFirstVoyage();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstVoyage e' + e);
            }

            try {
                String s = newc.getFirstVoyageType();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstVoyageType e' + e);
            }

            try {
                User u = newc.getReplyToUser();
            }
            catch(Exception e){
                System.debug('********************* Exception getReplyToUser e' + e);
            }

            try {
                List<ORCarrierRateConfirmationController.StopWithLineItems> t = newc.getStopsWithLineItems();
            }
            catch(Exception e){
                System.debug('********************* Exception getStopsWithLineItems e' + e);
            }

            try {
                String s = newc.getToday();
            }
            catch(Exception e){
                System.debug('********************* Exception getToday e' + e);
            }

            try {
                Boolean b = newc.getIsTwoStopLoad();
            }
            catch(Exception e){
                System.debug('********************* Exception getIsTwoStopLoad e' + e);
            }

            try {
                Boolean b = newc.getShowContactInfoToCarrier();
            }
            catch(Exception e){
                System.debug('********************* Exception getShowContactInfoToCarrier e' + e);
            }

            try {
                rtms__CustomsBroker__c cb = newc.getCustomsBroker();
            }
            catch(Exception e){
                System.debug('********************* Exception getCustomsBroker e' + e);
            }

            try {
                rtms__EquipmentType__c et = newc.getEquipmentType();
            }
            catch(Exception e){
                System.debug('********************* Exception getEquipmentType e' + e);
            }

            try {
                Boolean b = newc.getMaskShipperConsigneeIdentity();
            }
            catch(Exception e){
                System.debug('********************* Exception getMaskShipperConsigneeIdentity e' + e);
            }

            try {
                String s = newc.getLanguageCode();
            }
            catch(Exception e){
                System.debug('********************* Exception getLanguageCode e' + e);
            }

            try {
                List<rtms__Container__c> t = newc.getContainerList();
            }
            catch(Exception e){
                System.debug('********************* Exception getContainerList e' + e);
            }

            try {
                Boolean b = newc.getShowContainers();
            }
            catch(Exception e){
                System.debug('********************* Exception getShowContainers e' + e);
            }

            try {
                List<FieldSetMember> t = newc.getContainerFields();
            }
            catch(Exception e){
                System.debug('********************* Exception getContainerFields e' + e);
            }

            try {
                String s = newc.getShippingStateField();
            }
            catch(Exception e){
                System.debug('********************* Exception getShippingStateField e' + e);
            }

            try {
                String s = newc.getShippingCountryField();
            }
            catch(Exception e){
                System.debug('********************* Exception getShippingCountryField e' + e);
            }
        //}
        //catch(Exception e){
        //    System.debug('********************* Exception e' + e);
        //}
        
        Test.stopTest(); 
    }  
    static testMethod void testORCarrierRateConController1() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);
        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);

            try{
                Decimal a = 1 / 0;
            }
            catch(Exception e){
                newc.handleException(e, 'THIS IS JUST A TEST');
            }
            try{
                Decimal a = 1 / 0;
            }
            catch(Exception e){
                newc.handleException(e, null);
            }
            try{
                Decimal a = 1 / 0;
            }
            catch(Exception e){
                ORDisplayableException z = new ORDisplayableException(e);
                newc.handleException(z, null);
            }
            try{
                Decimal a = 1 / 0;
            }
            catch(Exception e){
                SecurityException z = new SecurityException(e);
                newc.handleException(z, null);
            }
            try{
                Decimal a = 1 / 0;
            }
            catch(Exception e){
                e.setMessage('FIELD_CUSTOM_VALIDATION_EXCEPTION');
                newc.handleException(e, null);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }  
    static testMethod void testORCarrierRateConController2() {

        List<rtms__Stop__c> sList = [select Id from rtms__Stop__c limit 1];
        System.debug('********************* sList ' + sList);
        List<rtms__LineItem__c> lList = [select Id from rtms__LineItem__c limit 1];
        System.debug('********************* lList ' + lList);

        Test.startTest();  

        try{
            ORCarrierRateConfirmationController.StopWithLineItems st = 
                new ORCarrierRateConfirmationController.StopWithLineItems(sList[0], lList);
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }  
    static testMethod void testORCarrierRateConController3() {

        Test.startTest();  

        try{
            ORCarrierRateConfirmationController.CurrencyAmount c1 = 
                new ORCarrierRateConfirmationController.CurrencyAmount(1.0, '$');
            ORCarrierRateConfirmationController.CurrencyAmount c2 = 
                new ORCarrierRateConfirmationController.CurrencyAmount(2.0, '€');

            System.assertEquals(1.0, c1.getValue(), 'CurrencyAmount failed');
            System.assertEquals(2.0, c2.getValue(), 'CurrencyAmount failed');
            
            System.assertEquals('$', c1.getCurrencyCode(), 'CurrencyAmount failed');
            System.assertEquals('€', c2.getCurrencyCode(), 'CurrencyAmount failed');

            System.assertEquals(1, c1.compareTo(c2), 'CurrencyAmount failed');
            System.assertEquals(-1, c2.compareTo(c1), 'CurrencyAmount failed');
            
            c1.setValue(3.0);
            System.assertEquals(3.0, c1.getValue(), 'CurrencyAmount failed');
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController4() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);
        
        List<rtms__Stop__c> sList = [select Id, rtms__Location2__c from rtms__Stop__c where rtms__Load__c =: lList[0].Id];

        for(rtms__Stop__c stop: sList) {
            stop.rtms__Location2__c = null;
        }
        update sList;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            
            try {
                Account a = newc.getShipFrom();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipFrom e' + e);
            }

            try {
                Account a = newc.getShipTo();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipTo e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController5() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);

        rtms__CarrierQuote__c quote = [select Id, rtms__Net_Line_Haul__c from rtms__CarrierQuote__c where rtms__Accepted__c = true and rtms__Load__c =: lList[0].Id];
        quote.rtms__Net_Line_Haul__c = 20;
        quote.rtms__Fuel_Surcharge__c = 10;
        quote.rtms__Accessorial_Charges__c = 50;
        update quote;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            

            try {
                List<ORCarrierRateConfirmationController.CurrencyAmount> c = newc.getChargesByCurrency();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipFrom e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController6() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);

        rtms__CarrierQuote__c quote = [select Id, rtms__Net_Line_Haul__c from rtms__CarrierQuote__c where rtms__Accepted__c = true and rtms__Load__c =: lList[0].Id];
        quote.rtms__Net_Line_Haul__c = 20;
        quote.rtms__Fuel_Surcharge__c = 10;
        quote.rtms__Accessorial_Charges__c = 50;
        update quote;

        rtms__CarrierQuoteAccessorial__c accessorial = new rtms__CarrierQuoteAccessorial__c(rtms__Carrier_Quote__c = quote.Id);
        insert accessorial;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            
            try {
                List<ORCarrierRateConfirmationController.CurrencyAmount> c = newc.getChargesByCurrency();
            }
            catch(Exception e){
                System.debug('********************* Exception getShipFrom e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController7() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);

        rtms__Voyage__c voyage = [select Id, rtms__Destination_Type__c from rtms__Voyage__c where rtms__Load__c =: lList[0].Id];
        voyage.rtms__Destination_Type__c = ORCarrierRateConfirmationController.PORT_OF_DISCHARGE;
        update voyage;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            
            try {
                String s = newc.getFirstVoyageType();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstVoyageType e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController8() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);

        rtms__Voyage__c voyage = [select Id, rtms__Destination_Type__c from rtms__Voyage__c where rtms__Load__c =: lList[0].Id];
        voyage.rtms__Origin_Type__c = ORCarrierRateConfirmationController.PORT_OF_LOAD;
        update voyage;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            
            try {
                String s = newc.getFirstVoyageType();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstVoyageType e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static testMethod void testORCarrierRateConController9() {
        insertTestData();
        
        List<rtms__Load__c> lList = [select Id from rtms__Load__c limit 1];
        System.debug('********************* lList ' + lList);

        rtms__Voyage__c voyage = [select Id, rtms__Destination_Type__c from rtms__Voyage__c where rtms__Load__c =: lList[0].Id];
        voyage.rtms__Origin_Type__c = ORCarrierRateConfirmationController.PORT_OF_LOAD;
        voyage.rtms__Destination_Type__c = ORCarrierRateConfirmationController.PORT_OF_DISCHARGE;
        update voyage;

        Test.startTest();  

        try{
            ApexPages.StandardController sc = new ApexPages.StandardController(lList[0]);
            System.debug('********************* sc ' + sc);
            ORCarrierRateConfirmationController newc = new ORCarrierRateConfirmationController(sc);
            System.debug('********************* newc ' + newc);
            
            try {
                String s = newc.getFirstVoyageType();
            }
            catch(Exception e){
                System.debug('********************* Exception getFirstVoyageType e' + e);
            }
        }
        catch(Exception e){
            System.debug('********************* Exception e' + e);
        }
        
        Test.stopTest(); 
    }
    static private void insertTestData(){
          
        // insert Load information
        Account cust = getNewAccount();
        Account carrier = getNewAccount('Carrier (Ground)');
        
        rtms__Mode__c mde = new rtms__Mode__c(Name = 'Ocean FCL', rtms__Order__c = 1, rtms__Maximum_Weight__c = 50000, rtms__Minimum_Weight__c = 0);
        insert mde;
        
        List<Account> aList = [select Id, rtms__Transportation_Profile__c from Account where Id =: carrier.Id];
        List<rtms__TransportationProfile__c> tpList = [select Id from rtms__TransportationProfile__c where Id = : aList[0].rtms__Transportation_Profile__c];
        rtms__CarrierService__c cs = new rtms__CarrierService__c(
                Name = 'Carrier-CS',
                rtms__Transportation_Profile__c = tpList[0].Id,
                rtms__Carrier__c = carrier.Id,
                rtms__Mode__c = mde.Id,
                rtms__Minimum_Weight__c = 0,
                rtms__Maximum_Weight__c = 50000,
                rtms__Weight_Units__c = 'lbs',
                rtms__Quote_Method__c = 'Email',
                rtms__Tender_Method__c = 'Email');
        insert cs;
        
        rtms__DocumentOptions__c docopt = new rtms__DocumentOptions__c(rtms__Global_Defaults__c = true);
        insert docopt;

        // load
        Date orDT = Date.newInstance(2016,10,31);
        rtms__Load__c l = new rtms__Load__c(
                rtms__Customer__c                               = cust.Id,
                rtms__Bill_To__c                                = cust.Id,
                rtms__Customs_Broker__c                         = cust.Id,
                rtms__Order_Date__c                             = orDT,
                rtms__PRO_Number__c                             = 'tst-123456789',
                rtms__Total_Weight__c                           = 10000,
                rtms__Weight_Units__c                           = 'lbs',
                rtms__Customer_Sales_Rep__c                     = userinfo.getUserId(),
                rtms__Carrier_Sales_Rep__c                      = userinfo.getUserId(),
                rtms__Mode__c                                   = mde.Id,
                rtms__Customer_Invoice_Total__c                 = 1000,
                rtms__Customer_Invoice_Tax_Amount__c            = 0,
                rtms__Carrier_Invoice_Total__c                  = 500,
                rtms__Load_Status__c                            = 'All',
                rtms__Document_Options__c                       = docopt.Id,
                rtms__Sales_Status__c                           = 'Won');
        insert l;
        
        Date curDt = System.today();
        Date exDT = Date.newInstance(curDt.year(),curDt.month(),curDt.day());
        rtms__Stop__c stop1 = new rtms__Stop__c(
            Name = 'Stop 1',
            rtms__Expected_Date__c = exDT,
            rtms__Is_Dropoff__c = false,
            rtms__Is_Pickup__c = true,
            rtms__Load__c = l.Id,
            rtms__Location2__c = carrier.Id,
            rtms__Number__c = 1);
        insert stop1;
        
        rtms__Stop__c stop2 = new rtms__Stop__c(
            Name = 'Stop 2',
            rtms__Expected_Date__c = exDT,
            rtms__Is_Dropoff__c = false,
            rtms__Is_Pickup__c = true,
            rtms__Load__c = l.Id,
            rtms__Location2__c = carrier.Id,
            rtms__Number__c = 2);
        insert stop2;
        
        rtms__LineItem__c item1 = new rtms__LineItem__c(
            Name = 'Item 1',
            rtms__Pickup_Stop__c = stop1.Id,
            rtms__Delivery_Stop__c = stop2.Id,
            rtms__Item_Description__c = 'This and that',
            rtms__Load__c = l.Id,
            rtms__Weight__c = 10000,
            rtms__Packaging_Unit_Count__c = 10,
            rtms__Packaging_Units__c = 'Bales',
            rtms__Handling_Unit_Count__c = 10,
            rtms__Handling_Units__c = 'Bags',
            rtms__Weight_Units__c = 'lbs');
        insert item1;
        
        rtms__CarrierQuote__c caq = new rtms__CarrierQuote__c(
                rtms__Load__c            = l.Id,
                rtms__Carrier_Service__c = cs.Id,
                rtms__Carrier_Total__c   = 500,
                rtms__Accepted__c        = true,
                rtms__Vendor__c          = carrier.Id);
        insert caq;


        rtms__TMSDocument__c tmsdoc = new rtms__TMSDocument__c(Name = Label.CarrierRateAndLoadConfirmation);
        insert tmsdoc;

        rtms__TMSDocumentOptions__c tdocopt = new rtms__TMSDocumentOptions__c(rtms__Custom_Page_Name__c = 'ORCarrierRateConfirmation', 
                                                                              rtms__Suppress_Logo__c = false, 
                                                                              rtms__Suppress_Expected_Delivery_Date__c = false,
                                                                              rtms__TMS_Document__c = tmsdoc.Id,
                                                                              rtms__Document_Options__c = docopt.Id);

        insert tdocopt;

        rtms__FreightPlan__c fp = new rtms__FreightPlan__c();
        insert fp;

        rtms__FreightPlanLoad__c fpl = new rtms__FreightPlanLoad__c(rtms__Load__c = l.Id, rtms__Freight_Plan__c = fp.Id, rtms__Number__c = 1);
        insert fpl;

        rtms__Voyage__c voyage = new rtms__Voyage__c(
            rtms__Load__c = l.Id,
            rtms__Carrier_Service__c = cs.Id,
            rtms__Vessel__c = 'Titannic',
            rtms__Voyage_Number__c = '10101');
        insert voyage;

    }
    static private Account getNewAccount(){
        return getNewAccount('Customer; Shipper/Consignee');
    }
    static private Account getNewAccount(String TMStype){
        
        string curuserId = userinfo.getUserId();
        
        Account acct = new Account(Name = 'Revenova REST TEST Account',
                                   PHONE = '312-667-0992',
                                   FAX = '3122816609', 
                                   BillingStreet = '79 w. Monroe',
                                   BillingCity = 'Chicago',
                                   BillingStateCode = 'Il',
                                   BillingPostalCode = '60603',
                                   BillingCountryCode = 'US',
                                   ShippingStreet = '79 w. Monroe',
                                   ShippingCity = 'Chicago',
                                   ShippingStateCode = 'Il',
                                   ShippingPostalCode = '60603',
                                   ShippingCountryCode = 'US',
                                   rtms__TMS_Type__c = TMStype);
        insert acct;
        return acct;
    }
}