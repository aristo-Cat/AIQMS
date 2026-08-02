---
type: implementation-plan
work_item: WI-001
status: draft
created: "2026-08-02"
spec_refs:
  - specs/URS.md
  - specs/RA-INIT.md
  - specs/ADR.md
  - work/WI-001/THIN-SPECS.md
  - work/WI-001/SELECTED-DIRECTION.md
  - work/WI-001/RESEARCH-SLICES.md
---

# IMPLEMENTATION-PLAN — WI-001

Record Spine and Deviation — create, open with signature, QA Triage, segregation invariant, audit
trail. The acceptance criteria and the mandatory negative tests are in `work/WI-001/THIN-SPECS.md`
§ Acceptance criteria and are not restated here; this plan sequences the work that makes them pass.

## Sizing — read this before the rest

The work item does **not** fit a single fresh context window as one implement session, and saying
otherwise would be the kind of optimistic estimate the plan doctor exists to catch. It is therefore
planned as **three implementation slices**, each sized to its own window, which is what the Context
Window Doctrine sanctions: *"a work item — and each research slice or implementation slice inside
it — is sized to fit a single fresh context window."*

| Slice | Scope | Ends when |
|---|---|---|
| **IS-1** | Environment, the `ADR-EREC-001` handshake proven, the `aiqms_app` role proven, the schema, the audit trigger, the three immutability layers | The schema exists and nothing can be written to it unattributed or mutated behind the trail |
| **IS-2** | The five `SECURITY DEFINER` functions of `ADR-DATA-001` | Every write path exists and enforces its rules, tested from SQL |
| **IS-3** | The Python State Model engine, the repository, the acceptance path and the coverage evidence | The four acceptance steps and all fourteen negative tests pass end to end |

Between slices, **handoff-fork rather than compact-continue**: write `work/WI-001/loop-state.md`
and the latest `RUN-*.md`, then resume in a fresh window seeded only by the refs. Chat is not the
handoff surface.

If the plan doctor holds the *work item* rather than the slice to one window, the split into
`WI-001a` / `WI-001b` / `WI-001c` is already drawn along the IS-1/IS-2/IS-3 boundaries above and
can be applied mechanically — each boundary is a state the system can sit in with tests green.

## Conventions that apply to every task

- **TDD is not optional here** (`tdd.require_red_green_refactor: true`, `allow_not_applicable:
  false`). Each task below names its **seam under test**. The failing test is written and observed
  failing before the implementation, and the red and green runs are both captured as evidence.
- **No mock of the database, ever.** Every invariant in this slice is enforced by a constraint, a
  trigger or a privilege. A mock would assert the test double's behaviour and prove nothing about
  `URS-FUNC-057`.
- **Every schema change is a migration file.** `supabase migration new <name>` — nothing reaches any
  database outside that stream (`URS-DEVENV-002`).
- **Rollback, uniformly**: revert the migration file in git and run `supabase db reset`, which
  reapplies the ordered sequence from empty. Nothing is pushed to a hosted database until the local
  reset is green. On the hosted target, rollback is a **forward** migration that drops what the
  previous one created — `supabase_migrations.schema_migrations` records what was applied and the
  CLI will not un-apply it, so a hosted mistake is corrected by adding a migration, never by editing
  history. The one hosted push in this plan (T1.3) is a throwaway vehicle whose disposal migration
  is written **in the same task**, so the hosted database returns to empty by the same mechanism
  that filled it.
- **Evidence lands in `evidence/agent-runs/WI-001/`** — the red run and the green run for each task,
  named by task ID, plus the run log. Chat is never evidence.

## Slice IS-1 — foundation

### T1.1 — Pin the toolchain and stand up the local stack

Records the configuration items `URS-QUAL-004` requires and gives every later task a reproducible
environment. `supabase init`, then set `[db.pooler] enabled = true` and `pool_mode = "transaction"`
in `config.toml` — the local pooler is off by default and this slice must exercise it.

This step produces configuration, not code, and therefore produces **no TDD evidence** — which is
not the same as claiming TDD is *not applicable* to it. `tdd.allow_not_applicable` is `false` in
this harness precisely to close that phrasing as an escape hatch. T1.1 is a prerequisite of T1.2,
and T1.2 is the first task in the red-green ledger.

- **Evidence**: `config.toml` committed; the exact pinned versions of Python, the Supabase CLI,
  psycopg and pytest recorded in the run log and in the dependency manifest.
- **Stop condition**: `supabase start` reports every service healthy and the pooler is listening on
  `54329`.

### T1.2 — Prove the `ADR-EREC-001` handshake locally, through the pooler in transaction mode

The first code task, and deliberately so: `work/WI-001/RESEARCH-SLICES.md` §1 is
documentation-grounded and has never been executed. Everything else in the work item rests on it.

Smallest possible vehicle — one throwaway table, one `AFTER INSERT` trigger set `ENABLE ALWAYS`
that reads `current_setting('aiqms.actor_id', true)` and writes a scratch trail row, refusing the
write when the setting is absent.

**The vehicle is created and dropped inside the test fixture and never enters the migration
stream.** A scratch object left in an ordered migration sequence is a schema object with no
requirement behind it, and in a validated system an unjustified object is a finding rather than
untidiness.

- **Seam under test**: the **connection boundary** — a psycopg 3 connection with
  `prepare_threshold=None` against the local pooler port (`54329`), in transaction mode. The test
  drives real SQL through that connection; there is nothing between the test and the seam.
- **Tests, written failing first**: a write inside a transaction that has set all three settings is
  trailed with the right actor; a write with `aiqms.actor_id` unset is **rejected**, not recorded
  as unattributed (`URS-EREC-013`); `current_setting('aiqms.actor_id', true)` is null at the start
  of a fresh transaction, which is the transaction-local control of `ADR-EREC-001` §5.1.5 and the
  cross-attribution defence `RESEARCH-SLICES.md` §1 calls load-bearing.
- **Command**: `pytest tests/test_session_context.py -v`
- **Stop condition**: if any of the three fails, **stop and reopen `ADR-EREC-001`**. Do not work
  around it — the ADR is the reason the audit trail has this shape, and a workaround discovered at
  this point would be a design change wearing an implementation costume.
- **Evidence**: red run, green run, and the connection string's pooler port and mode visible in the
  captured configuration.

### T1.3 — Repeat T1.2 against hosted Supabase through Supavisor — **blocked, see Blockers**

The local stack runs **PgBouncer**, not Supavisor (`RESEARCH-SLICES.md` §1, amendment). The
mechanism holds in both, but PgBouncer is an analogue and the qualification evidence for
`ADR-EREC-001` must come from the environment production uses.

- **Seam under test**: identical to T1.2; only the DSN changes. The test file is the same one, run
  against a second target, which is itself the point — a divergence would show up as the same
  assertions failing.
- **Command**: `pytest tests/test_session_context.py -v` with the hosted DSN, transaction mode,
  port `6543`.
- **Stop condition**: this task does not block T1.4 onward. The slice may reach IS-3 with it
  outstanding, but **WI-001 cannot reach `evidence_ready`** without it, because the handshake would
  then be qualified on an analogue.
- **Rollback**: the vehicle's disposal migration is written in this task and applied before it
  closes, so the hosted database ends where it started. Nothing else is pushed hosted in IS-1.

### T1.4 — The application role, and proof it can connect with reduced privileges

**The precondition `ADR-DATA-001` rests on, and which the rest of the plan silently assumed.** Layer
1 of `RESEARCH-SLICES.md` §2 revokes writes *from the application role* — but Supabase's default
paths connect either as `postgres`, which owns the tables and would bypass Layer 1 entirely, or
through PostgREST's `authenticator`/`anon`/`authenticated` chain. Neither is what
`ADR-DATA-001` describes. A dedicated `aiqms_app` login role must exist, hold `EXECUTE` on the five
functions and nothing else, and be able to reach the database **through the pooler**.

Supabase documents the connection form for a custom user through the pooler —
`postgres://[USER].[PROJECT-REF]:[PASSWORD]@[REGION].pooler.supabase.com:...` — so the mechanism is
supported; whether it works for this role on this project is ***unverified*** and is settled here.

- **Seam under test**: the **role boundary** — a psycopg 3 connection authenticated as `aiqms_app`
  through the pooler.
- **Tests, written failing first**: `aiqms_app` connects; `aiqms_app` can `SELECT` on a permitted
  table; `aiqms_app` cannot `INSERT` on it; `aiqms_app` can `EXECUTE` a `SECURITY DEFINER` function
  that performs the same insert. That last pair is the whole of `ADR-DATA-001` in two assertions.
- **Command**: `pytest tests/test_application_role.py -v`
- **Stop condition**: if `aiqms_app` cannot connect through the pooler, **stop and reopen
  `ADR-DATA-001`** — its prevention limb would then have no carrier, and `URS-DATA-004` would fall
  back to *detectable* only, which is the finding the independent review raised against
  `THIN-SPECS.md` v0.1. Do not proceed by connecting as `postgres`; that would satisfy the tests and
  void the control.

### T1.5 — The schema migration

Every table, enum, composite foreign key, check constraint and the deferred constraint trigger in
`work/WI-001/THIN-SPECS.md` § Thin DS — schema, plus `record_state_catalog` seeded with the six
Deviation states and their terminal flags.

- **Seam under test**: the **schema itself**, exercised as SQL through pgTAP.
- **Tests, written failing first**: a `quality_record` insert with no `deviation` row → commit
  refused (`URS-FUNC-001`); a `deviation` row attached to a record of another `record_type` →
  refused; a containment action belonging to a different record → refused (`URS-FUNC-025`); a state
  not in `record_state_catalog` → refused; the partial-null combinations the `num_nonnulls` checks
  forbid → refused.
- **Command**: `supabase test db`
- **Evidence**: the migration file, the pgTAP red and green runs.

### T1.6 — The audit trigger (`ADR-EREC-001`, `ADR-DATA-002`)

One `AFTER INSERT OR UPDATE` trigger per table in GxP scope, each set **`ENABLE ALWAYS`**, writing
`audit_trail` with `quality_record_id`, `operation`, old and new value per column, `actor_id`,
`reason`, and the instant with its IANA zone. Any write whose transaction lacks `aiqms.actor_id`,
`aiqms.reason` or `aiqms.tz` is rejected.

- **Seam under test**: the **trigger**, driven by direct SQL as the owning role in pgTAP — not
  through the application, which does not exist yet.
- **Tests, written failing first**: an update produces one row per changed column with old and new
  values (`URS-EREC-004`); `reason` is never null (`URS-EREC-005`); the trail for one record is
  assemblable by `quality_record_id` alone (`URS-FUNC-009`); a write missing any of the three
  settings is rejected; the recorded zone is the acting user's, not the server's
  (`URS-DATA-003`, `ADR-DATA-002`).
- **Command**: `supabase test db`

### T1.7 — The three immutability layers (`RESEARCH-SLICES.md` §2)

- **Layer 1** — `REVOKE INSERT, UPDATE, DELETE, TRUNCATE` from the application role on every table.
  `TRUNCATE` is revoked **explicitly**: it is a separately grantable privilege and revoking
  `DELETE` does not remove it.
- **Layer 2** — `BEFORE UPDATE OR DELETE ... RAISE EXCEPTION` triggers, `ENABLE ALWAYS`, on
  `audit_trail`, `signature` and `security_event`, plus a `BEFORE UPDATE` trigger on
  `quality_record` rejecting any change to `record_no` (`URS-FUNC-002`). This layer exists because
  `ADR-DATA-001` runs the write path as the owner, which Layer 1 cannot restrain.
- **Layer 3** — statement-level `BEFORE TRUNCATE` triggers on the append-only tables, because
  row-level triggers never fire on `TRUNCATE`.
- **Schema conformance test** — asserts `pg_trigger.tgenabled` is `'A'` for **every** GxP trigger.
  `ENABLE ALWAYS` is one `ALTER TABLE` per trigger and is exactly the kind of step that is silently
  omitted; a test is the only control that survives a hurried migration.

- **Seam under test**: the **privilege and trigger boundary**, driven from pgTAP as the application
  role for Layer 1 and as the owner for Layers 2 and 3.
- **Tests, written failing first**: `DELETE FROM quality_record` as the application role → refused
  for want of privilege (`URS-FUNC-008`); `TRUNCATE audit_trail` → refused; `UPDATE quality_record
  SET state = …` directly → refused (`URS-DATA-004`, `ADR-DATA-001`); `UPDATE … SET record_no = …`
  → refused; an `UPDATE` on `audit_trail` as the owner → refused; `SET session_replication_role =
  'replica'` followed by a forbidden write → still refused, which is what `ENABLE ALWAYS` buys.
- **Command**: `supabase test db`
- **Documentation obligation**: the Design Specification must state the residual plainly — the
  table owner can disable a trigger, and a superuser bypasses every privilege. That boundary is an
  environment and procedural control, and `URS-DATA-004`'s *"where technically possible"* clause is
  what acknowledges it. Claiming the database prevents a superuser would be a false statement in a
  validation package.

## Slice IS-2 — the write path

Five `SECURITY DEFINER` functions, each with a pinned `search_path`, each tested from pgTAP as the
application role. The seam for every task in this slice is the **function signature** — the
application's only permitted verb — and the enforcement each function owns is in
`work/WI-001/THIN-SPECS.md` § Thin DS — write path.

| Task | Function | Written-failing-first tests |
|---|---|---|
| **T2.1** | `create_quality_record` | Spine and detail inserted in one transaction; a call missing a minimum field rejected (`URS-FUNC-001`); the record lands in `Draft` |
| **T2.2** | `apply_signature` | Password verified against `signature_secret_hash` and **re-entered for every signature** (`URS-ESIG-014`); ID ≥ 6 and password ≥ 12 enforced (`URS-ESIG-013`); signer name, meaning and transition frozen into the row (`URS-ESIG-002`, `003`); `content_hash` computed and stored (`URS-ESIG-017`); a `disabled` user rejected (`URS-ESIG-010`/`011`); a wrong password → no state change **and** a `security_event` row (`URS-ESIG-012`) |
| **T2.3** | `execute_transition` | Undeclared transition rejected; unauthorised Role rejected (`URS-FUNC-010`); missing signature does not complete (`URS-FUNC-011`); Segregation Invariant against the **Opening Signature signer** (`URS-FUNC-012`, `CONTEXT.md`); the `In triage` guard — severity set, containment resolved, determination recorded with justification, due date approved (`URS-FUNC-003`, `024`, `025`) |
| **T2.4** | `update_record_field` | Reason required (`URS-EREC-005`); `record_no` refused (`URS-FUNC-002`); a terminal record refused |
| **T2.5** | `cancel_quality_record` | Reason required; a terminal source state refused |

- **Command for all five**: `supabase test db`
- **Stop condition for the slice**: `apply_signature` is the one function whose failure mode is
  silent — a signature that verifies nothing still returns a row. T2.2's wrong-password test is
  therefore run and observed **red** before the verification code exists, not merely after.

## Slice IS-3 — the Python layer and the acceptance path

### T3.1 — `StateModel` and the engine

The declaration types and the engine that executes them, per `work/WI-001/THIN-SPECS.md` § Thin DS —
State Model as declared data.

- **Seam under test**: the **`StateModel` declaration** — data in, decision out, no I/O. This is the
  one genuinely unit-testable seam in the work item and it should be exercised hard: every
  transition, every role, every guard, and the `when` branch reading `investigation_required` and
  never `severity`.
- **The review criterion, enforced by a test**: no `record_type` branch may appear in the engine.
  A test asserts the engine module's source contains no reference to a concrete record type — crude,
  but it is the discipline that keeps Option A honest and `SELECTED-DIRECTION.md` § Consequences
  says it belongs in the specs as a constraint rather than an aspiration.
- **Command**: `pytest tests/test_state_model.py -v`

### T3.2 — The anti-drift tests — **three encodings, not two**

The Deviation state machine is written down in **three** places, and each pair can drift
independently: the `DEVIATION` declaration in Python, `execute_transition` in SQL, and the rows of
`record_state_catalog` that the `quality_record` foreign key resolves against. A divergence in any
pair is invisible until it produces a wrong decision or an unexplainable constraint violation.

- **Seam under test**: each pair, driven from the Python declaration as the single source.
- **Test A — Python ↔ SQL**: the test reads the declared transitions and asserts
  `execute_transition` accepts exactly those and rejects everything else, generated from the
  declaration rather than hand-listed.
- **Test B — Python ↔ catalog**: the set of `record_state_catalog` rows for `'deviation'` equals
  `DEVIATION.states` exactly, and the `is_terminal` flags match `DEVIATION.terminal`. Set equality,
  in both directions — an extra catalog row is as much a defect as a missing one, because it makes
  a state reachable by direct write that the engine will never produce.
- **Command**: `pytest tests/test_declaration_parity.py -v`

### T3.3 — The psycopg 3 repository

Raw parameterised SQL, no ORM (`RESEARCH-SLICES.md` §4). Its one structural obligation: the three
`set_config(..., true)` calls open **every** transaction that writes.

- **Seam under test**: the **repository interface**, against the real local PostgreSQL.
- **Test**: a write issued through a repository path that omitted the session context is rejected by
  the database — the belt-and-braces case, proving the trigger still catches an application bug.
- **Command**: `pytest tests/test_repository.py -v`

### T3.4 — The acceptance path and the fourteen negative tests

The four positive steps of `work/WI-001/THIN-SPECS.md` § Acceptance criteria end to end, then every
negative test in that section run through the Python layer rather than through SQL — the same
assertions at a different altitude, which is what shows the enforcement is not bypassable from
above.

- **Command**: `pytest -v`
- **Evidence**: this run is the flow evidence for the work item.

### T3.5 — Coverage, reported as two figures

- Python: `pytest --cov` .
- SQL: **first verify** whether `plpgsql_check`'s coverage functions are usable on this instance —
  Supabase documents the extension as a linter and does not document `plpgsql_coverage_statements`
  or `plpgsql_coverage_branches`, so this is ***unverified*** and is settled here, not assumed.
- **If they work**: report the measured SQL figure beside the Python figure.
- **If they do not**: evidence the SQL portion by **enumeration** — every branch of every
  `SECURITY DEFINER` function and every trigger listed, each tied to a named pgTAP test — and label
  it in the validation package as an enumerated claim, not a measurement.
- **The rule either way**: never one combined number. A blended percentage would hide precisely the
  portion whose measurement is in doubt, and `URS-QUAL-002`'s threshold would then mean less than it
  appears to.
- **Stop condition — the threshold is a gate, not a reading.** `URS-QUAL-002` demands **100%**
  coverage of the paths implementing the invariants, every signature step and every State
  transition. A measured figure below that on the Python side, or an enumeration with any unmatched
  branch on the SQL side, stops the slice short of `evidence_ready`. A coverage task with no
  threshold attached would be decoration.

## Blockers

1. **T1.3 needs a hosted Supabase project and nothing in this repository names one.**
   [NEEDS CLARIFICATION: which Supabase project, region and connection string are the qualified target for AI-QMS — the value must come from the human, not be invented here]
   Not blocking for IS-1 through IS-3 on the local stack; **blocking for `evidence_ready`**.
2. **Two URS gaps, already recorded** in `work/WI-001/THIN-SPECS.md` § Open items: `URS-ESIG-008`
   has no owner under Direction A, and `URS-ESIG-012`'s reporting-to-management limb is absent.
   Both are operational controls, so neither blocks this build — both need a URS amendment rather
   than an invented requirement, and that amendment is a separate work item.

## What this plan deliberately does not build

No HTTP surface and no web framework (`RESEARCH-SLICES.md` §4). No user administration beyond the
minimum `app_user` needed to attribute, authorise and verify a signature — `URS-FUNC-056`,
`URS-FUNC-058` and `URS-SEC-003` are a later work item, and the enrolment path built here must be
revisited then rather than treated as finished. No MFA: `URS-SEC-002` places it on remote login, not
on the signature. The other six Record Types are out of scope by the slice boundary; the shape of
`record_state_catalog` and `record_type_t` is what makes adding them cheap.
