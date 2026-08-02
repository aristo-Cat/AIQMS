---
title: "RA-INIT — Initial Risk Assessment for AI-QMS — AI-first electronic Quality Management System"
type: instance
based_on_template: "RA-INIT"
based_on_template_version: "0.1.0"
project_id: "AIQMS-2026-001"
system_id: "AIQMS-2026-001"
traces_to: "specs/URS.md (v0.1, draft)"
gamp_category: 5
status: draft
version: "0.1"
created: "2026-08-02"
updated: "2026-08-02"
language: "en"
detailed_ra_ref: "specs/RA-DET.md (planned — RA-DET required, see §8)"

# Copied from .gxp-dev.yaml for self-contained reference
profile: "pharma"
mode: "develop"
part11_applicable: true
---

# RA-INIT — Initial Risk Assessment

## 0. Identification and signatures

### System

| Field | Value |
|---|---|
| **System name** | AI-QMS — AI-first electronic Quality Management System |
| **System identifier** | `AIQMS-2026-001` |
| **URS assessed** | `specs/URS.md` (v0.1, `status: draft`) |
| **GxP business process** | The quality processes of a regulated GxP manufacturing organisation — quality events, deviations, CAPA, change control, audits received and performed, and their findings |
| **Determined GAMP category** | **5** *(key output of this document)* |

### Signatures

> [!warning] Fictional reviewers and approvers
> This system is a public demonstration artifact with no operating organisation behind it. The
> Author is real. The four reviewer and approver entries below are **fictional placeholders**,
> written with non-name identifiers so they cannot be mistaken for real people or for a genuine
> approval. This RA-INIT is `status: draft` and **is not approved**. The same convention is used
> in `specs/URS.md`.

| Role | Name | Department | Date | Signature |
|---|---|---|---|---|
| Author | Juan Miguel Saavedra | Quality Assurance / Computerised System Validation | 2026-08-02 |  |
| Reviewer 1 (Process Owner) *(owner of severity)* | `FICTIONAL-REVIEWER-1` | Quality Operations | — |  |
| Reviewer 2 (SME) | `FICTIONAL-REVIEWER-2` | Manufacturing / Engineering | — |  |
| Approver 1 (System Owner) | `FICTIONAL-APPROVER-1` | Information Technology | — |  |
| Approver 2 (Quality Unit) | `FICTIONAL-APPROVER-2` | Quality Assurance | — |  |

> [!note] Roles — GAMP 5 §M3 Table 11.1
> Process Owner / System Owner establish the team and approve; the SME + key-users identify and
> analyse risks; the Quality Unit owns the compliance-related risks. The **Process Owner signs**
> because they are the owner of severity.

> [!warning] Approval order (GAMP 5 §M3 step 1)
> In the canonical cascade RA-INIT reaches `approved` **before** the URS, because the URS inherits
> `gamp_category` from here. In this project the URS was authored first, as a deliberate sequencing
> choice recorded in the project's working state. This RA-INIT therefore **confirms** the category
> and the Part 11 / Annex 11 applicability the URS assumed; §5.3 and §5.4 record that they are
> consistent, and no discrepancy required propagation back into the URS.

---

## 1. Objective

This document performs the **Initial Risk Assessment** of **AI-QMS** in accordance with the
five-step QRM process of GAMP 5 (§5.3 + §M3), covering:

- **Step 1** — Initial Risk Assessment + System Impact: GxP determination, system impact, the
  **GAMP category**, and the applicability of 21 CFR Part 11 / EU Annex 11.
- **Step 2** — Identify Functions with Impact: the requirements of `specs/URS.md` that impact
  patient safety, product quality or data integrity.

Steps 3-5 (detailed Functional Risk Assessment, implementation and verification of controls, and
periodic review) are executed in `specs/RA-DET.md` and during operation.

---

## 2. Definitions and abbreviations

| Term | Definition |
|---|---|
| RA-INIT | Initial Risk Assessment (this document) |
| RA-DET | Detailed Risk Assessment (FMEA/RPN, GAMP 5 §M3 step 3) |
| QRM | Quality Risk Management (ICH Q9) |
| PS / PQ / DI | Patient Safety / Product Quality / Data Integrity (the three impact axes) |
| Severity | Severity of the impact on PS/PQ/DI (defined by the business process) |
| Probability | Probability that the failure occurs (scales with the GAMP category) |
| Detectability | Probability of detecting the failure before it causes harm |
| Risk Class | Severity × Probability |
| Risk Priority | Risk Class × Detectability |
| GAMP category | Cat 1 (infrastructure) / 3 (standard) / 4 (configured) / 5 (custom) — GAMP 5 §M4 |

The domain vocabulary of the assessed system (Quality Record, Record Spine, Optional Block, QA
Determination, Origin Link, Closure Dependency, Segregation Invariant, Opening Signature) is
defined in `CONTEXT.md` at the repository root and used here with those meanings.

---

## 3. Methodology

This RA-INIT applies the qualitative method of GAMP 5 §M3 §11.5.4:

```
Risk Class    = Severity × Probability
Risk Priority = Risk Class × Detectability
```

Each factor is rated **H / M / L** using the matrices of `templates/csv/RA-INIT.md` §3.1 (Risk
Class) and §3.2 (Risk Priority); the arithmetic is not improvised. Severity derives from the
quality business process of §4, never from the GAMP category; Probability scales with the category;
Detectability considers both automatic and manual mechanisms.

### 3.4 Rating conventions applied in this assessment

Because this assessment rates every GxP requirement of the URS individually, the three scales are
fixed in advance so that ratings are consistent across the register and reproducible by a reviewer.

**Severity** — from the business process of §4:

| Rating | Criterion |
|---|---|
| **H** | The failure breaks the evidentiary chain of the Quality Record, or allows an approval step to be bypassed. These are the two paths by which this system can contribute to product reaching a patient in a state the quality system believed it had controlled. |
| **M** | The failure degrades or delays a quality decision, with a compensating control existing outside the system (the quality organisation, a procedure, an independent report). |
| **L** | Operational inconvenience with no GxP consequence. |

**Probability** — scales with GAMP category 5 (custom code):

| Rating | Criterion |
|---|---|
| **H** | Complex, conditional or cross-record state logic (conditional Optional Blocks, Closure Dependency, invariants holding across seven State Models), or dependency on a non-deterministic third party. |
| **M** | Baseline for Cat 5: bespoke, verifiable logic scoped to a single record. |
| **L** | The capability is supplied by the qualified platform (PostgreSQL/Supabase primitives, managed encryption, managed storage) and the custom code only consumes it. |

**Detectability**:

| Rating | Criterion |
|---|---|
| **H** | The failure surfaces to the user at the moment it occurs (a rejected transition, a missing mandatory field, an operation that fails visibly), or the monitoring of `URS-OPS-004` raises it. |
| **M** | A defined review finds it: audit trail review before closure (`URS-OPS-003`), the six-monthly user access review (`URS-OPS-002`), or the annual periodic review (`URS-OPS-005`). |
| **L** | Nothing in the system reveals it: the audit trail does not capture the change, an AI marking is silently lost, a timestamp stores the wrong timezone, a report silently omits rows, a notification is never sent, a search silently returns less than it should. |

---

## 4. System context and boundary

**System boundary under analysis** — in scope: the AI-QMS web application, its database and audit
trail, its Role and permission configuration, the outbound interface to the external AI provider,
and the qualified hosted single-tenant environment in which it runs.

Out of scope: the external AI provider's own infrastructure and model, assessed separately in
`specs/SUP-ASSESS.md`; the on-premise deployment variant, which is a documented deployment variant
entering through change control when first used and is not the qualified environment; the four
anticipated business-system integrations (document management, training records, LIMS, ERP), which
this release does not implement; and the procedures of the quality organisation that operate around
the system, which are requirements upon it (`URS-PROC-001`) rather than parts of it.

**Supported GxP business process (origin of severity)** — the quality processes of a regulated GxP
manufacturing organisation: quality events, deviations, CAPA, change control, audits received and
audits performed, and the findings arising from them. These records evidence batch disposition, the
maintenance of validated state, and the effectiveness of corrective action. They are the record an
inspector reads and the basis on which a product-quality decision is defended. The system does not
control product or process; it holds the evidence that product and process were controlled.

---

## 5. Step 1 — Initial Risk Assessment + System Impact

### 5.1 GxP determination

Is the system GxP-relevant? **`gxp-relevant`**

The system creates, modifies, stores and transmits records under GxP predicate rules as the
**primary electronic record** of six quality processes, and applies electronic signatures at every
approval step. It is not `indirect-gxp`: that determination is for systems supporting a GxP process
without holding its record.

### 5.2 System impact

Overall impact on patient safety / product quality / data integrity: **`high`**

| Axis | Impact (H/M/L) | Justification |
|---|---|---|
| Patient Safety (PS) | **H** | The system does not control product or process, but it holds the decisions that keep defective product from reaching a patient. A Change Control approved without its Impact Assessment of validated state, or a critical Deviation closed with its Investigation waived — which `URS-FUNC-026` permits by signed QA Determination — are paths by which a failure of this system contributes directly to patient exposure. |
| Product Quality (PQ) | **H** | The record is the evidence that a deviation was investigated, an impact assessed and a change controlled. If the record fails, the product-quality decision rests on nothing. |
| Data Integrity (DI) | **H** | The system is the primary electronic GxP record, with audit trail and electronic signature. ALCOA+ (`URS-EREC-013`) applies to it directly, not by inheritance from another system. |

### 5.3 Determination of the GAMP category (critical output)

**Assigned category**: **5**

**Rationale**: AI-QMS is a bespoke application developed to specification. No commercial product is
being configured: the record model, the seven State Models, the Optional Block mechanism, the
signature points and the invariants are all written as custom code. The configurability of Roles
and permissions required by `URS-FUNC-056` exists *within* a custom application and does not make
it a configured product in the §M4 sense. The external AI provider is a service consumed across an
interface (`URS-API-002`), not a component of the system; its non-deterministic behaviour does not
change the category — it raises the Probability rating of the AI-related risks and is governed
through supplier assessment and `URS-OPS-006`. Cat 5 carries the highest inherent probability of
failure of the four categories, which is why the URS mandates negative testing of the invariants,
signature steps and State transitions (`URS-TEST-004`) and 100% coverage of those paths
(`URS-QUAL-002`).

| Category | Criterion (GAMP 5 §M4) | Applies? |
|---|---|---|
| **Cat 1** | Infrastructure software (OS, DB engine, middleware). *Qualified*, not validated. | No — PostgreSQL and the hosting platform are Cat 1 components *beneath* this system, qualified through `URS-HW-001` and installation qualification, not the system itself |
| **Cat 3** | Standard non-configured product (COTS parameterizable, used out-of-the-box). | No — no commercial product is being used |
| **Cat 4** | Configured product (LIMS, SCADA, ERP, CDS, EDMS, BMS, configurable spreadsheets). | No — the Role and permission configuration of `URS-FUNC-056` is configuration *inside* bespoke code, not the configuration of a supplied product |
| **Cat 5** | Custom / bespoke application (developed to specification; higher inherent risk). | **Yes** |

### 5.4 Applicability of 21 CFR Part 11 / EU Annex 11

Does the system generate/store GxP electronic records or use electronic signatures?
**`part11_applicable: true`**

| Question | Yes/No | Consequence |
|---|---|---|
| Does it generate/store GxP electronic records as the primary source? | **Yes** — every Quality Record of the seven Record Types, enumerated in the `URS-EREC-012` determination | → activate preset URS-EREC |
| Does it implement electronic signatures (not scanned ones)? | **Yes** — ID and password, re-entered for every signature (`URS-ESIG-013`/`014` determinations) | → activate preset URS-ESIG |
| Does it process GxP data in cloud/SaaS or with remote access? | **Yes** — the qualified environment is the hosted single-tenant variant, and record content crosses an untrusted perimeter on every AI request | → activate preset URS-SEC (encryption + MFA) |
| Does it have interfaces that transfer GxP data? | **Yes** — the outbound interface to the external AI provider is the only one in this release, and it is in scope | → activate preset URS-API |
| Does it migrate legacy data from a predecessor system? | **No** — the system is new and starts empty | → URS-MIGR not activated (N/A) |

> **Consistency with the URS.** The URS activates `URS-EREC` (14 rows), `URS-ESIG` (18 rows),
> `URS-SEC` and `URS-API`, and records `URS-MIGR` as N/A. The five answers above match that
> activation exactly; no preset requires activation or deactivation as a result of this assessment,
> and `gamp_category: 5` matches the value the URS already carries. Nothing propagates back.

---

## 6. Step 2 — Identify Functions with Impact

> **Granularity of this step, and why.** The URS carries 163 requirements, 158 of them `GxP=Y`.
> This step identifies **functions with impact** at the level of function group, which is the level
> at which an *initial* risk assessment discriminates. The per-requirement, per-failure-mode
> analysis is the work of the Detailed Risk Assessment (`specs/RA-DET.md`, GAMP 5 §M3 step 3), and
> it is performed against an implemented system rather than against a requirement list. Every group
> below names the real `URS-<CAT>-NNN` requirements it covers; no requirement is silently omitted.

| Function group | URS requirements | PS | PQ | DI | GxP-critical? |
|---|---|---|---|---|---|
| Record Spine — identity, ownership, dates, audit trail scope | `URS-FUNC-001…003`, `009` | H | H | H | Yes |
| Overdue detection and notification | `URS-FUNC-004` | M | H | M | Yes |
| Attachments as supporting evidence | `URS-FUNC-005` | H | H | H | Yes |
| Retrieval, linking and reporting | `URS-FUNC-006`, `007`, `014` | M | H | M | Yes |
| Cancellation as the only exit; no delete path | `URS-FUNC-008` | H | H | H | Yes |
| Approval control — State transitions and signature points | `URS-FUNC-010`, `011` | H | H | H | Yes |
| Segregation Invariant (four eyes) | `URS-FUNC-012` | H | H | H | Yes |
| Committed work — Actions, Closure Dependency, closure gates | `URS-FUNC-013`, `031` | H | H | M | Yes |
| Optional Blocks and the signed QA Determination | `URS-FUNC-015…018`, `026`, `034`, `052` | H | H | M | Yes |
| The seven Record Type State Models | `URS-FUNC-019…030`, `032`, `033`, `035…055` | H | H | M | Yes |
| Configuration, access, and the four code-enforced invariants | `URS-FUNC-056…058` | H | H | H | Yes |
| AI Assistant — advisory output, marking, documented human review | `URS-FUNC-059…064`, `URS-DATA-002` | H | H | H | Yes |
| Electronic records preset (21 CFR Part 11 / Annex 11) | `URS-EREC-001…014` | H | H | H | Yes |
| Electronic signatures preset (21 CFR Part 11 / Annex 11) | `URS-ESIG-001…018` | H | H | H | Yes |
| Data model, timestamps, retention and disposal | `URS-DATA-001`, `003…005`, `URS-ARCH-001…003` | M | H | H | Yes |
| Security and the outbound AI interface | `URS-SEC-001…005`, `URS-API-001…004` | M | H | H | Yes |
| Availability, recovery and monitoring | `URS-PERF-003…005`, `URS-OPS-001`, `004` | M | H | H | Yes |
| Periodic reviews — access, audit trail, system, AI model | `URS-OPS-002`, `003`, `005`, `006` | M | H | H | Yes |
| Presentation and human-readable printout | `URS-UI-002`, `004`, `005` | M | M | H | Yes |
| Lifecycle controls — procedures, training, documentation, code quality, testing, deliverables, hardware, development environment | `URS-PROC-001…003`, `URS-TRAIN-001…005`, `URS-DOCS-001…003`, `URS-QUAL-001…005`, `URS-TEST-001…004`, `URS-DELIV-001…005`, `URS-HW-001`, `002`, `URS-DEVENV-001…006` | M | H | H | Yes — but these are **controls upon** the system, verified through the validation package and the development evidence, not system functions carrying their own failure mode |
| Non-GxP requirements | `URS-PERF-001`, `002`, `URS-UI-001`, `003`, `URS-TEST-005` | L | L | L | No — outside formal risk analysis |

---

## 7. Initial Risk Register — `RA-INIT-NNN`

> Risk Class = Severity × Probability; Risk Priority = Risk Class × Detectability, per the matrices
> of `templates/csv/RA-INIT.md` §3.1-3.2 and the rating conventions of §3.4 above.

> [!warning] Ratings are proposed, not yet owned
> Severity is owned by the **Process Owner**, who has not signed this document. Every rating below
> is the author's reasoned proposal under the §3.4 conventions and must be confirmed at review
> before this RA-INIT leaves `status: draft`.

| RA-ID | Assesses (URS-ID) | Risk (potential failure) | Severity | Probability | Risk Class | Detectability | Risk Priority | Initial control | Proceed to RA-DET? |
|---|---|---|---|---|---|---|---|---|---|
| `RA-INIT-001` | `URS-FUNC-009`, `URS-EREC-005` | A class of change is not captured by the audit trail — a field of an Optional Block, a Record Link, an Action reassignment | H | H | H | L | **H** | Audit scope enumerated in the requirement; 100% coverage of signature and transition paths (`URS-QUAL-002`); audit trail review before closure (`URS-OPS-003`) | Yes |
| `RA-INIT-002` | `URS-FUNC-002` | Record identifier duplicated, reused or modifiable, so cross-references resolve to the wrong record | H | L | M | M | M | Uniqueness and referential integrity of the qualified platform (`URS-DEVENV-002`); immutability enforced in code | Consider |
| `RA-INIT-003` | `URS-FUNC-004` | A Quality Record or Action passes its due date without being flagged or notified, and the committed work leaves the field of view | M | M | M | L | **H** | The reports of `URS-FUNC-014` list overdue items independently of the notification path; application monitoring (`URS-OPS-004`) | Yes |
| `RA-INIT-004` | `URS-FUNC-005` | An attachment is lost, or replaced without retaining the superseded file, so supporting evidence disappears | H | M | H | M | **H** | No deletion (`URS-FUNC-005`/`008`); backup with annually tested restore (`URS-OPS-001`); accessibility across retention (`URS-ARCH-002`) | Yes |
| `RA-INIT-005` | `URS-FUNC-006`, `007`, `014` | Retrieval or reporting is silently incomplete: a precedent is not returned by search, a report omits rows, recurrence stays invisible | M | M | M | L | **H** | Root-cause recurrence report as an independent path; OQ verification against a known record population | Yes |
| `RA-INIT-006` | `URS-FUNC-008`, `URS-FUNC-057` | A delete path exists — an exposed function, direct database access, or a cascade delete from a parent record or a user | H | M | H | L | **H** | Invariant enforced in code and not configurable (`URS-FUNC-057`); mandatory negative testing (`URS-TEST-004`); referential integrity without cascade (`URS-DEVENV-002`) | Yes |
| `RA-INIT-007` | `URS-FUNC-010`, `URS-FUNC-011` | A State transition completes without the Role the State Model requires, or without the electronic signature the transition requires | H | H | H | M | **H** | Declarative State Model; mandatory negative testing per restricted transition (`URS-TEST-004`); 100% path coverage (`URS-QUAL-002`) | Yes |
| `RA-INIT-008` | `URS-FUNC-012`, `URS-FUNC-057` | The system accepts an approval from the user who created the Quality Record or authored its Investigation — four eyes broken | H | H | H | M | **H** | Invariant enforced in code and not configurable; mandatory negative testing (`URS-TEST-004`) | Yes |
| `RA-INIT-009` | `URS-FUNC-013`, `URS-FUNC-031` | An Action closes without completion evidence, or a pre-closure Closure Dependency is ignored, so a record closes over work that never completed | H | H | H | M | **H** | Evidence mandatory at Action closure; closure gates of `URS-FUNC-029`/`035`/`042`/`055`; QA confirmation of the dependency at closure | Yes |
| `RA-INIT-010` | `URS-FUNC-015…018`, `026`, `034`, `052` | A conditional Optional Block is waived without a signed, justified QA Determination; or closure on a recorded justification after a failed Effectiveness Check becomes the routine path rather than the exception | H | H | H | M | **H** | The waiver is a signed act with recorded justification, never a checkbox (`URS-FUNC-015`); OQ exercises both the enabled and the waived path of every conditional block | Yes |
| `RA-INIT-011` | `URS-FUNC-019…030`, `032`, `033`, `035…055` | A Record Type's State Model admits a path that reaches a terminal state while skipping an approval the process requires | H | H | H | M | **H** | One declared State Model per Record Type over the minimum State Contract; negative testing of every restricted transition (`URS-TEST-004`) | Yes |
| `RA-INIT-012` | `URS-FUNC-056`, `URS-OPS-002` | A permission change takes effect without prior approval — permitted by design — and the compensating review does not catch an inappropriate grant before it is used | M | M | M | M | M | Six-monthly user access review approved by Quality Assurance (`URS-OPS-002`), which is the declared compensating control; mandatory reason recorded in the audit trail at the time of the change | Consider |
| `RA-INIT-013` | `URS-FUNC-063`, `064`, `URS-DATA-002` | AI-generated content enters a signed Quality Record without its marking, or without the documented human review | H | H | H | L | **H** | Marking retained for the life of the record and through editing (`URS-FUNC-063`); review gate before the record leaves `Draft` (`URS-FUNC-064`); model, prompt and context version recorded against the element (`URS-DATA-002`, `URS-QUAL-005`) | Yes |
| `RA-INIT-014` | `URS-ESIG-002`, `003`, `017` | A signature is not securely bound to its record, or a signed record can be modified without the signature being invalidated | H | M | H | M | **H** | Tamper-evidence (`URS-ESIG-017`); password re-entered for every signature (`URS-ESIG-014` determination); 100% coverage of signature steps (`URS-QUAL-002`) | Yes |
| `RA-INIT-015` | `URS-EREC-003`, `013`, `URS-ARCH-001`, `002` | Records cease to be accessible, readable or printable within the retention period, or an ALCOA+ attribute is not met in the implemented design | H | M | H | M | **H** | Retention without archival that removes a record from query (`URS-DATA-001`); human-readable printout (`URS-UI-005`); accessibility across upgrades and model changes (`URS-ARCH-002`) | Yes |
| `RA-INIT-016` | `URS-SEC-005`, `URS-API-002`, `003` | Quality Record content leaves the perimeter beyond what the assistance requires, is written to logs, or is retained or trained on by the AI provider | H | H | H | L | **H** | Minimum-necessary transmission (`URS-API-003`); record content never written to logs (`URS-SEC-005`); supplier assessment and a contractual no-training term; the Data Protection Impact Assessment | Yes |
| `RA-INIT-017` | `URS-PERF-003`, `004`, `URS-OPS-001` | The system is unavailable, or records are unrecoverable beyond the declared RPO/RTO after an infrastructure failure | M | M | M | M | M | Backup on a schedule meeting the RPO; full restore performed and documented annually (`URS-OPS-001`); availability monitoring (`URS-OPS-004`) | Consider |
| `RA-INIT-018` | `URS-DATA-004` | Stored record data is modified directly in the database, outside the application and therefore outside the audit trail | H | M | H | L | **H** | Modification only through functions that write the audit trail (`URS-DATA-004`); restricted database access in the qualified environment; schema changes only through versioned migrations (`URS-DEVENV-002`) | Yes |
| `RA-INIT-019` | `system-level` | The qualified hosted environment drifts from its qualified state through an unassessed infrastructure or platform change | M | M | M | M | M | Change control over the qualified environment; annual periodic review concluding on validated status (`URS-OPS-005`); installation qualification of the documented minimum specification (`URS-HW-001`) | Consider |
| `RA-INIT-020` | `system-level` | The AI model or a prompt changes in production without re-evaluation, so assistant behaviour shifts underneath a validated system | H | H | H | M | **H** | Model, prompt and context template as configuration items under change control (`URS-QUAL-005`); Change Control plus documented re-evaluation before release (`URS-OPS-006`); versioned evaluation set (`URS-TEST-003`) | Yes |

**Risk Priority = H → proceed to RA-DET** (16 of 20): `RA-INIT-001`, `003`, `004`, `005`, `006`,
`007`, `008`, `009`, `010`, `011`, `013`, `014`, `015`, `016`, `018`, `020`.

Two exposures are recorded here deliberately because they are consequences of decisions taken with
their arguments on the record, not oversights, and an inspector will read them first:

- **`RA-INIT-010`** — a conditional Investigation may be waived on a Deviation of *any* Severity,
  including critical, by signed QA Determination (`URS-FUNC-026`). The system-side mitigation is
  that the waiver is a signed, justified act; the residual exposure is procedural and belongs in
  the criteria of `URS-PROC-001`.
- **`RA-INIT-012`** — permission changes take effect without prior approval by design. The
  six-monthly user access review of `URS-OPS-002` is the declared compensating control, and it is
  weaker than prior approval because it detects rather than prevents.

---

## 8. Decision: is a Detailed RA (RA-DET) required?

**Is RA-DET required?** **`true`**

| Trigger | Present? | → RA-DET |
|---|---|---|
| `system_impact == high` | **Yes** — PS, PQ and DI all rated H (§5.2) | Yes |
| `gamp_category` 4 or 5 | **Yes** — Cat 5, bespoke application (§5.3) | Yes |
| ≥1 function with Risk Priority = H | **Yes** — 16 of 20 register entries (§7) | Yes |

**Final decision and justification**: a Detailed Risk Assessment is required. All three triggers
are present, and the first two are independent of the register — a Cat 5 system with high impact on
all three axes requires RA-DET regardless of how the initial register resolves.

`specs/RA-DET.md` performs the per-function FMEA (O×R×D → RPN) over the sixteen high-priority
entries above, expanding each function group into its individual `URS-<CAT>-NNN` requirements and
their specific failure modes. That expansion is deliberately deferred to RA-DET rather than
attempted here: GAMP 5 §M3 places the detailed assessment at step 3, against approved URS and FS,
and its output is the risk-based control and test rigor that flows into OQ and PQ. Performing it in
this document, against a requirement list with no implemented system behind it, would produce
volume rather than discrimination.

---

## 9. Related documents

| Document | Reference |
|---|---|
| URS assessed | `specs/URS.md` (v0.1, draft) |
| GxP Assessment | `specs/GXP-ASSESS.md` *(planned — not instantiated at the time of this assessment)* |
| Detailed Risk Assessment | `specs/RA-DET.md` *(planned — required, see §8)* |
| Supplier assessment (AI provider, hosting) | `specs/SUP-ASSESS.md` *(planned)* |
| Validation Plan | `specs/VP.md` *(planned)* |
| Domain glossary | `CONTEXT.md` (repository root) |

---

## 10. Revision history

| Version | Date | Reason for revision / Author |
|---|---|---|
| 0.1 | 2026-08-02 | Initial draft (RA-INIT) — Juan Miguel Saavedra, Quality Assurance / Computerised System Validation |
