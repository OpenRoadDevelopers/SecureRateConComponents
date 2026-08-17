import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import getCarrierQuote from '@salesforce/apex/SecureRateConManager.getCarrierQuote';
import highwayRateConAPI from '@salesforce/apex/SecureRateConManager.highwayRateConAPI';
import getValidUsers from '@salesforce/apex/SecureRateConManager.getValidUsers';
const USER_FIELDS = ['User.Email', 'User.Name'];
export default class RateConEmailModal extends LightningElement {
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    userRecord;
    get userEmail() {
        return this.userRecord && this.userRecord.data
            ? this.userRecord.data.fields.Email.value
            : '';
    }
    get userName() {
        return this.userRecord && this.userRecord.data
            ? this.userRecord.data.fields.Name.value
            : '';
    }
    fields = [];
    isModalOpen = false;
    isLoading = true;
    recordId = null;
    @track toEmails = [];
    carrierId = null;
    contentVersionId = null;
    carrierQuoteId = null;
    @track quoteInfo = '';
    allUsers = [];
    userSearch = '';
    toShare = [];
    dot = '';
    isError = false;
    highwayCarrierId = null;
    usersColumns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email' }
    ];
    

    @api openModal(recordId, contentVersionId, carrierId, carrierQuoteId, highwayCarrierId) {
        console.log('RateConEmailModal openModal called with recordId:', recordId, 'contentVersionId:', contentVersionId, 'carrierQuoteId:', carrierQuoteId, 'highwayCarrierId:', highwayCarrierId);
        this.recordId = recordId;
        this.carrierId = carrierId;
        this.contentVersionId = contentVersionId;
        this.carrierQuoteId = carrierQuoteId;
        this.isModalOpen = true;
        this.highwayCarrierId = highwayCarrierId;
        getCarrierQuote({carrierQuoteId: this.carrierQuoteId})
            .then(result => {
                console.log('getCarrierQuote result:', result);
                this.quoteInfo = result.rtms__Carrier_Service__r.Name + ' - ' 
                + (result.rtms__Carrier_Service__r.MC__c != null ? 'MC: ' + result.rtms__Carrier_Service__r.MC__c + ' - ' : '')
                + (result.rtms__Carrier_Service__r.UD_DOT__c != null ? 'UD DOT: ' + result.rtms__Carrier_Service__r.UD_DOT__c + ' - ' : '')
                + new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(result.rtms__Carrier_Total__c || 0);
                this.dot = result.rtms__Carrier_Service__r.UD_DOT__c;
                console.log('dot value:', this.dot);
                if (this.dot == null){
                    const event = new ShowToastEvent({
                        title: 'Error',
                        message: 'dot doesnt exist for this carrier, please contact your administrator',
                        variant: 'error',
                        mode: 'sticky'
                    });
                    this.dispatchEvent(event);
                    this.isError = true;
                }
            })
            .catch(error => {
                console.error('Error fetching carrier quote:', error);
            });
        getValidUsers()
            .then(result => {
                console.log('getValidUsers result:', result);
                this.allUsers = Array.isArray(result) ? result : [];;
            })
            .catch(error => {
                console.error('Error fetching all users:', error);
            });
        
        this.isLoading = false;
        
    }

    get filteredUsers() {
        const search = this.userSearch.toLowerCase();
        return this.allUsers.filter(user => {
            const firstName = (user.FirstName || '').toLowerCase();
            const lastName = (user.LastName || '').toLowerCase();
            const email = (user.Email || '').toLowerCase();
            return (
                (firstName && firstName.startsWith(search)) ||
                (lastName && lastName.startsWith(search)) ||
                (email && email.startsWith(search))
            );
        });
    }

    handleUserSearch(event) {
        this.userSearch = event.target.value;
    }

    sendEmail(){
        highwayRateConAPI({
            fromWho: this.userName,
            subject: null,
            loadId: this.recordId,
            highwayCarrierId: this.highwayCarrierId,
            recipients: this.toEmails,
            contentVersionId: this.contentVersionId
        })
        .then(result => {
            console.log('Email flow launched successfully:', result);
            if(result == 'SUCCESS'){
                this.handleSuccessfulEmailSent();
            }
            else{
                this.handleFailureEmailSent();
            }
            this.closeModal();
        })
        .catch(error => {
            console.error('Error launching email flow:', error);
        });
    }

    get userSelectedIds() {
        const emails = (this.toEmails || []).map(e => e.trim().toLowerCase()).filter(Boolean);
        return emails
        .map(email => {
            const u = this.allUsers.find(x => (x.Email || '').toLowerCase() === email);
            return u ? u.Id : null;
        })
        .filter(id => !!id);
    }

    handleUserSelection(event) {
        const selectedRows = event.detail.selectedRows;
        console.log('Selected rows:', selectedRows);
        this.toEmails = selectedRows.map(row => row.Email);
        console.log('Updated toEmails:', JSON.stringify(this.toEmails));
    }


    get toEmailsString() {
        return (this.toEmails || []).filter(Boolean).join(', ');
    }

    closeModal(){
        this.isModalOpen = false;
    }

    handleSuccessfulEmailSent() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Email sent successfully',
            variant: 'success',
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
    
    handleFailureEmailSent() {
        const event = new ShowToastEvent({
            title: 'Error',
            message: 'Failed to send email',
            variant: 'error',
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }
}