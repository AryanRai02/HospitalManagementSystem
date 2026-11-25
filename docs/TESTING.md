# Testing record

Functional testing of the MedCare Hospital Management System in the development org, 24 to 25 November 2026. All data used was fictional test data. Emails were sent to test inboxes only.

Each test notes what was done and what was observed, including defects found along the way.

## 1. Flows

| Flow | How it was tested | Result |
| --- | --- | --- |
| New Patient Registration | Ran the screen flow and registered a patient | **Passed.** Welcome email received |
| Appointment Confirmation | Changed an appointment from Requested to Confirmed | **Passed.** Confirmation email received on 24 Nov, and again on 25 Nov after a patient's Email field was corrected |
| Send Patient Summary Email | Launched from the action on a Patient record page | **Passed.** Running it from Flow Builder with no record gives "0 recipients", which is expected because there is no record context |
| Doctor Workload | Created a new appointment for a doctor | **Passed.** The doctor's Active Appointments increased by 1. The flow fires on create only |
| Billing Auto Create | Changed an appointment to Completed | **Passed.** A Draft bill was created and the patient's Total Billed Amount rose by ₹500 (10,000 to 10,500) |
| Billing Approved Notification | Changed a bill from Draft to Approved | **Passed.** Patient email received, and again after approval-process approvals |
| Daily Morning Reminder | Debug run on a Confirmed appointment dated the next day | **Passed.** Flow log shows the patient found and the email sent; reminder email received |
| Weekly Report | Debug run | **Passed.** Email delivered with a total of 10 appointments for the last 7 days. Version 20 adds a line break after each appointment line |

Notes from testing flows:

- Record-triggered flows here run only when a record **newly** meets the entry conditions. Re-saving a record that already meets them does nothing, so a test needs a real status change or a newly created record.
- Appointment Confirmation sent an error email once ("Probably Limit Exceeded or 0 recipients") for a patient record. After that patient's Email field was corrected, the confirmation email was delivered, so the cause was the patient's email address and not the flow itself.

Automatic scheduled execution of Daily Morning Reminder and Weekly Report has not been independently verified. Their successful debug runs and email delivery are recorded above.

## 2. Emergency Billing Approval

Test users: Test DeptHead (Step 1) and Test HospitalAdmin (Step 2).

| Scenario | Result |
| --- | --- |
| Reject a ₹150,000 bill as Department Head | **Passed.** Status Rejected, "Revise rejected bill" task created |
| Approve a ₹150,000 bill (one step) | **Passed.** Status Approved after the Department Head approval; Step 2 correctly skipped |
| Approve a ₹600,000 bill (two steps) | **Routing passed.** Both approval stages executed, but the Department Head was recorded as the actual approver for both stages. Separate approver authorization remains unverified |
| Record lock after approval | **Passed.** Checked as a non-administrator, the approved bill could not be edited |
| Approval request email | **Passed.** Delivered to the approver |
| Patient notification on approval | **Passed.** Billing Approved Notification email received |

System administrators can still edit locked records, because the process allows administrator edits. The lock was therefore checked as a non-administrator.

## 3. Lightning Web Components

| Component | How it was tested | Result |
| --- | --- | --- |
| hospitalDashboard | Changed the date to 26 Nov 2026 | **Passed.** 2 appointments (1 Requested, 1 Confirmed), department summary, revenue and pending approvals shown |
| patientSearchBar | Searched for a patient ID | **Passed.** Result found; "Open Selected Patient" opened the record |
| doctorScheduleCard | Selected a doctor and changed the date | **Passed after fixes** (see below) |
| appointmentForm | Booked an appointment from the Home page | **Passed.** The appointment was created as Requested and appeared in the doctor's schedule |

Defects found in doctorScheduleCard and fixed (commit `dce232b`):

1. `refreshApex` was used but not imported, which showed a "refreshApex is not defined" error on refresh.
2. The `effectiveDate` getter was missing, so the selected date never reached Apex and the schedule always showed today.
3. The "No appointments" message appeared before the data finished loading.

After the fix, the schedule showed two appointments on 26 Nov and none on 25 Nov, and refresh worked without an error.

## 4. Apex tests and CI

| Check | Result |
| --- | --- |
| Apex tests | 64 passed |
| Overall code coverage | 92% |
| `AppointmentTrigger` | 100% |
| `AppointmentTriggerHandler` | 98% |
| Salesforce CI, Apex Tests and Deployment Validation workflows | All passing |
| Deployment dry runs | 31 of 31 Apex components; 154 of 154 full metadata components |

A dry run is validation only. No deployment to a second org was performed.

## 5. Scope and limitations

- Functional security testing with the Doctor and Receptionist test users beyond the sharing-rule checks done during configuration. Their user records are inactive in the development org.
- A real cross-org deployment.
- Behaviour with real patient data. This is a demonstration project.
