-- WI-001 / IS-2 — the write path (ADR-DATA-001, ADR-ESIG-001).

-- A composite, deliberately. ADR-ESIG-001 gives up the exception contract for the signature path,
-- and the containment it names is a return type that cannot be silently coerced to a boolean
-- success. `if result then` does not compile against this.
create type aiqms.op_result as (
  ok      boolean,
  code    text,
  message text
);

-- ── Enrolment (URS-ESIG-013) ───────────────────────────────────────────────────────────────────
create function aiqms.enrol_signature_credential(p_app_user_id uuid, p_secret text)
returns aiqms.op_result
language plpgsql
security definer
set search_path = aiqms, extensions, pg_catalog
as $$
declare v_tz text := current_setting('aiqms.tz', true);
begin
  if char_length(p_secret) < 12 then
    return (false, 'AIQMS_SECRET_TOO_SHORT',
            'The signature password must be at least 12 characters (URS-ESIG-013)')::aiqms.op_result;
  end if;
  update aiqms.app_user
     set signature_secret_hash   = crypt(p_secret, gen_salt('bf', 12)),
         signature_secret_set_at = now(),
         signature_secret_set_tz = v_tz
   where id = p_app_user_id;
  if not found then
    return (false, 'AIQMS_UNKNOWN_USER', 'No such user')::aiqms.op_result;
  end if;
  return (true, 'AIQMS_OK', 'Signature credential enrolled')::aiqms.op_result;
end;
$$;

-- ── Creation (URS-FUNC-001, FUNC-002) ──────────────────────────────────────────────────────────
-- Type-agnostic: inserts the spine only. Each Record Type gets a thin wrapper that calls this and
-- inserts its detail row. A single function taking Deviation fields would put a per-type branch
-- into shared code. The deferred constraint of T1.5 makes the two-step insert safe in one
-- transaction and impossible to leave half-done.
create function aiqms.create_quality_record(
  p_record_type  aiqms.record_type_t,
  p_title        text,
  p_description  text,
  p_owner_id     uuid,
  p_area         text,
  p_due_date     date
) returns bigint
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_actor uuid   := current_setting('aiqms.actor_id', true)::uuid;
  v_tz    text   := current_setting('aiqms.tz', true);
  v_initial text;
  v_id    bigint;
begin
  -- The initial state is data, not a literal: whatever the declaration cannot be reached FROM is it.
  select rsc.state into v_initial
    from aiqms.record_state_catalog rsc
   where rsc.record_type = p_record_type
     and not rsc.is_terminal
     and not exists (select 1 from aiqms.state_transition st
                      where st.record_type = rsc.record_type and st.to_state = rsc.state);
  if v_initial is null then
    raise exception 'AIQMS_NO_INITIAL_STATE: % has no unreachable non-terminal state', p_record_type;
  end if;

  insert into aiqms.quality_record
    (record_no, record_type, title, description, originator_id, owner_id, area, due_date,
     state, created_at, created_tz)
  values
    (aiqms.next_record_no(p_record_type), p_record_type, p_title, p_description,
     v_actor, p_owner_id, p_area, p_due_date, v_initial, now(), v_tz)
  returning id into v_id;
  return v_id;
end;
$$;

create function aiqms.create_deviation(
  p_title       text,
  p_description text,
  p_owner_id    uuid,
  p_area        text,
  p_due_date    date,
  p_instruction_departed_from text,
  p_departure_description     text,
  p_detected_at   timestamptz,
  p_detection_method text,
  p_product_or_batch text default null
) returns bigint
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_tz text   := current_setting('aiqms.tz', true);
  v_id bigint;
begin
  v_id := aiqms.create_quality_record('deviation', p_title, p_description, p_owner_id,
                                      p_area, p_due_date);
  insert into aiqms.deviation
    (quality_record_id, instruction_departed_from, departure_description,
     detected_at, detected_tz, detection_method, product_or_batch)
  values
    (v_id, p_instruction_departed_from, p_departure_description,
     p_detected_at, v_tz, p_detection_method, p_product_or_batch);
  return v_id;
end;
$$;

-- ── Signature (URS-ESIG-002/003/010/011/012/014/017, ADR-ESIG-001) ─────────────────────────────
create function aiqms.apply_signature(
  p_quality_record_id bigint,
  p_signer_id         uuid,
  p_signature_secret  text,
  p_meaning           text,
  p_transition        text
) returns aiqms.op_result
language plpgsql
security definer
set search_path = aiqms, extensions, pg_catalog
as $$
declare
  v_tz   text := current_setting('aiqms.tz', true);
  v_user aiqms.app_user%rowtype;
  v_hash text;
begin
  select * into v_user from aiqms.app_user where id = p_signer_id;

  -- Every rejection below writes a security_event and RETURNS. It must not raise: a raise would
  -- roll back the very row that records the attempt (ADR-ESIG-001).
  if v_user.id is null or v_user.status <> 'active' then
    insert into aiqms.security_event
      (event_type, app_user_id, quality_record_id, detail, occurred_at, occurred_tz)
    values ('signature_attempt_failed', p_signer_id, p_quality_record_id,
            'Signature attempted by an unknown or disabled user (URS-ESIG-010, URS-ESIG-011)',
            now(), v_tz);
    return (false, 'AIQMS_SIGNER_NOT_ACTIVE',
            'The signer is unknown or disabled')::aiqms.op_result;
  end if;

  if v_user.signature_secret_hash is null then
    insert into aiqms.security_event
      (event_type, app_user_id, quality_record_id, detail, occurred_at, occurred_tz)
    values ('signature_attempt_failed', p_signer_id, p_quality_record_id,
            'Signature attempted before a credential was enrolled', now(), v_tz);
    return (false, 'AIQMS_NO_CREDENTIAL',
            'No signature credential is enrolled for this user')::aiqms.op_result;
  end if;

  if v_user.signature_secret_expires_at is not null
     and v_user.signature_secret_expires_at <= now() then
    insert into aiqms.security_event
      (event_type, app_user_id, quality_record_id, detail, occurred_at, occurred_tz)
    values ('signature_attempt_failed', p_signer_id, p_quality_record_id,
            'Signature attempted with an expired credential (URS-ESIG-009)', now(), v_tz);
    return (false, 'AIQMS_CREDENTIAL_EXPIRED',
            'The signature credential has expired')::aiqms.op_result;
  end if;

  if crypt(p_signature_secret, v_user.signature_secret_hash) <> v_user.signature_secret_hash then
    insert into aiqms.security_event
      (event_type, app_user_id, quality_record_id, detail, occurred_at, occurred_tz)
    values ('signature_attempt_failed', p_signer_id, p_quality_record_id,
            'Signature password did not verify (URS-ESIG-012)', now(), v_tz);
    return (false, 'AIQMS_BAD_SIGNATURE',
            'The signature password did not verify')::aiqms.op_result;
  end if;

  -- URS-ESIG-017: freeze what was signed, so a later change is detectable.
  select encode(digest(
           coalesce(to_jsonb(qr)::text, '') || coalesce(to_jsonb(d)::text, ''), 'sha256'), 'hex')
    into v_hash
    from aiqms.quality_record qr
    left join aiqms.deviation d on d.quality_record_id = qr.id
   where qr.id = p_quality_record_id;

  insert into aiqms.signature
    (quality_record_id, signer_id, signer_name_at_signing, meaning, transition,
     content_hash, signed_at, signed_tz)
  values
    (p_quality_record_id, p_signer_id, v_user.full_name, p_meaning, p_transition,
     v_hash, now(), v_tz);

  return (true, 'AIQMS_OK', 'Signature applied')::aiqms.op_result;
end;
$$;

-- ── The engine (URS-FUNC-010/011/012, FUNC-003/024/025) ────────────────────────────────────────
-- Reads the declaration. No branch on record_type appears below; every type-specific rule lives in
-- state_transition, state_transition_role or a guard function.
create function aiqms.execute_transition(
  p_quality_record_id bigint,
  p_to_state          text,
  p_signature_secret  text default null
) returns aiqms.op_result
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_actor uuid := current_setting('aiqms.actor_id', true)::uuid;
  v_qr    aiqms.quality_record%rowtype;
  v_t     aiqms.state_transition%rowtype;
  v_terminal boolean;
  v_guard_ok boolean;
  v_opening_signer uuid;
  v_sig   aiqms.op_result;
begin
  select * into v_qr from aiqms.quality_record where id = p_quality_record_id for update;
  if v_qr.id is null then
    return (false, 'AIQMS_UNKNOWN_RECORD', 'No such quality record')::aiqms.op_result;
  end if;

  select is_terminal into v_terminal from aiqms.record_state_catalog
   where record_type = v_qr.record_type and state = v_qr.state;
  if v_terminal then
    return (false, 'AIQMS_TERMINAL_STATE',
            format('%s is terminal; no transition is permitted', v_qr.state))::aiqms.op_result;
  end if;

  -- Exact declaration first, then the wildcard. Both come from the same table.
  select * into v_t from aiqms.state_transition
   where record_type = v_qr.record_type and from_state = v_qr.state and to_state = p_to_state;
  if v_t.record_type is null then
    select * into v_t from aiqms.state_transition
     where record_type = v_qr.record_type and from_state = '*' and to_state = p_to_state;
  end if;
  if v_t.record_type is null then
    return (false, 'AIQMS_UNDECLARED_TRANSITION',
            format('%s -> %s is not declared for %s', v_qr.state, p_to_state,
                   v_qr.record_type))::aiqms.op_result;
  end if;

  -- URS-FUNC-010
  if not exists (select 1 from aiqms.state_transition_role str
                  join aiqms.app_user_role aur on aur.role = str.role
                 where str.record_type = v_t.record_type and str.from_state = v_t.from_state
                   and str.to_state = v_t.to_state and aur.app_user_id = v_actor) then
    return (false, 'AIQMS_ROLE_NOT_AUTHORISED',
            'The acting user holds no Role authorised for this transition')::aiqms.op_result;
  end if;

  if v_t.guard_fn is not null then
    execute format('select aiqms.%I($1)', v_t.guard_fn) into v_guard_ok using p_quality_record_id;
    if not coalesce(v_guard_ok, false) then
      return (false, 'AIQMS_GUARD_FAILED',
              'The record does not yet satisfy the conditions for this transition')::aiqms.op_result;
    end if;
  end if;

  if v_t.signature_meaning is not null then
    -- URS-FUNC-012, checked BEFORE the signature so a segregation breach never consumes one.
    -- CONTEXT.md fixes the comparand: the signer of the Opening Signature, not the creating account.
    if v_t.requires_segregation then
      select signer_id into v_opening_signer from aiqms.signature
       where quality_record_id = p_quality_record_id
       order by id asc limit 1;
      if v_opening_signer is not null and v_opening_signer = v_actor then
        return (false, 'AIQMS_SEGREGATION',
                'The signer of the Opening Signature may not approve this record')::aiqms.op_result;
      end if;
    end if;

    if p_signature_secret is null then
      return (false, 'AIQMS_SIGNATURE_REQUIRED',
              'This transition requires an electronic signature (URS-FUNC-011)')::aiqms.op_result;
    end if;

    v_sig := aiqms.apply_signature(p_quality_record_id, v_actor, p_signature_secret,
                                   v_t.signature_meaning, v_qr.state || ' -> ' || p_to_state);
    -- ADR-ESIG-001: no state change, no raise. The security_event written inside survives.
    if not v_sig.ok then
      return v_sig;
    end if;
  end if;

  update aiqms.quality_record set state = p_to_state where id = p_quality_record_id;

  return (true, 'AIQMS_OK',
          format('%s -> %s', v_qr.state, p_to_state))::aiqms.op_result;
end;
$$;

-- ── Field update (URS-EREC-005, FUNC-002) and cancellation ─────────────────────────────────────
create function aiqms.update_record_field(
  p_quality_record_id bigint,
  p_table             text,
  p_column            text,
  p_value             text
) returns aiqms.op_result
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_qr aiqms.quality_record%rowtype;
  v_terminal boolean;
begin
  if btrim(coalesce(current_setting('aiqms.reason', true), '')) = '' then
    return (false, 'AIQMS_NO_REASON', 'A reason for change is required (URS-EREC-005)')::aiqms.op_result;
  end if;
  if p_column = 'record_no' then
    return (false, 'AIQMS_IMMUTABLE_RECORD_NO',
            'record_no is never modifiable (URS-FUNC-002)')::aiqms.op_result;
  end if;
  if p_table not in ('quality_record', 'deviation') then
    return (false, 'AIQMS_UNKNOWN_TABLE', 'Not an updatable record table')::aiqms.op_result;
  end if;

  select * into v_qr from aiqms.quality_record where id = p_quality_record_id for update;
  if v_qr.id is null then
    return (false, 'AIQMS_UNKNOWN_RECORD', 'No such quality record')::aiqms.op_result;
  end if;
  select is_terminal into v_terminal from aiqms.record_state_catalog
   where record_type = v_qr.record_type and state = v_qr.state;
  if v_terminal then
    return (false, 'AIQMS_TERMINAL_STATE', 'A terminal record cannot be edited')::aiqms.op_result;
  end if;

  execute format('update aiqms.%I set %I = $1 where %I = $2',
                 p_table, p_column,
                 case when p_table = 'quality_record' then 'id' else 'quality_record_id' end)
    using p_value, p_quality_record_id;

  return (true, 'AIQMS_OK', format('%s.%s updated', p_table, p_column))::aiqms.op_result;
end;
$$;

create function aiqms.cancel_quality_record(p_quality_record_id bigint, p_reason text)
returns aiqms.op_result
language plpgsql
security definer
set search_path = aiqms, pg_catalog
as $$
declare
  v_tz text := current_setting('aiqms.tz', true);
  v_r  aiqms.op_result;
begin
  if btrim(coalesce(p_reason, '')) = '' then
    return (false, 'AIQMS_NO_REASON', 'Cancellation requires a reason')::aiqms.op_result;
  end if;
  update aiqms.quality_record
     set cancelled_at = now(), cancelled_tz = v_tz, cancel_reason = p_reason
   where id = p_quality_record_id;
  v_r := aiqms.execute_transition(p_quality_record_id, 'Cancelled');
  return v_r;
end;
$$;

-- ADR-DATA-001: the application may call these and nothing else.
revoke all on all functions in schema aiqms from aiqms_app;
grant execute on function
  aiqms.create_deviation(text, text, uuid, text, date, text, text, timestamptz, text, text),
  aiqms.execute_transition(bigint, text, text),
  aiqms.update_record_field(bigint, text, text, text),
  aiqms.cancel_quality_record(bigint, text),
  aiqms.enrol_signature_credential(uuid, text)
  to aiqms_app;
