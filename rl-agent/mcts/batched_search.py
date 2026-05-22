"""Batched MCTS that amortises the policy/value forward across K parallel trees.

Each tick, every active tree independently selects a path down to a leaf
(an unexpanded ``DecisionNode`` or a ``TerminalNode``). All "needs-eval"
leaves from the K trees are then collected into one batch and fed through
a single ``batch_policy_fn`` call. Terminal leaves skip the batch and
backprop directly. After expansion the leaves are scored and backed up.

This is the standard "K leaves per tick" parallel-MCTS schedule. It does
*not* use within-tree virtual loss; the K-way parallelism comes from
running K independent self-play games concurrently. For Hex 5x5 + the
TinyGNN this typically gives a 5-20x throughput speedup at K~32-128
because PyTorch dispatch overhead dominates batch-1 inference.

Reuses ``DecisionNode``/``ChanceNode``/``TerminalNode``/``Edge`` and
``SearchResult`` from the existing single-tree implementation so training
code paths stay drop-in compatible.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Optional

import numpy as np

from .chance import expand_chance
from .node import ChanceNode, DecisionNode, Edge, Node, Plan, TerminalNode
from .puct import add_dirichlet_noise, c_puct
from .search import SearchResult


BatchPolicyFn = Callable[[list[object]], list[tuple[list[Plan], np.ndarray, float]]]
"""Given a list of envs, return a parallel list of (plans, log_priors, value)."""


@dataclass
class BatchedMCTSConfig:
    num_simulations: int = 80
    dirichlet_alpha: float = 0.3
    dirichlet_epsilon: float = 0.25
    add_root_noise: bool = True
    seed: int = 0


class BatchedMCTS:
    """Stateless batched-search driver. ``run`` builds K fresh trees per call."""

    def __init__(
        self,
        batch_policy_fn: BatchPolicyFn,
        cfg: BatchedMCTSConfig | None = None,
    ) -> None:
        self.batch_policy_fn = batch_policy_fn
        self.cfg = cfg or BatchedMCTSConfig()
        self._rng = np.random.default_rng(self.cfg.seed)

    # -- public --------------------------------------------------------------------
    def run(self, envs: list) -> list[Optional[SearchResult]]:
        K = len(envs)
        roots: list[Optional[DecisionNode]] = []
        for env in envs:
            if env.is_terminal():
                roots.append(None)
            else:
                roots.append(DecisionNode(env.clone(), parent=None, depth=0))

        # Initial root expansion (batched).
        initial = [(i, r) for i, r in enumerate(roots) if r is not None]
        if initial:
            evals = self.batch_policy_fn([r.env for _, r in initial])
            for (_i, node), (plans, log_priors, value) in zip(initial, evals):
                self._fill_node(node, plans, log_priors, value, is_root=True)

        # Sim ticks.
        for _ in range(self.cfg.num_simulations):
            need_eval: list[tuple[int, list, DecisionNode]] = []
            terminals: list[tuple[int, list, float]] = []

            for tree_idx, root in enumerate(roots):
                if root is None:
                    continue
                node: Node = root
                path: list[tuple[DecisionNode, Edge]] = []
                while True:
                    if isinstance(node, TerminalNode):
                        terminals.append((tree_idx, path, node.value))
                        break
                    if isinstance(node, ChanceNode):
                        seed = int(self._rng.integers(1, 2**31 - 1))
                        node = expand_chance(node, seed)
                        continue
                    assert isinstance(node, DecisionNode)
                    if not node.expanded:
                        need_eval.append((tree_idx, path, node))
                        break
                    edge = self._select_edge(node)
                    path.append((node, edge))
                    if edge.child is None:
                        edge.child = self._descend(node.env, edge.plan)
                    node = edge.child

            # Backprop terminal leaves immediately.
            for _idx, path, value in terminals:
                self._backprop(path, value)

            # Batch-evaluate the unexpanded leaves.
            if need_eval:
                envs_to_eval = [n.env for _, _, n in need_eval]
                evals = self.batch_policy_fn(envs_to_eval)
                for (_idx, path, node), (plans, log_priors, value) in zip(need_eval, evals):
                    self._fill_node(node, plans, log_priors, value, is_root=False)
                    team0_value = value if node.to_move == 0 else -value
                    self._backprop(path, team0_value)

        results: list[Optional[SearchResult]] = []
        for root in roots:
            if root is None:
                results.append(None)
            else:
                results.append(self._extract(root))
        return results

    # -- internals ---------------------------------------------------------------
    def _fill_node(
        self,
        node: DecisionNode,
        plans: list[Plan],
        log_priors: np.ndarray,
        value: float,
        is_root: bool,
    ) -> None:
        if not plans:
            node.expanded = True
            node.value_estimate = float(value)
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

    def _select_edge(self, node: DecisionNode) -> Edge:
        N = max(node.visits, 1)
        c = c_puct(N)
        sqrtN = np.sqrt(N)
        best_score = -np.inf
        best_edge: Edge | None = None
        for edge in node.edges:
            q_team0 = edge.q
            q_parent = q_team0 if node.to_move == 0 else -q_team0
            score = q_parent + c * edge.prior * sqrtN / (1.0 + edge.visits)
            if score > best_score:
                best_score = score
                best_edge = edge
        assert best_edge is not None
        return best_edge

    def _descend(self, parent_env, plan: Plan) -> Node:
        env = parent_env.clone()
        for sub in plan:
            env.apply_subaction(sub)
        if env.can_finalize_phase():
            env.finalize_phase()
        if env.is_terminal():
            return TerminalNode(env, value=env.team_reward(0), depth=0)
        if env.is_chance():
            return ChanceNode(env, depth=0)
        return DecisionNode(env, depth=0)

    def _backprop(self, path: list[tuple[DecisionNode, Edge]], value_team0: float) -> None:
        for _node, edge in reversed(path):
            edge.visits += 1
            edge.total_value += value_team0

    def _extract(self, root: DecisionNode) -> SearchResult:
        visits = np.array([e.visits for e in root.edges], dtype=np.int64)
        plans = [e.plan for e in root.edges]
        sample_log_probs = np.array(
            [e.sample_log_prob for e in root.edges], dtype=np.float64
        )
        return SearchResult(
            root=root,
            visits=visits,
            plans=plans,
            sample_log_probs=sample_log_probs,
            value_estimate=root.value_estimate,
        )
