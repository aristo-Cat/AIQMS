---
title: "ADR — Architecture Decision Records for AI-QMS — AI-first electronic Quality Management System"
type: instance
based_on_template: "ADR"
based_on_template_version: "0.1.0"
project_id: "AIQMS-2026-001"
system_id: "AIQMS-2026-001"
traces_to: "specs/URS.md (v0.1, draft)"
status: draft
version: "0.3"
created: "2026-08-02"
updated: "2026-08-02"
language: "en"
decision_date: "2026-08-02"
---

# ADR — Architecture Decision Records

## 0. Identification and signatures

### System

| Field | Value |
|---|---|
| **System name** | AI-QMS — AI-first electronic Quality Management System |
| **System identifier** | `AIQMS-2026-001` |
| **URS impacted** | `URS-EREC-005`, `URS-EREC-013`, `URS-DATA-003`, `URS-DATA-004`, `URS-FUNC-008`, `URS-FUNC-009`, `URS-FUNC-010`, `URS-FUNC-011`, `URS-FUNC-012`, `URS-FUNC-057`, `URS-UI-005` |
| **FS entries impacted** | *(FS not yet authored — this ADR precedes it and will constrain it)* |

### Signatures

> [!warning] Fictional reviewers and approvers
> This system is a public demonstration artifact with no operating organisation behind it. The
> Author is real; the reviewer and approver entries are **fictional placeholders**, using the same
> non-name convention as `specs/URS.md` and `specs/RA-INIT.md`. The document is `status: draft`.

| Role | Name | Department | Date | Signature |
|---|---|---|---|---|
| Author | Juan Miguel Saavedra | Quality Assurance / Computerised System Validation | 2026-08-02 |  |
| Reviewer 1 (System Owner / Lead Developer) | `FICTIONAL-APPROVER-1` | Information Technology | — |  |
| Reviewer 2 (SME / Architect) | `FICTIONAL-REVIEWER-2` | Manufacturing / Engineering | — |  |
| Approver (Quality Unit) *(required for GxP-impacting decisions)* | `FICTIONAL-APPROVER-2` | Quality Assurance | — |  |

---

## 1. Introduction

This document records Architecture Decision Records for **AI-QMS** (`AIQMS-2026-001`). Each ADR
captures one significant design decision with its context, the options weighed, the outcome chosen
and its consequences, so the rationale is preserved and auditable. GAMP 5 §D3 requires design
decisions to be documented and traceable to the requirements they realise; §M8 governs the record
kept when an accepted decision is later reversed.

An ADR is recorded here only when the decision is **all three of** hard to revert, surprising
without context, and a real trade-off with a genuine alternative given up. Decisions failing any of
those three are recorded in the work item's `SELECTED-DIRECTION.md`, not here — the gate exists to
prevent ADR sprawl.

---

## 2. Definitions and abbreviations

| Term | Definition |
|---|---|
| ADR | Architecture Decision Record |
| `ADR-<CATEGORY>-NNN` | Unique identifier: category code plus 3-digit sequence |
| Proposed | Under evaluation — no implementation may proceed on its scope |
| Accepted | Final — implementation may proceed |
| Superseded | Reversed or replaced by a later ADR; retained for audit continuity |

---

## 3. ADR category codes

IDs follow `ADR-<CATEGORY>-NNN` using the canonical category codes of
`docs/requirement-id-scheme.md`, scoped to the design area the decision affects.

---

## 4. ADR log (index)

| ADR-ID | Title (summary) | Status | Decision date | Relates to (URS/FS-IDs) |
|---|---|---|---|---|
| `ADR-EREC-001` | Audit trail written by database trigger, attributed through an application-set session context | **accepted** | 2026-08-02 | `URS-EREC-005`, `URS-DATA-004`, `URS-FUNC-009`, `URS-EREC-013` |
| `ADR-DATA-001` | Writes to GxP tables only through `SECURITY DEFINER` functions; direct DML revoked from the application role | **accepted** | 2026-08-02 | `URS-DATA-004`, `URS-FUNC-008`, `URS-FUNC-010`, `URS-FUNC-011`, `URS-FUNC-012`, `URS-FUNC-057` |
| `ADR-DATA-002` | Every recorded instant carries its originating time zone in an adjacent column | **accepted** | 2026-08-02 | `URS-DATA-003`, `URS-EREC-005`, `URS-EREC-013`, `URS-UI-005` |
| `ADR-ESIG-001` | A failed signature attempt returns a typed failure instead of raising, so its security record survives | **accepted** | 2026-08-02 | `URS-ESIG-012`, `URS-ESIG-014`, `URS-FUNC-011`, `URS-DATA-004` |

---

## 5. Architecture Decision Records

### `ADR-EREC-001` — Audit trail written by database trigger, attributed through an application-set session context

**Status:** `accepted`
**Decision date:** 2026-08-02
**Relates to:** `URS-EREC-005`, `URS-DATA-004`, `URS-FUNC-009`, `URS-DATA-003`, `URS-EREC-013`

> [!tip] Status: ACCEPTED — decision is final; implementation may proceed. Implementation must comply with the Decision Outcome and Consequences below.

#### 5.1.1 Context

AI-QMS holds the primary electronic GxP record of six quality processes. Two requirements bear on
where its audit trail is written, and they pull in opposite directions.

`URS-DATA-004` requires that no stored value of a Quality Record be modifiable except through a
function that writes the change to the audit trail, and that direct modification outside the
application be prevented and, where technically possible, **detectable**. Detectability is the
operative word: an audit trail that only the application writes is blind by construction to any
write that does not go through the application. `RA-INIT-018` rates that failure mode at Risk
Priority H, with Detectability L — nothing in the system reveals it.

`URS-EREC-005`, a preset row copied verbatim from 21 CFR Part 11 §11.10.e, requires each audit
trail entry to carry the user, the old value, the new value, a timestamp with timezone, and a
**reason for change prompted to the user**. The reason for change is application knowledge. It
exists in the user's session, not in the row being written, and a database trigger cannot infer it.

Neither layer alone satisfies both requirements. The persistence model this decision sits inside is
a shared `quality_record` spine table with per-type detail tables, selected in
`work/WI-001/SELECTED-DIRECTION.md`, running on PostgreSQL through Supabase (`URS-DEVENV-002`).

#### 5.1.2 Decision drivers

| Driver | Type | Weight (H/M/L) |
|---|---|---|
| Detectability of a write that bypasses the application (`URS-DATA-004`) | Regulatory | H |
| Reason for change captured on every entry (`URS-EREC-005`) | Regulatory | H |
| Attributability of every recorded change — the *A* of ALCOA+ (`URS-EREC-013`) | Regulatory | H |
| Number of mechanisms and test harnesses to keep in step | Operational | M |
| Implementation in one language rather than two | Organizational | L |

#### 5.1.3 Considered options

##### Option A — Application layer writes the audit trail

Python writes the audit trail row inside the same transaction as the change, with the reason for
change already in hand.

| Pros | Cons |
|---|---|
| One mechanism, one language, one test harness | A write that bypasses the application leaves no trace at all |
| Reason for change trivially available | `URS-DATA-004` would rest on database credential restriction — a control in the environment, not in the system |
| Simplest to validate in isolation | An inspector reads the weaker control first |

##### Option B — Database triggers only

An `AFTER INSERT OR UPDATE` trigger on every table in GxP scope writes the audit trail row.

| Pros | Cons |
|---|---|
| Fires on any write, including direct SQL — satisfies `URS-DATA-004` literally | Cannot supply the reason for change, leaving `URS-EREC-005` uncovered |
| Cannot be forgotten by application code | Cannot attribute the change to a user without application context |

##### Option C — Trigger authoritative, attributed through an application-set session context *(recommended)*

The trigger writes the row-level facts. The application sets transaction-scoped settings —
`aiqms.actor_id` and `aiqms.reason` — before any write, and the trigger reads them. A write
arriving with no attributable actor is rejected.

| Pros | Cons |
|---|---|
| Satisfies `URS-DATA-004` and `URS-EREC-005` together, which neither A nor B does alone | Two mechanisms that must be kept in step |
| The audit trail cannot be forgotten by application code | The handshake is itself a validated mechanism needing its own tests, including the negative case |
| Direct SQL writes are either attributed or refused — never silent | Trigger logic is SQL under migration control, with a test harness separate from the Python suite |

##### Option D — Do nothing distinct: rely on Supabase platform logging

Use the hosting platform's own logging rather than a system audit trail.

| Pros | Cons |
|---|---|
| No implementation cost | Platform logs are not a Part 11 audit trail: no old/new value, no reason for change, no retention under `URS-ARCH-001`, and not under this system's change control |
| — | Fails `URS-EREC-005` and `URS-FUNC-009` outright |

#### Comparison matrix

| Criterion | Option A | Option B | Option C | Option D |
|---|---|---|---|---|
| Detectability of bypassing writes (`DATA-004`) | Low | High | **High** | Low |
| Reason for change (`EREC-005`) | High | None | **High** | None |
| Attributability (`EREC-013`) | High | Low | **High** | Low |
| Mechanisms to keep in step | High | High | Medium | High |
| **Overall fit** | **Medium** | **Low** | **High** | **Unacceptable** |

#### 5.1.4 Decision outcome

**Chosen option: Option C — trigger authoritative, attributed through an application-set session
context.**

It is the only option that satisfies `URS-DATA-004` and `URS-EREC-005` simultaneously. Option A
leaves the highest-priority data-integrity risk in the register (`RA-INIT-018`) without a control
inside the system; Option B leaves a verbatim Part 11 preset requirement uncovered; Option D is not
an audit trail in the regulatory sense.

Two implementation constraints are part of this decision and are not left to the implementer:

1. **A write arriving with no attributable actor is rejected, not recorded as unattributed.** A GxP
   change with no attributable author fails the *Attributable* attribute of ALCOA+
   (`URS-EREC-013`), and writing it as "unattributed" would manufacture a legitimate-looking hole
   in the record. This is a single `RAISE EXCEPTION` and is reversible in one line if the position
   is ever revisited — the reversal would itself be an ADR under §M8.
2. **Timestamps are written by the database, not by an application clock**, so that entries from
   different application instances remain comparable and contemporaneous.

   > [!warning] Correction, 2026-08-02 — the original wording of this constraint was factually wrong
   > This clause first read *"written by the database with their timezone preserved
   > (`URS-DATA-003`)"*. That is false: a PostgreSQL `timestamptz` stores a UTC instant and
   > **discards** the input offset, rendering on output in the reader's session time zone. It
   > guarantees an unambiguous *instant*, which is not the same as preserving *the time zone the
   > event occurred in*, and `URS-DATA-003` requires the latter — *"record and preserve the timezone
   > of every timestamp"*.
   >
   > `URS-DATA-003` is therefore **not satisfied by the column type alone**. Preserving it requires
   > carrying the originating zone explicitly beside every recorded instant. The mechanism is
   > specified in `ADR-DATA-002` below rather than here, because it applies to every timestamp in
   > the system and not only to the audit trail. Found by independent review of `WI-001` before any
   > code was written; the decision this ADR takes is unaffected, only the justification was wrong.

#### 5.1.5 Consequences

##### Positive

- `URS-DATA-004`'s *detectable* is literally true: a direct `UPDATE` issued outside the application
  either lands in the audit trail with its actor, or is refused.
- The audit trail cannot be forgotten by application code, which removes the most common way
  `URS-FUNC-009`'s enumerated scope goes incomplete — the failure mode of `RA-INIT-001`, the
  highest-probability entry in the initial risk register.
- The audit trail exists at the same level as the data it describes, so it survives a refactor of
  the application layer without re-validation of the trail itself.

##### Negative / trade-offs

- Two implementation languages and two test harnesses for one requirement area. `URS-QUAL-002`'s
  100% coverage of signature and transition paths must account for both.
- Every table entering GxP scope must have its trigger added; a new table without one is a silent
  gap. This becomes a checklist item in the Design Specification and a verification step in IQ.
- Application code must set the session context on every transaction that writes. Forgetting it
  produces a hard failure rather than a silent one, which is the intended behaviour but will
  surface as rejected writes during development.

##### Risks

| Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|
| A new table enters GxP scope without its audit trigger | M | H | Trigger creation is part of the migration template; a schema test asserts that every table in GxP scope carries the trigger |
| The session-context handshake is bypassed by a connection pooler reusing a session across requests | M | H | Settings are set with the transaction-local flag so they never outlive their transaction; a test asserts the setting is absent at the start of a fresh transaction |
| Trigger logic diverges from application expectations after a schema change | M | M | Trigger logic under the same versioned migration control as the schema (`URS-DEVENV-002`); negative tests for the unattributed-write rejection |

#### 5.1.6 Relates to

| Reference type | ID | Description |
|---|---|---|
| URS requirement constrained | `URS-EREC-005` | Secure, computer-generated, time-stamped audit trail with old value, new value, user and reason for change |
| URS requirement constrained | `URS-DATA-004` | No stored value modifiable except through a function that writes the audit trail; direct modification prevented and detectable |
| URS requirement constrained | `URS-FUNC-009` | The system-specific enumeration of what the audit trail covers |
| URS requirement constrained | `URS-DATA-003` | Timezone of every timestamp recorded and preserved |
| URS requirement constrained | `URS-EREC-013` | ALCOA+ — specifically the *Attributable* attribute |
| Risk assessed | `RA-INIT-001`, `RA-INIT-018` | Both at Risk Priority H; this decision is their initial control |
| Work item | `WI-001` | Selected in `work/WI-001/SELECTED-DIRECTION.md` |

---

### `ADR-DATA-001` — Writes to GxP tables only through `SECURITY DEFINER` functions; direct DML revoked from the application role

**Status:** `accepted`
**Decision date:** 2026-08-02
**Relates to:** `URS-DATA-004`, `URS-FUNC-010`, `URS-FUNC-011`, `URS-FUNC-012`, `URS-FUNC-057`, `URS-FUNC-008`

> [!tip] Status: ACCEPTED — decision is final; implementation may proceed. Implementation must comply with the Decision Outcome and Consequences below.

#### 5.2.1 Context

`ADR-EREC-001` established that a database trigger writes the audit trail and that a write with no
attributable actor is refused. An independent review of `WI-001` found that this satisfies only
half of `URS-DATA-004`. The requirement reads: *"Direct modification of stored data outside the
application shall be **prevented** and, where technically possible in the qualified environment,
**detectable**."* Prevention is the primary obligation; detectability is the qualified secondary.

Under `ADR-EREC-001` alone, an operator holding the application's database credentials can issue
`UPDATE quality_record SET state = 'Closed'` with the session context set. The write is attributed,
audit-trailed and **accepted** — bypassing the State Model (`URS-FUNC-010`), the signature
requirement (`URS-FUNC-011`) and the Segregation Invariant (`URS-FUNC-012`), all three of which
`URS-FUNC-057` declares are enforced in code and not configurable away by any role. A control that
records its own circumvention is a detective control, not the preventive one the requirement asks
for first, and `RA-INIT-018` sits at Risk Priority H against exactly this path.

#### 5.2.2 Decision drivers

| Driver | Type | Weight (H/M/L) |
|---|---|---|
| Direct modification **prevented**, not merely recorded (`URS-DATA-004`) | Regulatory | H |
| The four invariants enforced below the application, where no role can disable them (`URS-FUNC-057`) | Regulatory | H |
| No delete path reachable by any role (`URS-FUNC-008`) | Regulatory | H |
| Amount of logic living in SQL, and its test burden | Operational | M |

#### 5.2.3 Considered options

##### Option A — Keep `ADR-EREC-001` as-is; prevention rests on credential restriction

The environment restricts who holds database credentials; the system itself prevents nothing.

| Pros | Cons |
|---|---|
| No further work; `URS-DATA-004`'s "where technically possible" arguably tolerates it | The control lives in the environment, not the system, so it is out of scope of this system's validation |
| Keeps all logic in one language | Leaves `RA-INIT-018` without any control inside the system, and leaves `URS-FUNC-057`'s "enforced in code" resting on application code an operator can go around |

##### Option B — Row Level Security policies

RLS policies restrict which rows and columns the application role may update.

| Pros | Cons |
|---|---|
| Native to the platform, less code than functions | RLS filters rows; it cannot express *"this transition is declared in the State Model, carries the required signature, and the actor is not the opening signer"* |
| Composes with the existing trigger | Solves part of the finding and leaves the State Model bypass open |

##### Option C — All writes through `SECURITY DEFINER` functions; direct DML revoked *(recommended)*

`INSERT`, `UPDATE` and `DELETE` are revoked from the application role on every table in GxP scope.
The application may only call a small set of database functions — create a record, change a field,
execute a transition, apply a signature, cancel — which validate the State Model, the Role, the
signature requirement and the invariants before writing. The `ADR-EREC-001` trigger continues to
write the audit trail beneath them.

| Pros | Cons |
|---|---|
| A direct `UPDATE` is not possible rather than merely visible — `URS-DATA-004` satisfied on its primary limb | Meaningful logic moves into SQL, in two languages for one behaviour |
| The invariants sit below the application, which is what `URS-FUNC-057` actually claims | The Slice 5 SQL test harness stops being optional; `URS-QUAL-002` coverage must report both languages honestly |
| `DELETE` revoked outright makes `URS-FUNC-008` structural rather than a matter of not building the endpoint | A new table entering GxP scope without its revoke and its functions is a silent gap |

#### Comparison matrix

| Criterion | Option A | Option B | Option C |
|---|---|---|---|
| Direct modification prevented (`DATA-004`) | Low | Medium | **High** |
| Invariants enforced below the application (`FUNC-057`) | Low | Low | **High** |
| No delete path (`FUNC-008`) | Low | Medium | **High** |
| SQL logic and test burden | Low | Medium | High |
| **Overall fit** | **Low** | **Medium** | **High** |

#### 5.2.4 Decision outcome

**Chosen option: Option C — all writes to GxP tables through `SECURITY DEFINER` functions, with
`INSERT`, `UPDATE` and `DELETE` revoked from the application role.**

It is the only option under which `URS-DATA-004`'s *prevented* is true of the system rather than of
its environment, and the only one under which `URS-FUNC-057`'s "enforced in code and not
configurable away" describes something an operator with database access cannot step around. This
extends `ADR-EREC-001` rather than reversing it: the trigger and the session-context handshake
remain exactly as accepted, and now sit beneath a write path that is itself closed.

#### 5.2.5 Consequences

##### Positive

- `URS-DATA-004`, `URS-FUNC-008`, `URS-FUNC-010`, `URS-FUNC-011` and `URS-FUNC-012` gain an
  enforcement point that survives any defect or bypass in the application layer.
- `RA-INIT-018` acquires a preventive initial control; its Detectability rating stops being the
  only thing standing between the system and an unrecorded change.

##### Negative / trade-offs

- Two languages implement one behaviour. Every transition rule exists in the State Model
  declaration *and* in the function that enforces it; keeping them in step is a review criterion.
- The application can no longer be tested against a plain table; the test harness needs a real
  PostgreSQL with the functions and grants installed. This is Slice 5's question, now mandatory.

##### Risks

| Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|
| A new GxP table is added without its revokes and functions | M | H | A schema test asserts that no application role holds `INSERT`/`UPDATE`/`DELETE` on any table in GxP scope; the test fails the build, not a review |
| Function logic drifts from the Python State Model declaration | M | H | The declaration is the single source; the functions are generated from or verified against it, and a test asserts every declared transition has a matching function and no function exists for an undeclared one |
| `SECURITY DEFINER` functions widen privilege if their search path is not pinned | M | H | Every function pins `search_path`; a schema test asserts it |

#### 5.2.6 Relates to

| Reference type | ID | Description |
|---|---|---|
| URS requirement constrained | `URS-DATA-004` | Direct modification prevented and detectable |
| URS requirement constrained | `URS-FUNC-057` | The four invariants enforced in code, not configurable away |
| URS requirement constrained | `URS-FUNC-008`, `URS-FUNC-010`, `URS-FUNC-011`, `URS-FUNC-012` | No delete path; role-restricted transitions; signature required; segregation |
| Risk assessed | `RA-INIT-018`, `RA-INIT-006` | Both Priority H; this decision is their preventive control |
| Extends | `ADR-EREC-001` | The audit trail trigger and session context are unchanged and sit beneath this write path |

---

### `ADR-DATA-002` — Every recorded instant carries its originating time zone in an adjacent column

**Status:** `accepted`
**Decision date:** 2026-08-02
**Relates to:** `URS-DATA-003`, `URS-EREC-005`, `URS-EREC-013`, `URS-UI-005`

> [!tip] Status: ACCEPTED — decision is final; implementation may proceed.

#### 5.3.1 Context

`URS-DATA-003` requires the system to *"record and preserve the timezone of every timestamp, and
present timestamps unambiguously in printouts and on screen"*, supporting the *Contemporaneous*
attribute of `URS-EREC-013`.

A PostgreSQL `timestamptz` does **not** do this. It converts its input to a UTC instant, discards
the offset, and renders on output in whatever time zone the reading session is set to. It therefore
guarantees an unambiguous *instant* but says nothing about *where the event happened*. Two
signatures applied at the same wall-clock hour in two sites are indistinguishable after storage,
and a printout produced in a third zone shows neither original local time. This was asserted
incorrectly in the first version of `ADR-EREC-001` §5.1.4 and corrected there.

The system is single-tenant but not single-site: `URS-UI-002` states record content is entered in
the language its author writes, and nothing in the URS confines users to one time zone.

#### 5.3.2 Decision drivers

| Driver | Type | Weight (H/M/L) |
|---|---|---|
| Time zone of the event recorded and preserved (`URS-DATA-003`) | Regulatory | H |
| Unambiguous presentation in printouts (`URS-UI-005`, `URS-EREC-002`) | Regulatory | H |
| Instants remain comparable and sortable across sites | Operational | M |

#### 5.3.3 Considered options

##### Option A — Do nothing; rely on `timestamptz`

| Pros | Cons |
|---|---|
| No work | `URS-DATA-003` is simply not met; the requirement asks for the zone and the column does not hold it |

##### Option B — Store local time in a naive `timestamp` plus the zone name

| Pros | Cons |
|---|---|
| Local time is directly readable | Loses the guaranteed instant; comparing and ordering across zones becomes application arithmetic, and arithmetic on a naive timestamp is where date bugs live |

##### Option C — `timestamptz` plus an adjacent zone column *(recommended)*

Every recorded instant is stored as `timestamptz` — preserving the unambiguous instant — beside a
`text` column holding the IANA zone identifier in force for the acting user at the moment of the
event (for example `Europe/Madrid`). Local time is derived from the pair when needed.

| Pros | Cons |
|---|---|
| The instant stays exact and sortable; the zone is preserved as the requirement asks | One extra column beside every recorded instant, and the pair must be written together or not at all |
| A printout can show both the local time of the event and its UTC instant, which is what makes it unambiguous | The zone must be captured from the acting user's context, so it joins the session-context handshake of `ADR-EREC-001` |

#### 5.3.4 Decision outcome

**Chosen option: Option C — `timestamptz` plus an adjacent IANA zone column, written together.**

It is the only option that satisfies `URS-DATA-003` literally while keeping the ordering guarantee
that a UTC instant provides. The zone identifier travels with the actor through the same
transaction-scoped session context that `ADR-EREC-001` already establishes, as a third setting
alongside `aiqms.actor_id` and `aiqms.reason`; a write with an actor but no zone is refused on the
same grounds and by the same mechanism.

#### 5.3.5 Consequences

##### Positive

- `URS-DATA-003` is met by the stored data rather than by a claim about a column type.
- The human-readable printout of `URS-UI-005` can state the local time of an act and its instant,
  which is what makes a signature time unambiguous to a reader in another country.

##### Negative / trade-offs

- Every table carrying a recorded instant grows a column, and every write path must supply it.
- IANA zone identifiers change over time as political boundaries and rules change; a stored
  identifier is a reference to a database that itself has versions.

##### Risks

| Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|
| A write supplies the instant but not the zone, leaving the pair incomplete | M | M | The zone travels in the session context and its absence refuses the write, exactly as a missing actor does; a negative test asserts it |
| A zone identifier is stored that the runtime's time zone database does not know | L | M | The zone is validated on write against the database's own zone catalogue rather than accepted as free text |

#### 5.3.6 Relates to

| Reference type | ID | Description |
|---|---|---|
| URS requirement constrained | `URS-DATA-003` | Record and preserve the timezone of every timestamp |
| URS requirement constrained | `URS-EREC-005` | Audit trail entries carry date and time with timezone |
| URS requirement constrained | `URS-EREC-013` | ALCOA+ — the *Contemporaneous* attribute |
| URS requirement constrained | `URS-UI-005` | Human-readable printout with signature date and time |
| Corrects | `ADR-EREC-001` §5.1.4 | Replaces the incorrect claim that `timestamptz` preserves a time zone |

---

### `ADR-ESIG-001` — A failed signature attempt returns a typed failure instead of raising, so its security record survives

**Status:** `accepted`
**Decision date:** 2026-08-02
**Relates to:** `URS-ESIG-012`, `URS-ESIG-014`, `URS-FUNC-011`, `URS-DATA-004`

> [!tip] Status: ACCEPTED — decision is final; implementation may proceed.

#### 5.4.1 Context

`URS-ESIG-012` requires failed signature attempts to be **recorded**. Under Direction A
(`work/WI-001/RESEARCH-SLICES.md` §3) this system owns the signature credential, so the failure is
this system's to record — nothing upstream sees it. `work/WI-001/THIN-SPECS.md` gives it a
`security_event` table, and the independent review's finding 5 had already observed that the attempt
would otherwise be invisible by construction.

Implementing it surfaced what neither anticipated. `ADR-DATA-001` puts signature verification inside
`apply_signature`, a `SECURITY DEFINER` function. The natural implementation writes the
`security_event` row and then raises, so the caller sees a failure. **PostgreSQL rolls that row back
with the rest of the transaction.** The record of the failure destroys itself, and
`URS-ESIG-012` is satisfied in the source and unsatisfied in the database — the worst combination,
because a reviewer reading the code would see the requirement met.

This is not a coding slip that a careful implementer avoids. Every in-transaction way of recording
the failure has the same fate, because a transaction is atomic by definition. The requirement and
the exception contract are in direct conflict.

#### 5.4.2 Decision

**`apply_signature` does not raise on a failed verification.** It writes the `security_event` row,
returns a typed failure, and `execute_transition` — seeing that failure — performs no state change
and returns the failure to the caller. **The transaction commits**: the security event is durable,
the quality record is untouched, and the audit trail correctly shows that nothing changed.

Raising is reserved for conditions that are genuine faults rather than expected outcomes — an
unknown record, an undeclared transition, a missing session context. A wrong password is an expected
outcome of a control working correctly, and it is the one outcome that must leave a trace.

#### 5.4.3 Alternatives considered

| Alternative | Why rejected |
|---|---|
| **`dblink` as an autonomous transaction** — write the event through a self-connection that commits independently | Genuinely works, and `dblink` is available on this platform. Rejected because it requires a foreign server and a user mapping holding a **database password in the catalogue**, to make durable a record the database could already have made durable by not throwing it away. It also adds an extension and a stored credential as configuration items under `URS-QUAL-004`, both inside the control that protects electronic signatures |
| **The application writes the event in a separate transaction after catching the error** | Puts the durability of a security record back into the application. If the process dies between the failure and the write, the failed attempt is invisible — and `ADR-DATA-001` exists precisely because controls that depend on the application being well-behaved are not controls |
| **Savepoints** | Do not help at all. A savepoint rolls back *within* a transaction; it cannot commit independently of it |

#### 5.4.4 Consequences

**Positive.** The control stays wholly inside the database, where `ADR-DATA-001` put it. No new
extension, no stored credential, no dependency on caller behaviour for the durability of a security
record. The benign-failure property is the strongest argument: a caller that ignores the returned
value still causes **no state change**, because the transition simply did not happen.

**Negative, and the trade-off given up.** The ordinary exception contract. A caller cannot assume
"no exception means it worked" for the signature path, and that assumption is so common that it is
the likely source of a future defect. Two things contain it: the return type is a composite that
cannot be silently coerced to a boolean success, and `URS-TEST-004`'s negative suite carries a test
asserting that a wrong password leaves the record in its prior state **and** writes exactly one
`security_event` row.

**On lockout.** This ADR decides how a failed attempt is *recorded*, not what happens after
repeated failures. Any lockout or escalation reads `security_event`, which this decision is what
makes possible.

**Residual.** `URS-ESIG-012`'s other limb — *"results reported periodically to management"* — still
has no owner, as `work/WI-001/THIN-SPECS.md` § Open items records. This ADR does not close it, and
it needs a URS amendment rather than an invention here.

---

## 6. Related documents

| Document | Reference |
|---|---|
| User Requirements Specification | `specs/URS.md` (v0.1, draft) |
| Initial Risk Assessment | `specs/RA-INIT.md` (v0.1, draft) |
| Functional Specification | `specs/FS.md` *(planned — this ADR constrains it)* |
| Design Specification | `specs/DS.md` *(planned — accepted ADRs must be cited where they constrain design)* |
| Requirements Traceability Matrix | `specs/RTM.md` *(derived)* |
| Selected direction for WI-001 | `work/WI-001/SELECTED-DIRECTION.md` |

---

## 7. Revision history

| Version | Date | Reason for revision / Author |
|---|---|---|
| 0.1 | 2026-08-02 | Initial issue — `ADR-EREC-001` accepted. Juan Miguel Saavedra, Quality Assurance / Computerised System Validation |
| 0.3 | 2026-08-02 | `ADR-ESIG-001` accepted. Found while implementing `apply_signature`, not while designing it: `URS-ESIG-012` requires a failed signature attempt to be recorded, but a `security_event` row written before a `RAISE` is rolled back with the transaction, so the record of the failure destroys itself. The requirement would have read as satisfied in the source and been unsatisfied in the database. Decision selected by Juan Miguel Saavedra from three alternatives. Juan Miguel Saavedra |
| 0.2 | 2026-08-02 | Independent review of `WI-001` (`work/WI-001/RESEARCH-REVIEW.md`) returned `changes required`. Three consequences, all before any code was written: (1) `ADR-EREC-001` §5.1.4 carried a factually incorrect claim that a PostgreSQL `timestamptz` preserves a time zone — corrected in place, with the mechanism that does satisfy `URS-DATA-003` moved to `ADR-DATA-002`. The decision `ADR-EREC-001` takes is unchanged; only its justification was wrong. (2) `ADR-DATA-001` added: `URS-DATA-004` requires direct modification to be *prevented*, and the trigger of `ADR-EREC-001` only makes it *detectable*. (3) `ADR-DATA-002` added. Juan Miguel Saavedra |
