# IS-2 — the write path

**Work item**: WI-001 · **Date**: 2026-08-02
**Migrations**: `20260802140359_aiqms_roles_and_state_model_as_data`,
`20260802140515_aiqms_write_path_functions`
**Suite**: `supabase/tests/write_path.test.sql` — **20 of 20 pass** (14 + 6)

## Two amendments to `work/WI-001/THIN-SPECS.md` that implementing forced

**1. Roles had no representation at all.** `app_user` carried no role, yet `URS-FUNC-010` requires
an unauthorised Role to be rejected and every transition in the declaration names its roles. Added
`app_role` and `app_user_role`, both audited and both under the immutability layers.

**2. The Python `StateModel` declaration had no SQL counterpart.** Without one,
`execute_transition` would have had to hard-code the machine — a per-type branch in shared code,
which `SELECTED-DIRECTION.md` § Consequences forbids and calls the discipline that keeps Option A
honest. The declaration lives in `state_transition` and `state_transition_role`, and the engine
reads it. Type-specific logic lives in guard functions named by the row, invoked dynamically, so
`execute_transition` contains **no branch on `record_type`**.

This makes the state machine's **third** encoding explicit rather than accidental — the Python
declaration, these tables, and `record_state_catalog`. `PLAN-DOCTOR.md` finding 2 already required
parity tests across all three; T3.2 is where they land, and it is now unavoidable rather than
optional.

## Design decisions taken here

- **The initial state is derived, not written down.** `create_quality_record` selects the
  non-terminal state that no declared transition can reach. Adding a state before `Draft` cannot
  leave a stale literal behind.
- **`record_no` is assigned by the system.** `URS-FUNC-002` makes it immutable, which implies the
  system owns it — a caller-supplied identifier could collide or be chosen. Prefix per type is data
  (`record_type_registry`), so a new Record Type needs no code change.
- **`from_state = '*'`** expresses "any non-terminal state" for cancellation, so a new state cannot
  forget to allow it.
- **The segregation check runs before `apply_signature`**, so a breach never consumes a signature.
  The comparand is the Opening Signature signer, per `CONTEXT.md`.
- **bcrypt via `pgcrypto`** (`crypt`/`gen_salt('bf', 12)`) for the signature credential. Argon2 is
  not available in-database and verifying outside the function would break `ADR-DATA-001`'s premise.
  The cost factor is a configuration item.

## `ADR-ESIG-001` in practice

Four assertions establish it, and the fourth is the one that matters:

1. a wrong password returns `AIQMS_BAD_SIGNATURE`;
2. the record state is **unchanged**;
3. **exactly one** `security_event` row records the attempt, and no `signature` row was written;
4. **`lives_ok` on a subsequent query.** Had `apply_signature` raised, the transaction would be
   aborted and every statement after it would fail. That it does not is the whole decision,
   observable rather than argued.

## Results

Part 1 (14): initial state derived from the declaration · `record_no` shape · unauthorised Role
refused · undeclared transition refused · signature required and absent · the four `ADR-ESIG-001`
assertions · correct password completes the Opening Signature · signer name frozen at signing ·
content hash present · QA moves the record into triage.

Part 2 (6): `Registered -> In triage` needs no signature · the triage guard refuses before severity,
containment, determination and due-date approval are all present · **segregation refuses the Opening
Signature signer even though she holds QA** · that breach consumed no signature · a different QA
completes the approval · `record_no` refused through `update_record_field`.

The segregation test is deliberately constructed so the actor holds the QA Role. Testing it with a
user lacking QA would have been refused by the Role check and proved nothing about `URS-FUNC-012`.

## Not yet covered

- `cancel_quality_record` is implemented and ungated by a test.
- The composite key tying a containment action to the same record (`URS-FUNC-025`) is applied and
  still unexercised; the guard currently passes on the justification limb only.
- Nothing here runs through the pooler or through psycopg 3. `execute_transition` has never been
  called by an application, only by SQL.
- No coverage figure. Still no CI: the runner is the management API.
