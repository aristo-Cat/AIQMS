-- WI-001 / IS-2 — Roles and the State Model, both as DATA.
--
-- Two amendments to work/WI-001/THIN-SPECS.md that implementing execute_transition forced:
--   1. Roles had no representation at all. app_user carries no role, yet URS-FUNC-010 requires an
--      unauthorised Role to be rejected and every transition in the declaration names its roles.
--   2. The Python StateModel declaration has no SQL counterpart, so execute_transition would have
--      had to hard-code the machine — a per-type branch in shared code, which
--      SELECTED-DIRECTION.md § Consequences forbids. It lives in tables instead, and the engine
--      reads them.
--
-- This makes the state machine's THIRD encoding explicit rather than accidental (Python declaration,
-- these tables, record_state_catalog). PLAN-DOCTOR finding 2 already required parity tests across
-- all three; T3.2 is where they land.

create table aiqms.app_role (
  role text primary key
);
insert into aiqms.app_role (role) values
  ('Reporter'), ('Investigator'), ('ProcessOwner'), ('QA');

create table aiqms.app_user_role (
  app_user_id uuid not null references aiqms.app_user(id),
  role        text not null references aiqms.app_role(role),
  primary key (app_user_id, role)
);

-- The declaration. from_state '*' means every non-terminal state, so Cancel is one row rather than
-- one row per state — the engine expands it, and adding a state cannot forget to allow cancellation.
create table aiqms.state_transition (
  record_type          aiqms.record_type_t not null,
  from_state           text not null,
  to_state             text not null,
  signature_meaning    text,          -- null = no signature required
  requires_segregation boolean not null default false,
  reason_required      boolean not null default false,
  guard_fn             text,          -- aiqms.<guard_fn>(bigint) returns boolean; null = no guard
  primary key (record_type, from_state, to_state),
  constraint state_transition_to_state_valid
    foreign key (record_type, to_state) references aiqms.record_state_catalog(record_type, state)
);

create table aiqms.state_transition_role (
  record_type aiqms.record_type_t not null,
  from_state  text not null,
  to_state    text not null,
  role        text not null references aiqms.app_role(role),
  primary key (record_type, from_state, to_state, role),
  foreign key (record_type, from_state, to_state)
    references aiqms.state_transition(record_type, from_state, to_state)
);

-- Identifier assignment. URS-FUNC-002 makes record_no immutable, which implies the system owns it;
-- a caller-supplied identifier could collide or be chosen. The prefix is data, so a new Record Type
-- needs no code change.
create table aiqms.record_type_registry (
  record_type aiqms.record_type_t primary key,
  id_prefix   text not null
);
insert into aiqms.record_type_registry (record_type, id_prefix) values ('deviation', 'DEV');

create sequence aiqms.record_no_seq;

create function aiqms.next_record_no(p_record_type aiqms.record_type_t)
returns text
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_prefix text;
begin
  select id_prefix into v_prefix
    from aiqms.record_type_registry where record_type = p_record_type;
  if v_prefix is null then
    raise exception 'AIQMS_UNKNOWN_TYPE: no identifier prefix registered for %', p_record_type;
  end if;
  return v_prefix || '-' || to_char(now(), 'YYYY') || '-'
         || lpad(nextval('aiqms.record_no_seq')::text, 4, '0');
end;
$$;

-- ── The Deviation declaration, mirroring THIN-SPECS.md § State Model as declared data ──────────
insert into aiqms.state_transition
  (record_type, from_state, to_state, signature_meaning, requires_segregation, reason_required,
   guard_fn) values
  ('deviation', 'Draft',      'Registered', 'Opened and submitted for triage', false, false, null),
  ('deviation', 'Registered', 'In triage',  null,                              false, false, null),
  ('deviation', 'In triage',  'Under investigation',
       'QA Triage approved; investigation required', true, false, 'guard_triage_to_investigation'),
  ('deviation', 'In triage',  'In actions',
       'QA Triage approved; no investigation required', true, false, 'guard_triage_to_actions'),
  ('deviation', '*',          'Cancelled',  null,                              false, true,  null);

insert into aiqms.state_transition_role (record_type, from_state, to_state, role) values
  ('deviation', 'Draft', 'Registered', 'Reporter'),
  ('deviation', 'Draft', 'Registered', 'Investigator'),
  ('deviation', 'Draft', 'Registered', 'ProcessOwner'),
  ('deviation', 'Draft', 'Registered', 'QA'),
  ('deviation', 'Registered', 'In triage', 'QA'),
  ('deviation', 'In triage', 'Under investigation', 'QA'),
  ('deviation', 'In triage', 'In actions', 'QA'),
  ('deviation', '*', 'Cancelled', 'QA');

-- ── Guards. Type-specific logic lives HERE, never in the engine ────────────────────────────────
-- URS-FUNC-003 (due date approved by QA), FUNC-024 (severity), FUNC-025 (containment resolved),
-- and the recorded QA Determination with its justification.
create function aiqms.guard_triage_complete(p_qr_id bigint)
returns boolean
language sql
stable
security definer
set search_path = aiqms, pg_catalog
as $$
  select d.severity is not null
     and (d.containment_action_id is not null
          or d.containment_not_applicable_justification is not null)
     and d.investigation_required is not null
     and d.investigation_determination_justification is not null
     and qr.due_date_approved_by is not null
  from aiqms.deviation d
  join aiqms.quality_record qr on qr.id = d.quality_record_id
  where d.quality_record_id = p_qr_id;
$$;

-- `when` reads investigation_required — the recorded QA Determination — and never severity.
create function aiqms.guard_triage_to_investigation(p_qr_id bigint)
returns boolean
language sql
stable
security definer
set search_path = aiqms, pg_catalog
as $$
  select aiqms.guard_triage_complete(p_qr_id)
     and (select investigation_required from aiqms.deviation where quality_record_id = p_qr_id);
$$;

create function aiqms.guard_triage_to_actions(p_qr_id bigint)
returns boolean
language sql
stable
security definer
set search_path = aiqms, pg_catalog
as $$
  select aiqms.guard_triage_complete(p_qr_id)
     and not (select investigation_required from aiqms.deviation where quality_record_id = p_qr_id);
$$;

-- New tables join the audit trail and the immutability layers; nothing is exempt.
create trigger trg_audit_app_user_role
  after insert or update on aiqms.app_user_role
  for each row execute function aiqms.write_audit_trail('app_user_id', '');
alter table aiqms.app_user_role enable always trigger trg_audit_app_user_role;

create trigger trg_no_truncate_app_user_role before truncate on aiqms.app_user_role
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.app_user_role enable always trigger trg_no_truncate_app_user_role;

grant select on aiqms.app_role, aiqms.app_user_role, aiqms.state_transition,
                aiqms.state_transition_role, aiqms.record_type_registry to aiqms_app;
revoke insert, update, delete, truncate on aiqms.app_role, aiqms.app_user_role,
       aiqms.state_transition, aiqms.state_transition_role, aiqms.record_type_registry
  from aiqms_app;
