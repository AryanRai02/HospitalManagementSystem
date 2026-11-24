import { LightningElement, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import PATIENT_SELECTED from '@salesforce/messageChannel/PatientSelected__c';
import searchPatients from '@salesforce/apex/PatientService.searchPatients';

const DEBOUNCE_MS = 350;
const MIN_LENGTH = 2;

export default class PatientSearchBar extends LightningElement {
    searchTerm = '';
    results = [];
    errorMessage;
    isSearching = false;
    hasSearched = false;
    selectedName;

    delayTimer;

    @wire(MessageContext)
    messageContext;

    handleChange(event) {
        this.searchTerm = event.target.value;

        // Debounce: wait until the user stops typing before calling Apex
        window.clearTimeout(this.delayTimer);
        if (!this.searchTerm || this.searchTerm.trim().length < MIN_LENGTH) {
            this.results = [];
            this.hasSearched = false;
            this.errorMessage = undefined;
            return;
        }
        this.delayTimer = window.setTimeout(() => this.runSearch(), DEBOUNCE_MS);
    }

    // Imperative Apex call (not @wire), made on demand
    async runSearch() {
        const term = this.searchTerm.trim();
        this.isSearching = true;
        this.errorMessage = undefined;
        try {
            const data = await searchPatients({ searchTerm: term });
            // Ignore the answer if the user has already typed something else
            if (term !== this.searchTerm.trim()) {
                return;
            }
            this.results = data.map((p) => ({
                ...p,
                label: p.Full_Name__c || p.Name,
                dobLabel: p.DOB__c ? p.DOB__c : 'n/a'
            }));
            this.hasSearched = true;

            // Child to parent: send the results up
            this.dispatchEvent(
                new CustomEvent('searchresults', {
                    detail: { term, results: data }
                })
            );
        } catch (error) {
            this.results = [];
            this.errorMessage = error?.body?.message || 'The search failed.';
        } finally {
            this.isSearching = false;
        }
    }

    get hasResults() {
        return this.results.length > 0;
    }

    get showNoResults() {
        return this.hasSearched && !this.isSearching && this.results.length === 0 && !this.errorMessage;
    }

    // Lightning Message Service: publish PATIENT_SELECTED for appointmentForm
    handleSelect(event) {
        const patientId = event.currentTarget.dataset.id;
        const patientName = event.currentTarget.dataset.name;
        this.selectedName = patientName;
        publish(this.messageContext, PATIENT_SELECTED, { patientId, patientName });
    }

    disconnectedCallback() {
        window.clearTimeout(this.delayTimer);
    }
}