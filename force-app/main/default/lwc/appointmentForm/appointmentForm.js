import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue, createRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    subscribe,
    unsubscribe,
    publish,
    APPLICATION_SCOPE,
    MessageContext
} from 'lightning/messageService';

import PATIENT_SELECTED from '@salesforce/messageChannel/PatientSelected__c';
import APPOINTMENT_REFRESH from '@salesforce/messageChannel/AppointmentRefresh__c';
import getAvailableDoctors from '@salesforce/apex/HospitalController.getAvailableDoctors';

import APPOINTMENT_OBJECT from '@salesforce/schema/Appointment__c';
import DOCTOR_NAME from '@salesforce/schema/Doctor__c.Name';
import DOCTOR_SPECIALIZATION from '@salesforce/schema/Doctor__c.Specialization__c';
import DOCTOR_WORKLOAD from '@salesforce/schema/Doctor__c.Active_Appointments__c';
import SPECIALIST_FIELD from '@salesforce/schema/Appointment__c.Specialist_Required__c';

const SPECIALIST_TYPE = 'Specialist Consultation';

export default class AppointmentForm extends NavigationMixin(LightningElement) {
    patientId;
    patientName;
    doctorId;
    recordTypeId;
    slot;
    appointmentName;
    specialistRequired;
    errorMessage;
    isSaving = false;
    @api stayOnPage = false;
    doctorOptions = [];
    subscription = null;

    @wire(MessageContext)
    messageContext;

    // Subscribe to the message published by patientSearchBar
    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            PATIENT_SELECTED,
            (message) => this.handlePatientSelected(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handlePatientSelected(message) {
        this.patientId = message.patientId;
        this.patientName = message.patientName;
    }

    // Wire: doctors who can take bookings
    @wire(getAvailableDoctors)
    wiredDoctors({ data, error }) {
        if (data) {
            this.doctorOptions = data.map((d) => ({
                label: d.Specialization__c ? `${d.Name} (${d.Specialization__c})` : d.Name,
                value: d.Id
            }));
        } else if (error) {
            this.errorMessage = error?.body?.message || 'Could not load doctors.';
        }
    }

    // LDS: the selected doctor's record (no Apex needed)
    @wire(getRecord, {
        recordId: '$doctorId',
        fields: [DOCTOR_NAME, DOCTOR_SPECIALIZATION, DOCTOR_WORKLOAD]
    })
    doctorRecord;

    get doctorName() {
        return getFieldValue(this.doctorRecord?.data, DOCTOR_NAME);
    }

    get doctorSpecialization() {
        return getFieldValue(this.doctorRecord?.data, DOCTOR_SPECIALIZATION) || 'n/a';
    }

    get doctorWorkload() {
        return getFieldValue(this.doctorRecord?.data, DOCTOR_WORKLOAD) ?? 0;
    }

    // Appointment record types, read from the object's metadata
    @wire(getObjectInfo, { objectApiName: APPOINTMENT_OBJECT })
    objectInfo;

    get recordTypeOptions() {
        const infos = this.objectInfo?.data?.recordTypeInfos;
        if (!infos) {
            return [];
        }
        return Object.keys(infos)
            .filter((id) => !infos[id].master)
            .map((id) => ({ label: infos[id].name, value: id }));
    }

    get selectedTypeName() {
        const infos = this.objectInfo?.data?.recordTypeInfos;
        return infos && this.recordTypeId ? infos[this.recordTypeId]?.name : undefined;
    }

    // Conditional rendering: specialist fields only for the Specialist type
    get isSpecialist() {
        return this.selectedTypeName === SPECIALIST_TYPE;
    }

    // Specialist_Required__c values, which depend on the record type
    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: SPECIALIST_FIELD
    })
    specialistPicklist;

    get specialistOptions() {
        return this.specialistPicklist?.data?.values || [];
    }

    handleDoctorChange(event) {
        this.doctorId = event.detail.value;
    }

    handleTypeChange(event) {
        this.recordTypeId = event.detail.value;
        this.specialistRequired = undefined;
    }

    handleSlotChange(event) {
        this.slot = event.detail.value;
    }

    handleSpecialistChange(event) {
        this.specialistRequired = event.detail.value;
    }

    handleNameChange(event) {
        this.appointmentName = event.detail.value;
    }

    validate() {
        if (!this.patientId) {
            return 'Please pick a patient in the search bar first.';
        }
        if (!this.doctorId || !this.recordTypeId || !this.slot || !this.appointmentName) {
            return 'Please fill in the doctor, type, slot and name.';
        }
        return null;
    }

    async handleSave() {
        this.errorMessage = undefined;
        const problem = this.validate();
        if (problem) {
            this.errorMessage = problem;
            return;
        }

        const fields = {
            Name: this.appointmentName,
            Patient__c: this.patientId,
            Doctor__c: this.doctorId,
            Slot__c: this.slot,
            Status__c: 'Requested'
        };
        if (this.isSpecialist && this.specialistRequired) {
            fields.Specialist_Required__c = this.specialistRequired;
        }

        this.isSaving = true;
        try {
            const record = await createRecord({
                apiName: APPOINTMENT_OBJECT.objectApiName,
                fields,
                recordTypeId: this.recordTypeId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Appointment booked',
                    message: `${this.appointmentName} was created.`,
                    variant: 'success'
                })
            );

            // Child to parent: tell the dashboard (or any parent) a booking happened
            this.dispatchEvent(
                new CustomEvent('appointmentbooked', { detail: { appointmentId: record.id } })
            );

            // Lightning Message Service: tell other components to refresh
            publish(this.messageContext, APPOINTMENT_REFRESH, { appointmentId: record.id });

            // Navigation: open the new Appointment record
                       if (this.stayOnPage) {
                this.handleClear();
            } else {
                // Navigation: open the new Appointment record
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: record.id,
                        objectApiName: APPOINTMENT_OBJECT.objectApiName,
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleClear() {
        this.patientId = undefined;
        this.patientName = undefined;
        this.doctorId = undefined;
        this.recordTypeId = undefined;
        this.slot = undefined;
        this.appointmentName = undefined;
        this.specialistRequired = undefined;
        this.errorMessage = undefined;
    }

    reduceError(error) {
        const body = error?.body;
        if (body?.output?.errors?.length) {
            return body.output.errors.map((e) => e.message).join(' ');
        }
        if (body?.output?.fieldErrors) {
            const messages = Object.values(body.output.fieldErrors)
                .flat()
                .map((e) => e.message);
            if (messages.length) {
                return messages.join(' ');
            }
        }
        if (Array.isArray(body)) {
            return body.map((e) => e.message).join(' ');
        }
        return body?.message || error?.message || 'Could not book the appointment.';
    }
}