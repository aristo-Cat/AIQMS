---
type: design-options
work_item: WI-001
status: draft
created: "2026-08-02"
---

# DESIGN-OPTIONS — WI-001

**Slice**: Record Spine and Deviation — create, open with the Opening Signature, QA Triage,
Segregation Invariant, audit trail.

**Why this slice first**: the Record Spine is reused verbatim by all seven Record Types, and the
Deviation is the record type that exercises every spine behaviour the other six need — an approval
transition with a signature, a conditional Optional Block gated by a QA Determination, a closure
gate over committed work, and the Segregation Invariant. Nothing built here is thrown away when
the remaining six types arrive. It is also the highest-risk cluster of the initial risk assessment:
`RA-INIT-001`, `006`, `007`, `008` and `009` all land in this slice, all at Risk Priority H.

## Constraints that are already fixed (not open for design)

These come from the approved-in-draft URS and bound every option below.

| Constraint | Source |
|---|---|
| Python on the server, TypeScript on the client | `URS-DEVENV-001` |
| PostgreSQL through Supabase; schema under version control as ordered, repeatable migrations | `URS-DEVENV-002` |
| Record identifier unique, never reused, not modifiable by any user or role | `URS-FUNC-002` |
| No delete function exposed to any role, including the Administrator; Cancellation is the only exit | `URS-FUNC-008`, `URS-FUNC-057` |
| Audit trail captures user, old value, new value, timestamp with timezone, and a prompted reason for change, at the time of the event | `URS-EREC-005`, `URS-DATA-003` |
| Audit trail scope: creation, every Record Spine and Optional Block field change, every State transition, every signature, every Action created/reassigned/closed, every Record Link, and Cancellation | `URS-FUNC-009` |
| Direct modification of stored data outside the application prevented and, where technically possible, **detectable** | `URS-DATA-004` |
| Signature securely linked to its record; a signed record cannot be modified, or modification makes it appear unsigned | `URS-ESIG-003`, `URS-ESIG-017` |
| 100% test coverage of the four invariants, every signature step and every State transition; negative testing mandatory for all three | `URS-QUAL-002`, `URS-TEST-004` |

## Decision 1 — how the Record Spine and the seven Record Types are persisted

### Option A — Shared spine table + per-type detail tables

One `quality_record` table carrying the whole Record Spine with a `record_type` discriminator, and
one detail table per Record Type (`deviation`, `capa`, …) joined 1:1. Shared child tables for
`record_action`, `record_link`, `signature`, `audit_trail`. The State Model is declared as data in
Python — states, permitted transitions, the Role each transition requires, whether it requires a
signature, and which invariants apply — one declaration per Record Type over a single engine.

- **Trade-off**: the spine invariants are written once and hold for all seven types by
  construction, which is exactly where the initial risk assessment put the probability (`RA-INIT-007`,
  `008`: Probability H, justified by "invariants holding across seven State Models"). The cost is a
  join on every read and a migration per new Record Type.
- **Risk**: the discriminator invites per-type conditionals leaking into spine code. Mitigated by
  keeping every type-specific rule inside its State Model declaration, never in the engine.
- **Test implication**: one invariant test suite parameterised over Record Types, plus one state
  transition suite per type. The 100% coverage requirement of `URS-QUAL-002` is reachable because
  the enforcement points are few and shared.

### Option B — Shared spine table + per-type fields in JSONB

One `quality_record` table; everything type-specific lives in a JSONB payload column. No per-type
tables and no migration when a Record Type gains a field.

- **Trade-off**: fastest path to a running Deviation, and the schema never churns. The cost is that
  a JSONB field cannot carry `NOT NULL`, a foreign key or a check constraint, so *"reject the
  creation until every mandatory minimum field is complete"* (`URS-FUNC-001`) and the mandatory
  Origin Link of a CAPA become application-only rules with nothing underneath them.
- **Risk**: the Design Specification and the Database Specification have no schema to show. An
  inspector asking "how does the system guarantee this field is present" gets an answer that lives
  in Python and can be bypassed by any direct write — which weakens `URS-DATA-004` precisely where
  `RA-INIT-018` rated it H.
- **Test implication**: every mandatory-field rule needs its own application test because the
  database asserts nothing. Coverage is achievable but the evidence is weaker: a passing test proves
  the application path, not the invariant.

### Option C — One full table per Record Type, spine columns repeated

Seven independent tables, each carrying its own copy of the spine columns plus its type-specific
ones. Shared behaviour lives in a Python base class.

- **Trade-off**: the strongest per-type database constraints — every column typed, every foreign
  key real, no discriminator and no join. The cost is that the spine is duplicated seven times in
  the schema, and every spine change is a seven-table migration.
- **Risk**: the four invariants must be applied at seven independent enforcement points. This is
  the concrete form of the failure mode `RA-INIT-006`/`007`/`008` describe, and it multiplies the
  surface where one type silently misses a check. Inheritance in the application layer helps only
  as long as nobody writes a query that bypasses it.
- **Test implication**: the invariant suite must be executed against all seven tables independently
  — no parameterised shortcut is honest here, because the point is that the seven paths are
  genuinely separate. Highest test cost of the four options.

### Option D — Event-sourced spine, current state as a projection

An append-only event log is the source of truth; the current state of every Quality Record is a
projection rebuilt from it.

- **Trade-off**: the audit trail stops being a side-table that the application must remember to
  write, and becomes the system itself. Tamper-evidence (`URS-ESIG-017`) and the ALCOA+ *Original*
  and *Enduring* attributes follow from the design rather than from discipline, and `RA-INIT-001`
  — the highest-probability risk in the register — largely disappears as a failure mode.
- **Risk**: it moves the risk rather than removing it. A projection defect becomes a data-integrity
  defect that presents as correct data, which is the lowest-detectability failure class in §3.4 of
  the RA-INIT. Reporting (`URS-FUNC-014`) and search (`URS-FUNC-007`) need read models built and
  validated separately. For a Cat 5 system this raises Probability across the board, not lowers it.
- **Test implication**: every projection needs its own verification against the event log, and the
  OQ has to demonstrate that a rebuilt projection equals the live one. Materially the largest
  validation surface of the four, on the first slice of a system with no code yet.

## Decision 2 — where the audit trail is written (orthogonal to Decision 1)

### Option T1 — PostgreSQL triggers on every table in GxP scope

- Fires on any write, including one made outside the application. This is the only option that
  makes `URS-DATA-004`'s *"detectable"* literally true and directly answers `RA-INIT-018`.
- Cost: the *reason for change* required by `URS-EREC-005` is application knowledge, not row
  knowledge, so it must reach the trigger through a session-scoped variable set by the application
  on every transaction. That handshake is itself a validated mechanism and needs its own tests.
  Trigger logic is SQL under migration control, with a separate test harness from the Python suite.

### Option T2 — Application layer writes the audit trail

- Simplest: one place, in Python, with the reason for change already in hand, and one test harness.
- Cost: a write that bypasses the application writes nothing to the audit trail and leaves no trace.
  `URS-DATA-004` is then satisfied only by restricting database credentials — a control that lives
  in the environment, not the system, and that an inspector will read as weaker.

### Option T3 — Both: triggers as the authoritative record, application context for the reason

- Triggers write the row-level facts; the application sets the session context (acting user, reason
  for change, transition identifier) that the trigger reads.
- Cost: two mechanisms to keep in step, and the failure mode where a write occurs with no session
  context set must be defined — reject the write, or record it as an unattributed change.

## Open questions for the human

1. Decision 1 — which persistence model.
2. Decision 2 — where the audit trail is written.
3. Whether the selected direction meets the three-condition ADR gate (hard to revert **and**
   surprising without context **and** a real trade-off given up). Decision 1 plainly is hard to
   revert; the other two conditions are assessed once the direction is chosen.

*No new domain terms are introduced by these options; nothing to challenge against `CONTEXT.md`.*
