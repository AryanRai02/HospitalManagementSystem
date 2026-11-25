# Hospital Management System  MedCare Hospital

A Salesforce-based Hospital Management System (HMS) built as a training and demonstration project. It brings patient registration, appointment scheduling, doctor workload, department management, billing, medical records and hospital reporting into a single Lightning application.

## Features

| Module | Functionality |
| --- | --- |
| Patient management | Patient registration, patient details and medical records |
| Appointment management | Scheduling, conflict detection, cancellation and appointment notifications |
| Doctor and department management | Doctor assignments, active appointment tracking and bed occupancy reporting |
| Billing | Bill creation, amount calculation and approval workflow |
| Procedure management | Procedures and patient-procedure associations |
| Automation | Record-triggered, screen and scheduled flows; Apex triggers and asynchronous jobs |
| Integrations | Apex REST services, HTTP callout examples and mock laboratory/insurance integrations |
| Analytics | Seven reports and a hospital administration dashboard |

## Technology stack

- Salesforce Lightning Experience and Salesforce Developer Edition
- Apex, SOQL, DML, Apex triggers and Apex test classes
- Batch, scheduled and other asynchronous Apex
- Lightning Web Components (LWC)
- Salesforce Flow, approval processes and workflow actions
- REST APIs, Named Credentials and External Credentials
- Salesforce CLI, VS Code, Git and GitHub
- Salesforce Metadata API v68.0 for source retrieval

## Data model

| Custom object API name | Purpose |
| --- | --- |
| `Patient__c` | Patient information |
| `Doctor__c` | Doctor information and workload |
| `Department__c` | Hospital departments and bed capacity |
| `Appointment__c` | Patient appointments and scheduling |
| `Billing__c` | Billing and payment-related information |
| `Medical_Record__c` | Patient medical records |
| `Procedure__c` | Hospital procedures |
| `Patient_Procedure__c` | Patient-procedure associations |

The project also uses custom fields, relationships, validation rules, record types, picklists, page layouts, Lightning record pages and quick actions.

## Security and access control

Custom profiles include Hospital Admin, Doctor and Receptionist. The role hierarchy is CEO → Hospital Admin → Department Head → Doctor → Receptionist. Permission sets, sharing rules, field-level security and object permissions support role-based access. The `Billing_Managers` public group supports the billing approval configuration.

This is a demonstration application, not a production-ready clinical system. Apex sharing, CRUD/FLS enforcement, email delivery, integrations and handling of patient information require further security review before real-world use.

## Automation and business logic

### Salesforce Flow

| Flow | Type | Behaviour |
| --- | --- | --- |
| New Patient Registration | Screen flow | Registers a patient and sends a welcome email |
| Appointment Confirmation | Record-triggered (Appointment) | Emails the patient when an appointment becomes Confirmed |
| Doctor Workload | Record-triggered (Appointment) | Adds 1 to the doctor's Active Appointments when an appointment is created |
| Billing Auto Create | Record-triggered (Appointment) | Creates a Draft bill and updates the patient's total when an appointment becomes Completed |
| Billing Approved Notification | Record-triggered (Billing) | Emails the patient when a bill becomes Approved |
| Send Patient Summary Email | Screen flow (record action) | Emails a summary from the Patient record page |
| Daily Morning Reminder | Scheduled, daily | Reminds patients with a Confirmed appointment tomorrow |
| Weekly Report | Scheduled, weekly | Emails the administrator a summary of the last 7 days of appointments |

### Apex development

Representative classes include `AppointmentTriggerHandler`, `EmailService`, `BillingCalculator`, `HospitalController`, `PatientService`, `PatientRestService`, `AppointmentReminderBatch`, `AppointmentScheduler`, `MonthlyBillingReport`, `MonthlyBillingReportScheduler`, `InsuranceVerificationService`, `LabSystemService` and `LabResultProcessor`.

`AppointmentTrigger` and its handler implement appointment validation, doctor scheduling conflict checks, cancellation handling and workload updates. Apex test classes and `TestDataFactory` support automated testing.

### Billing approval

The Emergency Billing Approval process is active in the development org. A bill above ₹100,000 goes to the Department Head; a bill above ₹500,000 needs a second approval from the Hospital Admin. Submitting sets the status to Pending Approval and locks the record, final approval sets it to Approved, and any rejection is final: the status becomes Rejected, the record is unlocked and a "Revise rejected bill" task is created. Approving a bill fires the Billing Approved Notification flow, which emails the patient.

The approve, reject and two-step routing paths were tested. Independent approval by two separate users remains unverified (see [docs/TESTING.md](docs/TESTING.md)). The approval process file in this repository keeps placeholder approver usernames, so it records the org configuration but is not deployable unchanged; approvers must be mapped to real users in the target org.

### Integrations

The project includes patient REST service code and insurance and laboratory callout examples. `LabSystem_NC` and `LabSystem_EC` demonstrate Named Credential and External Credential configuration. The laboratory URL is a mock endpoint, and its exported external credential uses no authentication. These examples are not live healthcare integrations.

## Reports and dashboard

The Hospital Admin Dashboard brings together hospital operational and billing metrics. Reports include:

- Appointment Status Distribution
- Monthly Revenue by Department
- Pending Approvals
- Doctor Workload
- Bed Occupancy by Department
- Today's Appointment List
- Doctor Performance

The custom report type `Billing_Revenue_by_Department` supports departmental revenue reporting.

## Testing

| Metric | Observed result in the development org |
| --- | --- |
| Apex tests | 64 passed |
| Overall Apex code coverage | 92% |
| `AppointmentTrigger` coverage | 100% |
| `AppointmentTriggerHandler` coverage | 98% |

These are development-org results, not a guarantee of coverage or deployment success in another org. Functional testing of all eight flows, the four Lightning Web Components and the approval process is recorded in [docs/TESTING.md](docs/TESTING.md). Design decisions and known gaps are in [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md).

## Repository structure

```text
HospitalManagementSystem/
|-- force-app/main/default/
|-- config/
|-- scripts/
|-- docs/
|   |-- TESTING.md
|   `-- DESIGN_DECISIONS.md
|-- .github/workflows/
|-- .forceignore
|-- .gitignore
|-- sfdx-project.json
`-- README.md
```

The metadata directory contains Apex classes, triggers, objects, flows, Lightning components, security configuration, reports, dashboards, approval processes and integration configuration.

## Installation and deployment

### Prerequisites

- A Salesforce development org with the required features enabled
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
- [VS Code with Salesforce Extension Pack](https://developer.salesforce.com/tools/vscode/)
- Git; Dev Hub is optional unless using scratch orgs

### 1. Clone the repository

```bash
git clone https://github.com/AryanRai02/HospitalManagementSystem.git
cd HospitalManagementSystem
```

### 2. Authorize a target development org

```bash
sf org login web --alias HMSDev
```

### 3. Configure the target environment

Before attempting deployment:

- Replace placeholder usernames and email addresses (`example.com`) in the Apex and metadata with appropriate target-org values. Do not commit private values to the public repository.
- Configure and verify the org-wide email address, email deliverability and default workflow user.
- Configure dashboard ownership, running user and report/dashboard folder access.
- Configure approval users, role/group membership, workflow task assignment and integration endpoints or credentials as required.
- Review scheduled flows, dates, frequency and activation status. The Weekly Report and Daily Morning Reminder flows are scheduled (weekly and daily); confirm their start dates and activation status in the target org.
- Review target-org feature availability and metadata dependencies; adjust the deployment scope if needed.

Use a private local copy or environment-specific configuration for these changes. Do not deploy the sanitized public source unchanged to a working org.

### 4. Validate before deploying

```bash
sf project deploy start --dry-run --source-dir force-app --target-org HMSDev --test-level RunLocalTests --wait 30
```

Resolve any dependency, configuration or test errors before proceeding.

### 5. Deploy and run Apex tests

```bash
sf project deploy start --source-dir force-app --target-org HMSDev --test-level RunLocalTests --wait 30
sf apex run test --target-org HMSDev --test-level RunLocalTests --code-coverage --result-format human --wait 30
```

The commands are intended for a configured development org. A clean-org deployment has not yet been verified.

## Privacy and deployment status

The public source uses placeholder email addresses and usernames. Local Salesforce authentication caches, private keys and environment files are excluded from Git. Only fictional test data should be used; never commit real patient records, credentials or org-specific secrets.

Change Sets are not available in a standalone Developer Edition org, which has no connected target environment to deploy to. The deployment workflow therefore uses the Salesforce CLI, Git and GitHub Actions instead.

Three GitHub Actions workflows are in place and passing:

| Workflow | Purpose |
| --- | --- |
| Salesforce CI | Validates the project structure on every push and pull request |
| Salesforce Apex Tests | Runs the Apex tests against the development org (manual run) |
| Salesforce Deployment Validation | Dry-run deployment validation (manual run) |

The dry runs validated 31 of 31 Apex components and 154 of 154 components in the full metadata set, with 64 tests passing. A dry run is a validation, not a deployment: an actual deployment to a second org has not been performed.

## References

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Salesforce VS Code Extensions](https://developer.salesforce.com/tools/vscode/)
