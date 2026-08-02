---
type: research-slices
work_item: WI-001
status: draft
created: "2026-08-02"
---

# RESEARCH-SLICES — WI-001

Five scoped investigations, each sized to fit a single fresh context window. **v0.2, 2026-08-02 —
all five are now answered**; slices 2, 4 and 5 were closed in a second pass, slice 3's direction was
chosen by the human, and slice 1 gained an amendment that changes what the local stack can be used
to prove.

**Evidence labels used below**: *documented* = grounded in the vendor's own documentation, read
this session; *unverified* = reasoned but not confirmed against a live system or a run; *open* =
not yet investigated.

**Two *unverified* items survive into the implementation plan as explicit tasks, not as
assumptions**: the `ADR-EREC-001` handshake has never been executed against a live instance
(slice 1), and it is not established that `plpgsql_check`'s coverage functions are usable on
Supabase (slice 5). Everything else below is documentation-grounded.

---

## Slice 1 — Does the `ADR-EREC-001` session-context handshake survive Supabase connection pooling?

**Why it matters**: the whole audit trail mechanism rests on the application setting
`aiqms.actor_id` and `aiqms.reason` and a trigger reading them back. If the pooler breaks that,
`ADR-EREC-001` is unimplementable and the decision has to be reopened before any code is written.

**Finding — *documented***. Supavisor offers two pool modes. In **transaction mode** the connection
is returned to the pool when the transaction ends, and the features that break are the
**session-scoped** ones — the documentation names prepared statements explicitly. In **session
mode** the connection is held until the client releases it.

`set_config('aiqms.actor_id', $1, true)` sets a **transaction-local** value: the third argument
`true` means it is reverted at the end of the transaction. The transaction is precisely the unit
that transaction mode keeps intact, so the handshake holds. **`ADR-EREC-001` stands.**

**The corollary is a control, not a detail.** Using `false` — a session-level setting — would be
wrong in both modes, and wrong in a way that is dangerous rather than merely broken:

- In transaction mode the setting would outlive its transaction on a connection that is then handed
  to another client, so a write could be **attributed to the wrong user**. That is a
  cross-attribution defect in a GxP audit trail: it produces a record that is complete, plausible
  and false, which is the lowest-detectability failure class in `specs/RA-INIT.md` §3.4.
- In session mode the same leak occurs across requests reusing the connection.

The `true` flag is therefore a load-bearing control and belongs in the Design Specification as such,
with a test asserting the setting is absent at the start of a fresh transaction. This was already
listed as a risk row in `ADR-EREC-001` §5.1.5; this slice raises it from a risk to a named
mechanism.

**Second consequence — *documented***: transaction mode does not support prepared statements, so
the Python driver must disable statement preparation. This constrains Slice 4 and is not optional.

**Still unverified**: none of the above has been executed against a live Supabase project. It is
documentation-grounded. The implementation plan must carry a first task that proves the handshake
end to end on a real instance before anything is built on top of it.

**Amended 2026-08-02 — the local stack is not the same pooler.** `config.toml` exposes a
`[db.pooler]` block (`enabled: false`, `port: 54329`, `pool_mode: "transaction"`), and the Supabase
documentation describes it as *"the local PgBouncer service"*, linking to pgbouncer.org for every
setting. **Local development therefore runs PgBouncer; hosted Supabase runs Supavisor.** The
mechanism this slice relies on holds in both — a transaction-local `set_config` is scoped by
PostgreSQL, and both poolers pin a server connection for the duration of a transaction — but
**PgBouncer is an analogue, not the product**. The consequence for evidence is the useful part, and
it happens to match the GxP position anyway: development evidence may come from the local stack with
`[db.pooler] enabled = true` and `pool_mode = "transaction"`, but the **qualification** evidence for
`ADR-EREC-001` must be produced against the qualified hosted environment through Supavisor in the
mode production actually uses. The plan carries both as separate tasks and must not let the local
run stand in for the hosted one.

---

## Slice 2 — How are immutability and the no-delete invariant enforced at the database level?

**Why it matters**: `URS-FUNC-002` (identifier never modifiable), `URS-FUNC-008` (no delete
function exposed to any role) and the append-only nature of `audit_trail` and `signature` are three
of the invariants `URS-FUNC-057` says are enforced in code and not configurable away. If they rest
only on application discipline, `RA-INIT-006` keeps its Detectability L.

**Finding — *documented*. Neither mechanism alone is sufficient; the answer is three layers plus a
residual that must be written down rather than glossed.**

**Layer 1 — privileges.** `ADR-DATA-001` already revokes `INSERT`/`UPDATE`/`DELETE` from the
application role. One correction: **`TRUNCATE` is a separately grantable privilege** — the `GRANT`
synopsis lists it beside `DELETE`, and revoking `DELETE` does not revoke it. It must be revoked
explicitly on every table in GxP scope or `URS-FUNC-008` has a hole the size of a table.

**Layer 2 — `BEFORE UPDATE OR DELETE` triggers that `RAISE EXCEPTION`.** The reason this layer
exists is not redundancy. `ADR-DATA-001` moves every write into `SECURITY DEFINER` functions, which
execute as the owner — so Layer 1 constrains the application role but **cannot constrain the
functions themselves**. A defect in `execute_transition` that updated `quality_record.record_no` or
deleted a `signature` row would pass Layer 1 untouched. Layer 2 is the only layer that binds the
privileged path, and it is therefore the actual control behind `URS-FUNC-002` and the append-only
nature of `audit_trail` and `signature`.

**Layer 2 has a documented bypass that must be closed explicitly.** Setting
`session_replication_role = 'replica'` suppresses ordinary triggers. The fix is documented:
*"triggers configured as `ENABLE ALWAYS` will fire regardless of the current replication role"*.
Every trigger in GxP scope must therefore be created and then set `ENABLE ALWAYS` — one extra
`ALTER TABLE` per trigger, trivially forgotten, so it belongs in a **schema conformance test** that
asserts the state of `pg_trigger.tgenabled` for every GxP trigger, not in a review checklist.

**Layer 3 — a statement-level `BEFORE TRUNCATE` trigger.** Row-level triggers never see a
`TRUNCATE`: *"triggers may be defined to fire for `TRUNCATE`, though only `FOR EACH STATEMENT`"*.
Without this, a `TRUNCATE audit_trail` would be both permitted-if-the-privilege-slipped and
**invisible to the audit trail itself**. Layer 3 is cheap and closes the worst-detectability case
in the slice.

**Row-level security, and why it is not the mechanism here.** *"Table owners normally bypass row
security"* unless `FORCE ROW LEVEL SECURITY` is set, and *"superusers and roles with the
`BYPASSRLS` attribute always bypass the row security system"*. Since the `SECURITY DEFINER`
functions run as the owner, RLS would not constrain them either. RLS therefore governs the **read**
path for the application role — `audit_trail` and `signature` get `SELECT` and nothing else — and is
not load-bearing for immutability. Saying otherwise in the Design Specification would overstate the
control.

**The residual, stated plainly.** *"Regular user-defined triggers can be disabled by the table
owner"*, *"PostgreSQL allows an object owner to revoke their own ordinary privileges"* and re-grant
them, and *"database superusers can access all objects regardless of object privilege settings"*.
**No in-database mechanism defends against the table owner or a superuser.** That boundary is an
environment and procedural control — credential custody for the owner role, and the hosting
qualification — not a system control. `URS-DATA-004`'s *"where technically possible"* clause is
precisely what acknowledges it, and the Design Specification must say so rather than claim a
prevention the database cannot deliver.

**Status: answered.** The schema tasks can be planned. The residual is carried into the plan as a
statement the DS must make, not as an open question.

---

## Slice 3 — Where does the signature password verification live?

**Why it matters**: `URS-ESIG-014` requires the password to be re-entered for **every** signature
in a series, and `URS-ESIG-013` fixes ID ≥ 6 and password ≥ 12. The Opening Signature and the
Triage signature are both in this slice, so this is not deferrable.

**Finding — *documented***. Supabase Auth exposes **no API that verifies a password without a side
effect**:

- `reauthenticate()` does not check a password at all — it sends a **nonce by email** which is then
  passed to `updateUser()`. It is a password-*change* flow, not a password-*confirm* flow.
- `signInWithPassword()` verifies the password but **creates a new session**, which would replace
  or disturb the user's live session on every signature.

So the signature secret cannot simply be "the Supabase Auth login password, checked at signing
time". Three directions, none yet chosen:

| Direction | Consequence |
|---|---|
| **A** — a distinct signature credential held by this system, verified server-side against a strong hash, rotated under `URS-ESIG-009` | Clean separation, full control of the `ESIG-013` minimum lengths and of the failed-attempt logging `URS-ESIG-012` requires. Cost: a second secret per user, and `URS-ESIG-007` (no two persons share an ID/password combination) must be enforced by this system rather than inherited |
| **B** — server-side `signInWithPassword` against a throwaway client, session discarded | Reuses one credential, so nothing new for the user to remember. Cost: a side-effecting auth call per signature, subject to Auth rate limiting and lockout, and every signature emits a login event into a log that is not the audit trail |
| **C** — signature secret is the login password, but verification is done by this system against its own stored hash | Requires this system to hold the password hash, which duplicates the authority Supabase Auth already holds and creates two places a password can be changed. Rejected on sight unless A and B both fail |

**Note on the URS**: `URS-ESIG-013`'s determination says the mechanism is *user ID and password*.
It does **not** say that password is the login password. Direction A is therefore available without
amending the URS — but if A is chosen, `URS-PROC-003` and `URS-TRAIN-001` should say so plainly, so
a user is not surprised by a second secret.

**Status: answered. Direction A chosen by Juan Miguel Saavedra on 2026-08-02** — a distinct
signature credential held by this system. It is already carried through `work/WI-001/THIN-SPECS.md`
v0.2 (`app_user.signature_secret_hash`, `security_event`, the `URS-ESIG-010`/`011` coupling) and it
is what `work/WI-001/RESEARCH-REVIEW.md` findings 4, 5 and 11 were written against. The two URS
consequences the review raised — `URS-ESIG-008` has no owner, and `URS-ESIG-007` cannot mean
"no two persons share a password" once passwords are salted-hashed — are recorded in THIN-SPECS
§ Open items as URS amendments, not resolved by invention here.

---

## Slice 4 — Python server stack and the migration mechanism

**Why it matters**: `URS-DEVENV-001` names Python and `URS-DEVENV-002` requires the schema to be
held as **ordered migrations, applied in a repeatable and verifiable sequence**, with no schema
change reaching a qualified environment outside that mechanism. `URS-DEVENV-005` deliberately names
no tools and defers the choice to the Design Specification (D25), so this slice feeds that
document.

**Finding — *documented*. Migrations are owned by the Supabase CLI.** It satisfies both limbs of
`URS-DEVENV-002` on their own terms:

- *Verifiable* — the CLI *"tracks which migrations have been applied on each database in a table
  called `supabase_migrations.schema_migrations`"*. The applied sequence is a **queryable fact per
  environment**, not a claim in a change record. That table is the evidence `URS-DEVENV-002` asks
  for, and comparing it across environments is one command, `supabase migration list`.
- *Repeatable* — files are named `<timestamp>_description.sql` and *"applied in timestamp order"*,
  and `supabase db reset` reapplies the whole ordered sequence from empty. A clean-room rebuild is
  therefore itself testable, which is what makes the sequence trustworthy rather than merely
  recorded.
- SQL trigger and function definitions live in the same stream as the tables they guard, as
  `ADR-EREC-001` requires, because the stream is plain SQL. A Python migration tool would either
  split the stream in two or wrap the same raw SQL while adding a second history table with no
  extra guarantee.

**Two honest qualifications.** The docs note *"migration files are applied in timestamp order, so
concurrent pushes from different machines can cause conflicts"* — low risk on a single-developer
project, and the control is that `supabase migration list` is compared local against remote before
every push, which produces evidence rather than a habit. And idempotency is by **convention**
(`create table if not exists`), not enforced: a migration is applied once because the history table
says so, not because re-running it would be safe. The DS must not describe migrations as idempotent.

**Driver — psycopg 3, with `prepare_threshold=None`.** Slice 1 makes disabling statement
preparation mandatory. psycopg 3 documents *"a query is prepared automatically after it is executed
more than `prepare_threshold` times on a connection"*, and `None` disables the behaviour — one
documented knob on the connection or pool. asyncpg's equivalent (`statement_cache_size=0`) exists
but asyncpg's interaction with transaction-mode poolers is the better-known trap, and psycopg 3
serves both sync and async from the project's own supported path.

**Data-access layer — none.** Under `ADR-DATA-001` every write is a call to a `SECURITY DEFINER`
function; there is no write-side object graph for an ORM to map. Reads in this slice are a small
number of explicit queries. An ORM would add a configuration item under `URS-QUAL-004` that buys
nothing and introduces a layer capable of emitting a write nobody wrote. Raw parameterised SQL
through psycopg 3.

**Scope decision — no web framework in this slice.** `URS-DEVENV-001` names Python; it does not name
an HTTP surface, and WI-001 is Record Spine and Deviation through QA Triage. The domain layer, the
State Model engine, the persistence functions and the session-context handshake are all testable
without HTTP. Deferring the framework keeps the work item inside one fresh context window and avoids
choosing a framework before there is a requirement that discriminates between candidates.

**Python version and test runner** are pinned exactly in the first implementation task and recorded
as configuration items under `URS-QUAL-004`; pytest is the runner, since the SQL side needs its own
harness regardless (Slice 5).

**Status: answered.**

---

## Slice 5 — Test harness for SQL trigger logic

**Why it matters**: `URS-QUAL-002` demands 100% coverage of the paths implementing the invariants,
every signature step and every State transition, and `URS-TEST-004` makes negative testing of those
same paths mandatory. `ADR-EREC-001` puts part of that logic in SQL, so a coverage figure computed
over Python alone would overstate what is verified — and overstating coverage in a validated system
is worse than a low figure honestly reported.

**Finding — *documented*. Two harnesses, and two coverage figures reported separately.**

- **SQL — pgTAP, run by `supabase test db`.** Supabase documents pgTAP as *"a unit testing
  framework for Postgres"* covering structure, functions and data integrity, with tests created by
  `supabase test new <name>.test` producing `<name>.test.sql`. This is the harness for the
  `SECURITY DEFINER` functions, the `ENABLE ALWAYS` triggers, the Layer 2/3 rejections of Slice 2
  and the schema conformance assertions.
- **Python — pytest against a real local PostgreSQL**, the `supabase start` stack, never a mock.
  Mocking the database would void exactly the invariants under test: an invariant enforced by a
  check constraint or a trigger does not exist in a mock.

**The coverage figure is where honesty is at risk.** `plpgsql_check` is available on Supabase, but
the Supabase page documents it **as a linter only** — it lists `plpgsql_check_function`, *"scans a
function for errors"*, and does not document the upstream coverage or profiler functions. So
whether `plpgsql_coverage_statements` / `plpgsql_coverage_branches` are callable there is
***unverified*** and the plan carries a task to settle it against the live instance rather than
assume it.

Both outcomes are planned for:

- **If the coverage functions work**, the SQL figure is measured and reported beside the Python
  figure.
- **If they do not**, `URS-QUAL-002`'s SQL portion is evidenced by **enumeration**: every branch of
  every `SECURITY DEFINER` function and every trigger is listed, each is tied to a named pgTAP test,
  and the mapping table is the evidence. Weaker than a measurement, and it must be labelled as such
  in the validation package — an enumerated claim presented as a measured percentage would be the
  kind of overstatement that discredits the whole figure.

**The rule either way: never one combined number.** Two figures, each labelled with how it was
obtained. A single blended percentage would hide precisely the portion whose measurement is in
doubt.

**Status: answered as to the harness; one *unverified* item (the coverage functions) is carried
into the plan as a task.**
