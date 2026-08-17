import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCarrierRateCon from '@salesforce/apex/SecureRateConManager.getCarrierRateCon';
export default class SecureRateCon extends LightningElement {
    @api recordId;
    connectedCallback() {
        console.log('secureRateCon connected, recordId =', this.recordId);
    }
    renderedCallback() {
        console.log('secureRateCon rendered, recordId =', this.recordId);
    }
    handleOpenmodal(){
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
            });
    }
       
    handleNextModal(event){
        console.log('IN handleNextModal, event detail:', 'loadId: ', event.detail.loadId, 'contentVersionId: ', 
            event.detail.contentVersionId, 'carrierId: ', event.detail.carrierId, 'carrierQuoteId: ', event.detail.carrierQuoteId);
        const nextModal = this.template.querySelector('c-rate-con-email-modal');
        if (nextModal) {
            console.log('found c-rate-con-email-modal in DOM');
            nextModal.openModal(event.detail.loadId, event.detail.contentVersionId, event.detail.carrierId, event.detail.carrierQuoteId);
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