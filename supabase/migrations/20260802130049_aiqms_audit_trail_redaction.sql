-- WI-001 / T1.6 fix — redact secret-bearing columns from the audit trail.
--
-- Found by executing T1.6: `app_user.signature_secret_hash` was written verbatim into
-- `audit_trail.new_value`. Three things make that worse than an ordinary leak:
--   1. the application role must hold SELECT on audit_trail for the read path (URS-FUNC-009),
--      so every signature credential hash would be readable by the application;
--   2. audit_trail is append-only and immutable by design, so a hash written there can never be
--      removed — rotation under URS-ESIG-009 would merely add a second hash beside the first;
--   3. Direction A exists precisely so this system controls the signature credential
--      (RESEARCH-SLICES.md §3), and this would have surrendered it on the first write.
--
-- The redaction list is a trigger argument, not a configuration table: URS-FUNC-057 requires the
-- invariants to be enforced in code and not configurable away, and a list that lives in a row is a
-- list somebody can empty. Changing it requires a migration.
--
-- The *fact* of the change is still recorded — column name, operation, actor, reason, instant and
-- zone — because URS-ESIG-009 needs credential rotation to be visible in the trail. Only the value
-- is withheld.

create or replace function aiqms.write_audit_trail() returns trigger
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_actor    text := current_setting('aiqms.actor_id', true);
  v_reason   text := current_setting('aiqms.reason', true);
  v_tz       text := current_setting('aiqms.tz', true);
  v_pk_col   text := TG_ARGV[0];
  v_qr_col   text := TG_ARGV[1];
  v_redacted text[] := case
                         when TG_NARGS < 3 or TG_ARGV[2] = '' then array[]::text[]
                         else string_to_array(TG_ARGV[2], ',')
                       end;
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

    continue when TG_OP = 'INSERT' and v_new_v is null;
    continue when TG_OP = 'UPDATE' and v_new_v is not distinct from v_old_v;

    if v_key = any (v_redacted) then
      v_new_v := case when v_new_v is null then null else '[redacted]' end;
      v_old_v := case when v_old_v is null then null else '[redacted]' end;
    end if;

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

-- Re-declare the app_user trigger with the redaction list. The other five carry no secret columns.
drop trigger trg_audit_app_user on aiqms.app_user;
create trigger trg_audit_app_user
  after insert or update on aiqms.app_user
  for each row execute function aiqms.write_audit_trail('id', '', 'signature_secret_hash');
alter table aiqms.app_user enable always trigger trg_audit_app_user;
