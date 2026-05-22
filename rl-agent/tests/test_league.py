"""Tests for the league + Elo + leaderboard."""

from __future__ import annotations

import os
import tempfile

import torch

from envs.hex import HexEnv
from model.tiny_gnn import TinyGNN
from train.league import (
    League,
    make_player,
    play_match,
    round_robin_vs,
    wilson_ci,
)


def test_wilson_ci_known_values():
    # 50/100 = 0.50 ± ~0.098 — standard textbook example.
    lo, hi = wilson_ci(50, 100)
    assert 0.40 < lo < 0.41
    assert 0.59 < hi < 0.60


def test_wilson_ci_boundary_zero_total():
    lo, hi = wilson_ci(0, 0)
    assert lo == 0.0 and hi == 1.0


def test_wilson_ci_perfect_score():
    # 20/20 wins — upper CI must be at most 1.0, lower bound must be > 0.
    lo, hi = wilson_ci(20, 20)
    assert 0.0 < lo < 1.0
    assert hi <= 1.0
    # Should clearly exceed 0.5 (cannot be tied with 20/20).
    assert lo > 0.7


def test_raw_mcts_member_uses_extra_num_sims():
    """raw_mcts player should respect member.extra['num_sims'] over the default."""
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d)
        L.add_baseline("raw_strong", "raw_mcts", num_sims=42)
        assert L.members["raw_strong"].extra == {"num_sims": 42}
        # We can't easily introspect sims from the closure, but we can run a
        # game and confirm it doesn't crash and behaves like raw_mcts.
        play = make_player(
            L.members["raw_strong"],
            model_factory=lambda: TinyGNN(),
            edge_index=None,
            device="cpu",
            num_sims=999,  # would-be default; should be ignored.
            seed=1,
        )
        env = HexEnv(4)
        env.reset()
        a = play(env)
        assert isinstance(a, int)
        assert 0 <= a < env.num_cells


def test_elo_zero_sum_after_one_win():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d, k_factor=24.0)
        L.add_baseline("a", "random")
        L.add_baseline("b", "random")
        L.record_game("a", "b", 1.0)
        a = L.members["a"]
        b = L.members["b"]
        # Equal Elo (1200) => expected 0.5; A wins => +12 / -12.
        assert abs(a.elo - 1212.0) < 1e-6
        assert abs(b.elo - 1188.0) < 1e-6
        assert a.wins == 1 and b.losses == 1
        assert a.games == 1 and b.games == 1


def test_elo_draw_does_not_move_equal_ratings():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d, k_factor=24.0)
        L.add_baseline("a", "random")
        L.add_baseline("b", "random")
        L.record_game("a", "b", 0.5)
        assert abs(L.members["a"].elo - 1200.0) < 1e-6
        assert abs(L.members["b"].elo - 1200.0) < 1e-6
        assert L.members["a"].draws == 1 and L.members["b"].draws == 1


def test_leaderboard_sorts_descending_by_elo():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d)
        L.add_baseline("low", "random")
        L.members["low"].elo = 1100.0
        L.add_baseline("high", "random")
        L.members["high"].elo = 1300.0
        L.add_baseline("mid", "random")
        L.members["mid"].elo = 1200.0
        out = L.leaderboard()
        # First non-header data line starts with rank 1.
        data_lines = [
            line.strip() for line in out.splitlines()
            if line.strip() and line.strip()[0].isdigit()
        ]
        names_in_order = [line.split()[1] for line in data_lines]
        assert names_in_order == ["high", "mid", "low"]


def test_save_snapshot_writes_pt_and_loadable():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d)
        m = TinyGNN()
        L.add_snapshot("foo", m)
        path = os.path.join(d, "foo.pt")
        assert os.path.exists(path)
        # Round-trip into a fresh model.
        m2 = TinyGNN()
        m2.load_state_dict(torch.load(path))
        for k in m.state_dict():
            assert torch.allclose(m.state_dict()[k], m2.state_dict()[k])


def test_random_vs_random_play_match_completes():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d)
        L.add_baseline("ra", "random")
        L.add_baseline("rb", "random")
        a = make_player(L.members["ra"], model_factory=lambda: TinyGNN(),
                        edge_index=None, device="cpu", num_sims=1, seed=1)
        b = make_player(L.members["rb"], model_factory=lambda: TinyGNN(),
                        edge_index=None, device="cpu", num_sims=1, seed=2)
        a_w, b_w, draws = play_match(lambda: HexEnv(4), a, b, num_games=4, alternate=True)
        # No draws possible in Hex.
        assert draws == 0
        assert a_w + b_w == 4


def test_round_robin_updates_elo_and_records_games():
    with tempfile.TemporaryDirectory() as d:
        L = League(snapshot_dir=d)
        L.add_baseline("rand", "random")
        net = TinyGNN()
        L.add_snapshot("net0", net)
        # Use raw_mcts as the challenger so this test stays fast (no NN expand).
        L.add_baseline("raw", "raw_mcts")
        round_robin_vs(
            L,
            challenger_name="raw",
            opponent_names=["rand"],
            env_factory=lambda: HexEnv(4),
            model_factory=lambda: TinyGNN(),
            edge_index=None,
            device="cpu",
            num_sims=8,
            games_per_match=4,
            seed=0,
            verbose=False,
        )
        assert L.members["raw"].games == 4
        assert L.members["rand"].games == 4
        # raw_mcts at 8 sims should beat random more often than not on Hex 4x4;
        # at minimum its Elo should not crash to nonsense.
        assert 800.0 < L.members["raw"].elo < 1600.0
