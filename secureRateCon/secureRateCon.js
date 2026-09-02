import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCarrierRateCon from '@salesforce/apex/SecureRateConManager.getCarrierRateCon';
import getHighwayStatus from '@salesforce/apex/SecureRateConManager.getHighwayStatus';
import getLoadDetails from '@salesforce/apex/SecureRateConManager.getLoadDetails';
import setSecureRateCon from '@salesforce/apex/SecureRateConManager.setSecureRateCon';
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
    
    connectedCallback() {
        console.log('secureRateCon connected, recordId =', this.recordId);
        getLoadDetails({ loadId: this.recordId })
        .then(result => {
            console.log('getLoadDetails result:', result);
            this.isRequireRateCon = result.requireRateCon;
            if (this.isRequireRateCon) {
                this.banner = 'Use secure rate con for this load';
                this.isRequireRateConDisabled = false;
                this.isShowStatus = false;
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
    renderedCallback() {
        console.log('secureRateCon rendered, recordId =', this.recordId);
    }

    handleRequireRateConChange(event) {
        console.log('handleRequireRateConChange called');
        setSecureRateCon({ loadId: this.recordId});
    }
    handleOpenmodal(){
        this.buttonName = 'Loading...';
        console.log('Secure Rate Confirmation button clicked');
        console.log('Record Id:', this.recordId);
        getCarrierRateCon({ loadId: this.recordId })
            .then((result) => {
                console.log('getCarrierRateCon result:', result);
                if (result && Object.keys(result).length > 0) {
                    console.log('Carrier Rate Confirmation data found, opening modal');
                    const nextModal = this.template.querySelector('c-rate-con-email-modal');
                    if (nextModal) {
                        console.log('found c-rate-con-email-modal in DOM');
                        console.log('result: ' + result.contentVersionId + ' carrierId: ' + result.carrierId + 'carrierquoteid: ' + result.carrierQuoteId + ' highway carrier id: ' + result.highwayCarrierId);
                        nextModal.openModal(this.recordId, result.contentVersionId, result.carrierId, result.carrierQuoteId, result.highwayCarrierId);
                    } else {
                        console.error('c-rate-con-email-modal not found in DOM');
                    }
                } else {
                    const carrierQuoteModal = this.template.querySelector('c-carrier-quote-modal');
                    if (carrierQuoteModal) {
                        console.log('found c-carrier-quote-modal in DOM');
                        carrierQuoteModal.openModal(this.recordId, result.highwayCarrierId);
                    } else { 
                        console.error('c-carrier-quote-modal not found in DOM');
                    }
                }
            })
            .catch((error) => {
                console.error('Error in getCarrierRateCon:', error);
                this.showErrorMessage(error);
            })
            .finally(() => {
                this.buttonName = 'Secure Rate Confirmation';
            });
    }
       
    handleNextModal(event){
        console.log('IN handleNextModal, event detail:', 'loadId: ', event.detail.loadId, 'contentVersionId: ', 
            event.detail.contentVersionId, 'carrierId: ', event.detail.carrierId, 'carrierQuoteId: ', event.detail.carrierQuoteId,
        ' highwayCarrierId: ', event.detail.highwayCarrierId);
        const nextModal = this.template.querySelector('c-rate-con-email-modal');
        if (nextModal) {
            console.log('found c-rate-con-email-modal in DOM');
            nextModal.openModal(event.detail.loadId, event.detail.contentVersionId, event.detail.carrierId, event.detail.carrierQuoteId, event.detail.highwayCarrierId);
        } else {
            console.error('c-rate-con-email-modal not found in DOM');
        }
    }

    showErrorMessage(error) {
        const message = error && error.body ? (error.body.message || JSON.stringify(error.body)) : String(error);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

}


