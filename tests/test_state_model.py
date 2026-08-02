"""T3.1 — the State Model engine.

The one seam in WI-001 that needs no database: data in, decision out. `work/WI-001/
IMPLEMENTATION-PLAN.md` T3.1 asks for it to be exercised hard, so every transition, every Role,
both guard branches and the wildcard are covered here.
"""

from __future__ import annotations

import inspect
from pathlib import Path

import pytest

from aiqms import state_model
from aiqms.deviation import DEVIATION, RECORD_TYPE, triage_complete
from aiqms.state_model import (
    ANY_NON_TERMINAL,
    Outcome,
    SignatureRequirement,
    StateModel,
    Transition,
    evaluate,
)

QA = frozenset({"QA"})
REPORTER = frozenset({"Reporter"})
NOBODY: frozenset[str] = frozenset()

COMPLETE_TRIAGE = {
    "severity": "major",
    "containment_not_applicable_justification": "Line stopped; no product released",
    "investigation_required": True,
    "investigation_determination_justification": "Product contact surface affected",
    "due_date_approved_by": "22222222-2222-2222-2222-222222222222",
}


# ── The declaration itself ────────────────────────────────────────────────────────────────────

def test_initial_state_is_unreachable_by_any_declared_transition():
    """The invariant that lets both engines derive the initial state instead of storing it."""
    assert DEVIATION.initial not in {t.to_state for t in DEVIATION.transitions}


def test_declaration_rejects_a_reachable_initial_state():
    with pytest.raises(ValueError, match="reachable"):
        StateModel(
            initial="A",
            states=("A", "B"),
            terminal=(),
            transitions=(Transition("B", "A", roles=QA),),
        )


def test_declaration_rejects_an_undeclared_state():
    with pytest.raises(ValueError, match="undeclared states"):
        StateModel(
            initial="A",
            states=("A",),
            terminal=(),
            transitions=(Transition("A", "Nowhere", roles=QA),),
        )


def test_declaration_rejects_an_initial_state_that_is_not_declared():
    with pytest.raises(ValueError, match="not among the declared states"):
        StateModel(initial="Ghost", states=("A", "B"), terminal=(),
                   transitions=(Transition("A", "B", roles=QA),))


def test_declaration_rejects_a_terminal_state_that_is_not_declared():
    with pytest.raises(ValueError, match="terminal states must be declared"):
        StateModel(initial="A", states=("A", "B"), terminal=("Ghost",),
                   transitions=(Transition("A", "B", roles=QA),))


# ── Authorisation ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("role", ["Reporter", "Investigator", "ProcessOwner", "QA"])
def test_every_declared_role_may_open_a_deviation(role):
    d = evaluate(DEVIATION, current_state="Draft", to_state="Registered",
                 actor_roles=frozenset({role}), signature_supplied=True)
    assert d.ok, f"{role} should be able to open a Deviation"


def test_a_user_with_no_role_is_refused():
    d = evaluate(DEVIATION, current_state="Draft", to_state="Registered",
                 actor_roles=NOBODY, signature_supplied=True)
    assert d.outcome is Outcome.ROLE_NOT_AUTHORISED


def test_only_qa_may_move_a_registered_record_into_triage():
    assert evaluate(DEVIATION, current_state="Registered", to_state="In triage",
                    actor_roles=QA).ok
    assert evaluate(DEVIATION, current_state="Registered", to_state="In triage",
                    actor_roles=REPORTER).outcome is Outcome.ROLE_NOT_AUTHORISED


# ── Declaration lookup ────────────────────────────────────────────────────────────────────────

def test_an_undeclared_transition_is_refused():
    d = evaluate(DEVIATION, current_state="Draft", to_state="In actions", actor_roles=QA)
    assert d.outcome is Outcome.UNDECLARED_TRANSITION


def test_a_terminal_record_accepts_nothing():
    d = evaluate(DEVIATION, current_state="Cancelled", to_state="Registered", actor_roles=QA)
    assert d.outcome is Outcome.TERMINAL_STATE


@pytest.mark.parametrize("state", ["Draft", "Registered", "In triage", "Under investigation",
                                   "In actions"])
def test_the_wildcard_makes_every_non_terminal_state_cancellable(state):
    """One declared row, not one per state — so adding a state cannot forget cancellation."""
    assert evaluate(DEVIATION, current_state=state, to_state="Cancelled", actor_roles=QA).ok


# ── Signature and segregation ─────────────────────────────────────────────────────────────────

def test_a_transition_needing_a_signature_does_not_complete_without_one():
    d = evaluate(DEVIATION, current_state="Draft", to_state="Registered",
                 actor_roles=QA, signature_supplied=False)
    assert d.outcome is Outcome.SIGNATURE_REQUIRED


def test_the_opening_signer_may_not_approve_the_same_record():
    d = evaluate(DEVIATION, current_state="In triage", to_state="Under investigation",
                 actor_roles=QA, actor_id="ana", opening_signature_signer="ana",
                 signature_supplied=True, record_facts=COMPLETE_TRIAGE)
    assert d.outcome is Outcome.SEGREGATION


def test_segregation_is_checked_before_the_signature_is_demanded():
    """A breach must not be reported as a missing signature — the order is a control."""
    d = evaluate(DEVIATION, current_state="In triage", to_state="Under investigation",
                 actor_roles=QA, actor_id="ana", opening_signature_signer="ana",
                 signature_supplied=False, record_facts=COMPLETE_TRIAGE)
    assert d.outcome is Outcome.SEGREGATION


def test_a_different_qa_may_approve():
    d = evaluate(DEVIATION, current_state="In triage", to_state="Under investigation",
                 actor_roles=QA, actor_id="beatriz", opening_signature_signer="ana",
                 signature_supplied=True, record_facts=COMPLETE_TRIAGE)
    assert d.ok


# ── Guards ────────────────────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("missing", sorted(COMPLETE_TRIAGE))
def test_triage_is_incomplete_when_any_single_element_is_missing(missing):
    facts = dict(COMPLETE_TRIAGE)
    facts[missing] = None
    assert not triage_complete(facts), f"{missing} missing should leave triage incomplete"


def test_containment_is_resolved_by_an_action_as_well_as_by_a_justification():
    """URS-FUNC-025 accepts either limb; refusing neither is the point."""
    facts = dict(COMPLETE_TRIAGE)
    del facts["containment_not_applicable_justification"]
    facts["containment_action_id"] = 42
    assert triage_complete(facts)


def test_the_branch_reads_the_determination_and_never_the_severity():
    facts = dict(COMPLETE_TRIAGE) | {"investigation_required": False}
    assert evaluate(DEVIATION, current_state="In triage", to_state="Under investigation",
                    actor_roles=QA, actor_id="b", opening_signature_signer="a",
                    signature_supplied=True, record_facts=facts).outcome is Outcome.GUARD_FAILED
    assert evaluate(DEVIATION, current_state="In triage", to_state="In actions",
                    actor_roles=QA, actor_id="b", opening_signature_signer="a",
                    signature_supplied=True, record_facts=facts).ok


def test_the_guard_refuses_before_triage_is_complete():
    d = evaluate(DEVIATION, current_state="In triage", to_state="Under investigation",
                 actor_roles=QA, actor_id="b", opening_signature_signer="a",
                 signature_supplied=True, record_facts={})
    assert d.outcome is Outcome.GUARD_FAILED


# ── The discipline that keeps Option A honest ─────────────────────────────────────────────────

def test_the_engine_names_no_concrete_record_type():
    """SELECTED-DIRECTION.md § Consequences: every type-specific rule lives in the declaration.

    Crude by design. The alternative to a crude check is no check, and `RA-INIT-007`/`008` rate the
    invariants holding across seven State Models as the highest-probability failure in the register.
    """
    source = Path(inspect.getfile(state_model)).read_text(encoding="utf-8")
    engine = source.split('"""', 2)[2]  # skip the module docstring, which may cite examples
    assert RECORD_TYPE not in engine.lower()
    for word in ("deviation", "capa", "complaint", "change_control", "audit_finding"):
        assert word not in engine.lower(), f"the engine must not know about {word!r}"


def test_the_wildcard_constant_matches_the_sql_declaration():
    assert ANY_NON_TERMINAL == "*"


def test_outcome_codes_match_the_sql_op_result_codes():
    """Parity of vocabulary. Full parity against the database is T3.2."""
    assert Outcome.OK.value == "AIQMS_OK"
    assert Outcome.SEGREGATION.value == "AIQMS_SEGREGATION"
    assert Outcome.GUARD_FAILED.value == "AIQMS_GUARD_FAILED"
    assert Outcome.ROLE_NOT_AUTHORISED.value == "AIQMS_ROLE_NOT_AUTHORISED"
    assert Outcome.UNDECLARED_TRANSITION.value == "AIQMS_UNDECLARED_TRANSITION"
    assert Outcome.SIGNATURE_REQUIRED.value == "AIQMS_SIGNATURE_REQUIRED"
    assert Outcome.TERMINAL_STATE.value == "AIQMS_TERMINAL_STATE"


def test_signature_requirement_is_declared_for_the_two_signed_transitions():
    signed = {(t.from_state, t.to_state): t.signature for t in DEVIATION.transitions
              if t.signature is not SignatureRequirement.NONE}
    assert signed == {
        ("Draft", "Registered"): SignatureRequirement.OPENING,
        ("In triage", "Under investigation"): SignatureRequirement.APPROVAL,
        ("In triage", "In actions"): SignatureRequirement.APPROVAL,
    }
