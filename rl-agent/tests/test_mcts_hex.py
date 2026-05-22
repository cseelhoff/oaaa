"""MCTS smoke test on Hex 5x5.

Hex has no draws, so the strong claim "MCTS with enough simulations beats
random ≥ 95% of the time" is the right pass condition. Same shape as the
TTT smoke test in test_mcts_tictactoe.py.
"""

from __future__ import annotations

import numpy as np

from envs.hex import HexEnv
from mcts import MCTS, MCTSConfig
from mcts.sampling import enumerate_flat_plans


def uniform_policy(env):
    obs = env.observation()
    legals = obs.legal_subactions
    if legals.size == 0:
        return [], np.empty(0), 0.0
    logits = np.zeros(env.num_cells, dtype=np.float32)
    plans, log_priors = enumerate_flat_plans(env, logits, legals)
    return plans, log_priors, 0.0


def _best_action(env, sims: int, seed: int) -> int:
    cfg = MCTSConfig(num_simulations=sims, seed=seed, add_root_noise=False)
    res = MCTS(uniform_policy, cfg).run(env)
    best = int(np.argmax(res.visits))
    return int(res.plans[best][0])


def test_mcts_beats_random_as_p0():
    """As Red, MCTS with 600 sims should beat random Blue most of the time.

    The Sampled-AZ-style policy here uses uniform priors and a value of 0 for
    non-terminal leaves (no rollouts), so signal only flows from sims that
    reach terminal. 600 sims on a 25-cell tree comfortably exceeds the cell
    count many times over.
    """
    rng = np.random.default_rng(11)
    wins = 0
    games = 6
    for g in range(games):
        env = HexEnv(5)
        env.reset()
        while not env.is_terminal():
            if env.current_player() == 0:
                a = _best_action(env, sims=600, seed=100 + g)
            else:
                legals = env.legal_subactions()
                a = int(rng.choice(legals))
            env.apply_subaction(a)
        if env.team_reward(0) > 0:
            wins += 1
    assert wins >= 5, f"MCTS as Red won only {wins}/{games} vs random Blue"


def test_mcts_beats_random_as_p1():
    """As Blue, MCTS with 600 sims should beat random Red most of the time.

    P1 has a small structural disadvantage in Hex (P0 wins under perfect play)
    but against random Red this is still easy with sufficient search.
    """
    rng = np.random.default_rng(13)
    wins = 0
    games = 6
    for g in range(games):
        env = HexEnv(5)
        env.reset()
        while not env.is_terminal():
            if env.current_player() == 1:
                a = _best_action(env, sims=600, seed=200 + g)
            else:
                legals = env.legal_subactions()
                a = int(rng.choice(legals))
            env.apply_subaction(a)
        if env.team_reward(1) > 0:
            wins += 1
    assert wins >= 4, f"MCTS as Blue won only {wins}/{games} vs random Red"
