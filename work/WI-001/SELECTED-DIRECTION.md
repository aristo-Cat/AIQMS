---
type: selected-direction
work_item: WI-001
status: draft
created: "2026-08-02"
---

# SELECTED-DIRECTION — WI-001

Selected by Juan Miguel Saavedra on 2026-08-02, from the alternatives in
`work/WI-001/DESIGN-OPTIONS.md`.

## The direction

**Option A — shared spine table plus per-type detail tables — combined with T3 — PostgreSQL
triggers as the authoritative audit trail, fed by an application-set session context.**

A single `quality_record` table carries the whole Record Spine with a `record_type` discriminator;
each Record Type adds a 1:1 detail table. `record_action`, `record_link`, `signature` and
`audit_trail` hang off `quality_record` and are shared by all seven types. Each Record Type's State
Model is declared as data in Python — states, permitted transitions, the Role each transition
requires, whether it requires an electronic signature, and which invariants apply — and a single
engine executes those declarations.

Every table in GxP scope carries an `AFTER INSERT OR UPDATE` trigger that writes the audit trail
row. The application sets `aiqms.actor_id` and `aiqms.reason` as transaction-scoped settings before
any write; the trigger reads them. **A write that arrives with no attributable actor is rejected,
not recorded as unattributed** — a GxP change with no attributable author fails the *Attributable*
attribute of ALCOA+ (`URS-EREC-013`), and recording it anyway would manufacture a legitimate-looking
hole. This is one `RAISE EXCEPTION` and is reversible in one line if the position changes.

## Why

**Decision 1.** The invariants are the highest-probability failure in the initial risk assessment
precisely because they must hold across seven State Models (`RA-INIT-007`, `RA-INIT-008`,
Probability H). Option A is the only alternative that lets them be written once and hold for all
seven types by construction, while keeping real `NOT NULL`, foreign key and check constraints in
the database — so `URS-FUNC-001`'s rejection of an incomplete creation and the mandatory Origin
Link of a CAPA have something underneath them that a direct write cannot bypass. The Design and
Database Specifications get a schema an inspector can read.

**Decision 2.** `URS-DATA-004` requires direct modification outside the application to be
*detectable*, and `URS-EREC-005` requires a prompted reason for change on every audit trail entry.
No single layer satisfies both: a trigger sees the write but not the reason; the application knows
the reason but never sees a write that bypasses it. T3 is the combination, and it is the actual
control for `RA-INIT-018`, which sits at Risk Priority H.

## Rejected, and why

| Rejected | Why not |
|---|---|
| **B — JSONB payload per type** | A JSONB field carries no `NOT NULL`, no foreign key and no check constraint, so `URS-FUNC-001` and the CAPA Origin Link become application-only rules with nothing beneath them. It weakens `URS-DATA-004` exactly where `RA-INIT-018` rates the risk H, and leaves the DS/DBS without a schema to present. |
| **C — one full table per Record Type** | Moves the four invariants to seven independent enforcement points, which is the concrete form of the failure mode `RA-INIT-006`/`007`/`008` describe. Highest test cost of the four, and the cost buys per-type constraints that Option A already obtains through its detail tables. |
| **D — event sourcing** | Genuinely attractive: it would largely dissolve `RA-INIT-001`, the highest-probability entry in the register, by making the audit trail the system rather than a side-table. Rejected for this slice because it relocates the risk into projection correctness — the lowest-detectability failure class of the §3.4 conventions — and because search (`URS-FUNC-007`) and reporting (`URS-FUNC-014`) would each need separately validated read models. On the first slice of a Cat 5 system with no code yet, that raises Probability across the board rather than lowering it. |
| **T1 — triggers only** | Leaves `URS-EREC-005`'s reason for change uncovered, and that requirement is a preset row copied verbatim from §11.10.e. |
| **T2 — application layer only** | A write that bypasses the application leaves no trace. `URS-DATA-004` would rest on database credential restriction — a control in the environment, not in the system. |

## ADR gate

`patterns/living-documentation.md` records an ADR only when the decision is **all three of** hard to
revert, surprising without context, and a real trade-off given up.

| Decision | Hard to revert | Surprising without context | Real trade-off | ADR? |
|---|---|---|---|---|
| **1 — Option A persistence** | Yes — the schema shape propagates into every downstream artifact | **No** — a shared parent table with per-type detail tables is a conventional pattern a reader recognises on sight | Yes — C's per-type constraints and D's built-in audit were given up | **No** — this note is the record |
| **2 — T3 audit trail** | Yes — the trigger plus session-context handshake is load-bearing on every table in GxP scope | **Yes** — "why is the audit trail in SQL triggers, and why does the application set session variables before every write" is not answerable from the code, and the reason (no single layer satisfies `DATA-004` and `EREC-005` together) is not obvious | Yes — T2's single test harness and single implementation language were given up | **Yes** — written as `ADR-EREC-001` in `specs/ADR.md` |

## Amended 2026-08-02 after independent review

`work/WI-001/RESEARCH-REVIEW.md` returned `changes required`. Two of its findings changed this
direction rather than merely correcting how it was described, and both were settled by the human on
the same day:

| Finding | Decision | Recorded as |
|---|---|---|
| `URS-DATA-004` requires direct modification to be **prevented**, and T3 delivers only *detectable*. An attributed direct `UPDATE … SET state = …` was accepted, audit-trailed, and bypassed the State Model, the signature requirement and the Segregation Invariant | **All writes to GxP tables go through `SECURITY DEFINER` functions; `INSERT`/`UPDATE`/`DELETE` are revoked from the application role.** This extends T3 rather than replacing it — the trigger and session context are unchanged and now sit beneath a closed write path | `ADR-DATA-001` (accepted) |
| The Segregation Invariant had no defined comparand: `URS-FUNC-012` says the user who *created* the record, `CONTEXT.md` says the Opening Signature is what it is checked against, and those can be different people | **The signer of the Opening Signature.** It is a signed act attesting the submitted content, where the creating account is only a data field | `CONTEXT.md` § Segregation Invariant |

A third finding corrected a factual error rather than a decision: `ADR-EREC-001` claimed a
PostgreSQL `timestamptz` preserves a time zone. It does not — it stores a UTC instant and discards
the offset. The claim is corrected in place and the mechanism that does satisfy `URS-DATA-003` is
recorded as `ADR-DATA-002`.

## Consequences carried into the next state

- The session-context handshake is itself a validated mechanism and needs its own tests, including
  the negative case: a write with no `aiqms.actor_id` set must be rejected.
- Trigger logic is SQL under the migration control of `URS-DEVENV-002` and needs a test harness
  separate from the Python suite. `URS-QUAL-002`'s 100% coverage of signature and transition paths
  must account for both.
- The `record_type` discriminator invites per-type conditionals to leak into spine code. The
  discipline that keeps Option A honest is that every type-specific rule lives inside its State
  Model declaration and never in the engine — this belongs in the thin specs as an explicit
  constraint, not as an aspiration.
