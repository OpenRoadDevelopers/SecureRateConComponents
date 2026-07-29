import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import getCarrierEmails from '@salesforce/apex/SecureRateConManager.getCarrierEmails';
import getTenderTemplate from '@salesforce/apex/SecureRateConManager.getTenderTemplate';
import launchEmailFlow from '@salesforce/apex/SecureRateConManager.launchEmailFlow';
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
    @track toEmails = 'takunp@openroad.inc';
    carrierId = null;
    templateOptions = [];
    selectedTemplate = '';
    @track subject = '';
    @track body = '';
    contentVersionId = null;

    @api openModal(recordId, contentVersionId, carrierId) {
        console.log('RateConEmailModal openModal called with recordId:', recordId, 'contentVersionId:', contentVersionId);
        this.recordId = recordId;
        this.carrierId = carrierId;
        this.contentVersionId = contentVersionId;
        this.isModalOpen = true;
        //fetch carrier quote emails
        getCarrierEmails({accountId: this.carrierId })
            .then(result => {
                console.log('result: ' , result);
                const emails = Array.isArray(result)
                    ? result.map(r => (typeof r === 'string' ? r : (r.Email || r.email))).filter(Boolean)
                    : [];
                // this.toEmails = emails.join(', ');
            })
            .catch(error => {
                console.error('Error fetching carrier emails:', error);
            });
        getTenderTemplate({ recordId: this.recordId })
        .then(result => {
            this.templateOptions = [
                {
                    label: '-- Select Template --',
                    value: '', 
                    subject: '',
                    templateBody: ''
                },
                {
                    label: result.Name,
                    value: result.Id, 
                    subject: result.Subject,
                    templateBody: result.Body
                }
            ];
            const loadTenderTemplate = this.templateOptions.find(
                t => t.label && t.label.toLowerCase().includes('load tender')
            );
            if (loadTenderTemplate) {
                this.selectedTemplate = loadTenderTemplate.value;
                this.subject = loadTenderTemplate.subject;
                this.body = loadTenderTemplate.templateBody;
            }
        })
        .catch(error => {
            console.error('Error fetching email templates:', error);
        });
        this.isLoading = false;
        
    }

    sendEmail(){
        launchEmailFlow({
            fromWho: this.userName,
            subject: this.subject,
            body: this.body,
            templatename: this.selectedTemplate,
            loadId: this.recordId,
            userId: USER_ID,
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