"""TTT env contract tests."""

import numpy as np
import pytest

from envs.tictactoe import NUM_ACTIONS, OBS_DIM, TicTacToeEnv


def test_reset_initial_state():
    env = TicTacToeEnv()
    obs = env.reset()
    assert obs.global_features.shape == (OBS_DIM,)
    assert obs.global_features.dtype == np.float32
    assert env.current_player() == 0
    assert not env.is_terminal()
    assert set(env.legal_subactions().tolist()) == set(range(NUM_ACTIONS))


def test_player_alternates():
    env = TicTacToeEnv()
    env.reset()
    env.apply_subaction(0)
    assert env.current_player() == 1
    env.apply_subaction(1)
    assert env.current_player() == 0


def test_illegal_action_rejected():
    env = TicTacToeEnv()
    env.reset()
    env.apply_subaction(4)
    with pytest.raises(ValueError):
        env.apply_subaction(4)
    with pytest.raises(ValueError):
        env.apply_subaction(99)


def test_winning_line():
    env = TicTacToeEnv()
    env.reset()
    # X plays a row; O plays harmlessly.
    env.apply_subaction(0)  # X
    env.apply_subaction(3)  # O
    env.apply_subaction(1)  # X
    env.apply_subaction(4)  # O
    env.apply_subaction(2)  # X — wins top row
    assert env.is_terminal()
    assert env.team_reward(0) == 1.0
    assert env.team_reward(1) == -1.0


def test_draw():
    env = TicTacToeEnv()
    env.reset()
    # A drawn position.
    moves = [0, 1, 2, 4, 3, 5, 7, 6, 8]
    for m in moves:
        env.apply_subaction(m)
    assert env.is_terminal()
    assert env.team_reward(0) == 0.0
    assert env.team_reward(1) == 0.0


def test_clone_independence():
    env = TicTacToeEnv()
    env.reset()
    env.apply_subaction(0)
    env2 = env.clone()
    env.apply_subaction(1)
    # env2 should still see square 1 as legal.
    assert 1 in env2.legal_subactions().tolist()
    assert env2.current_player() == 1


def test_observation_perspective_flips():
    env = TicTacToeEnv()
    env.reset()
    env.apply_subaction(0)  # X plays 0; now O to move.
    obs = env.observation()
    # Plane 0 is "me" (= O); plane 1 is "opponent" (= X).
    assert obs.global_features[0:9].sum() == 0.0
    assert obs.global_features[9:18].sum() == 1.0  # opponent has the X piece
    assert obs.global_features[9 + 0] == 1.0
    assert obs.global_features[18] == 1.0  # current player index
