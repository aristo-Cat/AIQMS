-- WI-001 / T1.6 — the audit trail (ADR-EREC-001, ADR-DATA-002).
--
-- Amendment to work/WI-001/THIN-SPECS.md § Thin DS — schema, found by implementing it:
-- `audit_trail.row_id` was specified `bigint`, but `app_user.id` is a `uuid`. Auditing user
-- administration is not optional (URS-ESIG-010/011 disable a user, and that act must be trailed),
-- so `row_id` becomes `text` and carries the primary key rendered as text. Widening, applied
-- before any data exists.
alter table aiqms.audit_trail alter column row_id type text using row_id::text;

-- URS-EREC-013: the trail is attributable to a real person, enforced rather than asserted.
alter table aiqms.audit_trail
  add constraint audit_trail_actor_is_app_user
  foreign key (actor_id) references aiqms.app_user(id);

-- One generic writer. The table-specific facts — which column is the primary key, and which column
-- carries the owning quality_record — arrive through TG_ARGV, so this function contains no branch
-- per table. That is the same discipline SELECTED-DIRECTION.md imposes on the State Model engine.
--
-- NOTE: superseded in the same slice by 20260802130049_aiqms_audit_trail_redaction.sql, which adds
-- the secret-column redaction list. Kept as applied; the migration stream is append-only.
create function aiqms.write_audit_trail() returns trigger
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_actor  text := current_setting('aiqms.actor_id', true);
  v_reason text := current_setting('aiqms.reason', true);
  v_tz     text := current_setting('aiqms.tz', true);
  v_pk_col text := TG_ARGV[0];
  v_qr_col text := TG_ARGV[1];
  v_new    jsonb;
  v_old    jsonb;
  v_row_id text;
  v_qr_id  bigint;
  v_key    text;
  v_new_v  text;
  v_old_v  text;
  v_op     text;
begin
  if v_actor is null or btrim(v_actor) = '' then
    raise exception
      'AIQMS_NO_ACTOR: write to % rejected, no attributable actor (URS-EREC-013)', TG_TABLE_NAME;
  end if;
  if v_reason is null or btrim(v_reason) = '' then
    raise exception
      'AIQMS_NO_REASON: write to % rejected, no reason for change (URS-EREC-005)', TG_TABLE_NAME;
  end if;
  if v_tz is null or btrim(v_tz) = '' then
    raise exception
      'AIQMS_NO_TZ: write to % rejected, no acting time zone (ADR-DATA-002)', TG_TABLE_NAME;
  end if;

  v_op  := lower(TG_OP);
  v_new := to_jsonb(NEW);
  v_row_id := v_new ->> v_pk_col;
  v_qr_id  := case when v_qr_col = '' then null else (v_new ->> v_qr_col)::bigint end;

  if TG_OP = 'UPDATE' then
    v_old := to_jsonb(OLD);
  end if;

  for v_key in select jsonb_object_keys(v_new) loop
    v_new_v := v_new ->> v_key;
    v_old_v := case when v_old is null then null else v_old ->> v_key end;

    -- On insert, record every column that carries a value; on update, only what actually changed.
    continue when TG_OP = 'INSERT' and v_new_v is null;
    continue when TG_OP = 'UPDATE' and v_new_v is not distinct from v_old_v;

    insert into aiqms.audit_trail
      (quality_record_id, table_name, row_id, operation, column_name,
       old_value, new_value, actor_id, reason, occurred_at, occurred_tz)
    values
      (v_qr_id, TG_TABLE_NAME, v_row_id, v_op, v_key,
       v_old_v, v_new_v, v_actor::uuid, v_reason, now(), v_tz);
  end loop;

  return null;
end;
$$;

-- ENABLE ALWAYS on every one of them. Evidence from T1.2 on this instance: under
-- session_replication_role = 'replica' an ordinary trigger is skipped SILENTLY — the write lands and
-- nothing errors — while an ENABLE ALWAYS trigger still fires. Omitting it on one table would open a
-- hole that reports no error at any point.
create trigger trg_audit_quality_record
  after insert or update on aiqms.quality_record
  for each row execute function aiqms.write_audit_trail('id', 'id');
alter table aiqms.quality_record enable always trigger trg_audit_quality_record;

create trigger trg_audit_deviation
  after insert or update on aiqms.deviation
  for each row execute function aiqms.write_audit_trail('quality_record_id', 'quality_record_id');
alter table aiqms.deviation enable always trigger trg_audit_deviation;

create trigger trg_audit_record_action
  after insert or update on aiqms.record_action
  for each row execute function aiqms.write_audit_trail('id', 'quality_record_id');
alter table aiqms.record_action enable always trigger trg_audit_record_action;

create trigger trg_audit_signature
  after insert or update on aiqms.signature
  for each row execute function aiqms.write_audit_trail('id', 'quality_record_id');
alter table aiqms.signature enable always trigger trg_audit_signature;

create trigger trg_audit_security_event
  after insert or update on aiqms.security_event
  for each row execute function aiqms.write_audit_trail('id', 'quality_record_id');
alter table aiqms.security_event enable always trigger trg_audit_security_event;

create trigger trg_audit_app_user
  after insert or update on aiqms.app_user
  for each row execute function aiqms.write_audit_trail('id', '');
alter table aiqms.app_user enable always trigger trg_audit_app_user;
