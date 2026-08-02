"""The Deviation declaration.

Every rule specific to a Deviation lives here or in a guard below — never in
`aiqms.state_model`. This file is the Python half of the mirror; the SQL half is
`aiqms.state_transition` plus the guard functions in
`supabase/migrations/20260802140359_aiqms_roles_and_state_model_as_data.sql`.
"""

from __future__ import annotations

from collections.abc import Mapping

from .state_model import (
    ANY_NON_TERMINAL,
    SignatureRequirement,
    StateModel,
    Transition,
)

RECORD_TYPE = "deviation"
ID_PREFIX = "DEV"


def triage_complete(facts: Mapping[str, object]) -> bool:
    """`URS-FUNC-003`, `FUNC-024`, `FUNC-025` plus the recorded QA Determination.

    Mirrors `aiqms.guard_triage_complete`. Containment is *resolved* when either an action exists or
    a justification for there being none does — `URS-FUNC-025` accepts either, and accepting neither
    is what the guard refuses.
    """
    containment_resolved = bool(
        facts.get("containment_action_id") or facts.get("containment_not_applicable_justification")
    )
    return bool(
        facts.get("severity") is not None
        and containment_resolved
        and facts.get("investigation_required") is not None
        and facts.get("investigation_determination_justification")
        and facts.get("due_date_approved_by")
    )


def triage_to_investigation(facts: Mapping[str, object]) -> bool:
    """Reads the recorded QA Determination, never the severity."""
    return triage_complete(facts) and facts.get("investigation_required") is True


def triage_to_actions(facts: Mapping[str, object]) -> bool:
    return triage_complete(facts) and facts.get("investigation_required") is False


DEVIATION = StateModel(
    initial="Draft",
    states=(
        "Draft",
        "Registered",
        "In triage",
        "Under investigation",
        "In actions",
        "Cancelled",
    ),
    terminal=("Cancelled",),
    transitions=(
        Transition(
            "Draft",
            "Registered",
            roles=frozenset({"Reporter", "Investigator", "ProcessOwner", "QA"}),
            signature=SignatureRequirement.OPENING,
        ),
        Transition("Registered", "In triage", roles=frozenset({"QA"})),
        Transition(
            "In triage",
            "Under investigation",
            roles=frozenset({"QA"}),
            signature=SignatureRequirement.APPROVAL,
            segregation=True,
            guard_name="guard_triage_to_investigation",
            guard=triage_to_investigation,
        ),
        Transition(
            "In triage",
            "In actions",
            roles=frozenset({"QA"}),
            signature=SignatureRequirement.APPROVAL,
            segregation=True,
            guard_name="guard_triage_to_actions",
            guard=triage_to_actions,
        ),
        Transition(
            ANY_NON_TERMINAL,
            "Cancelled",
            roles=frozenset({"QA"}),
            reason_required=True,
        ),
    ),
)
