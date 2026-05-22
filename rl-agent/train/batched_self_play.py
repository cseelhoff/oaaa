"""Batched self-play for Hex.

Runs ``K`` games concurrently and uses :class:`mcts.batched_search.BatchedMCTS`
to evaluate every tick's K leaves in a single network forward. Returns the
collected training samples in the same packed format as
``train.demo_hex.collect_hex_game`` so downstream training code is unchanged.
"""

from __future__ import annotations

import numpy as np

from envs.hex import HexEnv
from mcts.batched_search import BatchedMCTS, BatchedMCTSConfig
from train.replay import Sample


def _pack_observation(node_feats: np.ndarray, global_feats: np.ndarray) -> np.ndarray:
    """Match the packing used by ``train.demo_hex.collect_hex_game``."""
    N, F = node_feats.shape
    return np.concatenate(
        [
            np.array([N, F, global_feats.size], dtype=np.float32),
            node_feats.reshape(-1).astype(np.float32),
            global_feats.astype(np.float32),
        ]
    )


def batched_self_play_hex(
    envs: list[HexEnv],
    batch_policy_fn,
    mcts_cfg: BatchedMCTSConfig,
    temperature_moves: int = 8,
    seed: int = 0,
) -> list[Sample]:
    """Play ``len(envs)`` games concurrently; return all training samples.

    Each call to ``BatchedMCTS.run`` produces ``num_simulations`` ticks of
    K-way batched leaf evaluation, then every still-active game commits one
    sub-action. Loop until all games are terminal.
    """
    rng = np.random.default_rng(seed)
    K = len(envs)
    trajectories: list[list[tuple]] = [[] for _ in range(K)]
    plies = [0] * K

    sim_step = 0
    while True:
        active_idx = [i for i in range(K) if not envs[i].is_terminal()]
        if not active_idx:
            break
        active_envs = [envs[i] for i in active_idx]
        # Fresh search per move; reseed per step so noise differs across moves.
        per_step_cfg = BatchedMCTSConfig(
            num_simulations=mcts_cfg.num_simulations,
            dirichlet_alpha=mcts_cfg.dirichlet_alpha,
            dirichlet_epsilon=mcts_cfg.dirichlet_epsilon,
            add_root_noise=mcts_cfg.add_root_noise,
            seed=mcts_cfg.seed + sim_step,
        )
        mcts = BatchedMCTS(batch_policy_fn, per_step_cfg)
        results = mcts.run(active_envs)

        for j, i in enumerate(active_idx):
            res = results[j]
            if res is None or len(res.plans) == 0:
                continue
            env = envs[i]
            obs = env.observation()
            plan_indices = np.array([p[0] for p in res.plans], dtype=np.int32)
            trajectories[i].append(
                (
                    obs.graph["node_features"].copy(),
                    obs.global_features.copy(),
                    plan_indices,
                    res.visits.copy(),
                    env.current_player(),
                )
            )

            if res.visits.sum() == 0:
                action = int(rng.choice(obs.legal_subactions))
            elif plies[i] < temperature_moves:
                probs = res.visits / res.visits.sum()
                chosen = int(rng.choice(len(plan_indices), p=probs))
                action = int(plan_indices[chosen])
            else:
                chosen = int(np.argmax(res.visits))
                action = int(plan_indices[chosen])
            env.apply_subaction(action)
            plies[i] += 1
        sim_step += 1

    samples: list[Sample] = []
    for i, traj in enumerate(trajectories):
        z_team0 = envs[i].team_reward(0)
        for node_feats, global_feats, plan_idx, visits, player in traj:
            outcome = z_team0 if player == 0 else -z_team0
            samples.append(
                Sample(
                    observation=_pack_observation(node_feats, global_feats),
                    plan_indices=plan_idx,
                    visits=visits.astype(np.int64),
                    sample_log_probs=np.zeros_like(plan_idx, dtype=np.float64),
                    outcome=float(outcome),
                )
            )
    return samples
