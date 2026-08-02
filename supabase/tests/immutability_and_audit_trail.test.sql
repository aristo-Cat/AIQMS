-- WI-001 — pgTAP suite for T1.6 (audit trail) and T1.7 (the three immutability layers).
--
-- Runs inside a transaction that rolls back. That is not tidiness: audit_trail, signature and
-- security_event refuse DELETE and TRUNCATE by design, so a suite that committed its fixtures would
-- leave permanent residue in a GxP table with no way to remove it.
--
-- Executed against the hosted project through the management API, because the Supabase CLI is not
-- installed and `supabase test db` cannot run. The assertions below are genuine pgTAP; the runner
-- is not pg_prove. When the CLI lands, this file runs unchanged.

begin;
select plan(14);

-- ── ADR-EREC-001: no session context, no write ────────────────────────────────────────────────
select throws_ok(
  $$insert into aiqms.app_user (id, user_id, full_name)
    values ('99999999-9999-9999-9999-999999999999', 'probe001', 'Probe User')$$,
  'P0001', null,
  'a write with no aiqms.actor_id is rejected, not recorded unattributed (URS-EREC-013)');

select set_config('aiqms.actor_id', '11111111-1111-1111-1111-111111111111', true);
select throws_ok(
  $$insert into aiqms.app_user (id, user_id, full_name)
    values ('99999999-9999-9999-9999-999999999999', 'probe001', 'Probe User')$$,
  'P0001', null,
  'a write with an actor but no reason is rejected (URS-EREC-005)');

select set_config('aiqms.reason', 'pgTAP suite: immutability and audit trail', true);
select throws_ok(
  $$insert into aiqms.app_user (id, user_id, full_name)
    values ('99999999-9999-9999-9999-999999999999', 'probe001', 'Probe User')$$,
  'P0001', null,
  'a write with actor and reason but no zone is rejected (ADR-DATA-002)');

select set_config('aiqms.tz', 'Europe/Madrid', true);
select lives_ok(
  $$insert into aiqms.app_user (id, user_id, full_name, signature_secret_hash,
                                signature_secret_set_at, signature_secret_set_tz)
    values ('99999999-9999-9999-9999-999999999999', 'probe001', 'Probe User',
            '$argon2id$SECRET', now(), 'Europe/Madrid')$$,
  'a write with all three settings present succeeds');

-- ── T1.6: the trail records what changed, and withholds what must never be published ──────────
select is(
  (select new_value from aiqms.audit_trail
    where table_name = 'app_user' and column_name = 'signature_secret_hash'
      and row_id = '99999999-9999-9999-9999-999999999999'),
  '[redacted]',
  'the signature credential hash is redacted from the audit trail (URS-ESIG-009, FUNC-057)');

select isnt(
  (select new_value from aiqms.audit_trail
    where table_name = 'app_user' and column_name = 'signature_secret_set_tz'
      and row_id = '99999999-9999-9999-9999-999999999999'),
  null,
  'the fact and zone of setting the credential are still trailed (URS-ESIG-009)');

-- ── T1.7 Layer 2: append-only binds the OWNER, not merely the application role ─────────────────
-- ADR-DATA-001 runs the write path as the owner, so Layer 1 cannot restrain a defect inside a
-- SECURITY DEFINER function. These four are the assertions that prove Layer 2 does.
select throws_ok(
  $$update aiqms.audit_trail set new_value = 'tampered'
     where id = (select min(id) from aiqms.audit_trail)$$,
  'P0001', null,
  'UPDATE on audit_trail is refused for the owner (URS-DATA-004)');

select throws_ok(
  $$delete from aiqms.audit_trail where id = (select min(id) from aiqms.audit_trail)$$,
  'P0001', null,
  'DELETE on audit_trail is refused for the owner (URS-FUNC-008)');

select throws_ok(
  $$delete from aiqms.app_user where id = '99999999-9999-9999-9999-999999999999'$$,
  'P0001', null,
  'DELETE on app_user is refused (URS-FUNC-008)');

-- ── T1.7 Layer 3: row triggers never see a TRUNCATE, so it needs statement triggers ───────────
select throws_ok($$truncate table aiqms.audit_trail$$, 'P0001', null,
  'TRUNCATE of audit_trail is refused (URS-FUNC-008, URS-DATA-004)');

select throws_ok($$truncate table aiqms.signature$$, 'P0001', null,
  'TRUNCATE of signature is refused (URS-FUNC-008)');

-- ── Conformance: without ENABLE ALWAYS every control above is bypassable by one SET ────────────
select is(
  (select count(*)::int from aiqms.trigger_conformance where not is_enable_always), 0,
  'every trigger in schema aiqms is ENABLE ALWAYS (session_replication_role bypass closed)');

select cmp_ok(
  (select count(*)::int from aiqms.trigger_conformance), '>=', 22,
  'the conformance view sees every GxP trigger');

-- ── URS-FUNC-001: a spine row without its detail row cannot commit ────────────────────────────
-- The check is DEFERRED, so the INSERT itself does not raise and a naive throws_ok around it
-- reports "caught: no exception" — or worse, passes while proving nothing. Forcing the constraint
-- immediate is what makes the assertion real.
insert into aiqms.quality_record
  (record_no, record_type, title, description, originator_id, owner_id, area, due_date,
   state, created_at, created_tz)
values ('DEV-PGTAP-0001', 'deviation', 'Spine with no detail', 'must not commit',
        '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111',
        'Packaging', current_date + 30, 'Draft', now(), 'Europe/Madrid');
select throws_ok(
  $$set constraints aiqms.trg_quality_record_detail_present immediate$$,
  'P0001', null,
  'a spine row with no detail row cannot pass the deferred check (URS-FUNC-001)');

select * from finish();
rollback;
