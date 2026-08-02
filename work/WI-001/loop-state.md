---
type: loop-state
work_item: WI-001
status: draft
created: "2026-08-02"
---

# loop-state — WI-001, handoff at the IS-1 / IS-2 boundary

Written as a **handoff-fork**, per the Context Window Doctrine: IS-1 filled its window, and IS-2 is
sized to start in a fresh one seeded only by the refs below. Chat is not the handoff surface; this
file and the evidence are.

## Where the work is

`WI-001` is `in_progress`. **IS-1 is complete except for the two pooler-dependent halves.**

| Task | State |
|---|---|
| T1.1 environment | Partially — hosted project is the environment; **no Supabase CLI, no Docker** locally |
| T1.2 handshake | **SQL half done and evidenced.** Pooler half open — needs a direct connection string |
| T1.3 hosted Supavisor run | Open, same dependency |
| T1.4 `aiqms_app` role | **Privilege model done and evidenced.** Connectivity through the pooler open |
| T1.5 schema | **Done** — 9 tables, migration `20260802124455` |
| T1.6 audit trail | **Done** — migrations `…125955`, `…130049` |
| T1.7 immutability layers | **Done** — migrations `…130351`, `…130427` |
| pgTAP suite | **14/14** — `supabase/tests/immutability_and_audit_trail.test.sql` |

Evidence lives in `evidence/agent-runs/WI-001/`. Read those four files before touching anything;
each one records what it does **not** prove as well as what it does.

## How to work without the CLI

`supabase test db` is only a runner. pgTAP is a Postgres extension (`1.3.3`, installed here in
`extensions`) and its assertions are plain SQL, so suites run through the Supabase MCP
`execute_sql` unchanged. Wrap every suite in `begin … rollback` — verified to work through that
transport. This is not optional tidiness: `audit_trail`, `signature` and `security_event` refuse
`DELETE` and `TRUNCATE`, so a committed fixture is permanent residue.

DDL goes through `apply_migration` and the file is then written to `supabase/migrations/` under the
**same version number the platform returns**, so `supabase migration list` compares cleanly later.
Test-only objects go through `execute_sql` so they never enter the product stream.

## ~~The decision that blocks `apply_signature`~~ — RESOLVED, see `ADR-ESIG-001`

`URS-ESIG-012` requires a **failed** signature attempt to be recorded. `THIN-SPECS.md` gives it a
`security_event` table, and the independent review's finding 5 already noted the attempt is
otherwise invisible. What neither anticipated: **if `apply_signature` raises on a bad password, the
`security_event` row it just wrote is rolled back with everything else.** The record of the failure
destroys itself.

Four ways out, with what each costs:

| | Approach | Cost |
|---|---|---|
| **A** | `dblink` self-connection as an autonomous transaction | `dblink` is available on this project but not installed. Needs a foreign server plus a user mapping holding a password in the catalog, and becomes another configuration item under `URS-QUAL-004` in a qualified system |
| **B** | The application writes the event in a separate transaction after catching the error | If the application dies between the failure and the write, the event is lost — the record of a failed signature would depend on the application, which is precisely what `ADR-DATA-001` moved away from |
| **C** | Savepoints | Does not help. A savepoint rolls back within the transaction; it cannot commit independently |
| **D** | **`apply_signature` does not raise.** It writes the `security_event`, returns a typed failure, and `execute_transition` performs no state change and returns that failure. The transaction **commits**: the event is durable, the record is untouched | The caller must read a return value instead of relying on an exception |

**RESOLVED 2026-08-02 — D chosen by Juan Miguel Saavedra and recorded as `ADR-ESIG-001` (accepted).**
The reasoning below is why. It keeps the control inside the database where `ADR-DATA-001` put it, needs no
new extension and no stored credential, and its failure mode is benign — a caller that ignores the
result still causes no state change, because the transition simply did not happen and the audit
trail shows nothing changed. A and B both make the durability of a security record depend on
machinery outside the function that produces it.

D is **surprising without context** — "why does a failed electronic signature return instead of
raising" is not answerable from the code — and it gives up the ordinary exception contract. That is
two of the three ADR conditions in `patterns/living-documentation.md`; whether it is hard to revert
is the open question. Judge it properly before implementing rather than after.

## Also settled while building, worth not re-deriving

- **Signature password verification uses `pgcrypto`** (`1.3`, already installed) with bcrypt via
  `crypt()`/`gen_salt('bf', …)`. Argon2 is not available in-database, and verifying outside the
  function would break `ADR-DATA-001`'s premise that the function enforces the rule. Record the cost
  factor as a configuration item. The `$argon2id$…` strings in earlier fixtures were placeholders,
  not a commitment.
- **`create_quality_record` should stay type-agnostic.** Put the spine insert in one function and
  give each Record Type a thin wrapper (`create_deviation`) that calls it and inserts the detail.
  A single function taking Deviation fields would put a per-type branch into shared code, which is
  the discipline `SELECTED-DIRECTION.md` § Consequences forbids. The deferred constraint makes the
  two-step insert safe inside one transaction.
- **`record_no` is system-assigned**, not caller-supplied — `URS-FUNC-002` makes it immutable, which
  implies the system owns it. A per-type, per-year sequence rendering `DEV-YYYY-NNNN` is the obvious
  form; it is not specified anywhere, so record it as a decision when implemented.
- The management API connects as `postgres`, and **`rolsuper` is false** — Supabase hands out no
  superuser. The `RESEARCH-SLICES.md` §2 residual on this platform is the table owner, not an
  operator-available superuser.

## Still owed, and not to be quietly dropped

- **Two `URS` gaps** in `THIN-SPECS.md` § Open items: `URS-ESIG-008` has no owner under Direction A,
  and `URS-ESIG-012`'s reporting-to-management limb is absent. Both need a URS amendment as a
  separate work item, not an invention here.
- **No CI.** Every suite so far was invoked by hand through the management API. There is no
  automated regression on change until the CLI exists.
- **No coverage figure.** `plpgsql_check 2.8` is available; whether its coverage functions work here
  is untested. That is T3.5, and `URS-QUAL-002` cannot be claimed before it.
- **T1.5's own pgTAP suite.** The composite key tying a containment action to the same record
  (`URS-FUNC-025`) and the `num_nonnulls` pairing constraints are applied but never exercised.

## What needs the human

1. The **direct database connection string** (Transaction pooler) in a git-ignored `.env` as
   `AIQMS_DB_URL`. Unblocks T1.2's pooler half, T1.4's connectivity half, and the psycopg 3 work of
   IS-3. Until then `ADR-EREC-001` is qualified on an analogue.
2. The **`aiqms_app` password**, set out of band with `alter role aiqms_app password '…'` and stored
   in the same `.env`. The role was deliberately created without one.
3. `winget install --id Supabase.CLI -e` for CI and `pg_prove`. Not blocking; the suites run without
   it.
