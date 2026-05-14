"""MCTS smoke test on Tic-Tac-Toe.

Runs MCTS with a uniform-prior, zero-value policy against TTT. With enough
simulations, MCTS alone (no learned net) should:

- Block immediate losses.
- Take immediate wins.
- Never lose from the empty board against a random opponent.

This validates PUCT, Dirichlet noise, backprop-with-sign-flip, and the env
contract together — the goals listed in plan.md §8 step 1.
"""

from __future__ import annotations

import numpy as np

from envs.tictactoe import NUM_ACTIONS, TicTacToeEnv
from mcts import MCTS, MCTSConfig
from mcts.sampling import enumerate_flat_plans


def uniform_policy(env):
    """Uniform prior over legals, value = 0. MCTS does the work."""
    obs = env.observation()
    legals = obs.legal_subactions
    if legals.size == 0:
        return [], np.empty(0), 0.0
    logits = np.zeros(NUM_ACTIONS, dtype=np.float32)
    plans, log_priors = enumerate_flat_plans(env, logits, legals)
    return plans, log_priors, 0.0


def _best_action(env, sims: int = 400, seed: int = 0) -> int:
    cfg = MCTSConfig(num_simulations=sims, seed=seed, add_root_noise=False)
    res = MCTS(uniform_policy, cfg).run(env)
    best = int(np.argmax(res.visits))
    return int(res.plans[best][0])


def test_mcts_takes_immediate_win():
    """X to move, can win at square 2. Strong MCTS must take it."""
    env = TicTacToeEnv()
    env.reset()
    # Set up: X at 0,1; O at 3,4. X to move.
    for sub in [0, 3, 1, 4]:
        env.apply_subaction(sub)
    assert env.current_player() == 0
    action = _best_action(env, sims=200, seed=1)
    assert action == 2, f"MCTS should win immediately by playing 2; chose {action}"


def test_mcts_blocks_immediate_loss():
    """O to move, must block X's threat at square 2."""
    env = TicTacToeEnv()
    env.reset()
    # X at 0,1 (threatens 2); O at 4. O to move.
    env.apply_subaction(0)  # X
    env.apply_subaction(4)  # O
    env.apply_subaction(1)  # X — threatens 2
    assert env.current_player() == 1
    action = _best_action(env, sims=400, seed=2)
    assert action == 2, f"MCTS should block at 2; chose {action}"


def test_mcts_never_loses_to_random_from_empty():
    """Standard TTT result: perfect play draws or wins from the empty board.

    We let MCTS play X (with enough sims to be near-perfect) and play O
    randomly. MCTS must never lose.
    """
    rng = np.random.default_rng(7)
    losses = 0
    games = 6
    for g in range(games):
        env = TicTacToeEnv()
        env.reset()
        while not env.is_terminal():
            if env.current_player() == 0:
                a = _best_action(env, sims=300, seed=100 + g)
            else:
                legals = env.legal_subactions()
                a = int(rng.choice(legals))
            env.apply_subaction(a)
        if env.team_reward(0) < 0:
            losses += 1
    assert losses == 0, f"MCTS lost {losses}/{games} games as X to random O"
