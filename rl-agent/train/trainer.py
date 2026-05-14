"""Trainer (plan.md §6.9). Single-process loop suitable for the TTT smoke test.

Public surface:

    cfg = TrainerConfig(...)
    trainer = Trainer(env_factory, model, cfg)
    trainer.fit()

Where ``env_factory()`` returns a fresh :class:`Env` for self-play.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np
import torch
import torch.nn as nn

from envs.tictactoe import NUM_ACTIONS
from mcts import MCTSConfig
from model.tiny_mlp import TinyMLP, make_tictactoe_policy_fn
from triplea_odin.env_base import Env

from .losses import alphazero_loss
from .replay import Replay, Sample
from .self_play import collect_game, visits_to_full_action_target


@dataclass
class TrainerConfig:
    iterations: int = 30
    games_per_iter: int = 20
    train_steps_per_iter: int = 50
    batch_size: int = 64
    lr: float = 1e-3
    weight_decay: float = 1e-4
    replay_capacity: int = 50_000
    num_simulations: int = 64
    dirichlet_alpha: float = 0.5
    temperature_moves: int = 4
    seed: int = 0
    device: str = "cpu"
    log_every: int = 1
    eval_every: int = 5
    num_actions: int = NUM_ACTIONS


class Trainer:
    def __init__(
        self,
        env_factory: Callable[[], Env],
        model: nn.Module,
        cfg: TrainerConfig | None = None,
    ) -> None:
        self.env_factory = env_factory
        self.cfg = cfg or TrainerConfig()
        self.device = torch.device(self.cfg.device)
        self.model = model.to(self.device)
        self.optim = torch.optim.AdamW(
            self.model.parameters(), lr=self.cfg.lr, weight_decay=self.cfg.weight_decay
        )
        self.replay = Replay(capacity=self.cfg.replay_capacity, seed=self.cfg.seed)
        self._rng = np.random.default_rng(self.cfg.seed)
        self.iter = 0

    # -- main loop ----------------------------------------------------------------
    def fit(self) -> None:
        for it in range(self.cfg.iterations):
            self.iter = it
            self._collect()
            stats = self._train_steps()
            if it % self.cfg.log_every == 0:
                print(
                    f"[iter {it:03d}] replay={len(self.replay):5d} "
                    f"policy={stats['policy']:.4f} value={stats['value']:.4f}"
                )

    # -- collection ---------------------------------------------------------------
    def _collect(self) -> None:
        if isinstance(self.model, TinyMLP):
            policy_fn = make_tictactoe_policy_fn(self.model, self.device)
        else:
            raise NotImplementedError("Only TinyMLP is wired for the smoke test.")
        for g in range(self.cfg.games_per_iter):
            env = self.env_factory()
            cfg = MCTSConfig(
                num_simulations=self.cfg.num_simulations,
                dirichlet_alpha=self.cfg.dirichlet_alpha,
                seed=int(self._rng.integers(1, 2**31 - 1)),
            )
            samples = collect_game(
                env=env,
                policy_fn=policy_fn,
                mcts_cfg=cfg,
                num_actions=self.cfg.num_actions,
                temperature_moves=self.cfg.temperature_moves,
                rng=self._rng,
            )
            self.replay.extend(samples)

    # -- training steps -----------------------------------------------------------
    def _train_steps(self) -> dict[str, float]:
        if len(self.replay) == 0:
            return {"policy": float("nan"), "value": float("nan")}
        self.model.train()
        running = {"policy": 0.0, "value": 0.0, "n": 0}
        for _ in range(self.cfg.train_steps_per_iter):
            batch = self.replay.sample(self.cfg.batch_size)
            obs, visits_full, legal, outcomes = self._collate(batch)
            logits, values = self.model(obs)
            losses = alphazero_loss(
                policy_logits=logits,
                target_visits=visits_full,
                pred_value=values,
                target_outcome=outcomes,
                legal_mask=legal,
            )
            self.optim.zero_grad(set_to_none=True)
            losses["total"].backward()
            torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
            self.optim.step()
            running["policy"] += float(losses["policy"].item())
            running["value"] += float(losses["value"].item())
            running["n"] += 1
        n = max(running["n"], 1)
        return {"policy": running["policy"] / n, "value": running["value"] / n}

    def _collate(self, batch: list[Sample]) -> tuple[torch.Tensor, ...]:
        obs = np.stack([s.observation for s in batch], axis=0)
        visits_full = np.zeros((len(batch), self.cfg.num_actions), dtype=np.int64)
        legal = np.zeros((len(batch), self.cfg.num_actions), dtype=bool)
        outcomes = np.zeros(len(batch), dtype=np.float32)
        for i, s in enumerate(batch):
            v, lm = visits_to_full_action_target(s.plan_indices, s.visits, self.cfg.num_actions)
            visits_full[i] = v
            legal[i] = lm
            outcomes[i] = s.outcome
        return (
            torch.from_numpy(obs).to(self.device),
            torch.from_numpy(visits_full).float().to(self.device),
            torch.from_numpy(legal).to(self.device),
            torch.from_numpy(outcomes).to(self.device),
        )
