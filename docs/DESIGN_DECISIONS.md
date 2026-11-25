# Design decisions and known gaps

This document records the choices made while building the MedCare Hospital Management System, the reasons for them, and the gaps that remain. It is meant to be read alongside the [README](../README.md) and the [testing record](TESTING.md).

## Design decisions

### Billing and approvals

- **Amounts in rupees.** The hospital is set in India, so the org uses INR as its currency and English (India) as the locale, and sample bills use rupee amounts.
- **One approval process, two thresholds.** Every bill above ₹100,000 needs the Department Head. Only bills above ₹500,000 also need the Hospital Admin. Smaller bills skip the second step instead of waiting for someone who has no reason to review them.
- **Rejection is final.** A rejected bill is unlocked, set to Rejected and a "Revise rejected bill" task is created, so the fix goes through a new submission rather than a recall. Recall is switched off.
- **Locked while pending.** Submitting locks the bill. Record editability is administrators only, so a mistake can still be corrected by an administrator.
- **Bills are created from completed appointments.** When an appointment becomes Completed, a Draft bill is created automatically. The charge depends on the appointment type: ₹500 for a general consultation, ₹1,500 for a specialist consultation, ₹3,000 for an emergency, and ₹500 if the type is blank. The patient's Total Billed Amount is updated in the same flow.

### Doctor workload

- **Increase in a flow, decrease in Apex.** The Doctor Workload flow adds 1 when an appointment is created, and the appointment trigger subtracts 1 when an appointment is cancelled or deleted. The two never touch the same event, so the count cannot be doubled.
- **Conflict checks live in Apex.** Double-booking a doctor's slot is blocked by the trigger handler, which handles a bulk load of records correctly. A flow would be harder to keep bulk-safe.
- **Past dates are rejected.** The same handler refuses appointments dated in the past.
- **Every new appointment creates a follow-up task.** The trigger creates a "Confirm appointment with patient by phone" task due the next day, assigned to an active user in the Receptionist role (or to the current user if there is none). This keeps confirmation as a human step.

### Automation and email

- **Emails send from one verified org-wide address.** This gives patients a consistent sender and avoids using an individual user's address.
- **Scheduled flows pick records by status and date.** The daily reminder selects Confirmed appointments whose date is tomorrow, using a checkbox formula on the appointment, so the schedule needs no date logic of its own.
- **Record-triggered flows fire only on a change.** Flows such as Billing Auto Create and Billing Approved Notification run only when a record newly meets the entry condition. This avoids duplicate emails and duplicate bills from ordinary edits.

### User interface

- **One home page for daily work.** The Hospital Home page combines the dashboard, doctor schedule, patient search and appointment booking, so a receptionist can find a patient and book a slot without leaving the page.
- **The date drives the whole page.** The dashboard date filters the counts, the department summary and the doctor schedule together.

### Repository and deployment

- **Public repository with placeholders.** Real usernames and email addresses are replaced with `example.com` placeholders before anything is committed, and the history was checked for leaks. The result is that the approval process file and the flows in the repository document the org but cannot be deployed unchanged.
- **CLI, Git and GitHub Actions instead of Change Sets.** A standalone Developer Edition org has no connected target environment, so Change Sets cannot be demonstrated. The same goals (versioned changes, validation before release) are met with source control and a deployment dry run in CI.

## Known gaps

| Gap | Effect | Possible fix |
| --- | --- | --- |
| No duplicate-bill protection | An appointment that goes Completed, then back, then Completed again creates a second bill | Check for an existing bill on the appointment before creating one |
| Workload counter ignores reinstated or reassigned appointments | The counter goes down when an appointment is cancelled or deleted, but does not go back up if a cancelled appointment is reopened, and it does not move if the doctor on an appointment is changed | Handle status and doctor changes in the trigger handler |
| Reminder Sent is never updated | The field stays unticked after a reminder is sent | Add an Update Records step after the email |
| Email flows do not check for a missing patient email | A patient record without an email makes the flow raise an error instead of skipping the patient | Add a decision that checks the patient has an email |
| Approval emails are generic | The Billing Approved email has no patient name or amount | Use a template with merge fields |
| Weekly report covers the last 7 days only | Upcoming appointments are not listed | Change the date range or add a second section |
| Gmail shows a sender-authentication notice | Messages sent from an org-wide Gmail address show "via salesforce.com" | Use a domain address with SPF and DKIM set up |
| Approval process file has placeholder approvers | It cannot be deployed as is | Map approvers to real users in the target org |
| Developer Edition email limits | Heavy testing can hit the low daily limit for single emails | Spread tests out, or use a larger org |
| No cross-org deployment | Deployment is validated but not performed | Deploy to a second org when one is available |

## Approval authorization limitation

Both approval stages route correctly. However, one recorded test shows the Department Head approving the Hospital Admin stage. Independent approver authorization requires further verification.

## Specification notes

- The brief assumes a team of five. This project was built by one person, so the work was organised by section instead of by team member.
- The demonstration is not a clinical system. Real patient records, production security review and healthcare integrations are out of scope.
