-- WI-001 / T1.7 — caught by the conformance view on its first run.
--
-- `trg_quality_record_detail_present` was created in 20260802124455 without ENABLE ALWAYS, so
-- URS-FUNC-001 — a spine row cannot commit without its detail row — was bypassable by
-- `set session_replication_role = 'replica'`, silently, which is the exact failure mode T1.2
-- demonstrated on this instance. Twenty-one of twenty-two triggers were correct; this was the
-- twenty-second, and no error anywhere would ever have reported it.
alter table aiqms.quality_record
  enable always trigger trg_quality_record_detail_present;
