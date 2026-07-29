import { LightningElement, api } from 'lwc';

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
        const carrierQuoteModal = this.template.querySelector('c-carrier-quote-modal');
        if (carrierQuoteModal) {
            console.log('found c-carrier-quote-modal in DOM');
            carrierQuoteModal.openModal(this.recordId);
        } else { 
            console.error('c-carrier-quote-modal not found in DOM');
        }
    }
    handleNextModal(event){
        console.log('IN handleNextModal, event detail:', 'loadId: ', event.detail.loadId, 'contentVersionId: ', event.detail.contentVersionId, 'carrierId: ', event.detail.carrierId);
        const nextModal = this.template.querySelector('c-rate-con-email-modal');
        if (nextModal) {
            console.log('found c-rate-con-email-modal in DOM');
            nextModal.openModal(event.detail.loadId, event.detail.contentVersionId, event.detail.carrierId);
        } else {
            console.error('c-rate-con-email-modal not found in DOM');
        }
    }

}