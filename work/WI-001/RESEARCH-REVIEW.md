---
type: research-review
work_item: WI-001
status: draft
created: "2026-08-02"
reviewer: independent
---

# RESEARCH-REVIEW — WI-001

Independent review of `specs/URS.md`, `CONTEXT.md`, `specs/RA-INIT.md`, `specs/ADR.md` and the four
WI-001 work artifacts, against the `research_review` gate. The reviewer did not author any of them
and has taken no claim on trust.

## Verdict

**changes required**

The direction is sound and the reasoning behind it is better than most of what this gate normally
sees, but the URS coverage table in `THIN-SPECS.md` claims more than the design delivers in at
least five rows, and two of those — `URS-FUNC-001` and `URS-DATA-004` — are the exact claims the
selected direction was justified by. The slice also applies two electronic signatures while no
requirement governing the integrity of a signed record is in its scope, which leaves a Risk
Priority H entry (`RA-INIT-014`) with an initial control that exists nowhere in the project. Fix
the coverage table and the schema constraints and this reaches `planned` quickly; approving it as
written would propagate false coverage into the traceability matrix, which is the one defect this
gate exists to stop.

## Findings

### 1. The schema does not make an incomplete creation impossible, which is the whole claim `URS-FUNC-001` rests on — Blocking

`work/WI-001/THIN-SPECS.md`, URS coverage table: "*A Deviation is created only when every mandatory
minimum field is present; **the database rejects an incomplete row, not only the application***".
`work/WI-001/SELECTED-DIRECTION.md` repeats the claim as the reason Option A beat Option B: real
constraints "so `URS-FUNC-001`'s rejection of an incomplete creation … [has] something underneath
[it] that a direct write cannot bypass".

It does not. The foreign key runs from `deviation.quality_record_id` to `quality_record(id)`, so a
`quality_record` row with `record_type = 'deviation'` and no `deviation` row at all is a perfectly
legal insert — a Deviation with no departure description, no detection method and no detected-at.
Per-column `NOT NULL` protects each table in isolation; nothing protects the record. Four further
gaps sit in the same DDL: `record_type`, `state` and `severity` are unconstrained `text`, so
`'devation'`, `'Closed'` and `'catastrophic'` all insert cleanly, while the coverage table claims
Severity is "critical/major/minor" and `URS-FUNC-001` speaks of Record Types "in scope";
`containment_action_id` is not constrained to an Action of the same Quality Record;
`cancelled_at` is not tied to `state = 'Cancelled'`; and nothing states how `record_no` is
generated, though `URS-FUNC-002` requires the system to assign it at creation.

Fix: a `DEFERRABLE INITIALLY DEFERRED` constraint trigger on `quality_record` asserting that the
detail row required by `record_type` exists at commit; `CHECK` or enum domains on `record_type`,
`state` and `severity`; a composite foreign key tying `containment_action_id` to the same
`quality_record_id`; and a stated `record_no` generation mechanism. Until then the
`URS-FUNC-001` row should read "the application rejects an incomplete creation; the database
enforces per-table completeness only".

### 2. Direct modification is detectable but not prevented, and a direct state change is neither guarded nor tested — Blocking

`THIN-SPECS.md` claims `URS-DATA-004` as realized: "*No stored value changes except through a path
that writes the audit trail; a write with no attributable actor is rejected*". `specs/ADR.md`
§5.1.5 states it more strongly still: "`URS-DATA-004`'s *detectable* is literally true".

`URS-DATA-004` requires two things: direct modification outside the application shall be
**prevented**, and where technically possible **detectable**. `ADR-EREC-001` delivers the second and
leaves the first entirely to database credential restriction — which is precisely the control the
ADR rejected Option A/T2 for relying on ("a control in the environment, not in the system"), and
which no WI-001 artifact names, owns or tests. The consequence is sharper than a wording problem:
an *attributed* `UPDATE quality_record SET state = 'Under investigation'` is accepted, written to
the audit trail and indistinguishable from a legitimate transition, bypassing `URS-FUNC-010`,
`URS-FUNC-011` and the Segregation Invariant. The negative-test list covers `record_no`, `DELETE`
and the unattributed write; it does not cover a direct, attributed change to `state`, `severity` or
`investigation_required`. `RA-INIT-007` and `RA-INIT-011` are both Risk Priority H on exactly this
failure mode.

Fix: name the prevention control in the thin specs — at minimum `REVOKE UPDATE` on the state and
determination columns from the application role, with transitions performed through a
`SECURITY DEFINER` function — add the direct-state-change negative test, and correct the
`URS-DATA-004` row to distinguish what is prevented from what is merely detected.

### 3. Nothing freezes a record once it is signed, and `URS-ESIG-017` has no home anywhere in the project — Blocking

The slice produces two signatures (`URS-FUNC-011` (a) and (b)) and the coverage table lists
`URS-ESIG-003` and `URS-ESIG-013`/`014`. It does not list `URS-ESIG-017`, `URS-ESIG-002` or
`URS-FUNC-015`, and the schema implements none of them.

`URS-ESIG-017` requires that a signed record cannot be modified, or that modification makes it
appear unsigned. `DESIGN-OPTIONS.md` lists it as a fixed constraint on every option; it then
disappears. The `signature` table holds `signer_id`, `meaning`, `transition` and `signed_at` and no
digest of what was signed, so after the Opening Signature the record remains freely editable —
`URS-FUNC-003` explicitly permits owner and due-date changes — with nothing marking the signature
stale. `RA-INIT-014` sits at Risk Priority H and names `URS-ESIG-017` as its initial control; that
control does not exist in this slice or anywhere else in the repository. The same gap swallows
`URS-FUNC-015`'s rule that a waived block "shall not be re-enabled without a new signed
determination": `investigation_required` is a mutable boolean, and an attributed update flips it
after Triage without a second signature. `URS-ESIG-002`'s obligation to show signer name, date,
time and meaning attaches the moment the first signature exists, and is absent too.

Fix: store a digest over the signed field set on the `signature` row and re-verify it on read (the
"appears unsigned" branch of `URS-ESIG-017` is the cheaper of the two); revoke `UPDATE` on the
Triage determination columns once signed; and add `URS-ESIG-002`, `URS-ESIG-017` and
`URS-FUNC-015` rows to the coverage table with what this slice actually does for each.

### 4. Direction A makes `app_user` the electronic-signature control surface, and the thin specs still defer it — Blocking

`THIN-SPECS.md` § "Open items carried forward": "*`app_user` is assumed to exist … this slice needs
only enough of it to attribute and to authorise*". Under Direction A that is no longer true.

Once the signature secret is held by this system rather than by Supabase Auth, four preset rows
stop being inherited and become this system's code and data, in the first slice that signs
anything. `URS-ESIG-004` requires the signature to be unique to one person and never reassigned,
which is now a property of a row in `app_user`, not of the identity provider. `URS-ESIG-005`
requires the holder's identity to be verified before the signature is assigned — under Direction A
issuing the credential is an act this system performs, and no enrolment step exists in the URS
determinations, in `URS-PROC-003` or here. `URS-ESIG-009` requires periodic expiry and mandatory
renewal, so this system now runs a second rotation cycle beside the auth provider's, and the
behaviour when a credential expires mid-transition is undefined (`URS-SEC-004` states the analogous
rule for session expiry and nothing states it for credential expiry). Most concretely,
`URS-ESIG-010` and `URS-ESIG-011` require blocking on departure or loss: disabling the Supabase Auth
account does **not** disable a signature credential this system holds, so `URS-SEC-003`'s "disabled
without delay on departure" now needs two revocations kept in step, and a departed user's signature
credential stays valid until the second one happens.

Fix: bring the signature-credential portion of `app_user` into WI-001's schema — issuance with
recorded identity verification, expiry, revocation, and the never-reassigned rule — or split it into
a prerequisite work item that WI-001 declares a hard dependency on. It cannot stay an assumption.

### 5. Under Direction A a failed signature attempt is invisible by construction — Blocking

`RESEARCH-SLICES.md` Slice 3 lists as a benefit of Direction A "full control of the failed-attempt
logging `URS-ESIG-012` requires". The design as specified cannot produce that log at all.

`ADR-EREC-001` makes the audit trail trigger-driven off table writes, and `THIN-SPECS.md` states
`audit_trail` is "written only by trigger; no application INSERT path". A rejected signature writes
no row, so it fires no trigger and leaves no record. There is no second store, no lockout or
rate-limit position, and — since `URS-ESIG-012` requires periodic reporting to management — no
owner for that report. The acceptance criteria compound it: the mandatory negative tests cover
segregation, containment, a missing signature, an unauthorised role and an undeclared transition,
but there is no test for a **wrong**, absent or expired signature credential, which under Direction
A is this system's own logic and falls squarely inside `URS-TEST-004`'s "every electronic signature
step" and `URS-QUAL-002`'s 100% coverage of them.

Fix: specify a signature-attempt log distinct from `audit_trail`, with its retention and its
reporting route; state the lockout position and its interaction with a transition that then cannot
complete; and add the wrong-credential negative test to the slice's acceptance criteria.

### 6. `URS-FUNC-003` is claimed as covered with the Quality Assurance half of it missing — Blocking

`THIN-SPECS.md` coverage table: "*Originator, owner, area and a due date proposed by the opener;
owner and due date changeable with a mandatory reason captured in the audit trail*".

`URS-FUNC-003` says the due date is "proposed by the user who opens the record **and approved by
Quality Assurance**", excepting only CAPA and Change Control — a Deviation is not excepted.
`CONTEXT.md` states the same rule twice, under **Due Date**, as a decision taken on 2026-08-01 with
the exception named explicitly. The only Quality Assurance act in this slice is Triage, and Triage
as specified carries Severity, the Containment Action, the QA Determination and a signature. There
is no due-date approval in the state model declaration, no column recording it, and no acceptance
criterion for it. The row therefore claims a requirement the slice realizes about half of.

Fix: add the due-date approval to the Triage act — a `due_date_approved_at` on the spine set by the
same signed transition is enough — or restate the row as partial coverage and name the later slice
that completes it. Silent partial coverage is what turns into an unearned "covered" cell in the RTM.

### 7. The Segregation Invariant has no defined comparand — Blocking

`THIN-SPECS.md` covers `URS-FUNC-012` as "*The user who created the Deviation cannot perform its
Triage. Enforced in code, not configurable*", and the state model attaches `invariants=[SEGREGATION]`
to both Triage transitions. Nowhere does it say what the acting user is compared against.

`CONTEXT.md` is explicit that the Opening Signature "fixes authorship of the content submitted and
**is the evidence the Segregation Invariant is checked against** at every later approval". The
schema's obvious candidate is `originator_id`. These are not necessarily the same person: the
`Draft → Registered` transition is declared open to four roles with no identity guard, so any
Reporter can apply the Opening Signature to a record another user created, and the two candidate
comparands then disagree. `URS-FUNC-011` (a) says the Opening Signature is applied "by the user who
opens it", and `THIN-SPECS.md` repeats that in prose, but no mechanism enforces it.

Fix: state which record the invariant reads — the signer of the `Draft` exit, per `CONTEXT.md` — and
add a guard on the `Draft → Registered` transition that the signer is the originator, with a negative
test. `RA-INIT-008` puts this invariant at Risk Priority H; an H-rated invariant should not rest on
an unstated comparand.

### 8. The audit trail cannot be assembled per Quality Record, and `URS-EREC-005`'s reason for change is not enforced — Blocking

`THIN-SPECS.md` claims `URS-EREC-005` as "*Every audit trail entry carries user, old value, new
value, timestamp with timezone, and reason for change*".

Two problems, both in the `audit_trail` sketch. First, `reason` is a plain nullable column and the
trigger raises only when `aiqms.actor_id` is absent — `THIN-SPECS.md` and `specs/ADR.md` both say so
in as many words. A change made with `aiqms.reason` unset is therefore recorded silently, so
"every entry carries … reason for change" is false as designed. `URS-EREC-005` is a preset row
copied verbatim from 21 CFR Part 11 and is one of the least forgiving rows in the URS. Second, the
table is keyed on `table_name` plus `row_id` with no `quality_record_id`, while `URS-FUNC-009`
scopes the trail "for every Quality Record", `URS-OPS-003` requires that per-record trail to be
reviewed before closure, `URS-UI-005` requires it in the printout and the slice's own acceptance
criterion 4 reads it per record. Reassembling it means resolving `table_name` to a join path across
`deviation`, `record_action` and `signature` in application code — the audit trail's most
inspection-facing query, unsupported by the schema. There is also no operation column, so an
insert and an update that sets a previously null field are indistinguishable, though `URS-EREC-005`
speaks of create and modify actions.

Fix: denormalise `quality_record_id` onto every audit row from the trigger; add the operation; and
record the determination on when a reason is required — if creation rows legitimately carry none,
say so, then make the trigger enforce it for updates and mark `reason` accordingly.

### 9. `timestamptz` does not preserve a timezone, and two documents claim it does — Blocking

`THIN-SPECS.md` covers `URS-DATA-003` as "*Timestamps written by the database with timezone
preserved, never from an application clock*", and `specs/ADR.md` §5.1.4 makes it implementation
constraint 2: "Timestamps are written by the database **with their timezone preserved**".

PostgreSQL `timestamp with time zone` stores a UTC instant and renders it in the session's
`TimeZone` setting. The offset in force where and when the act occurred is discarded at input and
never recoverable. The second half of both claims is true and worth keeping — the database clock
rather than the application clock. The first half is not. `URS-DATA-003` requires the system to
"record and preserve the timezone of every timestamp"; if that means only "unambiguous instant",
`timestamptz` plus explicit offset rendering satisfies it and the reading should be recorded; if it
means the actor's local offset, a second column is required.

Fix: settle which reading `URS-DATA-003` carries, record it as a system-specific determination, and
correct the coverage row and the ADR constraint. This decides a column in the first migration, so it
belongs in the plan rather than after it.

### 10. `THIN-SPECS.md` silently drops the `In triage` state that `CONTEXT.md` declares, and contradicts itself about Cancellation — Blocking

The Deviation State Model in `CONTEXT.md` — the authoritative one, per `specs/URS.md` §1.2 — runs
`Draft → Registered → In triage ⊕ → Under investigation | In actions → Pending closure → Closed`.
The diagram in `THIN-SPECS.md` runs `Draft → Registered → Under investigation | In actions`, with no
`In triage` state, and the Python declaration matches the diagram. The divergence is not flagged
anywhere, and the same document then writes "**Out**: everything after `In triage`" — using a state
name its own model no longer contains.

The consequence is not cosmetic. With no `In triage` state, the Triage content must be written while
the record is `Registered` and validated by `guard=triage_complete` at transition time, which means
Severity, the containment fields and the determination are editable in `Registered` by anyone with
edit rights. That is a defensible design, but it is a different design from the one `CONTEXT.md`
declares, and `URS-DOCS-001` requires the user manual to describe the State Model that actually
ships. The same section also says "Cancelled reachable from Draft, Registered", while the
declaration uses `ANY_NON_TERMINAL` and both `URS-FUNC-008` and the State Contract require every
non-terminal state — including the two the slice has just made reachable.

Fix: either restore `In triage` or amend `CONTEXT.md` as a recorded domain change with its
justification, and make the cancellation scope one statement in both places. The acceptance criteria
should also gain a positive cancellation test from each non-terminal state; at present only
"cancellation without a reason → rejected" appears.

### 11. `URS-ESIG-007` cannot be enforced the way Direction A implies — Non-blocking

`RESEARCH-SLICES.md` Slice 3 lists as a cost of Direction A that "`URS-ESIG-007` (no two persons
share an ID/password combination) must be enforced by this system rather than inherited".

Taken literally that is unachievable, and chasing it is dangerous. Verified against a salted strong
hash — which Direction A requires — two users with the same password produce different digests, so
collision detection is impossible by comparison; an implementer trying to satisfy the row as written
could reach for a deterministic or unsalted hash and turn a compliance row into a security
regression. The satisfiable reading is that uniqueness of the **ID** makes the ID-plus-password
combination unique regardless of the password, which is how the row is normally met. Related and
unresolved: Direction A does not say what the "ID" component of a signature now is — the login
identifier or a separate signature ID — while `URS-ESIG-013`'s determination fixes a six-character
minimum for it and reads, as written, as the login credential.

Fix: record both determinations in the `URS-ESIG-013` note in `specs/URS.md` — that the signature
password is distinct from the login password, and that `URS-ESIG-007` is met through ID uniqueness —
before the first signature test is written. Slice 3 already flags that `URS-PROC-003` and
`URS-TRAIN-001` should say so; the mechanism description in `URS-ESIG-013` is where a reader looks
first.

### 12. `URS-ESIG-008` has no owner, and neither do several stated initial controls — Non-blocking

`URS-ESIG-008` requires the correct functioning of the ID and password credentials to be checked
periodically. Under Direction A that check is over a mechanism this system owns, and nothing in
`URS-OPS-001` to `URS-OPS-006` covers it: `URS-OPS-002` reviews accounts, roles and permission
changes, not credential functioning. The same pattern shows elsewhere in `specs/RA-INIT.md` §7,
where the "Initial control" column is written in the present tense over artifacts that do not exist
— `RA-INIT-016` cites the Data Protection Impact Assessment and a contractual no-training term, and
§9 lists `specs/DPIA.md` and `specs/SUP-ASSESS.md` as planned.

Fix: add the periodic credential check to `URS-OPS` or to the procedures of `URS-PROC-001` as part
of accepting Direction A, and mark the register's initial controls as existing or planned so a
reader can tell which risks are actually controlled today.

### 13. Two evidence labels in `RESEARCH-SLICES.md` are honest but scoped more broadly than the evidence — Non-blocking

Slice 1 concludes "`ADR-EREC-001` **stands**" from Supavisor documentation, and says plainly that
nothing has been executed against a live project. The label is honest and the reasoning about
`set_config(..., true)` being transaction-local, and the transaction being the unit transaction-mode
pooling preserves, is correct. What the slice does not state is what would falsify it, and the
proving task as written could pass without testing anything: a positive-only assertion run over a
direct connection proves nothing about the pooled path. The task must run through the same pooler
mode and port production uses and must assert the **negative** — that a fresh transaction on a
reused pooled connection sees no leaked setting.

Slice 3's *documented* label covers the Supabase Auth **API** surface, and the three directions are
presented as the space. They are the space of API-level options; verifying against the provider's
own stored password hash from inside the database is a fourth shape that the slice does not name. It
would not change the outcome — a Cat 5 system depending on an internal vendor schema is a poor
validation bet, and Direction A is chosen — but the claim should be scoped to the API surface rather
than presented as exhaustive.

### 14. Minor factual inconsistencies — Non-blocking

`specs/RA-INIT.md` §7 and §8 both state "15 of 20" register entries at Risk Priority H; the list
that follows names sixteen, the table contains sixteen, and §8's closing paragraph says "the sixteen
high-priority entries". Separately, `RA-INIT-002` is rated Probability **L**, which §3.4 reserves for
capabilities "supplied by the qualified platform … [where] the custom code only consumes it" — but
its own initial control reads "immutability **enforced in code**", which is §3.4's M baseline for
Cat 5. At M the row becomes Risk Class H and Risk Priority H and joins the RA-DET list, and the
mechanism in question is one WI-001 writes.

`SELECTED-DIRECTION.md` instructs "write `specs/ADR-001.md`"; the artifact is `specs/ADR.md`
carrying `ADR-EREC-001`. And `THIN-SPECS.md`'s out-of-scope list omits `URS-FUNC-004` and
`URS-FUNC-013` although the slice sets due dates and creates the Containment Action, so both are
touched without appearing in either list; relatedly the no-delete negative test covers only
`quality_record`, while `URS-FUNC-013` forbids deleting an Action and the sketch marks `signature`
and `audit_trail` append-only.

## Assumptions that remain unverified

Everything load-bearing in this slice rests on one mechanism that has never been executed. The
`set_config` plus `AFTER` trigger handshake of `ADR-EREC-001` is documentation-grounded only, and
four properties of it are assumed rather than shown: that the transaction-local setting survives the
pooler mode production will actually use; that it does **not** survive into the next transaction on
the same pooled connection; that a `RAISE EXCEPTION` from the trigger aborts every write path the
chosen driver takes, including any that runs outside an explicit transaction, where the
`set_config` would already be gone and every write would be refused; and that the trigger's read of
a never-set custom GUC behaves as intended rather than erroring on an unrecognised parameter.
Research slices 2, 4 and 5 are open, and each blocks something concrete: how immutability and the
no-delete rule are enforced at database level, whether the migration mechanism can hold trigger DDL
in the same ordered stream that `URS-DEVENV-002` demands, and whether SQL-side coverage can be
evidenced at all — without which `URS-QUAL-002`'s threshold means less than it claims.

Direction A adds one more: that a second credential can be issued, rotated and revoked without a
feature this system does not yet have, and that revocation can be kept in step with Supabase Auth
account disablement.

**The first implementation task should therefore be a single end-to-end proof of the write path on a
real Supabase instance**, through the production pooler mode: an attributed write lands in
`audit_trail` with actor, reason and database timestamp; an unattributed write is refused; a fresh
transaction on the same pooled connection sees no leaked setting; a `DELETE` and an `UPDATE` on
`record_no` fail at the database role level; and a direct `UPDATE` of `state` demonstrates whichever
behaviour finding 2 settles on. Nothing else should be built until that returns, because every other
task in the slice inherits it.

## Sound as reviewed

Checked and found no fault with: the `URS-FUNC-023` coverage row, verified field by field against
the URS text; the `URS-FUNC-026` row, including its "Severity is not an input" clause and the
two-transition shape that makes the QA Determination real, which matches both `URS-FUNC-026` and
`CONTEXT.md`; the placement of the Segregation Invariant on the approval transitions only and not on
the `Draft` exit; the Opening Signature at the exit from `Draft` rather than at creation, per
`CONTEXT.md`; the rejection rationales for Options B, C, D, T1 and T2 in `SELECTED-DIRECTION.md`,
each of which I traced back to the URS rows it cites and each of which holds; the ADR gate table's
conclusion that Decision 1 does not warrant an ADR and Decision 2 does, against the three-condition
rule in `patterns/living-documentation.md`; Slice 1's transaction-local reasoning and its promotion
of the `true` flag from a risk row to a named control, which is the right call; `specs/RA-INIT.md`
§5.3's Cat 5 determination and §5.4's preset activation, both consistent with `specs/URS.md` with
nothing to propagate; the §3.4 rating conventions, which are legible and reproducible and applied
consistently across the register apart from `RA-INIT-002`; and the choice of slice itself — the
argument that a Deviation through Triage exercises every Record Spine behaviour the other six types
need is correct, and nothing built here is wasted.
