---
type: thin-specs
work_item: WI-001
status: draft
version: "0.2"
created: "2026-08-02"
updated: "2026-08-02"
---

# THIN-SPECS — WI-001

Minimal URS/FS/DS coverage for one slice. Not the system FS: this says only what must be true for
**Record Spine + Deviation through QA Triage** to be implemented and traced.

> **Version 0.2, 2026-08-02.** Version 0.1 was reviewed independently
> (`work/WI-001/RESEARCH-REVIEW.md`, verdict `changes required`, ten blocking findings) and every
> one of them is addressed here. The three that changed the design rather than the wording:
> `URS-DATA-004` requires modification to be *prevented*, not only recorded — closed by
> `ADR-DATA-001`; a PostgreSQL `timestamptz` does not preserve a time zone — closed by
> `ADR-DATA-002`; and nothing in v0.1 froze a signed record, leaving `URS-ESIG-017` and the initial
> control of `RA-INIT-014` with no implementation anywhere.

Design constrained by `specs/ADR.md` → `ADR-EREC-001`, `ADR-DATA-001`, `ADR-DATA-002` (all accepted
2026-08-02) and by `work/WI-001/SELECTED-DIRECTION.md`.

## Slice boundary

**In**: creating a Deviation as a Quality Record; the immutable identifier; originator, owner, area,
and a due date proposed by the opener and approved by Quality Assurance; the Opening Signature at
the exit from `Draft`; QA Triage as a signed approval act carrying Severity, the Containment Action
or its justification, and the QA Determination on the Investigation block; the Segregation
Invariant on that approval; Cancellation from any non-terminal state; and the audit trail beneath
all of it.

**Out**: everything after the exit from `In triage` — the Investigation block content, the Impact
Assessment, closure and its gates. Also out: attachments (`URS-FUNC-005`), Record Links
(`URS-FUNC-006`), search (`URS-FUNC-007`), reports (`URS-FUNC-014`), the AI Assistant, and the
other six Record Types. Actions appear only as far as the Containment Action Triage requires.

### State Model implemented

Taken verbatim from the Deviation model in `CONTEXT.md`, front portion only:

```
Draft ──⊕ Opening Signature (opener)──> Registered ──> In triage
In triage ──⊕ Triage (QA)──> Under investigation      (QA Determination required an Investigation)
In triage ──⊕ Triage (QA)──> In actions               (QA Determination waived it)
<any non-terminal state> ──> Cancelled                (reason required; terminal)
```

Two readings are recorded rather than assumed. **First**: `CONTEXT.md` annotates `In triage` with
the signature symbol; this slice places the signature on the **exit** from `In triage`, because
that is the point at which Severity, the Containment Action and the QA Determination all exist and
can be attested together. Signing on entry would attest an empty triage. **Second**: `In triage` is
a real state, not a synonym for the transition — v0.1 of this document dropped it and then referred
to it, which the review caught.

`Under investigation` and `In actions` are reachable here and carry no behaviour yet; they exist so
the QA Determination has two genuine destinations.

## URS coverage

Each row states what this slice actually implements. Where a requirement is only partly realised,
the row says which part.

| URS-ID | What this slice realizes |
|---|---|
| `URS-FUNC-001` | A Deviation is created only through `create_quality_record`, which inserts the spine and the detail row in one transaction; a deferred constraint trigger refuses a commit leaving a `quality_record` without the detail row its `record_type` requires. Mandatory minimum fields are `NOT NULL` in the schema, so incompleteness is refused by the database, not only by the application |
| `URS-FUNC-002` | `record_no` unique and `NOT NULL`; a `BEFORE UPDATE` trigger raises if it changes. Direct `UPDATE` is unavailable to the application role in any case (`ADR-DATA-001`) |
| `URS-FUNC-003` | Originator, owner, area, and a due date **proposed by the opener and approved by Quality Assurance** — `due_date_approved_by` and `due_date_approved_at` are `NOT NULL` before the record may leave `In triage`. Owner and due date changes go through a function that requires a reason, captured in the audit trail |
| `URS-FUNC-008` | Cancellation reachable from **any non-terminal state**, requires a reason, terminal. `DELETE` is revoked from the application role on every table in scope (`ADR-DATA-001`), so no delete path exists to expose |
| `URS-FUNC-009` | Audit trail covers, for this slice: creation, every Record Spine and Deviation field change, every State transition, every electronic signature, and Cancellation. Each entry carries `quality_record_id`, so a record's trail is assemblable without joining across tables by hand |
| `URS-FUNC-010` | A transition executes only through `execute_transition`, which rejects a transition the State Model does not declare, and rejects a declared transition attempted by a Role it does not authorise |
| `URS-FUNC-011` (a) | The exit from `Draft` requires the Opening Signature of the user opening the record |
| `URS-FUNC-011` (b) | The exit from `In triage` requires an electronic signature; the transition does not complete without it |
| `URS-FUNC-012` | The **signer of the Opening Signature** cannot perform the Triage approval. That comparand — rather than the account that created the draft row — was undefined in v0.1 and is now settled in `CONTEXT.md`. Enforced inside `execute_transition`, below the application |
| `URS-FUNC-015` | The QA Determination on the Investigation block is a signed act carrying a recorded justification, made at the step the Record Type declares (`In triage`), and a waived block is not re-enabled without a new determination. Partial: only the Deviation→Investigation determination exists in this slice |
| `URS-FUNC-023` | A Deviation records the approved instruction departed from, what the departure was, when and how it was detected, the area, and the product or batch where applicable |
| `URS-FUNC-024` | Triage sets Severity, resolves the Containment Action, makes the QA Determination, and is signed and subject to segregation |
| `URS-FUNC-025` | A check constraint makes a recorded Containment Action and a not-applicable justification mutually exclusive; `execute_transition` refuses to leave `In triage` with neither |
| `URS-FUNC-026` | The determination is made at Triage by the reviewing QA user with its justification, covered by the Triage signature. **No code path reads `severity` to select the destination state** — this is a review criterion and a test, not a comment |
| `URS-FUNC-057` | Two of the four invariants land here — no role deletes a Quality Record, and nobody approves what they opened. Both live in the database layer where no role can disable them (`ADR-DATA-001`) |
| `URS-EREC-005` | Every audit trail entry carries user, old value, new value, timestamp with its zone, and a reason for change. `reason` is `NOT NULL`; the trigger refuses a write whose session context lacks an actor, a reason or a zone |
| `URS-EREC-013` | *Attributable* — an unattributable write is refused. *Contemporaneous* — instants written by the database with their originating zone (`ADR-DATA-002`). *Original* and *Enduring* — no delete path, no update path outside the audited functions |
| `URS-DATA-003` | Every recorded instant is a `timestamptz` **plus** an adjacent IANA zone column, written together (`ADR-DATA-002`). Partial: presentation in printouts is `URS-UI-005` and is out of this slice |
| `URS-DATA-004` | *Prevented*: `INSERT`/`UPDATE`/`DELETE` revoked from the application role on every table in scope; writes only through `SECURITY DEFINER` functions. *Detectable*: the `ADR-EREC-001` trigger beneath them |
| `URS-ESIG-002` | A signature row stores the signer's full legible name **as it was at signing**, the instant with its zone, and the meaning of the signature. Partial: on-screen and printout rendering is `URS-UI-004`/`005` and is out of this slice |
| `URS-ESIG-003` | A signature row references the Quality Record and the specific transition it attests |
| `URS-ESIG-004` | One signature credential per `app_user`, and `app_user.user_id` is unique — no credential is shared or reassigned |
| `URS-ESIG-007` | Satisfied through **ID uniqueness**: `user_id` is unique, so two persons cannot hold the same ID and therefore cannot hold the same ID-and-password combination, whatever their passwords are. A salted hash makes password comparison impossible by design, so this is the only honest way to satisfy the requirement |
| `URS-ESIG-010`/`011` | Disabling an `app_user` disables its signature credential in the same act; `execute_transition` refuses a signature from a disabled user. Under Direction A this is **this system's** responsibility — disabling the Supabase Auth login account does not by itself revoke the signature credential, and the two are disabled together or the control is illusory |
| `URS-ESIG-012` | A failed signature attempt is written to `security_event` by the signature function. The trigger-driven audit trail cannot see it — a rejected signature writes no row — so this is a separate, explicit write. Partial: the periodic report to management has no owner (see Open items) |
| `URS-ESIG-013`/`014` | User ID minimum 6 and signature password minimum 12, enforced at enrolment; the password is re-entered for every signature with no session-scoped caching |
| `URS-ESIG-017` | On signing, a hash over the canonical serialisation of the attested content is stored in the signature row. Any later change makes the hash mismatch, so the record renders as no longer validly signed — the second limb the requirement permits (*"any subsequent modification makes the record appear as unsigned"*) |

## Thin DS — schema

```sql
create type record_type_t is enum ('deviation');            -- one per slice; grows with the types
create type severity_t    is enum ('critical','major','minor');
create type user_status_t  is enum ('active','disabled');

-- State validity is per Record Type, so it cannot be one global enum.
record_state_catalog
  record_type   record_type_t not null
  state         text          not null
  is_terminal   boolean       not null
  primary key (record_type, state)

app_user
  id                      uuid primary key
  user_id                 text not null unique          -- ESIG-004/007/013, min length 6
  full_name               text not null                 -- ESIG-002, frozen into each signature
  auth_user_id            uuid unique                   -- Supabase Auth: login only
  signature_secret_hash   text                          -- Direction A, null until enrolled
  signature_secret_set_at timestamptz
  signature_secret_set_tz text
  signature_secret_expires_at timestamptz               -- ESIG-009 rotation
  status                  user_status_t not null default 'active'
  disabled_at             timestamptz
  disabled_tz             text
  check ((status = 'disabled') = (disabled_at is not null))

quality_record
  id                    bigserial primary key
  record_no             text not null unique            -- FUNC-002, immutable
  record_type           record_type_t not null
  title                 text not null
  description           text not null
  originator_id         uuid not null references app_user(id)
  owner_id              uuid not null references app_user(id)
  area                  text not null
  due_date              date not null                   -- proposed by the opener
  due_date_approved_by  uuid references app_user(id)    -- FUNC-003, QA
  due_date_approved_at  timestamptz
  due_date_approved_tz  text
  state                 text not null
  created_at            timestamptz not null
  created_tz            text not null                   -- ADR-DATA-002
  cancelled_at          timestamptz
  cancelled_tz          text
  cancel_reason         text
  foreign key (record_type, state) references record_state_catalog(record_type, state)
  unique (id, record_type)                              -- lets detail tables pin their type
  check (num_nonnulls(cancelled_at, cancelled_tz, cancel_reason) in (0, 3))
  check (num_nonnulls(due_date_approved_by, due_date_approved_at, due_date_approved_tz) in (0, 3))

deviation
  quality_record_id  bigint primary key
  record_type        record_type_t not null generated always as ('deviation') stored
  instruction_departed_from  text not null              -- FUNC-023
  departure_description      text not null
  detected_at                timestamptz not null
  detected_tz                text not null
  detection_method           text not null
  product_or_batch           text                       -- nullable: "where applicable"
  severity                   severity_t                 -- null until Triage; FUNC-024
  containment_action_id      bigint
  containment_not_applicable_justification text
  investigation_required     boolean                    -- the QA Determination outcome
  investigation_determination_justification text
  foreign key (quality_record_id, record_type)
      references quality_record(id, record_type)        -- a deviation row cannot attach to another type
  foreign key (containment_action_id, quality_record_id)
      references record_action(id, quality_record_id)   -- FUNC-025: containment belongs to THIS record
  check (num_nonnulls(containment_action_id,
                      containment_not_applicable_justification) <= 1)
  check (num_nonnulls(investigation_required,
                      investigation_determination_justification) in (0, 2))

record_action
  id                bigserial primary key
  quality_record_id bigint not null references quality_record(id)
  owner_id          uuid   not null references app_user(id)
  description       text   not null
  due_date          date   not null
  status            text   not null
  completion_evidence text
  created_at        timestamptz not null
  created_tz        text not null
  unique (id, quality_record_id)                        -- target of the containment FK above

signature                                                -- append-only
  id                    bigserial primary key
  quality_record_id     bigint not null references quality_record(id)
  signer_id             uuid   not null references app_user(id)
  signer_name_at_signing text  not null                 -- ESIG-002, frozen
  meaning               text   not null                 -- ESIG-002
  transition            text   not null                 -- ESIG-003
  content_hash          text   not null                 -- ESIG-017 tamper evidence
  signed_at             timestamptz not null
  signed_tz             text not null

security_event                                           -- ESIG-012; append-only
  id                bigserial primary key
  event_type        text not null                        -- 'signature_attempt_failed', ...
  app_user_id       uuid references app_user(id)
  quality_record_id bigint references quality_record(id)
  detail            text not null
  occurred_at       timestamptz not null
  occurred_tz       text not null

audit_trail                                              -- written only by trigger
  id                bigserial primary key
  quality_record_id bigint                               -- FUNC-009: assemblable per record
  table_name        text not null
  row_id            bigint not null
  operation         text not null                        -- insert | update
  column_name       text
  old_value         text
  new_value         text
  actor_id          uuid not null
  reason            text not null                        -- EREC-005: never null
  occurred_at       timestamptz not null
  occurred_tz       text not null
```

**A deferred constraint trigger** (`deferrable initially deferred`) asserts at commit that every
`quality_record` has the detail row its `record_type` requires. This is what makes `URS-FUNC-001`
true of the database rather than of the application, and it was the review's first finding against
v0.1.

## Thin DS — write path (`ADR-DATA-001`)

`INSERT`, `UPDATE` and `DELETE` are revoked from the application role on every table above. The
application may call only:

| Function | Enforces |
|---|---|
| `create_quality_record(...)` | Spine and detail inserted together; minimum fields present |
| `update_record_field(...)` | Reason required; field is not `record_no`; record is not terminal |
| `execute_transition(...)` | Transition declared in the State Model · Role authorised · signature applied and verified where required · Segregation Invariant against the Opening Signature signer · guard satisfied (for the `In triage` exit: severity set, containment resolved, determination recorded with justification, due date approved) |
| `apply_signature(...)` | Signature password verified against `signature_secret_hash` · user `active` and credential unexpired · `content_hash` computed and stored · on failure, a `security_event` row and no state change |
| `cancel_quality_record(...)` | Reason required · source state non-terminal |

Every function pins its `search_path`. The `ADR-EREC-001` trigger writes the audit trail beneath
all of them, refusing any write whose transaction lacks `aiqms.actor_id`, `aiqms.reason` or
`aiqms.tz`.

## Thin DS — session context (`ADR-EREC-001`, `ADR-DATA-002`)

```sql
SELECT set_config('aiqms.actor_id', $1, true);   -- true = transaction-local; see RESEARCH-SLICES §1
SELECT set_config('aiqms.reason',   $2, true);
SELECT set_config('aiqms.tz',       $3, true);   -- IANA zone of the acting user
```

The transaction-local flag is a control, not hygiene: a session-level setting would survive into
another client's transaction under connection pooling and could attribute a write to the wrong
user. A test asserts the settings are absent at the start of a fresh transaction.

## Thin DS — State Model as declared data

One declaration per Record Type; a single engine executes it, and `execute_transition` is generated
from or verified against the same declaration so the two cannot drift. No `record_type` branch may
appear in the engine — that discipline is what keeps Option A honest and it is a review criterion.

```python
DEVIATION = StateModel(
    initial="Draft",
    states=["Draft", "Registered", "In triage",
            "Under investigation", "In actions", "Cancelled"],
    terminal=["Cancelled"],
    transitions=[
        Transition("Draft", "Registered",
                   roles={"Reporter", "Investigator", "ProcessOwner", "QA"},
                   signature=SignatureRequirement.OPENING),
        Transition("Registered", "In triage", roles={"QA"}),
        Transition("In triage", "Under investigation",
                   roles={"QA"}, signature=SignatureRequirement.APPROVAL,
                   invariants=[SEGREGATION], guard=triage_complete,
                   when=lambda d: d.investigation_required is True),
        Transition("In triage", "In actions",
                   roles={"QA"}, signature=SignatureRequirement.APPROVAL,
                   invariants=[SEGREGATION], guard=triage_complete,
                   when=lambda d: d.investigation_required is False),
        Transition(ANY_NON_TERMINAL, "Cancelled", roles={"QA"}, reason=Required),
    ],
)
```

`when` reads `investigation_required` — the recorded QA Determination — and never `severity`.

## Acceptance criteria

Positive path, which is also the flow evidence to capture:

1. A Reporter creates a Deviation with the minimum fields; it lands in `Draft`.
2. The Reporter exits `Draft` with the Opening Signature — ID plus signature password re-entered —
   and the record is `Registered`. The signature row carries the signer's name as at signing, the
   meaning, the instant with its zone, and the content hash.
3. QA moves it to `In triage`, sets Severity, records a Containment Action, approves the due date,
   records the QA Determination requiring an Investigation with its justification, and signs. The
   record moves to `Under investigation`.
4. The audit trail, queried by `quality_record_id` alone, shows creation, every field change with
   old and new value, both signatures, all transitions, each with actor, reason, instant and zone.

Negative tests, mandatory under `URS-TEST-004`:

- The Opening Signature signer attempts the Triage approval → rejected (`URS-FUNC-012`).
- Exit from `In triage` with neither a Containment Action nor a justification → rejected (`025`).
- Exit from `In triage` without a signature → does not complete (`URS-FUNC-011`).
- Exit from `In triage` with the due date unapproved → rejected (`URS-FUNC-003`).
- A transition attempted by an unauthorised Role, and a transition not declared at all → both
  rejected (`URS-FUNC-010`).
- `UPDATE quality_record SET state = 'In actions'` issued directly by the application role →
  **rejected for want of privilege** (`URS-DATA-004`, `ADR-DATA-001`). This is the test v0.1 could
  not have passed.
- `UPDATE quality_record SET record_no = …` → rejected (`URS-FUNC-002`).
- `DELETE FROM quality_record` by the application role → rejected for want of privilege (`008`).
- `INSERT` into `quality_record` without its `deviation` row → commit refused (`URS-FUNC-001`).
- A write with no `aiqms.actor_id`, or no `aiqms.reason`, or no `aiqms.tz` → rejected
  (`URS-EREC-005`, `ADR-DATA-002`).
- A signature attempted with the wrong password → rejected, no state change, and a
  `security_event` row written (`URS-ESIG-012`).
- A signature attempted by a `disabled` user → rejected (`URS-ESIG-010`/`011`).
- A field of a signed record changed afterwards → the stored `content_hash` no longer matches, and
  the record renders as no longer validly signed (`URS-ESIG-017`).
- Session settings asserted absent at the start of a fresh transaction (`ADR-EREC-001`).

## Open items

- **URS gap — `URS-ESIG-008`.** *"It must be ensured that the correct functioning of the credentials
  (ID and password) is checked periodically."* Under Direction A the signature credential belongs
  to this system, so this is now this system's periodic check — and no `URS-OPS` requirement owns
  it. `URS-OPS-002` covers the user access review, which is not the same thing. This needs a URS
  amendment, not an invented requirement here; it does not block WI-001 because it is an
  operational control, not a build task.
- **`URS-ESIG-012` reporting limb has no owner.** The logging half is implemented here via
  `security_event`. The *"results reported periodically to management"* half belongs in `URS-OPS`
  and is absent. Same disposition as above.
- **`app_user` minimum.** This slice needs enough of `app_user` to attribute, authorise and verify
  a signature. Full user administration (`URS-FUNC-056`, `URS-FUNC-058`, `URS-SEC-003`) is a later
  work item; the enrolment path built here is the minimum and must be revisited then, not treated
  as finished.
- **MFA is not in scope.** `URS-SEC-002` places multi-factor authentication on remote login, not on
  the signature.
