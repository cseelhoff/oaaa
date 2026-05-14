"""Evaluation harness for TTT (plan.md §6.12, scaled down).

Plays the trained model against a random opponent for ``num_games``, alternating
who moves first. The trained side should NEVER lose if it is at perfect-play
strength — TTT is solved as a draw under perfect play, and a perfect player
beats a random player on most openings.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import torch

from envs.tictactoe import TicTacToeEnv
from mcts import MCTS, MCTSConfig
from model.tiny_mlp import TinyMLP, make_tictactoe_policy_fn


@dataclass
class EvalResult:
    games: int
    wins: int
    draws: int
    losses: int

    @property
    def no_loss_rate(self) -> float:
        return (self.wins + self.draws) / self.games if self.games else 0.0

    def __str__(self) -> str:
        return (
            f"games={self.games} W/D/L={self.wins}/{self.draws}/{self.losses} "
            f"no-loss={self.no_loss_rate * 100:.1f}%"
        )


def _greedy_move(env: TicTacToeEnv, policy_fn, num_simulations: int) -> int:
    cfg = MCTSConfig(
        num_simulations=num_simulations,
        add_root_noise=False,  # eval = no exploration
        seed=0,
    )
    res = MCTS(policy_fn, cfg).run(env)
    best = int(np.argmax(res.visits))
    return int(res.plans[best][0])


def evaluate_vs_random(
    model: TinyMLP,
    num_games: int = 100,
    num_simulations: int = 64,
    device: str = "cpu",
    seed: int = 0,
) -> EvalResult:
    """Play ``num_games`` halves as X and halves as O against a random opponent."""

    policy_fn = make_tictactoe_policy_fn(model, device)
    rng = np.random.default_rng(seed)
    wins = draws = losses = 0

    for g in range(num_games):
        env = TicTacToeEnv()
        env.reset()
        agent_player = g % 2  # alternate who moves first
        while not env.is_terminal():
            if env.current_player() == agent_player:
                action = _greedy_move(env, policy_fn, num_simulations)
            else:
                legals = env.legal_subactions()
                action = int(rng.choice(legals))
            env.apply_subaction(action)
        r = env.team_reward(agent_player)
        if r > 0:
            wins += 1
        elif r < 0:
            losses += 1
        else:
            draws += 1
    return EvalResult(games=num_games, wins=wins, draws=draws, losses=losses)


@torch.no_grad()
def evaluate_raw_policy_vs_random(
    model: TinyMLP,
    num_games: int = 100,
    device: str = "cpu",
    seed: int = 0,
) -> EvalResult:
    """Sanity check: play with the bare network (argmax over masked logits, no MCTS).

    Useful for confirming the network alone has learned something, independent
    of MCTS strength.
    """
    rng = np.random.default_rng(seed)
    model.eval()
    dev = torch.device(device)
    wins = draws = losses = 0
    for g in range(num_games):
        env = TicTacToeEnv()
        env.reset()
        agent = g % 2
        while not env.is_terminal():
            if env.current_player() == agent:
                obs = env.observation()
                x = torch.from_numpy(obs.global_features).to(dev).unsqueeze(0)
                logits, _ = model(x)
                masked = logits[0].cpu().numpy().copy()
                mask = np.full_like(masked, -np.inf)
                mask[obs.legal_subactions] = masked[obs.legal_subactions]
                action = int(np.argmax(mask))
            else:
                legals = env.legal_subactions()
                action = int(rng.choice(legals))
            env.apply_subaction(action)
        r = env.team_reward(agent)
        if r > 0:
            wins += 1
        elif r < 0:
            losses += 1
        else:
            draws += 1
    return EvalResult(games=num_games, wins=wins, draws=draws, losses=losses)
