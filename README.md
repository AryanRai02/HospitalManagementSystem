# Hospital Management System — MedCare Hospital

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

- Appointment Confirmation
- Billing Auto Create
- Billing Approved Notification
- Doctor Workload
- New Patient Registration
- Send Patient Summary Email
- Daily Morning Reminder
- Weekly Report

### Apex development

Representative classes include `AppointmentTriggerHandler`, `EmailService`, `BillingCalculator`, `HospitalController`, `PatientService`, `PatientRestService`, `AppointmentReminderBatch`, `AppointmentScheduler`, `MonthlyBillingReport`, `MonthlyBillingReportScheduler`, `InsuranceVerificationService`, `LabSystemService` and `LabResultProcessor`.

`AppointmentTrigger` and its handler implement appointment validation, doctor scheduling conflict checks, cancellation handling and workload updates. Apex test classes and `TestDataFactory` support automated testing.

### Billing approval

The Emergency Billing Approval process is configured for Department Head approval above ₹100,000 and additional Hospital Admin approval above ₹500,000. Workflow actions update the billing status to Pending Approval, Approved or Rejected and create a follow-up task on rejection. The exported approval process is inactive and requires target-org configuration and testing before activation.

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
| Overall Apex code coverage | 92% |
| `AppointmentTrigger` coverage | 100% |
| `AppointmentTriggerHandler` coverage | 98% |

These are development-org results recorded before repository sanitization, not a guarantee of coverage or deployment success in another org.

## Repository structure

```text
HospitalManagementSystem/
├── force-app/main/default/   # Salesforce metadata
├── config/                   # Scratch org configuration
├── scripts/                  # Apex and SOQL example scripts
├── .forceignore              # Salesforce CLI exclusions
├── .gitignore                # Git exclusions
├── sfdx-project.json         # Salesforce DX project configuration
└── README.md
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
- Review scheduled flows, dates, frequency and activation status. The exported Weekly Report flow uses a one-time schedule and must be reconfigured for recurring execution if desired.
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

Change Sets were not available in the standalone Developer Edition org, so Salesforce CLI and source control are used for the deployment workflow. GitHub Actions CI/CD and target-org deployment verification are planned next steps, not completed features.

## References

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Salesforce VS Code Extensions](https://developer.salesforce.com/tools/vscode/)
