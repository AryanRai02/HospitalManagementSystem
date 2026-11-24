import { LightningElement, api, wire } from 'lwc';
import getAppointmentsByDoctor from '@salesforce/apex/HospitalController.getAppointmentsByDoctor';

export default class DoctorScheduleCard extends LightningElement {
    // Passed in by the parent (for example hospitalDashboard passes selectedDate)
    // On a Doctor record page Salesforce fills recordId automatically
    @api recordId;
    @api doctorId;
    @api selectedDate; // ISO date string, for example 2026-11-23

    rows = [];
    errorMessage;
    isLoading = false;

    // Apex wire: runs again whenever doctorId or selectedDate changes
      wiredResult;

    @wire(getAppointmentsByDoctor, {
        doctorId: '$effectiveDoctorId',
        selectedDate: '$effectiveDate'
    })
    wiredAppointments(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.errorMessage = undefined;
            this.rows = data.map((appt) => ({
                ...appt,
                timeLabel: this.formatTime(appt.slot),
                patientName: appt.patientName || 'Unknown patient'
            }));
            this.loaded = true;
        } else if (error) {
            this.rows = [];
            this.errorMessage = this.reduceError(error);
            this.loaded = true;
        }
    }

    // Lets a parent reload the schedule after a booking
    @api
    refresh() {
        return this.wiredResult ? refreshApex(this.wiredResult) : Promise.resolve();
    }

    get hasRows() {
        return this.rows.length > 0;
    }
        get effectiveDoctorId() {
        return this.doctorId || this.recordId;
    }
    get showEmpty() {
        return !this.isLoading && !this.errorMessage && this.rows.length === 0 && !!this.doctorId;
    }

    get dateLabel() {
        const date = this.selectedDate ? new Date(this.selectedDate + 'T00:00:00') : new Date();
        return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
    }

    formatTime(slot) {
        if (!slot) {
            return '';
        }
        return new Date(slot).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }

    // Row click: tell the parent which appointment was selected
    handleRowClick(event) {
        const appointmentId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('appointmentselected', {
                detail: { appointmentId },
                bubbles: true,
                composed: true
            })
        );
    }
}