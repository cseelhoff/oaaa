"""Environment contract used by MCTS, self-play and training.

This is the abstract interface defined in plan.md §6.1. Concrete implementations:

- :class:`envs.tictactoe.TicTacToeEnv` — pure-Python TTT for the smoke test.
- :class:`triplea_odin.env.AAEnv` — the Odin-engine-backed A&A env (stubbed).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import IntEnum
from typing import Any

import numpy as np


class Phase(IntEnum):
    """Decision phases. Mirrors the Odin engine ``ts_current_phase`` enum (plan.md §4.1)."""

    PURCHASE_COMBATMOVE = 0
    COMBAT = 1  # chance node
    NCM_PLACE = 2
    END_TURN = 3
    GAME_OVER = 4


@dataclass
class Observation:
    """A featurised game state.

    For TTT this is a flat tensor in ``global_features``. For A&A this will be
    a ``torch_geometric.data.HeteroData`` graph (plan.md §6.1) carried in
    ``graph`` while ``global_features`` holds the global feature vector.
    """

    global_features: np.ndarray
    graph: Any | None = None  # PyG HeteroData for A&A; None for flat envs.
    legal_subactions: np.ndarray | None = None  # int32 array of legal sub-action ids


class Env(ABC):
    """Plan-as-action environment contract.

    Each *plan* is a sequence of sub-actions terminated by ``FINALIZE``.
    Decision phases consume one plan; the chance phase resolves combat.
    Flat games like TTT collapse to: one sub-action per plan, no chance node.
    """

    # -- lifecycle -----------------------------------------------------------------
    @abstractmethod
    def reset(self, seed: int = 0) -> Observation: ...

    @abstractmethod
    def clone(self) -> "Env":
        """Cheap deep copy. MCTS calls this hundreds of times per move (plan.md §4.3)."""

    # -- queries -------------------------------------------------------------------
    @abstractmethod
    def current_player(self) -> int:
        """Team index in {0, 1}. Allies=0, Axis=1."""

    def acting_power(self) -> int:
        """Power index in 0..N-1. For 2-player games this equals current_player()."""
        return self.current_player()

    def current_phase(self) -> Phase:
        return Phase.PURCHASE_COMBATMOVE

    def round_number(self) -> int:
        return 0

    @abstractmethod
    def is_terminal(self) -> bool: ...

    @abstractmethod
    def team_reward(self, team: int) -> float:
        """+1 win / -1 loss / 0 otherwise, from ``team``'s perspective."""

    # -- sub-action interface ------------------------------------------------------
    @abstractmethod
    def legal_subactions(self) -> np.ndarray:
        """int32 array of legal sub-action ids at the current decision point."""

    @abstractmethod
    def apply_subaction(self, sub: int) -> None:
        """Apply a sub-action. Must raise ValueError on illegal input (plan.md §12.6)."""

    def can_finalize_phase(self) -> bool:
        return True

    def finalize_phase(self) -> None:
        """Close the current decision phase and advance to the next node (chance or decision)."""

    # -- chance --------------------------------------------------------------------
    def is_chance(self) -> bool:
        return False

    def resolve_combat(self, seed: int) -> None:
        """Resolve all combat deterministically given ``seed``."""

    # -- observation ---------------------------------------------------------------
    @abstractmethod
    def observation(self) -> Observation: ...

    # -- ProAI hooks (no-ops for TTT) ---------------------------------------------
    def proai_plan(self) -> list[int] | None:
        """ProAI's plan for the current decision phase, or None if unavailable."""
        return None

    def proai_rollout(self, max_turns: int, seed: int) -> float | None:
        """Estimated team-0 win probability after a ProAI-vs-ProAI rollout."""
        return None

    def proai_value(self) -> float | None:
        """ProAI's static evaluation, or None if unavailable."""
        return None
