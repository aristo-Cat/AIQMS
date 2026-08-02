-- WI-001 / IS-2 — pgTAP suite for the write path.
-- Runs in begin/rollback: the append-only tables refuse DELETE and TRUNCATE, so committed fixtures
-- would be permanent residue.
--
-- The suite is split in two plans because the second needs a record already carried to `In triage`.

-- ══ Part 1 — creation, authorisation, and ADR-ESIG-001 ═════════════════════════════════════════
begin;
select plan(14);
select set_config('aiqms.actor_id', '11111111-1111-1111-1111-111111111111', true),
       set_config('aiqms.reason', 'pgTAP: write path', true),
       set_config('aiqms.tz', 'Europe/Madrid', true);

insert into aiqms.app_user (id, user_id, full_name) values
  ('22222222-2222-2222-2222-222222222222', 'qauser01', 'Beatriz QA'),
  ('33333333-3333-3333-3333-333333333333', 'norole01', 'Carlos NoRole');
insert into aiqms.app_user_role (app_user_id, role) values
  ('11111111-1111-1111-1111-111111111111', 'Reporter'),
  ('11111111-1111-1111-1111-111111111111', 'QA'),
  ('22222222-2222-2222-2222-222222222222', 'QA');
select aiqms.enrol_signature_credential('11111111-1111-1111-1111-111111111111', 'correct-horse-battery');
select aiqms.enrol_signature_credential('22222222-2222-2222-2222-222222222222', 'another-long-secret');

create temp table t as select aiqms.create_deviation(
  'Sealing temperature out of range', 'Line 3 sealer ran 8 C below set point',
  '11111111-1111-1111-1111-111111111111', 'Packaging', current_date + 30,
  'SOP-PKG-014 rev 6 s7.2', 'Set point 180 C, observed 172 C',
  now(), 'In-process check') as id;

select is((select state from aiqms.quality_record where id = (select id from t)), 'Draft',
  'a new Deviation lands in the initial state derived from the declaration (URS-FUNC-001)');
select matches((select record_no from aiqms.quality_record where id = (select id from t)),
  '^DEV-\d{4}-\d{4}$',
  'record_no is assigned by the system, not by the caller (URS-FUNC-002)');

select set_config('aiqms.actor_id', '33333333-3333-3333-3333-333333333333', true);
select is((aiqms.execute_transition((select id from t), 'Registered', 'correct-horse-battery')).code,
  'AIQMS_ROLE_NOT_AUTHORISED', 'a user with no authorised Role cannot transition (URS-FUNC-010)');

select set_config('aiqms.actor_id', '11111111-1111-1111-1111-111111111111', true);
select is((aiqms.execute_transition((select id from t), 'In actions', 'correct-horse-battery')).code,
  'AIQMS_UNDECLARED_TRANSITION', 'an undeclared transition is refused');

select is((aiqms.execute_transition((select id from t), 'Registered')).code,
  'AIQMS_SIGNATURE_REQUIRED', 'a transition needing a signature does not complete without one');

-- ── ADR-ESIG-001: the wrong password must not destroy its own security record ──────────────────
select is((aiqms.execute_transition((select id from t), 'Registered', 'wrong-password')).code,
  'AIQMS_BAD_SIGNATURE', 'a wrong signature password is refused (URS-ESIG-012)');
select is((select state from aiqms.quality_record where id = (select id from t)), 'Draft',
  'the record is unchanged after a failed signature');
select is((select count(*)::int from aiqms.security_event
            where event_type = 'signature_attempt_failed'), 1,
  'exactly one security_event records the failed attempt (URS-ESIG-012)');
select is((select count(*)::int from aiqms.signature), 0,
  'no signature row was written for the failed attempt');
-- The assertion the ADR exists for. Had apply_signature raised, the transaction would be aborted
-- and every statement after it would fail — including this one.
select lives_ok($$select count(*) from aiqms.quality_record$$,
  'the transaction is NOT aborted — apply_signature returned instead of raising (ADR-ESIG-001)');

select is((aiqms.execute_transition((select id from t), 'Registered', 'correct-horse-battery')).code,
  'AIQMS_OK', 'the correct password completes the Opening Signature');
select is((select signer_name_at_signing from aiqms.signature limit 1), 'Ana Reporter',
  'the signature freezes the signer name as at signing (URS-ESIG-002)');
select isnt((select content_hash from aiqms.signature limit 1), null,
  'the signature carries a content hash for tamper evidence (URS-ESIG-017)');
select lives_ok($$select aiqms.execute_transition((select id from t), 'In triage')$$,
  'QA moves the record into triage');

select * from finish();
rollback;

-- ══ Part 2 — the triage guard and the Segregation Invariant ════════════════════════════════════
begin;
select plan(6);
select set_config('aiqms.actor_id', '11111111-1111-1111-1111-111111111111', true),
       set_config('aiqms.reason', 'pgTAP: triage guard and segregation', true),
       set_config('aiqms.tz', 'Europe/Madrid', true);

insert into aiqms.app_user (id, user_id, full_name) values
  ('22222222-2222-2222-2222-222222222222', 'qauser01', 'Beatriz QA');
insert into aiqms.app_user_role (app_user_id, role) values
  ('11111111-1111-1111-1111-111111111111', 'Reporter'),
  ('11111111-1111-1111-1111-111111111111', 'QA'),
  ('22222222-2222-2222-2222-222222222222', 'QA');
select aiqms.enrol_signature_credential('11111111-1111-1111-1111-111111111111', 'correct-horse-battery');
select aiqms.enrol_signature_credential('22222222-2222-2222-2222-222222222222', 'another-long-secret');

create temp table t as select aiqms.create_deviation(
  'Sealing temperature out of range', 'Line 3 sealer ran 8 C below set point',
  '11111111-1111-1111-1111-111111111111', 'Packaging', current_date + 30,
  'SOP-PKG-014 rev 6 s7.2', 'Set point 180 C, observed 172 C', now(), 'In-process check') as id;

select aiqms.execute_transition((select id from t), 'Registered', 'correct-horse-battery');
select set_config('aiqms.actor_id', '22222222-2222-2222-2222-222222222222', true);
select aiqms.execute_transition((select id from t), 'In triage');

select is((select state from aiqms.quality_record where id = (select id from t)), 'In triage',
  'the record reaches In triage without a signature (Registered -> In triage)');

select is((aiqms.execute_transition((select id from t), 'Under investigation',
                                    'another-long-secret')).code,
  'AIQMS_GUARD_FAILED',
  'triage cannot be exited before severity, containment, determination and due date (FUNC-003/024/025)');

update aiqms.deviation
   set severity = 'major', investigation_required = true,
       containment_not_applicable_justification = 'Line stopped; no product released',
       investigation_determination_justification = 'Product contact surface affected'
 where quality_record_id = (select id from t);
update aiqms.quality_record
   set due_date_approved_by = '22222222-2222-2222-2222-222222222222',
       due_date_approved_at = now(), due_date_approved_tz = 'Europe/Madrid'
 where id = (select id from t);

-- Ana signed the Opening Signature AND holds QA, so she clears the Role check and must be stopped
-- by segregation rather than by authorisation. Testing it with a non-QA user would prove nothing.
select set_config('aiqms.actor_id', '11111111-1111-1111-1111-111111111111', true);
select is((aiqms.execute_transition((select id from t), 'Under investigation',
                                    'correct-horse-battery')).code,
  'AIQMS_SEGREGATION',
  'the signer of the Opening Signature may not approve the same record (URS-FUNC-012)');
select is((select count(*)::int from aiqms.signature where quality_record_id = (select id from t)), 1,
  'the segregation breach consumed no signature — it is checked before apply_signature');

select set_config('aiqms.actor_id', '22222222-2222-2222-2222-222222222222', true);
select is((aiqms.execute_transition((select id from t), 'Under investigation',
                                    'another-long-secret')).code,
  'AIQMS_OK', 'a QA who did not open the record approves the triage');

select is((aiqms.update_record_field((select id from t), 'quality_record', 'record_no', 'X')).code,
  'AIQMS_IMMUTABLE_RECORD_NO', 'record_no cannot be changed through the write path (URS-FUNC-002)');

select * from finish();
rollback;
