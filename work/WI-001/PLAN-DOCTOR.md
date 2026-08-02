---
type: plan-doctor
work_item: WI-001
plan_ref: work/WI-001/IMPLEMENTATION-PLAN.md
verdict: ready
checked_at: "2026-08-02"
---

# PLAN-DOCTOR — WI-001

## Independence — read this first

This review was performed by the same agent that authored the plan. `work/WI-001/RESEARCH-REVIEW.md`
was not: it was run by a separate agent with clean context, and it returned ten blocking findings
against thin specs the author believed were sound. The comparison is the honest calibration for
what follows — **a self-review at this gate is weaker evidence than the review at the previous
one**, and the verdict below should be read with that discount applied. The harness requires the
research review to be independent (`gates.research_review: required`) and does not impose the same
on the plan doctor, so this is within the rules; it is not within the rules to pretend the two
carry equal weight.

Six findings below were raised against the first pass and fixed before this verdict was issued. All
six are recorded rather than silently absorbed, because a doctor that only ever reports `ready` is
not a gate.

## Summary

`work/WI-001/IMPLEMENTATION-PLAN.md` sequences Record Spine and Deviation through QA Triage into
three implementation slices of fifteen tasks. After the fixes in the next section, an implementer
can execute it without inventing a requirement, an ID or a value. The one outstanding blocker —
which hosted Supabase project is the qualified target — affects a single task (T1.3) and does not
stop work starting.

The plan's strongest feature is that its two riskiest assumptions are its first two code tasks
(T1.2, the session-context handshake; T1.4, the application role), each with an explicit
*stop and reopen the ADR* condition rather than a workaround. Both are mechanisms the whole design
rests on and neither has ever been executed.

## First pass — findings, and what changed

**1 — `ADR-DATA-001` had no carrier. Blocking.** Layer 1 revokes writes "from the application
role", and no task created one. Supabase's default paths connect as `postgres`, which owns the
tables and bypasses Layer 1 entirely, or through the PostgREST `authenticator` chain, which is not
what the ADR describes. The plan would have reached T1.7 and passed its privilege tests as the
owner, proving nothing. **Fixed**: new task **T1.4** creates `aiqms_app`, grants it `EXECUTE` on
the five functions and nothing else, and proves it connects *through the pooler* — with an explicit
instruction not to satisfy the tests by connecting as `postgres`, which would void the control it
is meant to demonstrate.

**2 — the state machine is written down three times, and the plan checked two. Blocking.** T3.2
tested Python against SQL and ignored `record_state_catalog`, whose rows the `quality_record`
foreign key resolves against. An extra catalog row makes a state reachable by direct write that the
engine will never produce. **Fixed**: T3.2 is now two tests, and Test B asserts set equality in
both directions.

**3 — the coverage task had no threshold. Blocking.** T3.5 measured and reported without saying
what figure stops the slice. `URS-QUAL-002` demands 100% of the invariant, signature and transition
paths. **Fixed**: an explicit stop condition, covering both the measured case and the enumerated
fallback.

**4 — the T1.2 scratch vehicle had no disposal. Non-blocking.** A throwaway table and trigger left
in an ordered migration stream is a schema object with no requirement behind it — a finding in a
validated system, not untidiness. **Fixed**: the vehicle is created and dropped inside the test
fixture and never enters the migration stream.

**5 — "TDD does not apply" appeared in a harness with `allow_not_applicable: false`. Non-blocking,
but it is the exact phrasing that flag exists to close.** **Fixed**: T1.1 now states it produces no
TDD evidence because it produces no code, which is a different claim, and names T1.2 as the first
entry in the red-green ledger.

**6 — the rollback statement was false for the one hosted task. Non-blocking.** The plan said there
was no hosted rollback path because nothing hosted holds data, while T1.3 pushes a vehicle to
hosted. **Fixed**: rollback on a hosted target is a forward migration that drops what the previous
one created — `supabase_migrations.schema_migrations` records what was applied and the CLI will not
un-apply it — and T1.3's disposal migration is written in the same task.

## Readiness checks

| Criterion | Verdict |
|---|---|
| Tasks small enough for mini-loop execution | **Pass.** Fifteen tasks; the largest, T1.5, is one migration file with its pgTAP suite |
| Every task cites real spec IDs from `spec_refs` | **Pass.** Verified against `specs/URS.md` and `specs/ADR.md`; no invented IDs |
| Expected implementation evidence named | **Pass** after fix 6 — `evidence/agent-runs/WI-001/`, red and green run per task |
| Test commands explicit | **Pass.** `supabase test db` for SQL, named `pytest` targets for Python |
| Stop conditions clear | **Pass.** T1.2 and T1.4 carry *stop and reopen the ADR*; T2.2 and T3.5 carry their own |
| Rollback or recovery path stated | **Pass** after fix 6 |
| Blockers and `[NEEDS CLARIFICATION:]` surfaced | **Pass.** One marker, on the hosted project identity, scoped to T1.3 |
| Plan invents no requirements, architecture, packages or IDs | **Pass.** Every technology choice traces to `RESEARCH-SLICES.md` §4/§5 with its documented reason; the Python version is pinned in T1.1 as a recorded configuration item rather than derived from a requirement that does not exist |
| Seams under test named for each code task | **Pass.** Connection boundary, role boundary, schema, trigger, privilege boundary, function signature, `StateModel` declaration, repository interface |
| Context-window sizing | **Qualified pass** — see below |
| Wide refactors sequenced expand–contract | **Not applicable.** Greenfield; no existing call sites |

### On sizing

The plan states plainly that the work item does not fit one fresh context window and splits it into
three window-sized implementation slices with handoff-fork between them. The Context Window Doctrine
sanctions this — *"a work item — and each research slice or implementation slice inside it — is
sized to fit a single fresh context window"* — while the plan-doctor sizing criterion is written
about the work item. The plan resolves the tension in the open rather than by optimism, and pre-draws
the `WI-001a/b/c` split along the same boundaries if the stricter reading is preferred. Each boundary
is a state the system can sit in with tests green, which is the property that makes a split cheap.

**This is the finding most likely to be wrong**, and it is the one a reviewer with clean context
should attack first: the author both estimated the size and chose the reading of the rule that
accommodates the estimate.

## Expected evidence

- `evidence/agent-runs/WI-001/` — red and green runs per task, named by task ID, plus the run log.
- Migration files under the Supabase migration stream; `supabase migration list` output comparing
  local against remote before any hosted push.
- The T1.2 and T1.3 handshake results, kept separate — local PgBouncer and hosted Supavisor are not
  interchangeable evidence.
- Two coverage figures, separately labelled with how each was obtained.
- Flow evidence: the four-step acceptance path of `work/WI-001/THIN-SPECS.md` run end to end at
  T3.4.

## Stop conditions

1. **T1.2** — any of the three handshake assertions fails → stop, reopen `ADR-EREC-001`. Do not work
   around it; a workaround at this point is a design change wearing an implementation costume.
2. **T1.4** — `aiqms_app` cannot connect through the pooler → stop, reopen `ADR-DATA-001`.
   `URS-DATA-004` would fall back to *detectable* only, which is exactly the finding the independent
   review raised against `THIN-SPECS.md` v0.1.
3. **T2.2** — the wrong-password test must be observed red before verification code exists.
   `apply_signature` is the one function whose failure mode is silent.
4. **T3.5** — coverage below 100% on the invariant, signature and transition paths → the slice does
   not reach `evidence_ready`.
5. **Any slice boundary** — hand off through `work/WI-001/loop-state.md` and the latest `RUN-*.md`
   rather than compact-continuing in a degraded context.

## Rollback / recovery

Per-task: revert the migration file in git, `supabase db reset`. Nothing reaches a hosted database
until the local reset is green. On hosted, rollback is a forward migration; history is never edited.
Per-slice: each boundary is a green state, so recovery is to the previous boundary rather than to
the start.

## Required fixes

None outstanding. The six findings above were applied to `work/WI-001/IMPLEMENTATION-PLAN.md` before
this verdict was issued.

## Blockers carried into implementation

1. `[NEEDS CLARIFICATION: which Supabase project, region and connection string are the qualified target for AI-QMS]` — scoped to **T1.3**. Local work is unblocked; `evidence_ready` is not.
2. Two URS gaps recorded in `work/WI-001/THIN-SPECS.md` § Open items — `URS-ESIG-008` has no owner
   under Direction A, and `URS-ESIG-012`'s reporting limb is absent. Both are operational controls
   and neither blocks this build; both need a URS amendment as a separate work item.

---

PLAN_DOCTOR_READY -> work/WI-001/PLAN-DOCTOR.md
