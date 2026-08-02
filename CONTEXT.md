# CONTEXT — AI-QMS — AI-first electronic Quality Management System domain glossary

> Living domain glossary. Add a term the moment it is settled (in the URS interview,
> during `/gdd.clarify`, or when a design option names a new concept). Domain vocabulary
> only — no implementation details (no file names, function signatures, or framework choices).

## Language

**Quality Record**: the primary electronic record of this system — an identified,
audit-trailed, signable unit of quality work of one **Record Type**. Every quality record
carries the **Record Spine** and may carry **Optional Blocks** and **Actions**.
_Avoid_: "ticket", "case", "issue", "document".

**Record Spine**: the fields and behaviours every **Quality Record** has regardless of its
**Record Type** — identifier, type, title, description, originator, area, owner, dates,
current **State**, electronic signature at the type's approval steps, audit trail,
attachments, **Record Link**s, and **Cancellation**.
_Avoid_: "base record", "common core", "parent class".

**Record Type**: the classification that determines which **Optional Blocks** a
**Quality Record** uses and which **State Model** governs it. Seven types are in scope:
**Quality Event**, **Deviation**, **CAPA**, **Change Control**, **Audit Received**,
**Audit Performed**, **Finding**.
_Avoid_: "process" when referring to the record itself (a process is the work, a record type is the artifact).

**Action**: a reusable unit of committed work held by any **Quality Record** — owner, due
date, status and completion evidence. A quality record holds zero or more actions. An action
carries **no** corrective/preventive classification: that distinction belongs to the **CAPA**
as a whole and nowhere else (Juan, 2026-08-01 — *"las acciones de controles de cambios son
acciones y ya está"*). An action of a **Change Control** does carry a **Closure Dependency**,
because that is where a change control's committed work lives — the same role a **CAPA** plays
for a **Deviation** or a **Quality Event**.
_Avoid_: "task", "to-do", "CAPA action" (an action is not specific to a **CAPA**); "corrective
action" as a label on an action.

**Optional Block**: a named cluster of fields and steps that a **Record Type** declares it
uses. Three blocks exist: **Investigation**, **Impact Assessment**, **Effectiveness Check**.
A **Record Type** declares each block as **required** — always used — or **conditional** —
enabled or waived per record by a **QA Determination**. A block is never *partially* used:
it is used in full, or waived with a signed justification.
_Avoid_: "module", "plugin", "section".

**QA Determination**: the signed decision by which Quality Assurance enables or waives a
**conditional** **Optional Block** on one **Quality Record**, carrying a justification and made
at the step the **Record Type** declares for it. Three exist: on a **Deviation**, whether an
**Investigation** is required — decided at **Triage** by the reviewing QA and covered by the
Triage signature; on a **Finding**, whether an **Investigation** is required — decided once the
initial content and explanations are recorded, after QA has read them and spoken to the
responsible person; on a **CAPA**, whether an **Effectiveness Check** is required — decided at
QA's evaluation of the CAPA its owner has executed. A waived block is not re-enabled without a
new determination.
_Avoid_: "waiver" alone, "skip", "N/A" — the determination is an act with an author, a
justification and a signature, never an empty field.

**Investigation**: the **Optional Block** holding documented root cause and supporting
evidence for a **Quality Record**.
_Avoid_: "analysis", "RCA" as the record-facing term.

**Impact Assessment**: the **Optional Block** holding the assessment of consequence —
on product, batch, patient, data or validated state — and the resulting disposition.
_Avoid_: "risk assessment" (that is the separate `RA-INIT` / `RA-DET` cascade artifact).

**Effectiveness Check**: the **Optional Block** holding verification of a **Quality Record**
against a criterion defined *before any verification evidence is gathered* — the criterion, the
horizon, the responsible party, the evidence, and a pass/fail outcome. A fail does **not** close
the record by itself and does not automatically undo the work: QA either extends the horizon and
keeps the record open, or closes it on a recorded justification (Juan, 2026-08-01 — *"puede
extenderse un poco más y mantenerse abierto, o derivar a una justificación de cierre"*). Those
are the **only two** outcomes: returning a failed **CAPA** to planning was in the 2026-07-31
model and was removed on 2026-08-01 when Juan was asked directly. Where the plan itself was
wrong, a new **CAPA** is derived rather than the old one reopened.
One block, reused: a **CAPA** uses it as its effectiveness check, a **Change Control**
uses it as its post-implementation verification. The criterion and the horizon are set per
record, not per type — on a **CAPA** at the **QA Determination** over the executed record, on a
**Change Control** at approval, before implementation.
_Avoid_: "review", "follow-up"; and do not treat post-implementation verification as a separate
concept — it is this block. Do not state the criterion is defined before the *work* is executed:
on a CAPA it is not, and the property that holds is that it precedes the *evidence*.

**Due Date**: the date by which a **Quality Record** or an **Action** is committed to be closed.
It is **proposed by whoever opens the work** and **modified and approved by QA** — never assigned
by the system from a severity table (Juan, 2026-08-01: *"normalmente los deadline de todos
deberían ser propuestos por quien abre el objeto y luego QA lo puede modificar y aprobar"*).
**One exception**, decided the same day: on a **CAPA** and a **Change Control** the dates are
approved by the Process Owner, because they travel inside the plan or the change he already
signs — adding a QA signature there would put a second one on the two highest-volume approvals
after the deviation. A regulatory or externally imposed deadline overrides the proposal and is
recorded as such.
_Avoid_: "target date", "SLA"; and do not speak of a deadline "derived from" **Severity** — that
model was rejected.

**State**: the current position of a **Quality Record** in its **State Model**.

**State Model**: the states and permitted transitions declared by one **Record Type**. Every
state model must satisfy the **State Contract**.

**State Contract**: the minimum every **State Model** satisfies — one initial `Draft` state whose
exit is signed by the user who opens the record, at least one approval transition requiring an
electronic signature, a terminal closed state, and **Cancellation** reachable from any
non-terminal state. Transitions are restricted by **Role**, and the **Segregation Invariant**
applies to every approval transition.

**Opening Signature**: the electronic signature applied by the user who opens a **Quality
Record**, at the transition out of `Draft` — never at the instant of creation, since an empty
form attests to nothing. It fixes authorship of the content submitted and is the evidence the
**Segregation Invariant** is checked against at every later approval.
_Avoid_: "author field", "created by" (those are data; this is a signed act).

**Cancellation**: the only way a **Quality Record** leaves the active population — a
terminating transition carrying user, date and reason, recorded in the audit trail. Records
are never deleted.
_Avoid_: "delete", "remove", "void", "archive" (archival is retention, not cancellation).

**Record Link**: a directed, typed relation between two **Quality Record**s — for example a
**Deviation** to the **CAPA** it raised, a **Finding** to its parent **Audit**, or a
**Change Control** to the records it impacts.
_Avoid_: "reference", "attachment" (an attachment is a file, a link is between records).

**Quality Event**: the **Record Type** used to capture an occurrence before its nature is
known, and to route it to the right record type or close it with no further action.
_Avoid_: "incident", "observation" as synonyms.

**Deviation**: the **Record Type** for a departure from an approved instruction, specification
or established procedure. Declares **Impact Assessment** as **required** and **Investigation** as
**conditional** — the reviewing QA decides at **Triage** whether one is needed, by **QA
Determination**, independently of **Severity**.

**CAPA**: the **Record Type** for corrective and preventive action — a planned, approved and
executed remediation. Every CAPA is classified **corrective** or **preventive**; this is the only
place in the model where that distinction is recorded. It declares **Effectiveness Check** as a **conditional** block: once its
owner reports it executed, a **QA Determination** decides whether the check is required or
waived with justification. A CAPA never originates on its own: it always derives from a source
**Quality Record** through an **Origin Link**. Where the check is required, failing it does not
close the CAPA on its own — see **Effectiveness Check** for the two outcomes.
_Avoid_: "corrective action" alone (a CAPA covers both corrective and preventive); "new CAPA"
as an entry point (the only entry point is deriving one from a source record).

**Origin Link**: the mandatory **Record Link** from a **CAPA** back to the **Quality Record**
it derives from — a **Deviation**, a **Quality Event** or a **Finding**. A CAPA without an
origin link cannot exist. Every origin link carries a **Closure Dependency**.
_Avoid_: "parent" (a CAPA is not owned by its source — it closes on its own schedule).

**Closure Dependency**: the attribute declaring whether committed work must complete **before**
its source **Quality Record** closes — *pre-closure* — or may continue **after** it —
*post-closure*. One rule, two carriers, matching where each remediation mechanism lives: on a
**CAPA**'s **Origin Link**, for a **Deviation** or a **Quality Event**; and on an **Action** of a
**Change Control**. Proposed with a rationale by whoever opens the work, confirmed by QA at the
closure of the source record. It follows the nature of the work, never the **Record Type**
(Juan, 2026-08-01: *"lo de si se puede hacer Preclosure o Post Closure … se comparte entre las
dos"*).
_Avoid_: "blocking"/"non-blocking" (superseded 2026-08-01 by Juan's terms), "mandatory CAPA",
"child closes first" as a universal rule — both values are legitimate and the choice is a
recorded judgement.

**Triage**: the step where a **Deviation** is classified by **Severity**, its **Containment
Action** is recorded or justified as not applicable, and the **QA Determination** on the
**Investigation** block is made. Performed by QA, and signed — it decides the rigour of
everything downstream, so it is an approval step subject to the **Segregation Invariant**.
_Avoid_: "assessment", "review", "screening".

**Containment Action**: the immediate **Action** taken to limit the consequence of a
**Deviation** before its cause is known — isolating a batch, stopping a line. Recorded at
**Triage**, or explicitly justified as not applicable. Never a substitute for a **CAPA**.
_Avoid_: "immediate action" alone, "correction" (a correction fixes the instance; containment
limits the spread — and both differ from a CAPA, which addresses the cause).

**Severity**: the classification of consequence carried by a **Deviation** — critical, major or
minor, set at **Triage** — and by a **Finding** — critical, major, minor or observation, set when
it is opened. It is **recorded and reported, and triggers no system behaviour**: it does not gate
the **Investigation** (a **QA Determination** does), does not set the **Due Date** (the opener
proposes it), does not choose the signatory (QA by default, reassignable per record) and does not
compel a **CAPA**. Juan, 2026-08-01: *"en el sistema QA es quien decide. Ya si hay un
procedimiento que lo gobierne, no tiene ninguna implicación en el sistema."* Any SOP that binds
consequences to severity lives outside this system.
_Avoid_: "criticality", "priority" (priority is urgency of work; severity is consequence); and
any wording that makes severity *drive* a path, a deadline or a signatory.

**Change Control**: the **Record Type** for a proposed change, assessed through an **Impact
Assessment** and verified after implementation through the **Effectiveness Check**. Two
independent attributes govern its path: **Urgency** (normal or emergency) decides whether
approval precedes implementation or is ratified after it, and **Duration** (permanent or
temporary) decides whether the change carries an expiry.

**Urgency**: the **Change Control** attribute that is either normal — approved and signed before
implementation — or emergency — implemented first with recorded justification, then ratified by
signature within a defined maximum period. An emergency change is not an unapproved change; it is
one whose approval is displaced in time and bounded by a deadline.
_Avoid_: "urgent" as a priority label.

**Duration**: the **Change Control** attribute that is either permanent, or temporary — in which
case the change carries an expiry date and a mandatory **Action** to revert it or convert it to
permanent before that date. Independent of **Urgency**: a temporary change may be planned and
normally approved, and an emergency change may be permanent.
_Avoid_: "provisional", "interim".

**Audit Received**: the **Record Type** acting as the container for an audit or inspection of
this organisation by an external party — the authority or customer, the scope, the dates and the
report received. Its **Finding**s are answered by this organisation, under the responding party's
own commitments and any regulatory deadline.
_Avoid_: "inspection" as a distinct record type (an inspection is an audit received whose auditor
is an authority); "external audit" (ambiguous — it does not say which side is audited).

**Audit Performed**: the **Record Type** acting as the container for an audit this organisation
carries out on a supplier, a site or itself — the annual programme it belongs to, the plan, the
scope and the report issued. Its **Finding**s are answered by the auditee, whose commitments this
organisation tracks to closure.
_Avoid_: "internal audit" (an audit performed may be on a supplier, not internal); "supplier
qualification" (qualification is a decision the audit feeds, not the audit).

**Finding**: the **Record Type** for a single observation raised by an **Audit** — a
**Quality Record** in its own right, with its own owner, state, signature and **Action**s.
A finding closes on its own schedule and survives the closure of its parent **Audit**'s report.
It declares **Investigation** as a **conditional** block: once the initial content and
explanations are recorded, a **QA Determination** decides whether a deeper investigation is
required. It does **not** declare **Effectiveness Check** — effectiveness is a property of
actions, not of observations, so it is verified on the **CAPA** the responder derives, never on
the finding itself (Juan, 2026-08-01: *"no revisas efectividad de un finding, revisas efectividad
de acciones, es decir, de CAPAs, por concepto"*).
_Avoid_: "observation", "non-conformance", "deficiency" as interchangeable synonyms — they are
severity classifications of a finding, not other names for it.

**Role**: a named, configurable set of permissions. Five roles ship as defaults — Reporter,
Investigator, Process Owner, QA, Administrator — but the role and permission configuration is
itself a configuration item, changeable by the Administrator only.
_Avoid_: "user group", "profile".

**Segregation Invariant**: nobody approves a **Quality Record** they created or investigated.
One of **four** invariants enforced in code and not configurable away; the others are that no role
deletes a record (only **Cancellation**), that the Administrator never touches record content,
and that the **AI Assistant** executes no transition, signature, approval, closure,
**QA Determination** or **Closure Dependency** (promoted to an invariant 2026-08-01 — it is
enforced the same way, so it belongs in the same list).
_Avoid_: "four eyes" alone (four-eyes is the principle; this is its enforced form here);
"the three invariants" (superseded — there are four).

**AI Assistant**: the advisory capability of the system. It proposes — hypotheses, precedent,
draft narrative, classification, completeness checks — and never decides, approves or signs;
that prohibition is the fourth of the four invariants (see **Segregation Invariant**). Its output
is visibly marked and requires documented human review before entering a signed **Quality
Record**, and its precedent retrieval returns only records the requesting user is already
authorised to read — otherwise the assistant becomes a permission bypass.
_Avoid_: "the AI" as an actor that "does" anything to a record.

## Relationships

- A **Quality Record** has exactly one **Record Type**, one **Record Spine**, zero or more
  **Optional Block**s (fixed by its type), and zero or more **Action**s.
- A **Record Type** declares exactly one **State Model**, which satisfies the **State Contract**.
- An **Audit Received** or an **Audit Performed** holds zero or more **Finding**s; each
  **Finding** is itself a **Quality Record** linked to its parent audit by a **Record Link**.
  The parent type determines who owns the response — this organisation for an **Audit Received**,
  the auditee for an **Audit Performed**.
- A **Quality Event** routes to at most one other **Quality Record**, or closes with no action.
- Every **CAPA** holds exactly one **Origin Link**, to a **Deviation**, a **Quality Event** or a
  **Finding**. Those three are the only record types that can derive one.
- A **Deviation** or a **Quality Event** closes when every **Action** it holds is closed and every
  **CAPA** whose **Origin Link** to it is *pre-closure* has closed. A *post-closure* CAPA does not
  hold its source open.
- A **Change Control** closes when every **Action** it holds marked *pre-closure* is closed. A
  *post-closure* action continues after the change control has closed.
- A **CAPA** closes only after its **Effectiveness Check** passes, where a **QA Determination**
  required that check; a failed check returns it to planning. Where the determination waived the
  check, the CAPA closes on the signed justification instead.
- A **conditional** **Optional Block** is enabled or waived by exactly one **QA Determination**
  per **Quality Record**, signed, justified, and made at the step its **Record Type** declares.
- A **Change Control** is approved before implementation when its **Urgency** is normal, and
  ratified after it when it is emergency; when its **Duration** is temporary it also holds an
  expiry and a mandatory reversion **Action**.
- **Severity** on either type is recorded and reported and drives nothing: not the
  **Investigation** (a **QA Determination** decides), not the **Due Date**, not the signatory,
  not whether a **CAPA** is derived.
- The acceptance of a **Finding**'s response is signed by QA by default; QA may assign a
  different signatory on an individual finding, recorded in the audit trail.
- Every state transition is restricted by **Role**; the exit from `Draft` carries the **Opening
  Signature** of the user who opened the record, and every approval transition requires an
  electronic signature and honours the **Segregation Invariant**.
- The **AI Assistant** may write into a draft **Quality Record**; it may never execute a
  transition, apply a signature, or close a record.

## State models

One per **Record Type**, each satisfying the **State Contract**. `⊕` marks a transition
requiring an electronic signature. **Cancelled** is reachable from every non-terminal state in
every model and is not repeated below.

**Quality Event** — no **Optional Block**s.
`Draft → Registered → Assessed → Routed` (to a **Deviation**, a **Change Control** or a
**CAPA**) `| Closed – no action ⊕` (QA).

**Deviation** — declares **Impact Assessment** (required) and **Investigation** (conditional).
`Draft →` ⊕ (**Opening Signature**) `→ Registered → In triage ⊕` (QA sets **Severity**, records or
justifies the **Containment Action**, and makes the **QA Determination** on the **Investigation**)
`→ Under investigation` (when the determination required one) `| In actions` (when it waived one)
`→ Pending closure` (product and batch impact and disposition decided here) `→ Closed ⊕` (QA).
Where an **Investigation** was required, it is approved by the Process Owner ⊕ before actions begin.

**CAPA** — declares **Effectiveness Check** as **conditional**. Entered only by deriving from a
source record; an **Origin Link** is mandatory at creation.
`Draft → Plan proposed → Plan approved ⊕` (Process Owner) `→ In execution → Executed →`
**QA Determination** ⊕ (QA decides here whether an **Effectiveness Check** is required, and sets
its criterion and horizon when it is) `→ Effectiveness check in progress → Closed ⊕` (QA).
On a failed check QA either extends the horizon — the record stays in `Effectiveness check in
progress` — or closes it on a recorded justification: `→ Closed ⊕` (QA). When the determination
waives the check: `Executed →` **QA Determination** ⊕ `→ Closed ⊕` (QA).

**Change Control** — declares **Impact Assessment** and **Effectiveness Check** (as
post-implementation verification). Two paths, selected by **Urgency**.
Normal: `Draft → Proposed → Impact assessment → Approved ⊕` (Process Owner, before any
implementation) `→ In implementation → In verification → Closed ⊕` (QA).
Emergency: `Draft → Implemented with justification → Impact assessment → Ratified ⊕`
(retroactive signature, within a defined maximum period) `→ In verification → Closed ⊕` (QA).
When **Duration** is temporary, the record additionally carries an expiry date and a mandatory
reversion or conversion **Action** due before it.

**Audit Received** — no **Optional Block**s.
`Draft → Notified → In preparation → In execution → Report received → In response ⊕` (QA signs
the formal response) `→ In follow-up → Closed ⊕` (QA, only once every child **Finding** is closed).

**Audit Performed** — no **Optional Block**s.
`Draft → In annual programme → Planned → In execution → Report issued ⊕` (lead auditor)
`→ Commitment follow-up → Closed ⊕` (QA, only once every child **Finding** is closed).

**Finding** — declares **Investigation** as **conditional**.
`Draft → Open` (**Severity** set here, governing response deadline and signatory)
`→` **QA Determination** ⊕ (QA reads the initial content and explanations, and decides whether an
**Investigation** is required) `→ Under investigation` (when required) `→ Response proposed →
Response accepted ⊕ → Actions in progress → Closed ⊕` (QA). When the determination waives the
investigation, `Open →` **QA Determination** ⊕ `→ Response proposed`. Deriving a **CAPA** is the
responder's decision, never compelled by severity.

## Flagged ambiguities

- **"Audit" — one record type or two?** *Resolved 2026-07-31: two.* **Audit Received** and
  **Audit Performed** are separate record types, not one type with a direction attribute. They
  diverge more than they overlap — an audit received carries an authority and regulatory response
  deadlines, an audit performed carries an annual programme and a supplier. Cost accepted: two
  state models and two sets of test cases instead of one.

- **"Effectiveness Check" vs post-implementation verification.** *Resolved 2026-07-31: one
  block, reused.* A **CAPA**'s effectiveness check and a **Change Control**'s post-implementation
  verification are the same **Optional Block**; the criterion and the horizon differ per record,
  not per type.

- **Is an Optional Block declared per type, or decided per record?** *Resolved 2026-08-01: both,
  by declaration.* A **Record Type** declares each block **required** or **conditional**; a
  conditional block is enabled or waived per record by a signed, justified **QA Determination**.
  Two conditional blocks exist: **Finding**→**Investigation** and **CAPA**→**Effectiveness
  Check**. This replaces the earlier absolute rule that a block "is never partially used" — that
  rule survives only in the weaker form that a block is used in full or waived, never half-filled.
  Cost accepted: every conditional block doubles the paths its **Record Type** needs verified in
  OQ, and a waived **Effectiveness Check** on a CAPA is an exposed surface in an inspection —
  which is why the waiver is a signed act with a justification, not a checkbox.

- **"Process" vs "Record Type".** `IDEA.md` speaks of six *quality processes*; this glossary
  speaks of seven *record types* (the seventh being **Finding**, promoted to a record of its own
  when audits became containers). The process count and the record-type count are not the same
  number and should not be reconciled by force.

- **Is a CAPA a record or an action?** Raised by Juan 2026-07-31: *"las CAPAs deben ser acciones
  derivadas de desviaciones, eventos de calidad y auditorías, no son un item independiente."*
  *Resolved 2026-07-31:* a CAPA remains a **Record Type** — it needs a plan, an approval
  signature and an **Effectiveness Check**, which an **Action** does not carry — but it cannot be
  created standalone. Its only entry point is deriving it from a **Deviation**, a **Quality
  Event** or a **Finding**, recorded as an **Origin Link**.
