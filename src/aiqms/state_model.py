"""The State Model as declared data, and the single engine that executes it.

`work/WI-001/SELECTED-DIRECTION.md` § Consequences names the discipline that keeps the shared-spine
design honest: **every type-specific rule lives inside its State Model declaration and never in the
engine.** No name of a concrete Record Type may appear in this module's engine code. A test asserts
it, because an aspiration that nobody checks is not a constraint.

The declaration here is one of three encodings of the same machine — the others are the
`aiqms.state_transition` tables and `aiqms.record_state_catalog`. `work/WI-001/PLAN-DOCTOR.md`
finding 2 requires parity tests across all three; they live in `tests/test_declaration_parity.py`
and need a database. Nothing in this module does.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from enum import Enum
from typing import Protocol


class Guard(Protocol):
    """A guard reads the record's facts and says whether the transition may proceed.

    Declared as a Protocol rather than `Callable[[...], bool]` deliberately: the callable spelling
    contains a `[[` sequence that `anti-leak-guard.py` matches as a wikilink shape, and the way to
    live with a gate is to write code it can read, never to weaken the gate. It also names the
    parameter, which the callable form cannot.
    """

    def __call__(self, facts: Mapping[str, object]) -> bool: ...

#: `from_state` value meaning "any non-terminal state". Matches the SQL declaration, where the
#: cancellation row is written once rather than once per state, so a newly added state cannot
#: silently become uncancellable.
ANY_NON_TERMINAL = "*"


class SignatureRequirement(Enum):
    """What a transition demands of the acting user, beyond authorisation."""

    NONE = "none"
    OPENING = "opening"
    APPROVAL = "approval"


class Outcome(Enum):
    """Decision codes.

    These strings are the same ones `aiqms.execute_transition` returns in `op_result.code`. Keeping
    them identical is what lets the parity test compare the two engines rather than merely compare
    their shapes.
    """

    OK = "AIQMS_OK"
    UNKNOWN_RECORD = "AIQMS_UNKNOWN_RECORD"
    TERMINAL_STATE = "AIQMS_TERMINAL_STATE"
    UNDECLARED_TRANSITION = "AIQMS_UNDECLARED_TRANSITION"
    ROLE_NOT_AUTHORISED = "AIQMS_ROLE_NOT_AUTHORISED"
    GUARD_FAILED = "AIQMS_GUARD_FAILED"
    SEGREGATION = "AIQMS_SEGREGATION"
    SIGNATURE_REQUIRED = "AIQMS_SIGNATURE_REQUIRED"


@dataclass(frozen=True)
class Decision:
    """The engine's answer. Never raises — see `ADR-ESIG-001` for why the write path returns."""

    ok: bool
    outcome: Outcome
    message: str = ""


@dataclass(frozen=True)
class Transition:
    """One declared move, with everything the engine needs to police it."""

    from_state: str
    to_state: str
    roles: frozenset[str]
    signature: SignatureRequirement = SignatureRequirement.NONE
    #: Enforce the Segregation Invariant. The comparand is fixed by `CONTEXT.md`: the signer of the
    #: Opening Signature, never the account that created the draft row.
    segregation: bool = False
    reason_required: bool = False
    #: Name of the SQL guard (`aiqms.<guard_name>`) and, optionally, its Python twin. The name is
    #: what the parity test compares; the callable is what makes this module testable alone.
    guard_name: str | None = None
    guard: Guard | None = None


@dataclass(frozen=True)
class StateModel:
    """One Record Type's machine. Data only — it knows nothing about storage."""

    initial: str
    states: tuple[str, ...]
    terminal: tuple[str, ...]
    transitions: tuple[Transition, ...]

    def __post_init__(self) -> None:
        unknown = {s for t in self.transitions for s in (t.from_state, t.to_state)}
        unknown -= set(self.states) | {ANY_NON_TERMINAL}
        if unknown:
            raise ValueError(f"transition references undeclared states: {sorted(unknown)}")
        if self.initial not in self.states:
            raise ValueError(f"initial state {self.initial!r} is not among the declared states")
        if not set(self.terminal) <= set(self.states):
            raise ValueError("terminal states must be declared states")
        # The initial state is the one nothing can reach. The SQL side derives it the same way
        # rather than storing a literal, so the two cannot drift on this point.
        reachable = {t.to_state for t in self.transitions}
        if self.initial in reachable:
            raise ValueError(f"initial state {self.initial!r} is reachable by a declared transition")

    def find(self, from_state: str, to_state: str) -> Transition | None:
        """The exact declaration if there is one, otherwise the wildcard. Same order as SQL."""
        for t in self.transitions:
            if t.from_state == from_state and t.to_state == to_state:
                return t
        for t in self.transitions:
            if t.from_state == ANY_NON_TERMINAL and t.to_state == to_state:
                return t
        return None

    def is_terminal(self, state: str) -> bool:
        return state in self.terminal


def evaluate(
    model: StateModel,
    *,
    current_state: str,
    to_state: str,
    actor_roles: frozenset[str],
    actor_id: str | None = None,
    opening_signature_signer: str | None = None,
    signature_supplied: bool = False,
    record_facts: Mapping[str, object] | None = None,
) -> Decision:
    """Decide whether one transition may proceed. Pure: no I/O, no clock, no database.

    The order of the checks is itself a control and matches `aiqms.execute_transition`:
    terminal, then declaration, then Role, then guard, then **segregation before the signature** —
    so a segregation breach never consumes a signature.
    """
    if model.is_terminal(current_state):
        return Decision(False, Outcome.TERMINAL_STATE,
                        f"{current_state} is terminal; no transition is permitted")

    transition = model.find(current_state, to_state)
    if transition is None:
        return Decision(False, Outcome.UNDECLARED_TRANSITION,
                        f"{current_state} -> {to_state} is not declared")

    if not (actor_roles & transition.roles):
        return Decision(False, Outcome.ROLE_NOT_AUTHORISED,
                        "The acting user holds no Role authorised for this transition")

    if transition.guard is not None and not transition.guard(record_facts or {}):
        return Decision(False, Outcome.GUARD_FAILED,
                        "The record does not yet satisfy the conditions for this transition")

    if transition.signature is not SignatureRequirement.NONE:
        if transition.segregation and opening_signature_signer is not None \
                and opening_signature_signer == actor_id:
            return Decision(False, Outcome.SEGREGATION,
                            "The signer of the Opening Signature may not approve this record")
        if not signature_supplied:
            return Decision(False, Outcome.SIGNATURE_REQUIRED,
                            "This transition requires an electronic signature")

    return Decision(True, Outcome.OK, f"{current_state} -> {to_state}")
