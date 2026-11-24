import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import {
    subscribe,
    unsubscribe,
    APPLICATION_SCOPE,
    MessageContext
} from 'lightning/messageService';

import APPOINTMENT_REFRESH from '@salesforce/messageChannel/AppointmentRefresh__c';
import PATIENT_SELECTED from '@salesforce/messageChannel/PatientSelected__c';

import getTodayStats from '@salesforce/apex/HospitalController.getTodayStats';
import getRevenueSummary from '@salesforce/apex/HospitalController.getRevenueSummary';
import getDepartmentSummary from '@salesforce/apex/HospitalController.getDepartmentSummary';
import getAvailableDoctors from '@salesforce/apex/HospitalController.getAvailableDoctors';

// API name of the New Patient Registration screen flow (check Setup > Flows)
const REGISTER_FLOW_API_NAME = 'New_Patient_Registration';

export default class HospitalDashboard extends NavigationMixin(LightningElement) {
    selectedDate = this.todayIso();
    selectedDoctorId;
    selectedPatientId;
    selectedPatientName;

    stats = { total: 0, requested: 0, confirmed: 0, completed: 0, cancelled: 0 };
    revenue = { monthRevenue: 0, billCount: 0, pendingApprovals: 0 };
    departments = [];
    doctorOptions = [];

    isLoading = false;
    errorMessage;

    refreshSubscription;
    patientSubscription;

    @wire(MessageContext)
    messageContext;

    todayIso() {
        const now = new Date();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        return `${now.getFullYear()}-${month}-${day}`;
    }

    connectedCallback() {
        // Lightning Message Service: refresh when an appointment is booked anywhere
        this.refreshSubscription = subscribe(
            this.messageContext,
            APPOINTMENT_REFRESH,
            () => this.refreshAll(),
            { scope: APPLICATION_SCOPE }
        );
        // Remember the patient picked in the search bar (for the Open Patient button)
        this.patientSubscription = subscribe(
            this.messageContext,
            PATIENT_SELECTED,
            (message) => {
                this.selectedPatientId = message.patientId;
                this.selectedPatientName = message.patientName;
            },
            { scope: APPLICATION_SCOPE }
        );
        this.loadDashboard();
    }

    disconnectedCallback() {
        unsubscribe(this.refreshSubscription);
        unsubscribe(this.patientSubscription);
        this.refreshSubscription = null;
        this.patientSubscription = null;
    }

    // Doctors for the schedule picker
    @wire(getAvailableDoctors)
    wiredDoctors({ data }) {
        if (data) {
            this.doctorOptions = data.map((d) => ({ label: d.Name, value: d.Id }));
        }
    }

    // Several imperative Apex calls, run together
    async loadDashboard() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const [stats, revenue, departments] = await Promise.all([
                getTodayStats({ selectedDate: this.selectedDate }),
                getRevenueSummary(),
                getDepartmentSummary({ selectedDate: this.selectedDate })
            ]);
            this.stats = stats;
            this.revenue = revenue;
            this.departments = departments.map((d) => ({
                ...d,
                bedCountLabel: d.bedCount == null ? 0 : d.bedCount
            }));
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Could not load the dashboard.';
        } finally {
            this.isLoading = false;
        }
    }

    refreshAll() {
        this.loadDashboard();
        const card = this.template.querySelector('c-doctor-schedule-card');
        if (card) {
            card.refresh();
        }
    }

    get hasDepartments() {
        return this.departments.length > 0;
    }

    get noDepartments() {
        return !this.isLoading && this.departments.length === 0;
    }

    get noPatientSelected() {
        return !this.selectedPatientId;
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.loadDashboard();
    }

    handleDoctorChange(event) {
        this.selectedDoctorId = event.detail.value;
    }

    // Child to parent: appointmentForm tells us a booking happened
    handleAppointmentBooked() {
        this.refreshAll();
    }

    // Child to parent: a row was clicked in doctorScheduleCard, so open that Appointment
    handleAppointmentSelected(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.appointmentId,
                objectApiName: 'Appointment__c',
                actionName: 'view'
            }
        });
    }

    openSelectedPatient() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedPatientId,
                objectApiName: 'Patient__c',
                actionName: 'view'
            }
        });
    }

    openRegisterFlow() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/flow/${REGISTER_FLOW_API_NAME}` }
        });
    }
}