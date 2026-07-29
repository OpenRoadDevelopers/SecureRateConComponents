import { LightningElement, api } from 'lwc';
import getCarrierQuotes from '@salesforce/apex/SecureRateConManager.getCarrierQuotes';
import setCarrier from '@salesforce/apex/SecureRateConManager.setCarrier';
import saveLoadPdfToFiles from '@salesforce/apex/SecureRateConManager.saveLoadPdfToFiles';
export default class CarrierQuoteModal extends LightningElement {
    isModalOpen = false;
    quotes = [];
    selectedCarrier = null;
    selectedQuoteId = null;
    noData = false;
    isLoading = true;
    connectedCallback(){
        console.log('Carrier Quote Modal connected');
    }

    @api openModal(recordId) {
        this.recordId = recordId;
        this.isModalOpen = true;
        console.log('Carrier Quote Modal opened');
        console.log('In carrier quote modal record id:', this.recordId);
        getCarrierQuotes({ loadId: this.recordId })
            .then(result => {
                console.log('Carrier quotes retrieved:', result);
                if (result.length === 0) {
                    this.noData = true;
                } else {
                    this.noData = false;
                    this.quotes = result.map(quote => {
                        return {
                            ...quote,
                            isSelected: false,
                            isDisabled: false
                        };
                    });
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error retrieving carrier quotes:', error);
                this.isLoading = false;
            });


    }
    
    @api closeModal() {
        this.isModalOpen = false;
        console.log('Carrier Quote Modal closed');
    }

    handleSelect(event) {
        this.selectedCarrier = event.target.dataset.value;
        this.selectedQuoteId = event.target.dataset.quoteId;
        const isChecked = event.target.checked;
        
        console.log('Selected carrier value:', this.selectedCarrier, 'checked:', isChecked, 'selected quote id:', this.selectedQuoteId);
        //disable all other checkboxes after selection
        if (isChecked) {
            this.quotes = this.quotes.map(quote => ({
                ...quote,
                isSelected: quote.Id === this.selectedQuoteId,
                isDisabled: quote.Id !== this.selectedQuoteId
            }));
        } else {
            this.quotes = this.quotes.map(quote => ({
                ...quote,
                isSelected: false,
                isDisabled: false
            }));
        }
    }
    
    async nextModal(event){
        this.isLoading = true;
        console.log('nextModal clicked');
        console.log('Selected carrier value:', this.selectedCarrier);
        try {
            await setCarrier({
                loadId: this.recordId,
                carrierId: this.selectedCarrier,
                quoteId: this.selectedQuoteId
            });
            const pdfResult = await saveLoadPdfToFiles({ loadId: this.recordId });
            console.log('Load PDF saved successfully:', pdfResult);
            if (pdfResult) {
                console.log('dispatching nextmodal event with loadId:', this.recordId, 'and contentDocumentId:', pdfResult);
                this.dispatchEvent(new CustomEvent('nextmodal', {
                    detail: { loadId: this.recordId, contentVersionId: pdfResult, carrierId: this.selectedCarrier}, 
                    bubbles: true, 
                    composed: true
                }));
                this.isLoading = false;
                this.closeModal();
            }
        } catch (error) {
            console.error('Error in nextModal:', error);
            this.isLoading = false;
        }
        
    }
}
