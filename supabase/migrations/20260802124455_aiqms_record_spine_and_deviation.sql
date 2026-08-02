-- WI-001 / T1.5 — Record Spine and Deviation.
-- Source of truth: work/WI-001/THIN-SPECS.md § Thin DS — schema.
-- Objects live in schema `aiqms`, not `public`: the specs do not constrain the schema name, and a
-- dedicated schema keeps the later REVOKEs independent of whatever `public` grants by default.

create schema if not exists aiqms;

create type aiqms.record_type_t as enum ('deviation');
create type aiqms.severity_t    as enum ('critical', 'major', 'minor');
create type aiqms.user_status_t as enum ('active', 'disabled');

-- State validity is per Record Type, so it cannot be one global enum.
create table aiqms.record_state_catalog (
  record_type aiqms.record_type_t not null,
  state       text                not null,
  is_terminal boolean             not null,
  primary key (record_type, state)
);

create table aiqms.app_user (
  id                          uuid primary key,
  user_id                     text not null unique,          -- ESIG-004/007/013
  full_name                   text not null,                 -- ESIG-002, frozen into each signature
  auth_user_id                uuid unique,                   -- Supabase Auth: login only
  signature_secret_hash       text,                          -- Direction A, null until enrolled
  signature_secret_set_at     timestamptz,
  signature_secret_set_tz     text,
  signature_secret_expires_at timestamptz,                   -- ESIG-009 rotation
  status                      aiqms.user_status_t not null default 'active',
  disabled_at                 timestamptz,
  disabled_tz                 text,
  constraint app_user_user_id_min_length check (char_length(user_id) >= 6),   -- ESIG-013
  constraint app_user_disabled_consistent
    check ((status = 'disabled') = (disabled_at is not null)),
  constraint app_user_disabled_tz_paired
    check (num_nonnulls(disabled_at, disabled_tz) in (0, 2)),
  constraint app_user_secret_set_paired
    check (num_nonnulls(signature_secret_hash, signature_secret_set_at, signature_secret_set_tz)
           in (0, 3))
);

create table aiqms.quality_record (
  id                   bigserial primary key,
  record_no            text                not null unique,  -- FUNC-002, immutable
  record_type          aiqms.record_type_t not null,
  title                text                not null,
  description          text                not null,
  originator_id        uuid                not null references aiqms.app_user(id),
  owner_id             uuid                not null references aiqms.app_user(id),
  area                 text                not null,
  due_date             date                not null,         -- proposed by the opener
  due_date_approved_by uuid                references aiqms.app_user(id),   -- FUNC-003, QA
  due_date_approved_at timestamptz,
  due_date_approved_tz text,
  state                text                not null,
  created_at           timestamptz         not null,
  created_tz           text                not null,         -- ADR-DATA-002
  cancelled_at         timestamptz,
  cancelled_tz         text,
  cancel_reason        text,
  constraint quality_record_state_valid
    foreign key (record_type, state) references aiqms.record_state_catalog(record_type, state),
  constraint quality_record_id_type_unique unique (id, record_type),  -- detail tables pin their type
  constraint quality_record_cancel_triple
    check (num_nonnulls(cancelled_at, cancelled_tz, cancel_reason) in (0, 3)),
  constraint quality_record_due_approval_triple
    check (num_nonnulls(due_date_approved_by, due_date_approved_at, due_date_approved_tz) in (0, 3)),
  constraint quality_record_no_not_blank    check (char_length(btrim(record_no)) > 0),
  constraint quality_record_title_not_blank check (char_length(btrim(title)) > 0),
  constraint quality_record_desc_not_blank  check (char_length(btrim(description)) > 0),
  constraint quality_record_area_not_blank  check (char_length(btrim(area)) > 0)
);

create table aiqms.record_action (
  id                  bigserial primary key,
  quality_record_id   bigint not null references aiqms.quality_record(id),
  owner_id            uuid   not null references aiqms.app_user(id),
  description         text   not null,
  due_date            date   not null,
  status              text   not null,
  completion_evidence text,
  created_at          timestamptz not null,
  created_tz          text        not null,
  constraint record_action_id_record_unique unique (id, quality_record_id),
  constraint record_action_desc_not_blank check (char_length(btrim(description)) > 0)
);

create table aiqms.deviation (
  quality_record_id         bigint primary key,
  record_type               aiqms.record_type_t not null
                              generated always as ('deviation'::aiqms.record_type_t) stored,
  instruction_departed_from text not null,                   -- FUNC-023
  departure_description     text not null,
  detected_at               timestamptz not null,
  detected_tz               text        not null,
  detection_method          text        not null,
  product_or_batch          text,                            -- nullable: "where applicable"
  severity                  aiqms.severity_t,                -- null until Triage; FUNC-024
  containment_action_id     bigint,
  containment_not_applicable_justification  text,
  investigation_required                    boolean,         -- the QA Determination outcome
  investigation_determination_justification text,
  constraint deviation_record_type_matches
    foreign key (quality_record_id, record_type)
    references aiqms.quality_record(id, record_type),        -- cannot attach to another type
  constraint deviation_containment_same_record
    foreign key (containment_action_id, quality_record_id)
    references aiqms.record_action(id, quality_record_id),    -- FUNC-025
  constraint deviation_containment_exclusive
    check (num_nonnulls(containment_action_id,
                        containment_not_applicable_justification) <= 1),
  constraint deviation_determination_paired
    check (num_nonnulls(investigation_required,
                        investigation_determination_justification) in (0, 2)),
  constraint deviation_instruction_not_blank
    check (char_length(btrim(instruction_departed_from)) > 0),
  constraint deviation_departure_not_blank
    check (char_length(btrim(departure_description)) > 0),
  constraint deviation_method_not_blank
    check (char_length(btrim(detection_method)) > 0)
);

create table aiqms.signature (                               -- append-only
  id                     bigserial primary key,
  quality_record_id      bigint not null references aiqms.quality_record(id),
  signer_id              uuid   not null references aiqms.app_user(id),
  signer_name_at_signing text   not null,                    -- ESIG-002, frozen
  meaning                text   not null,                    -- ESIG-002
  transition             text   not null,                    -- ESIG-003
  content_hash           text   not null,                    -- ESIG-017 tamper evidence
  signed_at              timestamptz not null,
  signed_tz              text        not null,
  constraint signature_meaning_not_blank check (char_length(btrim(meaning)) > 0),
  constraint signature_hash_not_blank    check (char_length(btrim(content_hash)) > 0)
);

create table aiqms.security_event (                          -- ESIG-012; append-only
  id                bigserial primary key,
  event_type        text not null,
  app_user_id       uuid   references aiqms.app_user(id),
  quality_record_id bigint references aiqms.quality_record(id),
  detail            text not null,
  occurred_at       timestamptz not null,
  occurred_tz       text        not null,
  constraint security_event_type_not_blank check (char_length(btrim(event_type)) > 0)
);

create table aiqms.audit_trail (                             -- written only by trigger
  id                bigserial primary key,
  quality_record_id bigint,                                  -- FUNC-009: assemblable per record
  table_name        text not null,
  row_id            bigint not null,
  operation         text not null,
  column_name       text,
  old_value         text,
  new_value         text,
  actor_id          uuid not null,
  reason            text not null,                           -- EREC-005: never null
  occurred_at       timestamptz not null,
  occurred_tz       text        not null,
  constraint audit_trail_operation_known check (operation in ('insert', 'update')),
  constraint audit_trail_reason_not_blank check (char_length(btrim(reason)) > 0)
);

create index audit_trail_by_record on aiqms.audit_trail (quality_record_id, id);

-- FUNC-001: a spine row without its detail row is not a record. Deferred so a function may insert
-- the two in either order within one transaction, but never commit with only one.
create function aiqms.assert_detail_row_present() returns trigger
language plpgsql
set search_path = aiqms, pg_catalog
as $$
begin
  if NEW.record_type = 'deviation'
     and not exists (select 1 from aiqms.deviation d where d.quality_record_id = NEW.id) then
    raise exception
      'AIQMS_INCOMPLETE_RECORD: quality_record % of type % has no detail row (URS-FUNC-001)',
      NEW.id, NEW.record_type;
  end if;
  return null;
end;
$$;

create constraint trigger trg_quality_record_detail_present
  after insert or update on aiqms.quality_record
  deferrable initially deferred
  for each row execute function aiqms.assert_detail_row_present();

-- The six Deviation states of work/WI-001/THIN-SPECS.md § Thin DS — State Model as declared data.
insert into aiqms.record_state_catalog (record_type, state, is_terminal) values
  ('deviation', 'Draft',               false),
  ('deviation', 'Registered',          false),
  ('deviation', 'In triage',           false),
  ('deviation', 'Under investigation', false),
  ('deviation', 'In actions',          false),
  ('deviation', 'Cancelled',           true);
