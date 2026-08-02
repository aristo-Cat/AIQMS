---
type: research-slices
work_item: WI-001
status: draft
created: "2026-08-02"
---

# RESEARCH-SLICES — WI-001

Five scoped investigations, each sized to fit a single fresh context window. Slices 1 and 3 are
answered and both produced findings that change the design. Slices 2, 4 and 5 carry the question,
the way to settle it, and what blocks if it is not settled before planning.

**Evidence labels used below**: *documented* = grounded in the vendor's own documentation, read
this session; *unverified* = reasoned but not confirmed against a live system or a run; *open* =
not yet investigated.

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

---

## Slice 2 — How are immutability and the no-delete invariant enforced at the database level?

**Why it matters**: `URS-FUNC-002` (identifier never modifiable), `URS-FUNC-008` (no delete
function exposed to any role) and the append-only nature of `audit_trail` and `signature` are three
of the invariants `URS-FUNC-057` says are enforced in code and not configurable away. If they rest
only on application discipline, `RA-INIT-006` keeps its Detectability L.

**Questions**: whether `REVOKE DELETE` on the application role, a `BEFORE DELETE ... RAISE`
trigger, or both, is the right enforcement; how the same is done for `UPDATE` on `record_no` and on
the two append-only tables; and how row-level security interacts with a trigger-written audit trail
that the application role must not be able to write to directly.

**How to settle**: a throwaway prototype against a local PostgreSQL — one command to run, no
persistence — that attempts each forbidden operation and asserts it fails. The answer to capture is
which mechanism is used and why; the prototype is deleted once it has answered.

**Status: open.** Blocks the schema tasks of the implementation plan, not the plan itself.

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

**Status: answered as to the constraint, open as to the direction.** This is a decision for the
human, not for the implementer, and it is the one open item that should be closed before planning.

---

## Slice 4 — Python server stack and the migration mechanism

**Why it matters**: `URS-DEVENV-001` names Python and `URS-DEVENV-002` requires the schema to be
held as **ordered migrations, applied in a repeatable and verifiable sequence**, with no schema
change reaching a qualified environment outside that mechanism. `URS-DEVENV-005` deliberately names
no tools and defers the choice to the Design Specification (D25), so this slice feeds that
document.

**Questions**: whether migrations are owned by the Supabase CLI or by a Python migration tool, and
which of the two produces the *verifiable* sequence the requirement demands; whether SQL trigger
definitions live in the same migration stream as the tables they guard, which `ADR-EREC-001`
implies they must; and which driver and data-access layer is compatible with prepared statements
disabled, per Slice 1.

**How to settle**: read the two migration mechanisms' guarantees about ordering and re-application,
then choose on the "repeatable and verifiable" criterion rather than on convenience. Record the
choice and the reason — it becomes a configuration item under `URS-QUAL-004`.

**Status: open.** Blocks the first implementation task.

---

## Slice 5 — Test harness for SQL trigger logic

**Why it matters**: `URS-QUAL-002` demands 100% coverage of the paths implementing the invariants,
every signature step and every State transition, and `URS-TEST-004` makes negative testing of those
same paths mandatory. `ADR-EREC-001` puts part of that logic in SQL, so a coverage figure computed
over Python alone would overstate what is verified — and overstating coverage in a validated system
is worse than a low figure honestly reported.

**Questions**: whether trigger behaviour is tested in-database or through the Python suite against
a real PostgreSQL instance in continuous integration; and how the coverage of the SQL portion is
evidenced so the `URS-QUAL-002` threshold means what it claims.

**How to settle**: decide the harness, then state explicitly in the plan how the two coverage
figures are reported — one combined number that hides the split would not be honest evidence.

**Status: open.** Does not block the first implementation task but must be settled before the slice
can reach `evidence_ready`, because the TDD gate requires red-green-refactor evidence for logic
that lives in SQL as much as for logic in Python.
