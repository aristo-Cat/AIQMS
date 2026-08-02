---
title: "URS — User Requirements Specification for AI-QMS — AI-first electronic Quality Management System"
type: instance
based_on_template: "URS"
based_on_template_version: "0.1.0"
project_id: "AIQMS-2026-001"
system_id: "AIQMS-2026-001"
status: draft
version: "0.1"
created: "2026-08-02"
updated: "2026-08-02"
language: "en"

# Copied from .gxp-dev.yaml for self-contained reference
gamp_category: 5
profile: "pharma"
mode: "develop"
presets:
  part11_active: true
  annex11_active: true
  gdpr_active: true
  annex22_active: true
---

# URS — User Requirements Specification

## 0. Identification

| Field | Value |
|---|---|
| System Name | AI-QMS — AI-first electronic Quality Management System |
| Project ID | `AIQMS-2026-001` |
| System ID | `AIQMS-2026-001` |
| Supplier | In-house |
| Version | `0.1.0-dev` |
| GAMP Category | 5 (custom application) |
| Intended Use | A bespoke electronic Quality Management System for a regulated GxP manufacturing organisation, managing the full lifecycle of its quality processes as primary electronic records: tamper-evident, audit-trailed, and electronically signed at defined approval steps. AI assistants are advisory only. A qualified human reviews, decides and signs every record, so no AI output enters an approved GxP record without documented human review. |

### Signature block

> [!warning] Fictional reviewers and approvers
> This system is a public demonstration artifact with no operating organisation behind it. The
> Author is real. The four reviewer and approver entries below are **fictional placeholders**,
> written with non-name identifiers so they cannot be mistaken for real people or for a genuine
> approval. This URS is `status: draft` and **is not approved**. Replace these entries with named
> individuals before promoting the status.

| Role | Name | Department | Date |
|---|---|---|---|
| Author | Juan Miguel Saavedra | Quality Assurance / Computerised System Validation | 2026-08-02 |
| Reviewer 1 (Process Owner, GAMP 5 §6.2.3) | `FICTIONAL-REVIEWER-1` | Quality Operations | — |
| Reviewer 2 (Subject Matter Expert) | `FICTIONAL-REVIEWER-2` | Manufacturing / Engineering | — |
| Approver 1 (System Owner) | `FICTIONAL-APPROVER-1` | Information Technology | — |
| Approver 2 (Quality Unit) | `FICTIONAL-APPROVER-2` | Quality Assurance | — |

---

## 1. Project context

### 1.1 Objective and purpose

AI-QMS is a custom-built electronic Quality Management System in which the quality record is the
primary electronic record. It manages seven record types across the quality processes of a
regulated manufacturing organisation, enforces segregation of duties and electronic signature at
every approval step, and never deletes a record.

It embeds an advisory AI Assistant. The assistant proposes; it never decides, approves, signs or
closes. Every element it produces is visibly marked and requires documented human review before
it can enter a signed record. The purpose of the system is to demonstrate that an AI-assisted
quality system can be specified, built and validated to a regulated standard without the
assistant ever holding authority over a GxP record.

### 1.2 System description

Every quality record shares a **Record Spine**: identifier, type, title, description, originator,
area, owner, dates, current state, electronic signatures, audit trail, attachments, record links
and cancellation. A record type declares which **Optional Blocks** it uses — Investigation,
Impact Assessment, Effectiveness Check — as either *required* or *conditional*; a conditional
block is enabled or waived per record by a signed, justified **QA Determination**. Each record
type declares one **State Model** satisfying a minimum **State Contract**: one initial `Draft`
state whose exit is signed by whoever opens the record, at least one approval transition requiring
an electronic signature, a terminal closed state, and cancellation reachable from any non-terminal
state.

The seven record types are Quality Event, Deviation, CAPA, Change Control, Audit Received, Audit
Performed and Finding. A CAPA has no standalone entry point: it exists only by deriving from a
Deviation, a Quality Event or a Finding through a mandatory **Origin Link**. Committed work
carries a **Closure Dependency** declaring whether it must complete before its source record
closes (*pre-closure*) or may continue after it (*post-closure*); it is carried by a CAPA's Origin
Link and by an Action of a Change Control.

The system is single-tenant and supports two deployment variants, hosted or on-premise. One
environment is qualified: the hosted single-tenant one. The on-premise variant is a documented
deployment variant entering through change control when first used.

Domain vocabulary is maintained in `CONTEXT.md` at the repository root, which is the authoritative
glossary for the terms capitalised above.

### 1.3 End users

Quality Assurance, Quality Control, Production, Engineering, and system administrators.

Inspectors and customer auditors **hold no account**. They review accompanied by Quality
Assurance, on a Quality Assurance session. This is a system-specific determination, not a role.

Five application roles ship as configurable defaults: Reporter (creates, does not approve),
Investigator (investigates, cannot approve own record), Process Owner (approves in own area),
Quality Assurance (quality review, final approval, closure, effectiveness — the only role that
closes) and Administrator (users, configuration, templates; cannot approve or sign quality
records).

### 1.4 Related systems

No system is integrated in this release. Document management, training records, LIMS and ERP are
documented as **anticipated** interfaces only and are out of scope.

One interface does exist and is in scope: the outbound interface to the **external AI provider**,
which transfers quality record content across an untrusted perimeter on every assistance request.
It is covered by `URS-API-001` through `URS-API-004`.

### 1.5 Out of scope

- The four anticipated integrations above.
- Autonomous AI decisions and AI-applied electronic signatures.
- Multi-tenant operation.
- SOP lifecycle management and training-record management as products in their own right.
- Data migration. The system is new and starts empty.

---

## 2. Definitions and abbreviations

| Term | Definition |
|---|---|
| Quality Record | The primary electronic record of this system: an identified, audit-trailed, signable unit of quality work of one Record Type. |
| Record Spine | The fields and behaviours every Quality Record has regardless of its Record Type. |
| Record Type | The classification determining which Optional Blocks a record uses and which State Model governs it. |
| Action | A unit of committed work held by a Quality Record: owner, due date, status, completion evidence. |
| Optional Block | A named cluster of fields and steps a Record Type declares as *required* or *conditional*. |
| QA Determination | The signed, justified decision by which Quality Assurance enables or waives a conditional Optional Block on one record. |
| State Contract | The minimum every State Model satisfies. |
| Opening Signature | The electronic signature applied by whoever opens a record, at the transition out of `Draft`. |
| Cancellation | The only way a record leaves the active population. Records are never deleted. |
| Origin Link | The mandatory link from a CAPA back to the record it derives from. |
| Closure Dependency | Whether committed work is *pre-closure* or *post-closure* for its source record. |
| Segregation Invariant | Nobody approves a record they created or investigated. |
| AI Assistant | The advisory capability of the system. It proposes and never decides, approves or signs. |
| ALCOA+ | Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available. |
| GxP | Good practice regulations (GMP, GDP, GLP, GCP). |
| RPO / RTO | Recovery Point Objective / Recovery Time Objective. |

---

## 3. Category code catalog

This URS uses the 22 canonical category codes (FUNC, PERF, QUAL, …, EREC, ESIG). See
`gxp-driven-dev/docs/requirement-id-scheme.md` for definitions.

---

## 4. Requirements by category

### 4.1 `URS-FUNC` — Functional requirements

#### Record Spine (all seven Record Types)

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-001` | Y | H | The system shall allow an authorised user to create a Quality Record of any Record Type in scope (Quality Event, Deviation, CAPA, Change Control, Audit Received, Audit Performed, Finding) and shall reject the creation until every mandatory minimum field declared by that Record Type is complete. Entry-point restrictions declared by a Record Type — the mandatory Origin Link of a CAPA, the mandatory parent Audit of a Finding — apply at creation. |
| `URS-FUNC-002` | Y | H | The system shall assign every Quality Record, at creation, an identifier that is unique across the system, never reused, and not modifiable by any user or role for the life of the record. |
| `URS-FUNC-003` | Y | H | The system shall record for every Quality Record its originator, its responsible owner, its organisational area and its due date. The due date is proposed by the user who opens the record and approved by Quality Assurance, except on a CAPA and a Change Control, where the due dates travel inside the plan or the change approved by the Process Owner. Where a regulatory or externally imposed deadline applies, that deadline governs and is recorded as such. Owner and due date may be changed by an authorised Role; every change is captured in the audit trail with user, date and time and reason. |
| `URS-FUNC-004` | Y | H | The system shall flag as overdue every Quality Record and every Action whose due date has passed without closure, and shall notify both its owner and Quality Assurance on the day the due date passes. Overdue records and Actions shall also appear in the reports required by `URS-FUNC-014`. |
| `URS-FUNC-005` | Y | H | The system shall allow an authorised user to attach files as supporting evidence to a Quality Record and to any of its Actions, recording for each attachment the uploading user and the date and time. An attachment is never deleted; replacing one retains both the superseded and the current file. |
| `URS-FUNC-006` | Y | H | The system shall allow an authorised user to create a directed link of a declared link type between two Quality Records, and shall display for any record both its outgoing and its incoming links. |
| `URS-FUNC-007` | Y | H | The system shall allow a user to search and filter the population of Quality Records by Record Type, State, area, owner, date range, Severity and free text over title and description, and to open any record returned, so that precedent can be retrieved before an Investigation is concluded. |
| `URS-FUNC-008` | Y | H | Cancellation shall be the only means by which a Quality Record leaves the active population: available from any non-terminal State, restricted by Role, requiring a reason, and recorded in the audit trail with user, date and time and reason. The system shall expose no function, to any role including the Administrator, that deletes a Quality Record. |
| `URS-FUNC-009` | Y | H | The audit trail required by `URS-EREC-005` shall cover, for every Quality Record: its creation, every change to any field of the Record Spine or of a declared Optional Block, every State transition, every electronic signature, every Action created, reassigned or closed, every Record Link created or removed, and its Cancellation. This enumeration is the system-specific scope that `URS-EREC-005` requires to be specified. |
| `URS-FUNC-010` | Y | H | The system shall permit a State transition only to a Role that the State Model of that Record Type authorises for that transition, and shall reject any transition not declared in that State Model. |
| `URS-FUNC-011` | Y | H | The system shall require an electronic signature at each of the following, in addition to the signed determinations required by `URS-FUNC-015`: **(a)** the opening of any Quality Record, being the transition out of `Draft`, applied by the user who opens it; **(b)** each approval transition declared by the Record Type's State Model, at minimum: closure of a Quality Event with no action; Triage and closure of a Deviation; approval of a concluded Deviation Investigation; plan approval and closure of a CAPA; approval or ratification and closure of a Change Control; formal response and closure of an Audit Received; report issue and closure of an Audit Performed; response acceptance and closure of a Finding. A transition requiring a signature shall not complete unless the signature is applied, under the conditions of section 4.3. |
| `URS-FUNC-012` | Y | H | The system shall reject any approval transition attempted by the user who created the Quality Record or who authored its Investigation. This Segregation Invariant is enforced in code on every approval transition and is not configurable by any Role, including the Administrator. |
| `URS-FUNC-013` | Y | H | The system shall allow an authorised user to create Actions on any Quality Record, each with an owner, a description of the work committed and a due date proposed by its creator and subject to modification and approval by Quality Assurance; to reassign an Action's owner and due date; and to close an Action only with recorded completion evidence. An Action shall never be deleted. |
| `URS-FUNC-014` | Y | M | The system shall produce reports over the population of Quality Records covering at minimum: open and overdue records and Actions by owner, area, Record Type and Severity; cycle time from creation to closure by Record Type; and recurrence of documented root causes across records. |

#### Optional Blocks

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-015` | Y | H | Each Record Type shall declare each Optional Block as either required or conditional. A required block is always used in full. A conditional block is enabled or waived per Quality Record by a determination of Quality Assurance, made at the step the Record Type declares for it, recording a justification and requiring an electronic signature. A waived block shall not be re-enabled without a new signed determination. No block is ever partially used. |
| `URS-FUNC-016` | Y | H | Where the Investigation Optional Block is in use for a Quality Record, the system shall record the investigation method, the documented root cause, the supporting evidence, the investigating user and the date of conclusion, and shall prevent any transition out of the investigation State until a root cause and its supporting evidence are recorded. |
| `URS-FUNC-017` | Y | H | Where the Impact Assessment Optional Block is in use for a Quality Record, the system shall record the assessed consequence on product, batch, patient, data and validated state, the resulting disposition, the assessing user and the date, and shall prevent closure of the Quality Record until a disposition is recorded. |
| `URS-FUNC-018` | Y | H | Where the Effectiveness Check Optional Block is in use for a Quality Record, the system shall require the acceptance criterion, the verification horizon and the responsible party to be recorded at the point the block is enabled and before any verification evidence is gathered, and shall record the evidence and a pass or fail outcome at the end of the horizon. A fail outcome shall neither close the Quality Record on its own nor undo the work performed: Quality Assurance shall either extend the verification horizon, leaving the record open, or close the record on a recorded justification. The same block serves a CAPA's Effectiveness Check, whose criterion is set at the QA Determination over the executed record, and a Change Control's post-implementation verification, whose criterion is set at approval. |

#### Quality Event

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-019` | Y | H | The system shall allow an authorised user to register a Quality Event capturing what was observed, when and where it occurred, who observed it and the area affected, without requiring its nature or classification to be known at registration. |
| `URS-FUNC-020` | Y | H | The system shall require a Quality Event to be assessed by an authorised Role before it leaves the Assessed State, recording the assessment and the assessing user, and shall offer exactly two outcomes: routing to another Quality Record, or closure with no further action. |
| `URS-FUNC-021` | Y | H | On routing a Quality Event, the system shall create or attach exactly one target Quality Record — a Deviation, a Change Control or a CAPA — establish a typed Record Link from the Quality Event to it, and transition the Quality Event to Routed. A Quality Event shall route to at most one Quality Record. Where the target is a CAPA, that link is its mandatory Origin Link. |
| `URS-FUNC-022` | Y | H | The system shall require an electronic signature by Quality Assurance and a recorded justification to close a Quality Event with no further action, and shall not permit that State to be reached without both. |

#### Deviation

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-023` | Y | H | The system shall allow an authorised user to register a Deviation capturing the approved instruction, specification or procedure departed from, what the departure was, when and how it was detected, the area, and the product or batch affected where applicable. |
| `URS-FUNC-024` | Y | H | The system shall require Triage of a Deviation by Quality Assurance, in which the Severity is set to critical, major or minor, the Containment Action is resolved, and the determination on the Investigation Optional Block is made. Triage requires an electronic signature and is subject to the Segregation Invariant: the user who opened the Deviation shall not perform its Triage. |
| `URS-FUNC-025` | Y | H | The system shall require, at Triage, either a recorded Containment Action with its owner and due date, or an explicit justification that containment is not applicable. Triage shall not complete with neither. |
| `URS-FUNC-026` | Y | H | Whether a Deviation uses the Investigation Optional Block shall be decided at Triage by the reviewing Quality Assurance user, as a QA Determination under `URS-FUNC-015`, recorded with its justification and covered by the Triage signature. Severity shall not determine that outcome. Where the determination requires an Investigation the Deviation transitions to Under investigation; where it waives one it transitions directly to In actions. |
| `URS-FUNC-027` | Y | H | The system shall require the concluded Investigation of a Deviation to be approved by the Process Owner with an electronic signature before any Action derived from it may be started, and shall reject that approval from the user who authored the Investigation. |
| `URS-FUNC-028` | Y | H | The system shall require the Impact Assessment Optional Block to be completed for every Deviation before it reaches Pending closure, recording the consequence on product, batch, patient, data and validated state, and the resulting disposition. |
| `URS-FUNC-029` | Y | H | The system shall require an electronic signature by Quality Assurance to close a Deviation. Closure shall be rejected while any Action held by the Deviation remains open, or while any CAPA whose Origin Link to it declares a pre-closure Closure Dependency remains open. A post-closure CAPA shall not prevent closure of its source record. |

#### CAPA

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-030` | Y | H | The system shall permit a CAPA to be created only by deriving it from a Deviation, a Quality Event or a Finding, and shall record that derivation as a mandatory Origin Link at creation. The system shall expose no function that creates a CAPA without an Origin Link. |
| `URS-FUNC-031` | Y | H | The system shall require every CAPA Origin Link, and every Action of a Change Control, to declare a Closure Dependency: pre-closure, meaning the source Quality Record cannot close until that work closes, or post-closure, meaning it may. The value is proposed with a recorded rationale by the user who opens the work and confirmed by Quality Assurance at the closure of the source record; Quality Assurance may change it, and the change is captured in the audit trail. |
| `URS-FUNC-032` | Y | H | The system shall require a CAPA to be classified as corrective or preventive, and to carry a plan of one or more Actions — each with an owner, a due date and a description of the work committed — before that plan may be submitted for approval. Actions carry no corrective/preventive classification; the distinction is recorded on the CAPA alone. |
| `URS-FUNC-033` | Y | H | The system shall require the CAPA plan to be approved by the Process Owner with an electronic signature before any Action in it may be started, and shall reject that approval from the user who opened the CAPA. |
| `URS-FUNC-034` | Y | H | Once the CAPA owner reports the plan executed, the system shall require a QA Determination under `URS-FUNC-015` on whether an Effectiveness Check is required, recording its justification and, where the check is required, its acceptance criterion, verification horizon and responsible party before any verification evidence is gathered. |
| `URS-FUNC-035` | Y | H | The system shall require an electronic signature by Quality Assurance to close a CAPA. Where an Effectiveness Check was required, the system shall reject closure until either the check has passed or Quality Assurance has recorded the justification permitted by `URS-FUNC-018`. |

#### Change Control

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-036` | Y | H | The system shall allow an authorised user to open a Change Control recording the change proposed, its justification, the scope, and the products, processes, equipment or systems affected, and shall require two independent attributes to be set: Urgency, normal or emergency, and Duration, permanent or temporary. All four combinations are valid and the system shall support each. |
| `URS-FUNC-037` | Y | H | The system shall require the Impact Assessment Optional Block to be completed on every Change Control, including the effect on validated state, before the change may be approved or, for an emergency change, before it may be ratified. |
| `URS-FUNC-038` | Y | H | For a Change Control of normal Urgency, the system shall require approval by the Process Owner with an electronic signature before any implementation Action may be started, and shall reject the transition to In implementation while that signature is absent. |
| `URS-FUNC-039` | Y | H | For a Change Control of emergency Urgency, the system shall allow implementation to be recorded before approval provided a justification is captured, and shall then require ratification by electronic signature within a configurable maximum period from the recorded implementation, defaulting to **10 working days**. The system shall flag and escalate any emergency change not ratified within that period. |
| `URS-FUNC-040` | Y | H | For a Change Control of temporary Duration, the system shall require an expiry date and a mandatory Action to either revert the change or convert it to permanent, due before that expiry, and shall flag the Change Control as overdue if the expiry passes with that Action still open. |
| `URS-FUNC-041` | Y | H | The system shall require the Effectiveness Check Optional Block on every Change Control as its post-implementation verification, with criterion, horizon and responsible party recorded at approval, or at ratification for an emergency change, and always before any verification evidence is gathered. |
| `URS-FUNC-042` | Y | H | The system shall require an electronic signature by Quality Assurance to close a Change Control, and shall reject closure while any Action declaring a pre-closure Closure Dependency remains open, or while its post-implementation verification has neither passed nor been justified under `URS-FUNC-018`. |

#### Audit Received

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-043` | Y | H | The system shall allow an authorised user to open an Audit Received recording the auditing party and whether it is a regulatory authority or a customer, the scope, the planned dates and the notification received, and shall support the record existing from notification onwards, before the audit takes place. |
| `URS-FUNC-044` | Y | H | The system shall allow the received audit report to be attached to the Audit Received in the form the auditing party issued it, and each observation in that report to be transcribed by an authorised user as a child Finding, linked to the audit by a Record Link and carrying its own owner, Severity and State. The attached original and the transcribed Findings coexist; neither replaces the other. |
| `URS-FUNC-045` | Y | H | The system shall require the formal response to an Audit Received to be signed by Quality Assurance, and shall record the response deadline, regulatory where one applies and otherwise as committed, and flag the record when that deadline passes without a signed response. |
| `URS-FUNC-046` | Y | H | The system shall require an electronic signature by Quality Assurance to close an Audit Received, and shall reject closure while any child Finding remains open. |

#### Audit Performed

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-047` | Y | H | The system shall allow an authorised user to open an Audit Performed recording the auditee, being a supplier, a site or this organisation itself, the annual audit programme it belongs to, the scope, the plan and the dates, and shall allow the audits of a programme to be listed and their execution against plan reported. |
| `URS-FUNC-048` | Y | H | The system shall require the issued audit report to be signed by the lead auditor, and shall allow each observation in it to be registered as a child Finding linked to the Audit Performed. |
| `URS-FUNC-049` | Y | H | For a Finding of an Audit Performed, the system shall record the auditee's committed response, its owner at the auditee and its due date, entered on the auditee's behalf by an authorised internal user, since external parties hold no account in this system, and shall track each commitment to closure. |
| `URS-FUNC-050` | Y | H | The system shall require an electronic signature by Quality Assurance to close an Audit Performed, and shall reject closure while any child Finding remains open. |

#### Finding

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-051` | Y | H | The system shall permit a Finding to be created only as a child of an Audit Received or an Audit Performed, recorded as a mandatory Record Link to that parent at creation, and shall keep the Finding open on its own schedule after its parent audit's report has been recorded as received or issued. |
| `URS-FUNC-052` | Y | H | The system shall require a Finding's Severity, being critical, major, minor or observation, to be set when it is opened, and shall then require a QA Determination under `URS-FUNC-015` on whether the Investigation Optional Block is used, made once the initial content and explanations are recorded and carrying its justification and signature. |
| `URS-FUNC-053` | Y | H | The acceptance of a Finding's response shall be signed by Quality Assurance by default, and Quality Assurance may assign a different signatory on an individual Finding, with the assignment recorded in the audit trail. Severity shall determine neither the signatory nor the response deadline, which follows `URS-FUNC-003`. The system shall flag a Finding whose response deadline passes without an accepted response. |
| `URS-FUNC-054` | Y | H | The system shall require the response to a Finding to be proposed by its owner and accepted by electronic signature of the Role that `URS-FUNC-053` assigns, and shall reject that acceptance from the user who proposed the response. Deriving a CAPA in answer to a Finding shall be available at any Severity and compelled at none. |
| `URS-FUNC-055` | Y | H | The system shall require an electronic signature by Quality Assurance to close a Finding, and shall reject closure while any Action it holds remains open or while any CAPA whose Origin Link to it declares a pre-closure Closure Dependency remains open. |

#### Configuration and access

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-056` | Y | H | The system shall allow the Administrator, and no other Role, to configure Roles and their permissions. The five Roles shipped — Reporter, Investigator, Process Owner, Quality Assurance, Administrator — are defaults and not a fixed model. A permission change takes effect without prior approval and shall record the changing user, the date and time and a mandatory reason in the audit trail. |
| `URS-FUNC-057` | Y | H | The system shall enforce four invariants in code, and shall expose no configuration by which any Role, including the Administrator, can disable them: no user approves a Quality Record they created or investigated; no Role deletes a Quality Record, which leaves the active population only by Cancellation; the Administrator never modifies the content of a Quality Record; and the AI Assistant executes no State transition, applies no electronic signature, and makes no approval, closure, cancellation, QA Determination or Closure Dependency. |
| `URS-FUNC-058` | Y | H | The system shall permit the Administrator to manage users, Role configuration and templates, and shall reject any attempt by that Role to create, edit, approve, sign, close or cancel a Quality Record. |

#### AI Assistant (advisory)

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-FUNC-059` | Y | M | The system shall allow a user working on a Quality Record that uses the Investigation Optional Block to request root-cause hypotheses from the AI Assistant, returned as candidate hypotheses each accompanied by the records or data it is drawn from, and never as a determined root cause. |
| `URS-FUNC-060` | Y | M | The system shall allow a user to request from the AI Assistant the Quality Records most similar to the one being worked on, each returned with the reason for the match, and drawn only from records the requesting user is authorised to read. |
| `URS-FUNC-061` | Y | M | The system shall allow a user to request from the AI Assistant a draft narrative for a Quality Record and a proposed CAPA plan, delivered as editable draft content the user may accept, edit or discard in whole or in part. |
| `URS-FUNC-062` | Y | M | The system shall allow a user to request from the AI Assistant a suggested classification, being the Record Type a Quality Event should route to or a Deviation's Severity, and a completeness check listing the mandatory fields and evidence still missing before submission. Suggestions are advisory and shall never be applied by the system automatically. |
| `URS-FUNC-063` | Y | H | The system shall mark every element of a Quality Record originated by the AI Assistant as AI-generated, visibly on screen and in any printout, and shall retain that marking with the element for the life of the record. Editing an AI-generated element shall record that it was edited and by whom, and shall not remove the marking. |
| `URS-FUNC-064` | Y | H | The system shall require documented human review of every AI-generated element before the Quality Record containing it may leave `Draft` or receive any electronic signature, recording the reviewing user, the date and time, and whether each element was accepted, edited or rejected. No AI-generated content shall enter a signed Quality Record without that record of review. |

---

### 4.2 `URS-EREC` — Electronic Records requirements (21 CFR Part 11)

> Canonical preset, copied verbatim. Legal text and `GxP`/`Prio` cells are not edited.
> System-specific applicability is recorded in the determinations note below the table.

| ID-No. | GxP | Prio. | Requirement |
|---|---|---|---|
| `URS-EREC-001` | Y | H | It must be possible to **identify invalid or altered records** (21 CFR Part 11 §11.10.a). |
| `URS-EREC-002` | Y | H | Complete printouts of the electronic data must be producible from the system (§10.b). |
| `URS-EREC-003` | Y | H | Electronic records must remain electronically accessible throughout their retention period (§10.c). |
| `URS-EREC-004` | Y | H | System access must be limited per user; a strict user-management concept must be defined and implemented (§10.d, §10.g). |
| `URS-EREC-005` | Y | H | A **secure, computer-generated, time-stamped audit trail** that records operator create/modify/delete actions without obscuring previous information. For each change it must capture: user (with role if applicable), **old value**, **new value**, date+time (with timezone if applicable), and **reason for change** prompted to the user. Audit trail data must be recorded **at the time of events**, not at the end of the process. Specify which GxP data it is implemented for (21 CFR Part 11 §11.10.e + EU Annex 11 §12.2 p.10). |
| `URS-EREC-006` | Y | H | It must be possible to perform functional checks of the system (§10.f). |
| `URS-EREC-007` | Y | H | When performing device checks (e.g. terminals), it must be possible to determine the validity of the source of the data input or instruction (§10.h). |
| `URS-EREC-008` | Y | H | Training of users, developers and support must be documented (§10.i). |
| `URS-EREC-009` | Y | H | There must be a definition of which user groups can grant access rights and which system operations each is permitted (§10.k). |
| `URS-EREC-010` | Y | H | The system documentation must be managed under version control (§10.k). |
| `URS-EREC-011` | Y | H | It must be defined whether this is a **closed or open system** (21 CFR Part 11 §11.30). *(Note: a system accessible remotely via the Internet but only by the persons owning the data is still a closed system.)* **If open**: additional **encryption** and/or **digital signature** controls are required to ensure authenticity and confidentiality (§11.30). |
| `URS-EREC-012` | Y | H | Explicitly define which system data constitute "electronic records" in the Part 11 sense. *(Name them in detail here.)* |
| `URS-EREC-013` | Y | H | The system must implement the **ALCOA+** data-integrity principles: **A**ttributable, **L**egible, **C**ontemporaneous, **O**riginal, **A**ccurate + **C**omplete, **C**onsistent, **E**nduring, **A**vailable. Document how each of the 9 attributes is ensured in the design (EU Annex 11 §2.4 / Glossary p.17 + GAMP 5 §G2.1 p.389). |
| `URS-EREC-014` | Y | H | Audit trail reviews must be performed by personnel **not directly involved** in the activities covered by the review — **independent peer review** (EU Annex 11 §12.6 p.10). |

#### System-specific determinations — `URS-EREC`

- `URS-EREC-005`: the audit trail scope for this system is enumerated in `URS-FUNC-009`.
- `URS-EREC-007`: applicable. Source validity is established by unique individual accounts
  (`URS-SEC-003`), session control (`URS-SEC-004`) and the qualified hosted environment. No
  instruments or terminals feed data into this system.
- `URS-EREC-011`: **closed system**, in both deployment variants. Access is limited to the persons
  owning the data, which the preset's own note confirms remains a closed system even when reached
  over the Internet. The outbound interface to the external AI provider is a controlled transfer
  to a third party governed by contract and by `URS-API-002`, not third-party access to the system.
- `URS-EREC-012`: the electronic records of this system are every Quality Record of the seven
  Record Types, comprising its Record Spine, the Optional Blocks it uses, its Actions, its Record
  Links including Origin Links and their Closure Dependency, its attachments, its electronic
  signatures including the Opening Signature and every QA Determination, and its audit trail.
  Additionally: the Role and permission configuration, and the AI-generated content markings
  together with their human-review records.

---

### 4.3 `URS-ESIG` — Electronic Signatures requirements (21 CFR Part 11)

> Canonical preset, copied verbatim. Legal text and `GxP`/`Prio` cells are not edited.

| ID-No. | GxP | Prio. | Requirement |
|---|---|---|---|
| `URS-ESIG-001` | Y | H | An SOP must exist regulating that each person can be held accountable for actions performed under their electronic signature (§10.j). *(Check whether one already exists in the organization.)* |
| `URS-ESIG-002` | Y | H | Signed electronic records must visibly contain the signer's full legible name, the date and time of signing, and the meaning or reason for the signature — both in paper printout and in electronic display (§50). |
| `URS-ESIG-003` | Y | H | Electronic signatures must be securely linked to the record they belong to (§70). |
| `URS-ESIG-004` | Y | H | Each electronic signature must be unique to one single person; it cannot be reused or reassigned (§100.a). |
| `URS-ESIG-005` | Y | H | The holder's identity must be verified before assigning the electronic signature (§100.b). |
| `URS-ESIG-006` | Y | H | For non-biometric signatures: it must be ensured that an attempt to forge an electronic signature requires the collaboration of at least 2 persons (§200.a.3). |
| `URS-ESIG-007` | Y | H | For non-biometric signatures: it must be ensured that two persons do not obtain the same ID and password combination (§300.a). |
| `URS-ESIG-008` | Y | H | It must be ensured that the correct functioning of the credentials (ID and password) is checked periodically (§300.b). |
| `URS-ESIG-009` | Y | H | Periodic password expiry with mandatory renewal must be implemented (§300.b). |
| `URS-ESIG-010` | Y | H | The blocking or revocation of the identification must be regulated for cases of leaving the company or changing department (§300.b). |
| `URS-ESIG-011` | Y | H | It must be possible to electronically disable an access device or ID/password combination in case of loss (§300.c). |
| `URS-ESIG-012` | Y | H | For non-biometric signatures: unauthorized access attempts must be logged and the results reported periodically to management (§300.d). |
| `URS-ESIG-013` | Y | H | Describe the electronic signature mechanism (smartcard, fingerprint, etc.). If only ID/password is used: specify the minimum length of each (§200.a.1.i). |
| `URS-ESIG-014` | Y | H | Describe whether multiple consecutive signatures on screen are required. If so: the password must be re-entered for each signature (§200.a.1.ii). |
| `URS-ESIG-015` | Y | H | An organizational procedure must exist for cases of loss of access devices (smartcards, tokens): electronic disabling + strict control of any physical relocation (§300.c). |
| `URS-ESIG-016` | Y | H | When putting access devices into operation, a commissioning test must be performed, including verification against unauthorized tampering. Thereafter, periodic testing (§300.e). |
| `URS-ESIG-017` | Y | H | **Tamper-evidence**: signed records must implement controls ensuring the signed record **cannot be modified** or, alternatively, that any subsequent modification makes the record **appear as unsigned** (EU Annex 11 §13.7-13.8 p.11). |
| `URS-ESIG-018` | Y | H | **Hybrid solution** (handwritten signature on paper over an electronic record): if implemented, a high degree of certainty must be ensured that any change to the electronic record invalidates the signature — typically via a **checksum/hash** of the electronic record printed on the signature page (EU Annex 11 §13.9 p.11). *(Activate only if the organization uses hybrid signatures.)* |

#### System-specific determinations — `URS-ESIG`

- `URS-ESIG-013`: the mechanism is **user ID and password**. No biometric and no access device is
  used. Minimum length is **6 characters for the user ID** and **12 characters for the password**.
  The password is the only secret protecting each signature — `URS-SEC-002` places multi-factor
  authentication on remote login, not on the signature itself — and `URS-ESIG-009` rotates it
  periodically, so the length is set above the historical eight-character minimum.
- `URS-ESIG-014`: multiple consecutive signatures do occur, and **the password is re-entered for
  every signature** without exception, which is the literal reading of §200.a.1.ii.
- `URS-ESIG-015`: **N/A** — no access devices (smartcards, tokens) are used.
- `URS-ESIG-016`: **N/A** — no access devices are put into operation.
- `URS-ESIG-018`: **N/A** — no hybrid handwritten-over-electronic signatures are used. All
  signatures are electronic.
- `URS-ESIG-011` remains applicable to the ID and password combination.
- `URS-ESIG-001`: the required procedure is specified as `URS-PROC-003`.

---

### 4.4 `URS-DATA` — Data structure requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-DATA-001` | Y | H | The data model shall hold every Quality Record together with its complete audit trail at the volume of `URS-PERF-005` for the retention period of `URS-ARCH-001`, without archival that removes a record from query. |
| `URS-DATA-002` | Y | H | Every element of a Quality Record generated by the AI Assistant shall carry, for the life of the record, the model identifier, the model version, the prompt version and the context template version that produced it, the timestamp, and the user who requested it. |
| `URS-DATA-003` | Y | H | The system shall record and preserve the timezone of every timestamp, and shall present timestamps unambiguously in printouts and on screen, supporting the contemporaneousness attribute of `URS-EREC-013`. |
| `URS-DATA-004` | Y | H | No stored value of a Quality Record shall be modifiable except through a function that writes the change to the audit trail. Direct modification of stored data outside the application shall be prevented and, where technically possible in the qualified environment, detectable. |
| `URS-DATA-005` | Y | H | Personal data held in Quality Records shall be limited to what the quality process requires, shall be identified so it can be located on request, and shall be handled under the data protection assessment produced for this system. |

---

### 4.5 `URS-SEC` — Data security requirements

> Rows 001 and 002 are the EU Annex 11 2025 modernization preset, copied verbatim. The preset is
> **active**: the system supports a hosted deployment variant with remote access, and record
> content crosses an untrusted perimeter on every request to the external AI provider.

| ID | GxP | Prio. | Requirement |
|---|---|---|---|
| `URS-SEC-001` | Y | H | **Encryption of critical GxP data** at rest (at-rest) and in transit (in-transit). Cryptographic algorithms, key management, and key rotation documented (EU Annex 11 §10 — *encryption of critical data*). |
| `URS-SEC-002` | Y | H | **Multi-Factor Authentication (MFA)** mandatory for remote authentication of critical systems from outside controlled perimeters (EU Annex 11 §11.6 p.9 — NEW vs 2011). |
| `URS-SEC-003` | Y | H | Every user shall hold a unique individual account. Shared, generic and group accounts shall not be permitted, and an account shall be disabled without delay on departure or change of function, satisfying `URS-EREC-004` and EU Annex 11 §12. |
| `URS-SEC-004` | Y | H | An inactive session shall expire after a configurable period and require re-authentication, and expiry shall never leave an in-progress electronic signature applied. |
| `URS-SEC-005` | Y | H | Credentials for the external AI provider shall be held outside source control and shall be rotatable without a code change. Record content shall not be written to application or infrastructure logs. |

---

### 4.6 `URS-PERF` — Performance requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-PERF-001` | N | M | The system shall complete an interactive transaction, including opening a Quality Record, saving a field and applying an electronic signature, in 2 seconds or less with 50 concurrent users. |
| `URS-PERF-002` | N | M | The system shall generate any report required by `URS-FUNC-014` in 10 seconds or less over a record population of at least five years at the volume stated in `URS-PERF-005`. |
| `URS-PERF-003` | Y | H | The system shall be available for 99.5% of business hours, measured monthly, excluding scheduled maintenance announced in advance. |
| `URS-PERF-004` | Y | H | The system shall meet a Recovery Point Objective of 24 hours and a Recovery Time Objective of 8 hours. The backup and restore procedures achieving these are specified in `URS-OPS-001`. |
| `URS-PERF-005` | Y | M | The system shall be sized for 5,000 new Quality Records per year and 50 concurrent users, including their attachments, without degrading the response times of `URS-PERF-001` and `URS-PERF-002`. |

---

### 4.7 `URS-UI` — User interface requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-UI-001` | N | H | The system shall be a web application reached through a browser with no installation on the client, supporting the current and previous major versions of Chrome, Edge, Firefox and Safari. |
| `URS-UI-002` | Y | H | The user interface shall be presented in English. Record content shall be entered and stored in the language its author writes, and the system shall not translate record content. |
| `URS-UI-003` | N | M | The interface shall be usable on desktop and on tablet down to a documented minimum viewport, including entering record content and applying an electronic signature. |
| `URS-UI-004` | Y | H | Every screen presenting a Quality Record shall display its identifier, Record Type, current State, owner and due date, and shall show the AI-generated marking of `URS-FUNC-063` wherever such an element appears. |
| `URS-UI-005` | Y | H | The system shall produce a printable human-readable output of a complete Quality Record including its content, its Actions, its Record Links, every electronic signature with signer, date, time and meaning, and its audit trail. This output is the system-specific form of the printout required by `URS-EREC-002`. |

**Determination — accessibility.** No formal accessibility standard is committed for this release.
No WCAG conformance level is claimed and none is verified. This is a deliberate decision, not an
omission.

---

### 4.8 `URS-API` — Interface requirements

> Row 001 is the EU Annex 11 2025 preset, copied verbatim. The preset is **active**: the outbound
> interface to the external AI provider transfers GxP data across an untrusted perimeter.

| ID | GxP | Prio. | Requirement |
|---|---|---|---|
| `URS-API-001` | Y | H | All interfaces that transfer GxP data must be **validated**: correct input checks, documented error handling, end-to-end verifiable flow integrity, encryption if data crosses untrusted perimeters (EU Annex 11 §10 — *validated interfaces*). |
| `URS-API-002` | Y | H | The interface to the external AI provider is the only interface transferring GxP data outside the system in this release and shall be validated under `URS-API-001`, with documented input and output checks, error handling covering provider unavailability, timeout and malformed response, and encryption in transit. |
| `URS-API-003` | Y | H | The system shall transmit to the AI provider only the content necessary for the assistance requested, and shall record against the Quality Record that a transmission occurred, when, and which model and prompt version served it. |
| `URS-API-004` | Y | H | The system shall remain fully usable when the AI provider is unavailable. No State transition, electronic signature, QA Determination or closure shall depend on the AI interface. |

---

### 4.9 `URS-MIGR` — Data migration requirements

**N/A — no legacy data migration.** The system is new and starts empty. `URS-MIGR-001` of the
Annex 11 2025 / GAMP 5 §D7 preset does not apply and no migration requirements are raised.

---

### 4.10 `URS-ARCH` — Archiving and retention requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-ARCH-001` | Y | H | Quality Records and their audit trails shall be retained for at least 10 years from closure, or longer where a product-specific or national requirement applies, and shall not be disposed of before that period expires. |
| `URS-ARCH-002` | Y | H | Retained records shall remain electronically accessible, readable and printable in human-readable form throughout the retention period, across system upgrades, database migrations and changes of AI model, satisfying `URS-EREC-003`. |
| `URS-ARCH-003` | Y | H | Disposal of records at the end of the retention period shall require documented authorisation by Quality Assurance and shall itself be recorded. Disposal is distinct from Cancellation, which never removes a record. |

---

### 4.11 `URS-OPS` — Operational requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-OPS-001` | Y | H | The system shall be backed up on a schedule meeting the Recovery Point Objective of `URS-PERF-004`, and a full restore shall be performed and documented at least annually to demonstrate the Recovery Time Objective is met. |
| `URS-OPS-002` | Y | H | A review of every user account, its assigned Role and every permission change recorded since the previous review shall be performed at least every six months and approved by Quality Assurance. This review is the compensating control for permission changes taking effect without prior approval under `URS-FUNC-056`. |
| `URS-OPS-003` | Y | H | The audit trail of a Quality Record shall be reviewed before closure by the Quality Assurance user signing that closure, who is independent of its author by `URS-FUNC-057`. A periodic system-level audit trail review shall additionally be performed at least quarterly over a risk-based sample, with its outcome recorded, satisfying `URS-EREC-014`. |
| `URS-OPS-004` | Y | H | The system shall be monitored for availability, failed authentication attempts and application errors, with alerting to a defined recipient. Incidents shall be recorded and classified, and a critical incident shall receive a documented response within 4 business hours. |
| `URS-OPS-005` | Y | H | A periodic review of the validated system shall be performed at least annually, covering incidents, changes, deviations affecting the system, the outcomes of the user access and audit trail reviews, and continued fitness for intended use, concluding with a documented statement of validated status. |
| `URS-OPS-006` | Y | H | A change to the AI model identifier or version, or to any prompt or context template, shall be processed as a Change Control and shall require documented re-evaluation of the AI Assistant against its acceptance criteria before release. The assistant's outputs shall be monitored in operation, by a method and at a frequency defined in the operating procedures. |

---

### 4.12 `URS-PROC` — Process requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-PROC-001` | Y | H | Procedures shall exist and be approved before go-live covering: use of the system for each Record Type, the criteria Quality Assurance applies when making a QA Determination, audit trail review, user access management and its periodic review, use of the AI Assistant and the documented human review of its output, and backup, restore and incident handling. |
| `URS-PROC-002` | Y | H | The lifecycle roles of GAMP 5 §6.2.3 shall be named for this system: Process Owner, System Owner, Quality Unit and Subject Matter Expert. These are lifecycle roles and are distinct from the application Roles of `URS-FUNC-056`, which happen to share the name Process Owner. |
| `URS-PROC-003` | Y | H | The procedure required by `URS-ESIG-001`, establishing that each person is accountable for actions performed under their electronic signature, shall exist and be acknowledged by every user before their account is activated. |

---

### 4.13 `URS-DOCS` — Documentation requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-DOCS-001` | Y | M | A user manual shall describe each Record Type, its State Model, the signatures it requires and the Optional Blocks it uses, in terms a trained end user can follow without reference to the design documentation. |
| `URS-DOCS-002` | Y | H | System documentation shall be held under version control and updated with each release, satisfying `URS-EREC-010`. |
| `URS-DOCS-003` | Y | H | A document shall describe what the AI Assistant can and cannot do, the wording of its output marking, and the known limitations of its suggestions, and shall be available to every user of the assistant. |

---

### 4.14 `URS-TRAIN` — Training requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-TRAIN-001` | Y | H | Every end user shall be trained, before their account is activated, on the Record Types they will use, on Cancellation as the only exit from the active population, and on the four invariants of `URS-FUNC-057`. |
| `URS-TRAIN-002` | Y | H | Quality Assurance users shall additionally be trained on Triage, on QA Determinations and the criteria governing them, on audit trail review and on record closure. |
| `URS-TRAIN-003` | Y | H | Administrators shall additionally be trained on Role and permission configuration, on the audit trail their changes produce, and on the boundary that prevents them from touching record content. |
| `URS-TRAIN-004` | Y | H | Every user of the AI Assistant shall be trained on its advisory nature, on the marking of AI-generated content and on their obligation to perform and record the human review required by `URS-FUNC-064`. |
| `URS-TRAIN-005` | Y | H | Training shall be recorded and retained for developers, administrators, support staff and end users, satisfying `URS-EREC-008`. |

---

### 4.15 `URS-QUAL` — Quality requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-QUAL-001` | Y | H | Source code shall be written to a documented coding standard enforced automatically by static analysis in the build pipeline, and a build failing that analysis shall not produce a release candidate. |
| `URS-QUAL-002` | Y | H | Automated tests shall cover at least 80% of source statements overall, and 100% of the code paths implementing the four invariants of `URS-FUNC-057`, every electronic signature step and every State transition. A build below either threshold shall fail. |
| `URS-QUAL-003` | Y | H | Every change to source code shall be reviewed and approved by a person other than its author before merge, with the review recorded and retained. |
| `URS-QUAL-004` | Y | H | Source code, configuration, database schema, test specifications and test evidence shall be held under version control, and each release shall be identified by an immutable tag from which that release can be rebuilt. |
| `URS-QUAL-005` | Y | H | The AI model identifier and version, and every prompt and context template used by the AI Assistant, shall be configuration items under change control, versioned with the release and recorded against each AI-generated element. |

---

### 4.16 `URS-TEST` — Testing requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-TEST-001` | Y | H | Testing shall use synthetic test data. Production record content shall not be copied into development or validation environments. |
| `URS-TEST-002` | Y | H | A validation environment shall exist whose configuration matches the qualified production environment, and functional and fitness verification shall be executed there before release. |
| `URS-TEST-003` | Y | H | The AI Assistant shall be evaluated against a documented, versioned evaluation set with defined acceptance criteria, before first release and again after any change to the model identifier, model version, prompt or context template, as required by `URS-OPS-006`. |
| `URS-TEST-004` | Y | H | Negative testing shall be mandatory for the four invariants of `URS-FUNC-057`, for every electronic signature step and for every State transition restricted by Role. A release shall not proceed with any of these untested. |
| `URS-TEST-005` | N | M | Performance testing shall be executed at the volume and concurrency of `URS-PERF-005` before release, and its results recorded. |

---

### 4.17 `URS-DELIV` — Deliverables

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-DELIV-001` | Y | H | The project shall deliver the validation package: Validation Plan, initial and detailed Risk Assessments, URS, FS, DS, installation, functional and fitness verification specifications with executed evidence, Requirements Traceability Matrix and Validation Report. |
| `URS-DELIV-002` | Y | H | The project shall deliver source code and build artifacts under version control, identifying the tag from which each release was built. |
| `URS-DELIV-003` | Y | H | The project shall deliver executed test evidence for unit, integration, security and performance testing, retained and traceable to the requirements it verifies. |
| `URS-DELIV-004` | Y | M | The project shall deliver end-user documentation and an administrator runbook covering installation, configuration, backup and restore, and user administration. |
| `URS-DELIV-005` | Y | M | Each release shall be accompanied by release notes identifying the changes it contains and the configuration items they affect. |

---

### 4.18 `URS-PERIPH` — Peripheral requirements

**N/A — no peripherals.** No instruments, scanners, printers or sensors are integrated with this
system.

---

### 4.19 `URS-HW` — Hardware requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-HW-001` | Y | M | The qualified hosted environment shall meet a documented minimum specification for compute, memory, storage and network, sized to `URS-PERF-005` and verified during installation qualification. |
| `URS-HW-002` | Y | M | Storage shall be provisioned for the full retention period of `URS-ARCH-001` including record attachments, with documented headroom for growth. |

---

### 4.20 `URS-DEVENV` — Development environment requirements

| ID | GxP (Y/N) | Prio (H/M/L) | Requirement |
|---|---|---|---|
| `URS-DEVENV-001` | Y | H | The application shall be developed in Python on the server and TypeScript on the client, with the version of each runtime pinned and recorded against every release. |
| `URS-DEVENV-002` | Y | H | Persistence shall use PostgreSQL provided through Supabase. The database schema shall be held under version control as ordered migrations, applied in a repeatable and verifiable sequence, and no schema change shall reach a qualified environment outside that mechanism. |
| `URS-DEVENV-003` | Y | H | Source control shall be GitHub, with a documented branching strategy. Every change shall reach the release branch through a pull request reviewed and approved under `URS-QUAL-003`. |
| `URS-DEVENV-004` | Y | H | Continuous integration and delivery shall run on GitHub Actions, enforcing the coding standard gate of `URS-QUAL-001` and the coverage thresholds of `URS-QUAL-002`. A failing pipeline shall block the release it would have produced. |
| `URS-DEVENV-005` | Y | H | Static analysis shall run for both languages in the pipeline, covering conformance to the coding standard of `URS-QUAL-001` and static type checking, with the failure threshold documented and a failing analysis blocking the release candidate. The specific tools implementing this requirement are selected and justified in the Design Specification, and are configuration items under `URS-QUAL-004`. |
| `URS-DEVENV-006` | Y | M | Dependencies shall be resolved from locked version files, and each release shall record a software bill of materials identifying every third-party component and its version. |

---

## 5. Related documents

- `.gxp-dev.yaml` — project manifest
- `CONTEXT.md` — domain glossary, authoritative for the capitalised terms used throughout
- `specs/GXP-ASSESS.md` — GxP assessment *(planned)*
- `specs/VP.md` — Validation Plan *(planned)*
- `specs/SUP-ASSESS.md` — Supplier assessment, covering the AI model provider and the hosting and
  database provider *(planned)*
- `specs/RA-INIT.md` — Initial Risk Assessment *(planned)*
- `specs/DPIA.md` — Data Protection Impact Assessment *(planned)*
- Downstream: `specs/FS.md`, `specs/DS.md`, `specs/IQ.md`, `specs/OQ.md`, `specs/PQ.md`,
  `specs/RTM.md`

---

## 6. Revision history

| Version | Date | Reason | Author |
|---|---|---|---|
| 0.1 | 2026-08-02 | Initial draft from `gdd.urs.from-idea`, phases 1-11 | See signature block |
