"""MCTS node types (plan.md §6.6).

The node hierarchy mirrors the three kinds of states in our search tree:

- :class:`DecisionNode` — the side to move chooses a *plan* (= one MCTS edge).
- :class:`ChanceNode`   — combat resolves stochastically; children are sampled.
- :class:`TerminalNode` — the game has ended; carries the final value.

For TTT and other deterministic flat games, ``ChanceNode`` is never created
and each plan is a single sub-action.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

# A plan is a tuple of sub-action ids (terminating FINALIZE excluded).
Plan = tuple[int, ...]


@dataclass
class Edge:
    """A child edge of a :class:`DecisionNode`. One per sampled plan."""

    plan: Plan
    prior: float                                    # π(plan) at expansion time
    sample_log_prob: float = 0.0                    # for Sampled-AZ IS correction
    visits: int = 0
    total_value: float = 0.0                        # sum of backed-up values (parent POV)
    virtual_loss: int = 0                           # for parallel MCTS
    child: Optional["Node"] = None                  # lazy: created on first selection

    @property
    def q(self) -> float:
        eff_visits = self.visits + self.virtual_loss
        if eff_visits == 0:
            return 0.0
        return (self.total_value - self.virtual_loss) / eff_visits


class Node:
    """Base class — never instantiated directly."""

    __slots__ = ("env", "parent", "depth")

    def __init__(self, env, parent: Optional["Node"] = None, depth: int = 0) -> None:
        self.env = env
        self.parent = parent
        self.depth = depth


class DecisionNode(Node):
    __slots__ = ("edges", "expanded", "value_estimate", "to_move")

    def __init__(self, env, parent: Optional[Node] = None, depth: int = 0) -> None:
        super().__init__(env, parent, depth)
        self.edges: list[Edge] = []
        self.expanded = False
        self.value_estimate: float = 0.0  # network's v(state), POV of side-to-move
        self.to_move: int = env.current_player()

    @property
    def visits(self) -> int:
        return sum(e.visits for e in self.edges)

    def best_edge_by_visits(self) -> Edge:
        return max(self.edges, key=lambda e: (e.visits, e.q))

    def visit_distribution(self) -> np.ndarray:
        v = np.array([e.visits for e in self.edges], dtype=np.float64)
        s = v.sum()
        if s == 0:
            return np.full_like(v, 1.0 / max(len(v), 1))
        return v / s


class ChanceNode(Node):
    """Stochastic node. Outcomes are stored keyed by their hash so repeated
    samples accumulate visits/value as in OpenSpiel's mcts.py."""

    __slots__ = ("outcomes",)

    def __init__(self, env, parent: Optional[Node] = None, depth: int = 0) -> None:
        super().__init__(env, parent, depth)
        # outcome_key -> (sampled_env, child_node, visits, total_value)
        self.outcomes: dict[int, list] = {}


class TerminalNode(Node):
    __slots__ = ("value",)

    def __init__(self, env, value: float, parent: Optional[Node] = None, depth: int = 0) -> None:
        super().__init__(env, parent, depth)
        self.value = value  # POV of player at terminal time
