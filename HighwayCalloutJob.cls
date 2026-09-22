public class HighwayCalloutJob implements Queueable, Database.AllowsCallouts {
    private Id contentVersionId;
    private String fromWho;
    private String subject;
    private String loadId;
    private String highwayCarrierId;
    private List<String> recipients;
    private Id carrierQuoteId;
    private Boolean isCancel;

    public HighwayCalloutJob(Id contentVersionId, String fromWho, String subject, String loadId, String highwayCarrierId, List<String> recipients, Id carrierQuoteId, Boolean isCancel) {
        this.contentVersionId = contentVersionId;
        this.fromWho = fromWho;
        this.subject = subject;
        this.loadId = loadId;
        this.highwayCarrierId = highwayCarrierId;
        this.recipients = recipients;
        this.carrierQuoteId = carrierQuoteId;
        this.isCancel = isCancel;
    }

    public void execute(QueueableContext ctx) {
        String boundary = '----' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Blob bodyBlob = SecureRateConManager.buildRequestBody(fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, boundary, isCancel);
        
        API_key__mdt ApiKey = [SELECT Api_Credential__c FROM API_key__mdt WHERE DeveloperName = 'HighwayStagingAPIKey' LIMIT 1];
        String bearerToken = ApiKey.Api_Credential__c;
        List<String> notify = new List<String>{ 'IT@openroad.inc' };
        Http http = new Http();
        try {
            HttpResponse res = SecureRateConManager.sendRequest(bodyBlob, boundary, bearerToken);
            Integer status = res.getStatusCode();
            SecureRateConManager.handleStatus(status, res.getBody(), fromWho, subject, loadId, highwayCarrierId, recipients, contentVersionId, carrierQuoteId, isCancel, bodyBlob, boundary, bearerToken);
            System.debug('HighwayCalloutJob: status=' + res.getStatus() + ' code=' + res.getStatusCode());
        } catch (Exception e) {
            SecureRateConManager.handleCalloutError(e, loadId, carrierQuoteId, contentVersionId, this.fromWho);
        }
    }
}