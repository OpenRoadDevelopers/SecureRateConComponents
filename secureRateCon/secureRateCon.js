import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getCarrierRateCon from '@salesforce/apex/SecureRateConManager.getCarrierRateCon';
// import getHighwayStatus from '@salesforce/apex/SecureRateConManager.getHighwayStatus';
//import updatePostToHighway from '@salesforce/apex/SecureRateConManager.updatePostToHighway';
import getLoadDetails from '@salesforce/apex/SecureRateConManager.getLoadDetails';
import setupUpdateSecureRateCon from '@salesforce/apex/SecureRateConManager.setupUpdateSecureRateCon';
import setSecureRateCon from '@salesforce/apex/SecureRateConManager.setSecureRateCon';
import updateSecureRateConRequest from '@salesforce/apex/SecureRateConManager.updateSecureRateConRequest';
export default class SecureRateCon extends LightningElement {
    buttonName = 'Send Updated Secure Rate Con';
    @track status = '';
    @track datetime = '';
    @track banner = '';
    israteConDisabled = false;
    @api recordId;
    isRequireRateCon = false;
    isRequireRateConDisabled = false;
    isShowStatus = false;
    isShowButton = false;
    isLoading = true;
    loadStatus='';
    mode = '';
    @track infobubble= 'test';
    
    connectedCallback() {
        console.log('secureRateCon connected, recordId =', this.recordId);
        this.isLoading = true;
        this.secureRateConDetails();
        // getHighwayStatus({ loadId: this.recordId })
        //     .then(result => {
        //         console.log('getHighwayStatus result:', result);
        //         this.status = result.status;
        //         this.datetime = result.lastUpdated;
        //     })
        //     .catch(error => {
        //         console.error('Error in getHighwayStatus:', error);
        //     }); 
    }
    get toggleClass() {
        return this.isRequireRateConDisabled ? 'toggle-wrapper disabled' : 'toggle-wrapper';
    }
    secureRateConDetails(){
        getLoadDetails({ loadId: this.recordId })
        .then(result => {
            console.log('getLoadDetails result:', result);
            this.isRequireRateCon = result.requireRateCon;
            this.loadStatus = result.loadStatus;
            console.log('getLoadDetails loadStatus:', this.loadStatus);
            this.mode = result.modeName;
            console.log('getLoadDetails mode:', this.mode);
            if(this.isRequireRateCon){
                this.infobubble = `To send Carrier their Rate Confirmation, make sure your Carrier Quote and saved and simply use the “Assign” button. This will assign the carrier to the load and send them the rate confirmation via Highway's Secure Rate Con.\n\nTo disable, please speak to a manager or Carrier Setup/Compliance.`;
            }
            if (result.requireRateCon == false && result.carrierLoad == true && result.vendor == null && result.carrier == null && result.carrierService == null && result.mode != 'Rail' && (this.loadStatus == 'Unassigned' || this.loadStatus == 'Quotes Requested' || this.loadStatus == 'Quotes Received')) {
                console.log('conditions met for false able to enable secure rate con');
                this.banner = 'Use secure rate con for this load';
                this.isRequireRateConDisabled = false;
                this.isShowStatus = false;
                this.isShowButton = false;
                this.infobubble = `Enable to have Carrier Rate Confirmations sent via Highway's Secure Rate Con.`;
            }
            else if (result.requireRateCon == false && (this.loadStatus != 'Unassigned' && this.loadStatus != 'Quotes Requested' && this.loadStatus !='Quotes Received')){
                console.log('conditions not met can not enable secure rate con');
                this.isRequireRateConDisabled = true;
                this.isShowButton = false;
                this.infobubble = `Load Status must be Unassigned, Quotes Requested, or Quotes Received in order to enable use of Highway Secure Rate Con.`;

            } else {
                this.banner = 'Use/Secure rate con required for this load';
                this.isRequireRateConDisabled = true;
                this.status = result.quoteStatus;
                this.datetime = result.lastUpdated;
                if (this.status != 'cancelled') {
                    const vendor = result.vendor;
                    const carrier = result.carrier;
                    const carrierService = result.carrierService;
                    if(vendor != null && carrier != null && carrierService != null){
                        this.isShowStatus = true;
                        if(this.status != null && this.status != ''){
                            this.isShowButton = true;
                        }
                    }
                    else{
                        this.isShowStatus = false;
                        this.isShowButton = false;
                    }
                }
                else{
                    this.isShowStatus = false;
                    this.isShowButton = false;
                }
            }
        })
        .finally(() => {
            this.isRequireRateConDisabled = false;
            this.isLoading = false;
        });
    }
    handleRefresh(){
        console.log('handleRefresh called');
        this.isLoading = true;
        this.secureRateConDetails();
    }
    renderedCallback() {
        console.log('secureRateCon rendered, recordId =', this.recordId);
    }

    handleRequireRateConChange(event) {
        console.log('handleRequireRateConChange called');
        setSecureRateCon({ loadId: this.recordId});
    }

    handleUpdate(){
        console.log('in handle update');
        this.buttonName = 'sending...';
        console.log('calling setup secure rate con update');
        setupUpdateSecureRateCon({ loadId: this.recordId })
        .then (result => {
            console.log('setup secure rate con update called: '  + JSON.stringify(result));
            if(result && result.contentVersionId){
                updateSecureRateConRequest({
                    fromWho: result.fromWho,
                    subject: result.subject,
                    loadId: result.loadId,
                    highwayCarrierId: result.highwayCarrierId,
                    recipients: result.recipients,
                    contentVersionId: result.contentVersionId,
                    carrierQuoteId: result.carrierQuoteId,
                    isCancel: result.isCancel
                })
                .then(response => {
                    console.log('sendRequest response:', response);
                    if(response && (response.statusCode === 200 || response.statusCode === 201)){
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'Updated Secure Rate Con Sent',
                                variant: 'success',
                            }),
                        );
                    } else {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Failed',
                                message: 'Could not send Updated Secure Rate Con. See Email notification for troubleshooting steps',
                                variant: 'error',
                            }),
                        );
                    }
                })
                .catch(error => {
                    console.error('Error in sendRequest:', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Failed',
                            message: 'Could not send Updated Secure Rate Con. See Email notification for troubleshooting steps',
                            variant: 'error',
                        }),
                    );
                });
            }
        })
        .finally(() => {
            this.buttonName = 'Send Updated Secure Rate Con';
        });
        
        // updatePostToHighway({ loadId: this.recordId })
        //     .then(result => {
        //         console.log('updatePostToHighway result:', result);
        //         if(result && result.statusCode === '200'){
        //             this.dispatchEvent(
        //                 new ShowToastEvent({
        //                     title: 'Success',
        //                     message: 'Successfully posted to Highway.',
        //                     variant: 'success',
        //                 }),
        //             );
        //         } else {
        //             this.dispatchEvent(
        //                 new ShowToastEvent({
        //                     title: 'Error',
        //                     message: result.responseBody || 'An error occurred while posting to Highway.',
        //                     variant: 'error',
        //                 }),
        //             );
        //         }
        //     })
        //     .catch(error => {
        //         console.error('Error in updatePostToHighway:', error);
        //         this.dispatchEvent(
        //             new ShowToastEvent({
        //                 title: 'Error',
        //                 message: error.body ? error.body.message : error.message,
        //                 variant: 'error',
        //             }),
        //         );
        //     })
            
    }

    // handleOpenmodal(){
    //     this.buttonName = 'Loading...';
    //     console.log('Secure Rate Confirmation button clicked');
    //     console.log('Record Id:', this.recordId);
    //     getCarrierRateCon({ loadId: this.recordId })
    //         .then((result) => {
    //             console.log('getCarrierRateCon result:', result);
    //             if (result && Object.keys(result).length > 0) {
    //                 console.log('Carrier Rate Confirmation data found, opening modal');
    //                 const nextModal = this.template.querySelector('c-rate-con-email-modal');
    //                 if (nextModal) {
    //                     console.log('found c-rate-con-email-modal in DOM');
    //                     console.log('result: ' + result.contentVersionId + ' carrierId: ' + result.carrierId + 'carrierquoteid: ' + result.carrierQuoteId + ' highway carrier id: ' + result.highwayCarrierId);
    //                     nextModal.openModal(this.recordId, result.contentVersionId, result.carrierId, result.carrierQuoteId, result.highwayCarrierId);
    //                 } else {
    //                     console.error('c-rate-con-email-modal not found in DOM');
    //                 }
    //             } else {
    //                 const carrierQuoteModal = this.template.querySelector('c-carrier-quote-modal');
    //                 if (carrierQuoteModal) {
    //                     console.log('found c-carrier-quote-modal in DOM');
    //                     carrierQuoteModal.openModal(this.recordId, result.highwayCarrierId);
    //                 } else { 
    //                     console.error('c-carrier-quote-modal not found in DOM');
    //                 }
    //             }
    //         })
    //         .catch((error) => {
    //             console.error('Error in getCarrierRateCon:', error);
    //             this.showErrorMessage(error);
    //         })
    //         .finally(() => {
    //             this.buttonName = 'Secure Rate Confirmation';
    //         });
    // }
       
    // handleNextModal(event){
    //     console.log('IN handleNextModal, event detail:', 'loadId: ', event.detail.loadId, 'contentVersionId: ', 
    //         event.detail.contentVersionId, 'carrierId: ', event.detail.carrierId, 'carrierQuoteId: ', event.detail.carrierQuoteId,
    //     ' highwayCarrierId: ', event.detail.highwayCarrierId);
    //     const nextModal = this.template.querySelector('c-rate-con-email-modal');
    //     if (nextModal) {
    //         console.log('found c-rate-con-email-modal in DOM');
    //         nextModal.openModal(event.detail.loadId, event.detail.contentVersionId, event.detail.carrierId, event.detail.carrierQuoteId, event.detail.highwayCarrierId);
    //     } else {
    //         console.error('c-rate-con-email-modal not found in DOM');
    //     }
    // }

    // showErrorMessage(error) {
    //     const message = error && error.body ? (error.body.message || JSON.stringify(error.body)) : String(error);
    //     this.dispatchEvent(new ShowToastEvent({
    //         title: 'Error',
    //         message: message,
    //         variant: 'error'
    //     }));
    // }

}


