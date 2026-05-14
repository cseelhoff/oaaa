"""Sampled AlphaZero MCTS main loop (plan.md §6.6).

Designed for the smoke test on TTT but structured for the A&A path:

- ``policy_fn(env) -> (plans, log_priors, value)`` is the only model coupling.
- Chance nodes are supported via :mod:`mcts.chance` but only created when
  ``env.is_chance()`` is True (TTT never enters this code path).
- Selection uses PUCT with adaptive ``c_puct``.
- Dirichlet noise is mixed at the root.
- Plans are cloned-then-applied (no undo); this matches plan.md §12.7.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

import numpy as np

from .chance import expand_chance
from .node import ChanceNode, DecisionNode, Edge, Node, Plan, TerminalNode
from .puct import add_dirichlet_noise, c_puct

PolicyFn = Callable[[object], tuple[list[Plan], np.ndarray, float]]
"""Given an env, return (candidate plans, log-priors over them, value estimate v ∈ [-1, 1])
where the value is from the perspective of the side to move."""


@dataclass
class MCTSConfig:
    num_simulations: int = 64
    dirichlet_alpha: float = 0.3
    dirichlet_epsilon: float = 0.25
    add_root_noise: bool = True
    seed: int = 0
    # Future: leaf-rollout mixing weight (plan.md §6.6 "Leaf evaluation").
    rollout_weight: float = 0.0
    rollout_max_turns: int = 4


@dataclass
class SearchResult:
    root: DecisionNode
    visits: np.ndarray = field(default_factory=lambda: np.empty(0, dtype=np.int64))
    plans: list[Plan] = field(default_factory=list)
    sample_log_probs: np.ndarray = field(default_factory=lambda: np.empty(0))
    value_estimate: float = 0.0


class MCTS:
    """Stateless search driver. ``run`` builds a fresh tree per call."""

    def __init__(self, policy_fn: PolicyFn, cfg: MCTSConfig | None = None) -> None:
        self.policy_fn = policy_fn
        self.cfg = cfg or MCTSConfig()
        self._rng = np.random.default_rng(self.cfg.seed)

    # -- public --------------------------------------------------------------------
    def run(self, env) -> SearchResult:
        if env.is_terminal():
            raise ValueError("cannot run MCTS on a terminal state")
        root = DecisionNode(env.clone(), parent=None, depth=0)
        self._expand_decision(root, is_root=True)
        for _ in range(self.cfg.num_simulations):
            self._simulate(root)
        return self._extract(root)

    # -- core simulation -----------------------------------------------------------
    def _simulate(self, root: DecisionNode) -> None:
        path: list[tuple[DecisionNode, Edge]] = []
        node: Node = root
        # ---- selection / expansion --------------------------------------------
        while True:
            if isinstance(node, TerminalNode):
                value = node.value  # POV: team 0
                self._backprop(path, value, terminal=True)
                return
            if isinstance(node, ChanceNode):
                # Sample once; descend into the resulting decision node.
                seed = int(self._rng.integers(1, 2**31 - 1))
                node = expand_chance(node, seed)
                continue
            assert isinstance(node, DecisionNode)
            if not node.expanded:
                self._expand_decision(node, is_root=False)
                value = node.value_estimate  # POV of node.to_move
                # Translate to team-0 POV for backprop sign-flip uniformity.
                team0_value = value if node.to_move == 0 else -value
                self._backprop(path, team0_value, terminal=False)
                return
            edge = self._select_edge(node)
            path.append((node, edge))
            if edge.child is None:
                edge.child = self._descend(node.env, edge.plan)
            node = edge.child

    # -- expansion ----------------------------------------------------------------
    def _expand_decision(self, node: DecisionNode, is_root: bool) -> None:
        plans, log_priors, value = self.policy_fn(node.env)
        if not plans:
            # No legal plans — should only happen at terminal states; treat as draw.
            node.expanded = True
            node.value_estimate = 0.0
            return
        priors = np.exp(log_priors - log_priors.max())
        priors = priors / priors.sum()
        if is_root and self.cfg.add_root_noise and len(plans) > 1:
            priors = add_dirichlet_noise(
                priors,
                alpha=self.cfg.dirichlet_alpha,
                epsilon=self.cfg.dirichlet_epsilon,
                rng=self._rng,
            )
        node.edges = [
            Edge(plan=p, prior=float(pri), sample_log_prob=float(lp))
            for p, pri, lp in zip(plans, priors, log_priors)
        ]
        node.value_estimate = float(value)
        node.expanded = True

    def _descend(self, parent_env, plan: Plan) -> Node:
        """Apply ``plan`` to a clone of ``parent_env`` and wrap the result."""
        env = parent_env.clone()
        for sub in plan:
            env.apply_subaction(sub)
        # Auto-finalize for envs that need it (no-op for TTT).
        if env.can_finalize_phase():
            env.finalize_phase()
        if env.is_terminal():
            # Terminal value from POV of team 0 for uniform backprop sign-flip.
            return TerminalNode(env, value=env.team_reward(0), depth=0)
        if env.is_chance():
            return ChanceNode(env, depth=0)
        return DecisionNode(env, depth=0)

    # -- selection ----------------------------------------------------------------
    def _select_edge(self, node: DecisionNode) -> Edge:
        N = max(node.visits, 1)
        c = c_puct(N)
        sqrtN = np.sqrt(N)
        best_score = -np.inf
        best_edge: Edge | None = None
        for edge in node.edges:
            # Q from parent POV: edge.q is stored in team-0 POV; flip if mover==1.
            q_team0 = edge.q
            q_parent = q_team0 if node.to_move == 0 else -q_team0
            score = q_parent + c * edge.prior * sqrtN / (1.0 + edge.visits)
            if score > best_score:
                best_score = score
                best_edge = edge
        assert best_edge is not None
        return best_edge

    # -- backprop -----------------------------------------------------------------
    def _backprop(self, path: list[tuple[DecisionNode, Edge]], value_team0: float, terminal: bool) -> None:
        # Stored in each edge as team-0 POV; selection flips per node.to_move.
        for _node, edge in reversed(path):
            edge.visits += 1
            edge.total_value += value_team0

    # -- extract ------------------------------------------------------------------
    def _extract(self, root: DecisionNode) -> SearchResult:
        visits = np.array([e.visits for e in root.edges], dtype=np.int64)
        plans = [e.plan for e in root.edges]
        sample_log_probs = np.array([e.sample_log_prob for e in root.edges], dtype=np.float64)
        return SearchResult(
            root=root,
            visits=visits,
            plans=plans,
            sample_log_probs=sample_log_probs,
            value_estimate=root.value_estimate,
        )


def run_mcts(env, policy_fn: PolicyFn, cfg: MCTSConfig | None = None) -> SearchResult:
    """Convenience wrapper: one-shot search."""
    return MCTS(policy_fn, cfg).run(env)
