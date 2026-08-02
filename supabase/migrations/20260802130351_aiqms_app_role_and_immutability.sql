-- WI-001 / T1.4 + T1.7 — the application role and the three immutability layers.
-- Source: work/WI-001/RESEARCH-SLICES.md §2, ADR-DATA-001.
--
-- SECURITY NOTE: this role is created WITHOUT a password on purpose. Supabase requires password
-- authentication, so as written `aiqms_app` cannot connect. The password is set out of band with
-- `alter role aiqms_app password '…'` and recorded in a git-ignored .env — never in this file,
-- which lives in a public repository.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'aiqms_app') then
    create role aiqms_app login noinherit;
  end if;
end
$$;

grant usage on schema aiqms to aiqms_app;

-- Read is granted; every write verb is withheld. TRUNCATE is revoked EXPLICITLY: the GRANT synopsis
-- lists it beside DELETE as a separately grantable privilege, so revoking DELETE does not remove it.
grant select on all tables in schema aiqms to aiqms_app;
revoke insert, update, delete, truncate on all tables in schema aiqms from aiqms_app;
revoke all on all functions in schema aiqms from public;
revoke all on all functions in schema aiqms from aiqms_app;

alter default privileges in schema aiqms grant select on tables to aiqms_app;

-- ── Layer 2 ────────────────────────────────────────────────────────────────────────────────────
-- This layer exists because ADR-DATA-001 runs the write path as the table owner, which Layer 1
-- cannot restrain. A defect inside a SECURITY DEFINER function is the failure mode it catches.
create function aiqms.reject_mutation() returns trigger
language plpgsql
set search_path = aiqms, pg_catalog
as $$
begin
  raise exception
    'AIQMS_APPEND_ONLY: % on %.% is refused; the table is append-only (URS-FUNC-008, URS-DATA-004)',
    TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
end;
$$;

create trigger trg_append_only_audit_trail
  before update or delete on aiqms.audit_trail
  for each row execute function aiqms.reject_mutation();
alter table aiqms.audit_trail enable always trigger trg_append_only_audit_trail;

create trigger trg_append_only_signature
  before update or delete on aiqms.signature
  for each row execute function aiqms.reject_mutation();
alter table aiqms.signature enable always trigger trg_append_only_signature;

create trigger trg_append_only_security_event
  before update or delete on aiqms.security_event
  for each row execute function aiqms.reject_mutation();
alter table aiqms.security_event enable always trigger trg_append_only_security_event;

-- URS-FUNC-002: the identifier is never modifiable, by anyone, including the write-path functions.
create function aiqms.reject_record_no_change() returns trigger
language plpgsql
set search_path = aiqms, pg_catalog
as $$
begin
  if NEW.record_no is distinct from OLD.record_no then
    raise exception
      'AIQMS_IMMUTABLE_RECORD_NO: record_no cannot be changed (% -> %) (URS-FUNC-002)',
      OLD.record_no, NEW.record_no;
  end if;
  return NEW;
end;
$$;

create trigger trg_immutable_record_no
  before update on aiqms.quality_record
  for each row execute function aiqms.reject_record_no_change();
alter table aiqms.quality_record enable always trigger trg_immutable_record_no;

-- URS-FUNC-008: no delete path is exposed on the record tables either.
create trigger trg_no_delete_quality_record
  before delete on aiqms.quality_record
  for each row execute function aiqms.reject_mutation();
alter table aiqms.quality_record enable always trigger trg_no_delete_quality_record;

create trigger trg_no_delete_deviation
  before delete on aiqms.deviation
  for each row execute function aiqms.reject_mutation();
alter table aiqms.deviation enable always trigger trg_no_delete_deviation;

create trigger trg_no_delete_record_action
  before delete on aiqms.record_action
  for each row execute function aiqms.reject_mutation();
alter table aiqms.record_action enable always trigger trg_no_delete_record_action;

create trigger trg_no_delete_app_user
  before delete on aiqms.app_user
  for each row execute function aiqms.reject_mutation();
alter table aiqms.app_user enable always trigger trg_no_delete_app_user;

-- ── Layer 3 ────────────────────────────────────────────────────────────────────────────────────
-- Row-level triggers never fire on TRUNCATE — the docs allow TRUNCATE triggers only FOR EACH
-- STATEMENT. Without this, a TRUNCATE of audit_trail would be invisible to the audit trail itself.
create function aiqms.reject_truncate() returns trigger
language plpgsql
set search_path = aiqms, pg_catalog
as $$
begin
  raise exception
    'AIQMS_NO_TRUNCATE: TRUNCATE of %.% is refused (URS-FUNC-008, URS-DATA-004)',
    TG_TABLE_SCHEMA, TG_TABLE_NAME;
end;
$$;

create trigger trg_no_truncate_audit_trail    before truncate on aiqms.audit_trail
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.audit_trail enable always trigger trg_no_truncate_audit_trail;

create trigger trg_no_truncate_signature      before truncate on aiqms.signature
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.signature enable always trigger trg_no_truncate_signature;

create trigger trg_no_truncate_security_event before truncate on aiqms.security_event
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.security_event enable always trigger trg_no_truncate_security_event;

create trigger trg_no_truncate_quality_record before truncate on aiqms.quality_record
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.quality_record enable always trigger trg_no_truncate_quality_record;

create trigger trg_no_truncate_deviation      before truncate on aiqms.deviation
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.deviation enable always trigger trg_no_truncate_deviation;

create trigger trg_no_truncate_record_action  before truncate on aiqms.record_action
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.record_action enable always trigger trg_no_truncate_record_action;

create trigger trg_no_truncate_app_user       before truncate on aiqms.app_user
  for each statement execute function aiqms.reject_truncate();
alter table aiqms.app_user enable always trigger trg_no_truncate_app_user;

-- ── Conformance surface ────────────────────────────────────────────────────────────────────────
-- ENABLE ALWAYS is one ALTER TABLE per trigger and is trivially forgotten, and T1.2 proved on this
-- instance that forgetting it fails SILENTLY. This view is what the conformance test reads.
create view aiqms.trigger_conformance as
select n.nspname            as schema_name,
       c.relname            as table_name,
       t.tgname             as trigger_name,
       t.tgenabled          as enabled_flag,
       t.tgenabled = 'A'    as is_enable_always
from pg_trigger t
join pg_class c     on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'aiqms'
  and not t.tgisinternal;

grant select on aiqms.trigger_conformance to aiqms_app;
