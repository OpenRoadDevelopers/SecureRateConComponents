/**
* Copyright 2015-2022 Revenova, LLC. All rights reserved.
*/
public with sharing class ORCarrierRateConfirmationController {


public class StopWithImages {
    public rtms__Stop__c stop { get; set; }
    public List<String> imageIds { get; set; }

    public StopWithImages(rtms__Stop__c s) {
        stop = s;
        imageIds = new List<String>();

        if (!String.isBlank(s.Stop_Location_Custom_Rate_Con_Page_s__c)) {
            List<String> rawIds = s.Stop_Location_Custom_Rate_Con_Page_s__c.split(',');
            for (String id : rawIds) {
                imageIds.add(id.trim());
            }
        }
    }
}

public List<StopWithImages> stopsWithImages { get; set; }
    
public List<String> CustomerRateConImageIds { get; set; }

public String orgDomainUrl { get; set; }



    public static String LOAD = 'Load__c';
    public static String STOP = 'Stop__c';
    public static String LINE_ITEM = 'LineItem__c';
    public final static String PORT_OF_LOAD       = 'Port of Load';
    public final static String PORT_OF_DISCHARGE  = 'Port of Discharge';  
    public final static String DOOR_TO_DOOR  = 'Door to Door';
    public final static String DOOR_TO_PORT  = 'Door to Port';
    public final static String PORT_TO_DOOR  = 'Port to Door';
    public final static String PORT_TO_PORT  = 'Port to Port';

    public ORCarrierRateConfirmationController(ApexPages.StandardController sc) {
        m_document = ORDB.getTMSDocument(Label.CarrierRateAndLoadConfirmation);
        m_load = (rtms__Load__c) ORDB.getCompleteObject(rtms__Load__c.SObjectType, sc.getId());
        System.debug('m_load: ' + m_load);
        m_quote = ORDB.getAcceptedCarrierQuoteForLoad(m_load.Id);
        System.debug('m_quote: ' + m_quote);
        m_quoteAccessorials = ORDB.getQuoteAccessorials(m_quote.Id);
        m_stops = ORDB.getStops(m_load.Id);
        m_lineItems = ORDB.getLineItems(m_Load.Id);
        m_options = ORUtil.getDocumentOptions(m_load);
 

// ⭐️ NEW: Get Org Domain URL
    orgDomainUrl = URL.getOrgDomainUrl().toExternalForm();
        
       
// ⭐️ ADDED: Populate stopsWithImages from m_stops
        stopsWithImages = new List<StopWithImages>();
        for (rtms__Stop__c s : m_stops) {
            stopsWithImages.add(new StopWithImages(s));
        }

// ⭐️ Add this block to split and trim the custom images
    String rawIds = m_load.Customer_Custom_Rate_Con_Page_s__c;
    CustomerRateConImageIds = new List<String>();

    if (!String.isBlank(rawIds)) {
        List<String> splitIds = rawIds.split(',');
        for (String id : splitIds) {
            CustomerRateConImageIds.add(id.trim());
            }
        }


        String maskIdentity = ApexPages.currentPage().getParameters().get('maskIdentity');
        if(maskIdentity != null) {
            m_maskIdentity = Boolean.valueOf(maskIdentity);
        }
            
        if(!m_maskIdentity && m_load.rtms__Customer__c != null && m_load.rtms__Customs_Broker__c != null) {

            Account customer = ORDB.getAccountShippingInformation(m_load.rtms__Customer__c);
            Account shipFrom = getShipFrom();
            Account shipTo = getShipTo();

            m_broker = ORDB.getCustomsBroker(customer.rtms__Transportation_Profile__c, 
                                           m_load.rtms__Customs_Broker__c, 
                                           ORUtil.getTwoCharacterCountryCode(shipFrom.get(ORSObjectUtil.getShippingCountryField())),
                                           ORUtil.getTwoCharacterCountryCode(shipTo.get(ORSObjectUtil.getShippingCountryField())));
        }
    }
    
    //---------------------
    // getters/setters
    //---------------------

    // note that we pass a "fake" account for those stops without an account (yet)
    public Account getShipFrom() {
            
        if(m_shipFrom == null && m_stops.size() > 0) {
            
            rtms__Stop__c stop = getFirstStop(); 
            if(stop.rtms__Location2__c != null) { 
                m_shipFrom = ORDB.getAccountShippingInformation(stop.rtms__Location2__c);
            }
            else {
                m_shipFrom = new Account(Name = 'Not Specified', 
                                        rtms__TMS_Type__c = 'Shipper/Consignee',
                                        ShippingStreet = null, 
                                        ShippingCity = stop.rtms__City__c, 
                                        ShippingPostalCode = stop.rtms__Postal_Code__c,
                                        ShippingLatitude = stop.rtms__Geolocation__Latitude__s,
                                        ShippingLongitude = stop.rtms__Geolocation__Longitude__s);
                                        
                m_shipFrom.put(ORSObjectUtil.getShippingStateField(), stop.rtms__State_Province__c);
                m_shipFrom.put(ORSObjectUtil.getShippingCountryField(), stop.rtms__Country__c);
            } 
        }
        return m_shipFrom;
    }
    
    // note that we pass a "fake" account for those stops without an account (yet)
    public Account getShipTo() {

        if(m_shipTo == null && m_stops.size() > 1) {
            
            rtms__Stop__c stop = getLastStop();
            if(stop.rtms__Location2__c != null) {
                m_shipTo = ORDB.getAccountShippingInformation(stop.rtms__Location2__c);
            }
            else {
                m_shipTo = new Account(Name = 'Not Specified', 
                                        rtms__TMS_Type__c = 'Shipper/Consignee',
                                       ShippingStreet = null,
                                       ShippingCity = stop.rtms__City__c, 
                                       ShippingPostalCode = stop.rtms__Postal_Code__c,
                                       ShippingLatitude = stop.rtms__Geolocation__Latitude__s,
                                       ShippingLongitude = stop.rtms__Geolocation__Longitude__s);
                                                                              
                m_shipTo.put(ORSObjectUtil.getShippingStateField(), stop.rtms__State_Province__c);
                m_shipTo.put(ORSObjectUtil.getShippingCountryField(), stop.rtms__Country__c);                                       
            } 
        }
        return m_shipTo;
    }

    public rtms__Stop__c getFirstStop() {
        return m_stops.size() > 0 ? m_stops[0] : null;
    }

    public rtms__Stop__c getLastStop() {
        return m_stops.size() > 0 ? m_stops[getStops().size()-1] : null;
    }

    // key is account Id
    public Map<Id,Account> getStopLocations() {
    
        if(m_stopLocations == null) {
            m_stopLocations = ORDB.getLoadStopLocations(m_stops);
        }
        return m_stopLocations;
    }

    // key is contact Id
    public Map<Id,Contact> getStopContacts() {
    
        if(m_stopContacts == null) {
            m_stopContacts = ORDB.getLoadStopContacts(m_stops);
        }
        return m_stopContacts;
    }

    public rtms__CarrierQuote__c getQuote() {
        return m_quote;
    }
    
    public List<StopWithImages> getStopsWithImages() {
    return stopsWithImages;
}

public List<rtms__Stop__c> getRawStops() {
    return m_stops;
}



    public List<rtms__LoadAccessorial__c> getCarrierProvidedAccessorials() {
                
        if(m_accessorials == null) {
            m_accessorials = new List<rtms__LoadAccessorial__c>();
            for(rtms__LoadAccessorial__c a : ORDB.getLoadAccessorials(m_load.Id)) {
                if('Carrier' == a.rtms__Provider__c) {
                    m_accessorials.add(a);
                }
            }
        }                 
        return m_accessorials;
    }

    public Boolean getHasCarrierProvidedAccessorials() {
        return getCarrierProvidedAccessorials().size() > 0;
    }

    public List<rtms__CarrierQuoteAccessorial__c> getCarrierQuoteAccessorials() {
        return m_quoteAccessorials;
    }

    public Boolean getHasAccessorialCharges() {
        return m_quoteAccessorials.size() > 0;
    }

    public String getCurrencySymbol() {
        return ORSObjectUtil.getCurrencyCode(m_quote);
    }
    
    public List<CurrencyAmount> getChargesByCurrency() {
        String curr1 = ORSObjectUtil.getCurrencyCode(m_quote);
        Map<String,Decimal> caMap = new Map<String,Decimal>();

        if(m_quote.rtms__Net_Line_Haul__c != null) {
            caMap.put(curr1, m_quote.rtms__Net_Line_Haul__c);
        }
        if(m_quote.rtms__Fuel_Surcharge__c != null) {
            if(caMap.containsKey(curr1)) {
                caMap.put(curr1, m_quote.rtms__Fuel_Surcharge__c + caMap.get(curr1));
            }
            else {
                caMap.put(curr1, m_quote.rtms__Fuel_Surcharge__c);
            }
        }
        if(m_quote.rtms__Accessorial_Charges__c != null) {
            if(m_quoteAccessorials.size() > 0) {
                for(rtms__CarrierQuoteAccessorial__c cqa : m_quoteAccessorials) {
                    String curr2 = ORSObjectUtil.getCurrencyCode(cqa);
                    if(caMap.containsKey(curr2)) {
                        caMap.put(curr2, ORUtil.nullFriendlyAdd(cqa.rtms__Charge__c, caMap.get(curr2)));
                    }
                    else {
                        caMap.put(curr2, ORUtil.nullFriendlyAdd(cqa.rtms__Charge__c, 0));
                    }        
                }
            }
            else {
                if(caMap.containsKey(curr1)) {
                    caMap.put(curr1, m_quote.rtms__Accessorial_Charges__c + caMap.get(curr1));
                }
                else {
                    caMap.put(curr1, m_quote.rtms__Accessorial_Charges__c);
                }    
            }
        }
        if(caMap.size() == 0) {
            caMap.put(curr1, m_quote.rtms__Carrier_Total__c);
        }

        List<CurrencyAmount> caList = new List<CurrencyAmount>();
        for(String c : caMap.keySet()) {
            caList.add(new CurrencyAmount(caMap.get(c),c));
        }
        caList.sort();
        return caList;        
    }

    public rtms__Load__c getLoad() {
        return m_load;
    }

    // for drayage to/from port scenarios
    public rtms__Load__c getAdjacentOceanLoad() {
        
        if(ORDB.getFreightPlanLoadsForLoad(m_load.Id).size() > 0) {
            Id oceanId = ORDB.getAdjacentOceanLoadId(m_load); 
            if(oceanId != null) {
                return (rtms__Load__c)ORDB.getCompleteObject(rtms__Load__c.SObjectType, oceanId);
            }
        }
        return null;
    }

    public List<rtms__Stop__c> getStops() {
        return m_stops;
    }

    public Map<Id, List<rtms__LoadReference__c>> getLoadReferencesByStop() {
        
        Map<Id, List<rtms__LoadReference__c>> rMap = new Map<Id, List<rtms__LoadReference__c>>();
        for(rtms__Stop__c s : getStops()) {
            rMap.put(s.Id, new List<rtms__LoadReference__c>());
        }
        for(rtms__LoadReference__c lr : getLoadReferences()) {
            if(lr.rtms__Stop__c != null) {
                rMap.get(lr.rtms__Stop__c).add(lr);
            }
        }
        return rMap;
    }
    
    public List<rtms__LoadReference__c> getLoadReferences() {
        
        if(m_loadReferences == null) {
            m_loadReferences = new List<rtms__LoadReference__c>();
            Map<Id, List<rtms__LoadReference__c>> rMap = ORDB.getLoadReferences(new List<Id>{m_load.Id});
            if(rMap.containsKey(m_load.Id)) {
                m_loadReferences = rMap.get(m_load.Id);
            }
        }
        return m_loadReferences;
    }

    public Account getCarrier() {                
        return [select Id, Name from Account where Id = :m_quote.rtms__Vendor__c];
    }

    public String getMcNumber() {
        Account carrier = ORDB.getAccountShippingInformation(m_quote.rtms__Vendor__c);
        return carrier.rtms__Transportation_Profile__r.rtms__MC_Number__c;
    }

    public Contact getQuoteContact() {              
                
        rtms__CarrierService__c cs = ORDB.getCarrierService(m_quote.rtms__Carrier_Service__c);
        if(cs.rtms__Quote_Contact__c != null) { 
            return ORDB.getContactDetail(cs.rtms__Quote_Contact__c);
        }
        else {
            return null;
        }
    }
    
    public List<rtms__LineItem__c> getLineItems() {
        return m_lineItems;
    }

    public List<Contact> getHazMatContacts() {
        
        List<Id> contactIdList = new List<Id>();        
        for(rtms__LineItem__c item : getLineItems()) {
            if(item.rtms__HazMat_Contact__c != null) {
                contactIdList.add(item.rtms__HazMat_Contact__c);
            }    
        }
        
        return ORDB.getContactDetail(contactIdList); 
    }

    public Boolean getHasNMFCInformation() {
        
        for(rtms__LineItem__c item : getLineItems()) {
            if(item.rtms__NMFC_Class__c != null || item.rtms__NMFC_Number__c != null) {
                return true;
            }
        }
        return false;
    }
    
    public rtms__DocumentOptions__c getDocumentOptions() {
        return m_options; 
    }
    
    public Account getDocumentAccount() {
        
        if(m_options != null && m_options.rtms__Document_Account__c != null) {
            return ORDB.getAccountShippingInformation(m_options.rtms__Document_Account__c);
        }
        else {
            return new Account(Name = 'Please Configure Document Account');
        }
    }
    public List<rtms__TMSDocumentField__c> getExtraLoadFields() {
        return getExtraFields(LOAD);
    }
    public List<rtms__TMSDocumentField__c> getExtraStopFields() {
        return getExtraFields(STOP);
    }        
    public List<rtms__TMSDocumentField__c> getExtraLineItemFields() {
        return getExtraFields(LINE_ITEM);
    }   
    public Integer getExtraLineItemFieldCount() {
        return getExtraLineItemFields().size();
    }

    private List<rtms__TMSDocumentField__c> getExtraFields(String tableName) {
        List<rtms__TMSDocumentField__c> extraFields = new List<rtms__TMSDocumentField__c>();
        if(getDocumentOptions() != null) {
            for(rtms__TMSDocumentField__c tdf : getDocumentFields(getDocumentOptions().Id)) {
                if(tdf.rtms__Table__c == tableName) {
                    extraFields.add(tdf);
                }
            }
        }
        return extraFields;
    }
    private List<rtms__TMSDocumentField__c> getDocumentFields(Id documentOptionsId) {
        if(!m_fields.containsKey(documentOptionsId)) {
            m_fields.put(documentOptionsId, ORDB.getTMSDocumentFields(documentOptionsId, m_document.Id));      
        }
        return m_fields.get(documentOptionsId);  
    }
    public Boolean getIsMultiCurrencyOrganization() {
        return UserInfo.isMultiCurrencyOrganization();
    }
    private void initTDO() {
        m_tmsDocumentOptions = 
            [select rtms__Custom_Page_Name__c, rtms__Logo_Id__c, rtms__Suppress_Logo__c, rtms__Suppress_Expected_Delivery_Date__c 
               from rtms__TMSDocumentOptions__c where rtms__TMS_Document__c = :m_document.Id and rtms__Document_Options__c = :getDocumentOptions().Id];
    }  
    public Boolean getSuppressLogo() {
        
        try {
            if(m_tmsDocumentOptions == null) {
                initTDO();
            }
            return m_tmsDocumentOptions.rtms__Suppress_Logo__c;
        }
        catch(Exception e) {
            handleException(e,null);
            return false;
        }
    }
    public String getDocumentLogoUrl() {
        try {
            if(m_tmsDocumentOptions == null) {
                initTDO();
            }
            if(m_tmsDocumentOptions.rtms__Logo_Id__c != null) {
                return getLogoUrl(m_tmsDocumentOptions.rtms__Logo_Id__c);
            }
            else {
                return getLogoUrl(getDocumentOptions().rtms__Logo_Id__c);
            }
        }
        catch(Exception e) {
            handleException(e,null);
            return '';
        }
    }

    public String getLogoUrl(Id logoId) {
        if (logoId == null) {
            return '';
        }
        if(isAttachment(logoId) || isDocument(logoId)) {
            return '/servlet/servlet.FileDownload?file=' + logoId;
        }

        return '/sfc/servlet.shepherd/version/download/' + logoId;
    }
    
    private Boolean isAttachment(Id fileId) {
        return fileId.getSobjectType() == Attachment.getSObjectType();
    }

    private Boolean isDocument(Id fileId) {
        return fileId.getSobjectType() == Document.getSObjectType();
    }

    public List<rtms__Voyage__c> getVoyageList() {
        if(m_voyageList == null) {
            m_voyageList = new List<rtms__Voyage__c>();
            rtms__Load__c adjacentOceanLoad = getAdjacentOceanLoad();
            if(adjacentOceanLoad != null) {
                for(rtms__Voyage__c v : ORDB.getVoyagesForLoad(adjacentOceanLoad.Id)) {
                    m_voyageList.add(v);
                }
            }
        }
        return m_voyageList;
    }

    public Boolean getHasVoyages() {
        return getVoyageList().size() > 0;
    }

    public rtms__Voyage__c getFirstVoyage() {
        if(getHasVoyages()) {
            return getVoyageList()[0];
        } else {
            return null;
        }
    }

    public String getFirstVoyageType() {
        rtms__Voyage__c v = getFirstVoyage();
        if(PORT_OF_LOAD == v.rtms__Origin_Type__c) {

            if(PORT_OF_DISCHARGE == v.rtms__Destination_Type__c) {
                return PORT_TO_PORT;    
            }
            else {
                return PORT_TO_DOOR;
            }
        }
        else {

            if(PORT_OF_DISCHARGE == v.rtms__Destination_Type__c) {
                return DOOR_TO_PORT;
            }
            else {
                return DOOR_TO_DOOR;
            }            
        }
    }

    public User getReplyToUser() {
        
        if(UserInfo.getUserType().startsWith('Guest') || UserInfo.getUserType().startsWith('Partner') || UserInfo.getUserType().startsWith('Customer')) {
            return new User();
        }
        else {
            return ORDB.getUser(UserInfo.getUserId());
        }
    }

    public List<StopWithLineItems> getStopsWithLineItems() {
        
        List<StopWithLineItems> l = new List<StopWithLineItems>();

        for(rtms__Stop__c stop: m_stops) {

            StopWithLineItems sli = new StopWithLineItems(stop, new List<rtms__LineItem__c>());
            l.add(sli);

            for(rtms__LineItem__c item : m_lineItems) {
                if(item.rtms__Pickup_Stop__c == stop.Id || item.rtms__Delivery_Stop__c == stop.Id) {
                    sli.LineItems.add(item);
                }
            }
        }

        return l;
    }

    public String getToday() {
        return date.today().day() + '/' + date.today().month() + '/' + date.today().year();
    }

    public Boolean getIsTwoStopLoad() {
        return m_stops.size() <= 2;
    }

    public Boolean getShowContactInfoToCarrier() {
        return m_options.rtms__Show_Contact_Info__c;
    }

    public rtms__CustomsBroker__c getCustomsBroker() {
        return m_broker;
    }
    
    public rtms__EquipmentType__c getEquipmentType() {
        return m_load.rtms__Equipment_Type__c != null ? (rtms__EquipmentType__c)ORDB.getCompleteObject(rtms__EquipmentType__c.SObjectType, m_load.rtms__Equipment_Type__c) : null;  
    }


    public Boolean getMaskShipperConsigneeIdentity() {
        return m_maskIdentity;
    }

    public String getLanguageCode() {
        
        if(m_quote.rtms__Vendor__c != null) {
            Account carrier = ORDB.getAccountShippingInformation(m_quote.rtms__Vendor__c);
            return ORUtil.getLanguages().get(carrier.rtms__Transportation_Profile__r.rtms__Language__c);
        }
        else {
            return 'en';
        }
    }

    public List<rtms__Container__c> getContainerList() {

        if(m_containerList == null) {
            m_containerList = ORDB.getContainersForLoad(m_load.Id);
        }
        return m_containerList;
    }

    public Boolean getShowContainers() {
        return getContainerList().size() > 0 && 
               ORSObjectUtil.getCascadingFieldSetMembers(rtms__Container__c.SObjectType, 'TMS2', m_load.rtms__Mode__c).size() > 0;
    }

    public List<FieldSetMember> getContainerFields() {
        return ORSObjectUtil.getCascadingFieldSetMembers(rtms__Container__c.SObjectType, 'TMS2', m_load.rtms__Mode__c);
    }
    public String getShippingStateField() {
        return ORSObjectUtil.getShippingStateField();
    }
    public String getShippingCountryField() {
        return ORSObjectUtil.getShippingCountryField();
    }

    public void handleException(Exception e, String msg) {
    
        if(e instanceof SecurityException){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
        }
        else if(e instanceof ORDisplayableException){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, e.getMessage()));
        }
        else if(!ORUtil.isNullOrBlank(msg)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, msg));
        }
        else if(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, e.getMessage().substring(e.getMessage().indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION'))));
        }
        else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, Label.GenericErrorMessage));
        }
        
        ORUtil.logAlways(msg);
    }

    //-----------------------------
    // inner classes
    //-----------------------------

    public class StopWithLineItems {

        public StopWithLineItems(rtms__Stop__c s, List<rtms__LineItem__c> li) {
            Stop = s;
            LineItems = li;
        }
        public rtms__Stop__c            Stop {get;set;}
        public List<rtms__LineItem__c>  LineItems {get;set;}
    }

    public class CurrencyAmount implements Comparable {

        public CurrencyAmount(Decimal value, String curr) {
            m_value = value;
            m_currencyCode = curr;
        }
        
        public Decimal getValue() {
            return m_value;
        }
        public void setValue(Decimal v) {
            m_value = v;
        }
        
        public String getCurrencyCode() {
            return m_currencyCode;
        }
    
        public Integer compareTo(Object obj2) {
            CurrencyAmount ca2 = (CurrencyAmount)obj2;
            return this.getValue() >= ca2.getValue() ? -1 : 1;
        } 
        
        //-------------------
        // private
        //-------------------
        
        private Decimal m_value;
        private String  m_currencyCode;
        
    }

    //---------------------
    // private
    //---------------------
    
    private Account                                     m_shipFrom;               
    private Account                                     m_shipTo;
    private rtms__CarrierQuote__c                       m_quote;
    private List<rtms__CarrierQuoteAccessorial__c>      m_quoteAccessorials;
    private rtms__Load__c                               m_load;
    private List<rtms__LoadAccessorial__c>              m_accessorials = null;   
    private List<rtms__LoadReference__c>                m_loadReferences = null;
    private List<rtms__Stop__c>                         m_stops;
    private List<rtms__Voyage__c>                       m_voyageList = null;
    private Map<Id,String>                              m_stopDateMap;
    private Map<Id,Account>                             m_stopLocations;
    private Map<Id,Contact>                             m_stopContacts;
    private List<rtms__LineItem__c>                     m_lineItems;
    private List<rtms__Container__c>                    m_containerList = null;
    private rtms__DocumentOptions__c                    m_options;
    private rtms__TMSDocument__c                        m_document;
    private rtms__TMSDocumentOptions__c                 m_tmsDocumentOptions;
    private Map<Id, List<rtms__TMSDocumentField__c>>    m_fields = new Map<Id, List<rtms__TMSDocumentField__c>>();
    private String                                      m_docOptionsImage;
    private rtms__CustomsBroker__c                      m_broker;
    private Boolean                                     m_maskIdentity = false;
    
}

// EOF