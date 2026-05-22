"""League with Elo ratings, snapshots, and a leaderboard.

A ``League`` keeps a set of named ``LeagueMember``s and updates their Elo
ratings as games are recorded. Members come in three kinds:

- ``random``    — uniform random over legal sub-actions, no MCTS.
- ``raw_mcts``  — MCTS with uniform prior + value=0 (no neural network).
                  ``extra={"num_sims": N}`` controls strength.
- ``model``     — MCTS guided by a frozen GNN snapshot loaded from disk.

Snapshots are saved as ``state_dict`` ``.pt`` files under ``snapshot_dir``.
The active trainee can also be evaluated as a ``model`` member by passing
its live network directly (no disk round-trip) via :func:`make_player`.
"""

from __future__ import annotations

import json
import math
import os
from dataclasses import asdict, dataclass, field

import numpy as np
import torch


def wilson_ci(wins: int, total: int, z: float = 1.96) -> tuple[float, float]:
    """Wilson score 95% CI for a binomial proportion.

    More accurate than the normal approximation for small N or extreme p.
    Returns ``(lo, hi)`` in [0, 1]. For ``total == 0`` returns ``(0, 1)``.
    """
    if total <= 0:
        return (0.0, 1.0)
    p = wins / total
    denom = 1.0 + (z * z) / total
    center = (p + (z * z) / (2.0 * total)) / denom
    half = (z * math.sqrt(p * (1.0 - p) / total + (z * z) / (4.0 * total * total))) / denom
    return (max(0.0, center - half), min(1.0, center + half))


@dataclass
class LeagueMember:
    name: str
    kind: str = "model"  # "model" | "random" | "raw_mcts"
    weights_path: str | None = None
    elo: float = 1200.0
    games: int = 0
    wins: int = 0
    losses: int = 0
    draws: int = 0
    extra: dict = field(default_factory=dict)


@dataclass
class League:
    snapshot_dir: str
    k_factor: float = 24.0
    members: dict[str, LeagueMember] = field(default_factory=dict)

    def __post_init__(self) -> None:
        os.makedirs(self.snapshot_dir, exist_ok=True)

    # -- members ----------------------------------------------------------------
    def add_baseline(self, name: str, kind: str, elo: float = 1200.0, **extra) -> LeagueMember:
        if kind not in {"random", "raw_mcts"}:
            raise ValueError(f"baseline kind must be 'random' or 'raw_mcts', got {kind!r}")
        m = LeagueMember(name=name, kind=kind, elo=elo, extra=dict(extra))
        self.members[name] = m
        return m

    def add_snapshot(self, name: str, model: torch.nn.Module, elo: float = 1200.0) -> LeagueMember:
        path = os.path.join(self.snapshot_dir, f"{name}.pt")
        # Unwrap torch.compile() wrapper if present so the saved keys match a
        # vanilla TinyGNN.load_state_dict() at reload time.
        sd_source = getattr(model, "_orig_mod", model)
        torch.save(sd_source.state_dict(), path)
        m = LeagueMember(name=name, kind="model", weights_path=path, elo=elo)
        self.members[name] = m
        return m

    # -- elo --------------------------------------------------------------------
    @staticmethod
    def expected_score(elo_a: float, elo_b: float) -> float:
        return 1.0 / (1.0 + 10.0 ** ((elo_b - elo_a) / 400.0))

    def record_game(self, name_a: str, name_b: str, score_a: float) -> None:
        """Update Elo for one game; ``score_a`` is 1.0 / 0.5 / 0.0."""
        a = self.members[name_a]
        b = self.members[name_b]
        ea = self.expected_score(a.elo, b.elo)
        delta = self.k_factor * (score_a - ea)
        a.elo += delta
        b.elo -= delta
        a.games += 1
        b.games += 1
        if score_a > 0.5:
            a.wins += 1
            b.losses += 1
        elif score_a < 0.5:
            a.losses += 1
            b.wins += 1
        else:
            a.draws += 1
            b.draws += 1

    # -- reporting --------------------------------------------------------------
    def leaderboard(self) -> str:
        ms = sorted(self.members.values(), key=lambda m: -m.elo)
        lines = ["", "League leaderboard:"]
        header = f"  {'rank':<5} {'name':<22} {'elo':>7} {'games':>6} {'W':>5} {'L':>5} {'D':>5}"
        lines.append(header)
        lines.append("  " + "-" * (len(header) - 2))
        for i, m in enumerate(ms, 1):
            lines.append(
                f"  {i:<5} {m.name:<22} {m.elo:>7.1f} {m.games:>6} "
                f"{m.wins:>5} {m.losses:>5} {m.draws:>5}"
            )
        return "\n".join(lines)

    def save(self, path: str) -> None:
        data = {
            "k_factor": self.k_factor,
            "snapshot_dir": self.snapshot_dir,
            "members": [asdict(m) for m in self.members.values()],
        }
        with open(path, "w") as f:
            json.dump(data, f, indent=2)


# ---- player factory + match runner -------------------------------------------


def _make_uniform_value0_policy(num_cells: int):
    """Single-env policy: uniform prior, value=0 (used by 'raw_mcts')."""
    from mcts.sampling import enumerate_flat_plans

    def policy_fn(env):
        obs = env.observation()
        legals = obs.legal_subactions
        if legals is None or legals.size == 0:
            return [], np.empty(0), 0.0
        logits = np.zeros(num_cells, dtype=np.float32)
        plans, log_priors = enumerate_flat_plans(env, logits, legals)
        return plans, log_priors, 0.0

    return policy_fn


def make_player(
    member: LeagueMember,
    *,
    model_factory,
    edge_index: torch.Tensor | None,
    device: str | torch.device,
    num_sims: int,
    seed: int = 0,
    live_model: torch.nn.Module | None = None,
):
    """Return a callable ``env -> action`` for ``member``.

    For ``raw_mcts`` members, ``member.extra["num_sims"]`` overrides the
    ``num_sims`` argument so each baseline can have a fixed strength
    (e.g., raw_mcts_60 always uses 60 sims, raw_mcts_800 always 800).
    """
    from mcts import MCTS, MCTSConfig
    from model.tiny_gnn import make_hex_policy_fn

    if member.kind == "random":
        rng = np.random.default_rng(seed)

        def play_random(env):
            return int(rng.choice(env.legal_subactions()))

        return play_random

    if member.kind == "raw_mcts":
        sims = int(member.extra.get("num_sims", num_sims))
        cfg = MCTSConfig(num_simulations=sims, add_root_noise=False, seed=seed)

        def play_raw(env):
            policy_fn = _make_uniform_value0_policy(env.num_cells)
            res = MCTS(policy_fn, cfg).run(env)
            best = int(np.argmax(res.visits))
            return int(res.plans[best][0])

        return play_raw

    if member.kind == "model":
        if live_model is not None:
            net = live_model
        else:
            net = model_factory()
            state = torch.load(member.weights_path, map_location=device)
            target = getattr(net, "_orig_mod", net)
            target.load_state_dict(state)
        net.eval()
        policy_fn = make_hex_policy_fn(net, device)
        cfg = MCTSConfig(num_simulations=num_sims, add_root_noise=False, seed=seed)

        def play_model(env):
            res = MCTS(policy_fn, cfg).run(env)
            best = int(np.argmax(res.visits))
            return int(res.plans[best][0])

        return play_model

    raise ValueError(f"unknown member kind: {member.kind!r}")


def play_match(
    env_factory,
    player_a,
    player_b,
    num_games: int,
    alternate: bool = True,
    opening_random_plies: int = 0,
    seed: int = 0,
) -> tuple[int, int, int]:
    """Play ``num_games`` between ``player_a`` and ``player_b``.

    When ``alternate`` is True (default), A and B swap who moves first
    every game. Returns ``(a_wins, b_wins, draws)``.

    ``opening_random_plies`` forces the first N plies of every game to
    uniform-random moves. This is critical for evals where both players are
    deterministic (greedy MCTS, fixed seed): without random openings, the
    same matchup just replays the same game N times. With N>=1 random plies
    each game traces a distinct game tree, so games per matchup carry real
    information again.

    Per-game RNG is derived from ``seed`` + game index so the entire match
    is reproducible across re-runs.
    """
    a_wins = b_wins = draws = 0
    for g in range(num_games):
        rng = np.random.default_rng(seed * 1_000_003 + g)
        env = env_factory()
        env.reset()
        a_seat = g % 2 if alternate else 0
        ply = 0
        while not env.is_terminal():
            cur = env.current_player()
            if ply < opening_random_plies:
                legals = env.legal_subactions()
                action = int(rng.choice(legals))
            else:
                action = (player_a if cur == a_seat else player_b)(env)
            env.apply_subaction(action)
            ply += 1
        r = env.team_reward(a_seat)
        if r > 0:
            a_wins += 1
        elif r < 0:
            b_wins += 1
        else:
            draws += 1
    return a_wins, b_wins, draws


def round_robin_vs(
    league: League,
    challenger_name: str,
    opponent_names: list[str],
    *,
    env_factory,
    model_factory,
    edge_index: torch.Tensor | None,
    device: str | torch.device,
    num_sims: int,
    games_per_match: int,
    seed: int = 0,
    live_model: torch.nn.Module | None = None,
    verbose: bool = True,
    opening_random_plies: int = 0,
) -> dict[str, tuple[int, int, int]]:
    """Have the challenger play a series against each opponent; update Elo.

    Returns ``{opponent_name: (challenger_wins, opp_wins, draws)}``.
    """
    challenger = league.members[challenger_name]
    challenger_play = make_player(
        challenger,
        model_factory=model_factory,
        edge_index=edge_index,
        device=device,
        num_sims=num_sims,
        seed=seed,
        live_model=live_model,
    )

    out: dict[str, tuple[int, int, int]] = {}
    for opp_name in opponent_names:
        if opp_name == challenger_name:
            continue
        opp = league.members[opp_name]
        opp_play = make_player(
            opp,
            model_factory=model_factory,
            edge_index=edge_index,
            device=device,
            num_sims=num_sims,
            seed=seed + (abs(hash(opp_name)) % (2**16)),
        )
        a_w, b_w, draws = play_match(
            env_factory,
            challenger_play,
            opp_play,
            games_per_match,
            alternate=True,
            opening_random_plies=opening_random_plies,
            seed=seed + (abs(hash(opp_name)) % (2**16)),
        )
        for _ in range(a_w):
            league.record_game(challenger_name, opp_name, 1.0)
        for _ in range(b_w):
            league.record_game(challenger_name, opp_name, 0.0)
        for _ in range(draws):
            league.record_game(challenger_name, opp_name, 0.5)
        out[opp_name] = (a_w, b_w, draws)
        if verbose:
            total = a_w + b_w + draws
            wr = (a_w + 0.5 * draws) / total if total else 0.0
            lo, hi = wilson_ci(a_w, total)
            print(
                f"  {challenger_name} vs {opp_name:<22} W/L/D={a_w:3d}/{b_w:3d}/{draws:2d}  "
                f"wr={wr*100:5.1f}% CI[{lo*100:4.1f}%,{hi*100:5.1f}%]  "
                f"elo {league.members[challenger_name].elo:6.1f} vs {league.members[opp_name].elo:6.1f}"
            )
    return out
