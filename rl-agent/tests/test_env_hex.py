"""Hex env contract tests + win-detection sanity checks."""

import numpy as np
import pytest

from envs.hex import HexEnv


def test_initial_state_5x5():
    env = HexEnv(5)
    obs = env.reset()
    assert obs.global_features.shape == (HexEnv.GLOBAL_FEATURES,)
    assert obs.graph["node_features"].shape == (25, HexEnv.PER_NODE_FEATURES)
    assert obs.graph["edge_index"].shape[0] == 2
    assert env.current_player() == 0
    assert not env.is_terminal()
    assert obs.legal_subactions.size == 25


def test_player_alternates():
    env = HexEnv(5)
    env.reset()
    env.apply_subaction(0)
    assert env.current_player() == 1
    env.apply_subaction(1)
    assert env.current_player() == 0


def test_illegal_action_rejected():
    env = HexEnv(5)
    env.reset()
    env.apply_subaction(12)
    with pytest.raises(ValueError):
        env.apply_subaction(12)
    with pytest.raises(ValueError):
        env.apply_subaction(99)


def test_player0_top_to_bottom_win():
    """Red plays the entire left column; that connects row 0 to row N-1."""
    env = HexEnv(5)
    env.reset()
    # Red moves on column 0 of every row; Blue plays harmless cells in column 4
    # (but is interrupted by Red's win after 5 of its own moves).
    red_moves = [0, 5, 10, 15, 20]   # column 0 of each row
    blue_moves = [4, 9, 14, 19]      # column 4 of each row (Blue would-be win, but Red moves first)
    moves = []
    for i in range(5):
        moves.append(red_moves[i])
        if i < 4:
            moves.append(blue_moves[i])
    for m in moves:
        env.apply_subaction(m)
    assert env.is_terminal()
    assert env.team_reward(0) == 1.0
    assert env.team_reward(1) == -1.0


def test_player1_left_to_right_win():
    """Blue connects column 0 to column N-1 across row 0 (intermixed with Red)."""
    env = HexEnv(5)
    env.reset()
    # Sequence: Red harmless on row 4, Blue builds row 0 left->right.
    # Red plays first; alternate.
    seq = [
        20, 0,   # R(4,0)  B(0,0)
        21, 1,   # R(4,1)  B(0,1)
        22, 2,   # R(4,2)  B(0,2)
        23, 3,   # R(4,3)  B(0,3)
        24, 4,   # R(4,4)  B(0,4) — Blue wins
    ]
    for m in seq:
        env.apply_subaction(m)
    assert env.is_terminal()
    assert env.team_reward(1) == 1.0
    assert env.team_reward(0) == -1.0


def test_clone_independence():
    env = HexEnv(5)
    env.reset()
    env.apply_subaction(12)
    env2 = env.clone()
    env.apply_subaction(0)
    assert 0 in env2.legal_subactions().tolist()
    assert env2.current_player() == 1


def test_observation_perspective_flips():
    env = HexEnv(5)
    env.reset()
    env.apply_subaction(0)  # P0 plays cell 0; P1 to move.
    obs = env.observation()
    feats = obs.graph["node_features"]
    # Plane 0 is "me" (= P1, no stones yet); plane 1 is "opponent" (= P0).
    assert feats[:, 0].sum() == 0.0
    assert feats[:, 1].sum() == 1.0
    assert feats[0, 1] == 1.0
    # Edge-proximity from P1's POV: plane 3 = left col, plane 4 = right col.
    n = env.n
    for r in range(n):
        assert feats[r * n + 0, 3] == 1.0
        assert feats[r * n + (n - 1), 4] == 1.0


def test_adjacency_degrees_match_expected():
    """Per-cell degrees in the cached edge_index match what the offset table
    would produce by direct enumeration."""
    from envs.hex import HEX_NEIGHBOR_OFFSETS

    env = HexEnv(5)
    n = env.n
    counts = np.bincount(env._edge_index[0], minlength=env.num_cells)
    expected = np.zeros(env.num_cells, dtype=int)
    for r in range(n):
        for c in range(n):
            v = r * n + c
            for dr, dc in HEX_NEIGHBOR_OFFSETS:
                rr, cc = r + dr, c + dc
                if 0 <= rr < n and 0 <= cc < n:
                    expected[v] += 1
    assert (counts == expected).all()
    # Interior cells (not on any edge) all have 6 neighbors.
    for r in range(1, n - 1):
        for c in range(1, n - 1):
            assert expected[r * n + c] == 6


# -- swap rule tests -----------------------------------------------------------
def test_swap_rule_disabled_by_default():
    env = HexEnv(5)
    assert env.swap_rule is False
    assert env.num_actions == env.num_cells
    env.reset()
    legals = env.legal_subactions()
    # SWAP id must not appear when feature is off.
    assert env.SWAP_ACTION_ID not in legals.tolist()


def test_swap_rule_legal_only_at_ply_1_for_p1():
    env = HexEnv(5, swap_rule=True)
    env.reset()
    # P0 to move at ply 0: SWAP not legal yet.
    assert env.SWAP_ACTION_ID not in env.legal_subactions().tolist()
    env.apply_subaction(12)  # P0 plays center
    # P1 to move at ply 1: SWAP IS legal.
    assert env.SWAP_ACTION_ID in env.legal_subactions().tolist()
    # Make a regular move; SWAP should never be legal again.
    env.apply_subaction(0)
    for _ in range(5):
        if env.is_terminal():
            break
        legals = env.legal_subactions().tolist()
        assert env.SWAP_ACTION_ID not in legals
        env.apply_subaction(legals[0])


def test_swap_rule_mirrors_first_move_to_p1():
    env = HexEnv(5, swap_rule=True)
    env.reset()
    # P0 plays at (1, 3) -> cell index 1*5+3 = 8.
    env.apply_subaction(8)
    # P1 SWAPs.
    env.apply_subaction(env.SWAP_ACTION_ID)
    # After swap: board has exactly one P1 stone at the transposed cell (3, 1) -> 16.
    assert (env._board == 1).sum() == 0
    assert (env._board == 2).sum() == 1
    assert env._board[3 * 5 + 1] == 2
    # And it's P0's turn (P1 already used its move via SWAP).
    assert env.current_player() == 0
    # SWAP cannot be used again.
    assert env.SWAP_ACTION_ID not in env.legal_subactions().tolist()


def test_swap_rule_clone_preserves_state():
    env = HexEnv(5, swap_rule=True)
    env.reset()
    env.apply_subaction(12)
    env.apply_subaction(env.SWAP_ACTION_ID)
    env.apply_subaction(7)
    env2 = env.clone()
    assert env2.swap_rule is True
    assert env2.num_actions == env.num_actions
    assert (env2._board == env._board).all()
    assert env2.current_player() == env.current_player()
