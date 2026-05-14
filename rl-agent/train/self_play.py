"""Self-play game collection (plan.md §6.8).

Single-process for the TTT smoke test. The Ray-actor multi-worker variant
described in plan.md §6.8 will wrap :func:`collect_game` later.
"""

from __future__ import annotations

import numpy as np

from mcts import MCTS, MCTSConfig
from triplea_odin.env_base import Env

from .replay import Sample


def collect_game(
    env: Env,
    policy_fn,
    mcts_cfg: MCTSConfig,
    num_actions: int,
    temperature_moves: int = 6,
    rng: np.random.Generator | None = None,
) -> list[Sample]:
    """Play one self-play game; return per-decision training samples.

    Sampling: actions are sampled proportional to visit counts for the first
    ``temperature_moves`` plies (encourages diversity), then greedy.
    """
    rng = rng or np.random.default_rng()
    env.reset()
    mcts = MCTS(policy_fn, mcts_cfg)

    trajectory: list[tuple[np.ndarray, np.ndarray, np.ndarray, int, np.ndarray]] = []
    # (observation_features, plan_indices, visits, acting_player, sample_log_probs)

    ply = 0
    while not env.is_terminal():
        result = mcts.run(env)
        plan_indices = np.array([p[0] for p in result.plans], dtype=np.int32)
        obs = env.observation()
        trajectory.append((
            obs.global_features.copy(),
            plan_indices,
            result.visits.copy(),
            env.current_player(),
            result.sample_log_probs.copy(),
        ))

        # Action selection.
        if result.visits.sum() == 0:
            # Should not happen; fall back to uniform over legals.
            legals = obs.legal_subactions
            action = int(rng.choice(legals))
        elif ply < temperature_moves:
            probs = result.visits / result.visits.sum()
            chosen = int(rng.choice(len(plan_indices), p=probs))
            action = int(plan_indices[chosen])
        else:
            chosen = int(np.argmax(result.visits))
            action = int(plan_indices[chosen])

        env.apply_subaction(action)
        if env.can_finalize_phase():
            env.finalize_phase()
        ply += 1

    # Outcome from team-0 POV.
    z_team0 = env.team_reward(0)

    samples: list[Sample] = []
    for feats, plan_idx, visits, player, slp in trajectory:
        outcome = z_team0 if player == 0 else -z_team0
        samples.append(Sample(
            observation=feats,
            plan_indices=plan_idx,
            visits=visits.astype(np.int64),
            sample_log_probs=slp.astype(np.float64),
            outcome=float(outcome),
        ))
    return samples


def visits_to_full_action_target(
    plan_indices: np.ndarray,
    visits: np.ndarray,
    num_actions: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Scatter (plan_indices, visits) into a dense ``[num_actions]`` vector.

    Also returns a legal-mask (True where the action was considered).
    Used by the TTT trainer to convert per-plan visits into full-action targets.
    """
    target = np.zeros(num_actions, dtype=np.int64)
    legal = np.zeros(num_actions, dtype=bool)
    target[plan_indices] = visits
    legal[plan_indices] = True
    return target, legal
