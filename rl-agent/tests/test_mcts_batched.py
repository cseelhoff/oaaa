"""Tests for the batched-MCTS driver."""

from __future__ import annotations

import numpy as np

from envs.hex import HexEnv
from mcts import BatchedMCTS, BatchedMCTSConfig
from mcts.sampling import enumerate_flat_plans


def _single_uniform_value0_policy(env):
    obs = env.observation()
    legals = obs.legal_subactions
    if legals.size == 0:
        return [], np.empty(0), 0.0
    logits = np.zeros(env.num_cells, dtype=np.float32)
    plans, log_priors = enumerate_flat_plans(env, logits, legals)
    return plans, log_priors, 0.0


def _batched_uniform_policy(envs):
    return [_single_uniform_value0_policy(e) for e in envs]


def test_batched_mcts_single_env_runs_full_budget():
    env = HexEnv(5)
    env.reset()
    bmcts = BatchedMCTS(
        _batched_uniform_policy,
        BatchedMCTSConfig(num_simulations=64, seed=42, add_root_noise=False),
    )
    results = bmcts.run([env])
    assert len(results) == 1
    res = results[0]
    assert res is not None
    assert res.visits.sum() == 64
    assert len(res.plans) == 25  # all empty cells legal


def test_batched_mcts_eight_games_in_parallel():
    envs = [HexEnv(5) for _ in range(8)]
    for e in envs:
        e.reset()
    bmcts = BatchedMCTS(
        _batched_uniform_policy,
        BatchedMCTSConfig(num_simulations=32, seed=0, add_root_noise=False),
    )
    results = bmcts.run(envs)
    assert len(results) == 8
    for res in results:
        assert res is not None
        assert res.visits.sum() == 32


def test_batched_mcts_skips_terminal_envs():
    env_alive = HexEnv(5)
    env_alive.reset()
    env_done = HexEnv(5)
    env_done.reset()
    # Walk env_done to terminal (deterministic — alternating play of the
    # first legal cell guarantees one player connects within ~25 plies).
    while not env_done.is_terminal():
        env_done.apply_subaction(int(env_done.legal_subactions()[0]))
    bmcts = BatchedMCTS(
        _batched_uniform_policy,
        BatchedMCTSConfig(num_simulations=8, seed=0, add_root_noise=False),
    )
    results = bmcts.run([env_alive, env_done])
    assert results[0] is not None and results[0].visits.sum() == 8
    assert results[1] is None


def test_batched_mcts_picks_a_winning_move_when_one_exists():
    """Set up a state where one move wins immediately for the side to move,
    and verify MCTS selects it (highest visit count)."""
    env = HexEnv(5)
    env.reset()
    # Build a trivial near-win for player 0 (Red, top-bottom):
    # Place Red on (0,0)..(3,0); empty (4,0) wins. Sub-action = r*5+c.
    # Sequence: R(0,0), B(0,4), R(1,0), B(0,3), R(2,0), B(0,2), R(3,0).
    for sub in [0, 4, 5, 3, 10, 2, 15]:
        env.apply_subaction(sub)
    assert not env.is_terminal()
    assert env.current_player() == 1  # Blue's move next — let's swap to Red.
    # Reset and replay so Red is to move with the same near-win pattern.
    env = HexEnv(5)
    env.reset()
    # Sequence ending on Blue so Red moves next: 7 moves above ends on Red(3,0).
    # Add one Blue move to flip turn back to Red.
    for sub in [0, 4, 5, 3, 10, 2, 15, 1]:
        env.apply_subaction(sub)
    assert env.current_player() == 0
    # Now (4,0) = sub-action 20 is the winning play for Red.
    bmcts = BatchedMCTS(
        _batched_uniform_policy,
        BatchedMCTSConfig(num_simulations=64, seed=7, add_root_noise=False),
    )
    res = bmcts.run([env])[0]
    assert res is not None
    best = int(np.argmax(res.visits))
    chosen_action = int(res.plans[best][0])
    # MCTS should heavily prefer the winning move.
    visit_for_win = int(res.visits[res.plans.index((20,))])
    assert visit_for_win >= max(int(v) for v in res.visits) // 2, (
        f"winning move (20) only got {visit_for_win} visits; "
        f"distribution: {dict(zip(res.plans, res.visits.tolist()))}"
    )
    # And ideally the argmax IS the winning move:
    assert chosen_action == 20
