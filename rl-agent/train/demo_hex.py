"""End-to-end Hex 5x5 demo: GNN self-learning, then evaluation vs random.

Hex is a graph game (the win condition is graph connectivity), so this
exercises the GNN encoder + global-readout + per-node policy head shape
that A&A will need (plan.md §3.4, §6.3). No torch_geometric dependency —
the GNN is a tiny scatter_add implementation in :mod:`model.tiny_gnn`.

Run:
    python -m train.demo_hex
"""

from __future__ import annotations

import argparse
import time
from dataclasses import dataclass

import numpy as np
import torch

from envs.hex import HexEnv
from mcts import MCTS, MCTSConfig
from model.tiny_gnn import TinyGNN, make_hex_policy_fn
from train.losses import alphazero_loss
from train.replay import Replay, Sample
from train.self_play import visits_to_full_action_target


# ----- self-play (Hex variant — stores per-node features in Sample.observation) ----
def collect_hex_game(
    env: HexEnv,
    policy_fn,
    mcts_cfg: MCTSConfig,
    temperature_moves: int = 8,
    rng: np.random.Generator | None = None,
) -> list[Sample]:
    rng = rng or np.random.default_rng()
    env.reset()
    mcts = MCTS(policy_fn, mcts_cfg)

    trajectory: list[tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, int]] = []
    ply = 0
    while not env.is_terminal():
        result = mcts.run(env)
        plan_indices = np.array([p[0] for p in result.plans], dtype=np.int32)
        obs = env.observation()
        trajectory.append((
            obs.graph["node_features"].copy(),  # [N, F]
            obs.global_features.copy(),         # [G]
            plan_indices,
            result.visits.copy(),
            env.current_player(),
        ))

        if result.visits.sum() == 0:
            legals = obs.legal_subactions
            action = int(rng.choice(legals))
        elif ply < temperature_moves:
            probs = result.visits / result.visits.sum()
            chosen = int(rng.choice(len(plan_indices), p=probs))
            action = int(plan_indices[chosen])
        else:
            chosen = int(np.argmax(result.visits))
            action = int(plan_indices[chosen])

        env.apply_subaction(action)
        ply += 1

    z_team0 = env.team_reward(0)

    # Pack node_features and global_features together so we can reuse the
    # generic Replay buffer; we'll split them apart in the collate step.
    samples: list[Sample] = []
    for node_feats, global_feats, plan_idx, visits, player in trajectory:
        outcome = z_team0 if player == 0 else -z_team0
        # Flatten [N*F] then concat global_feats; stash original shape in dtype-agnostic way.
        N, F = node_feats.shape
        packed = np.concatenate(
            [
                np.array([N, F, global_feats.size], dtype=np.float32),
                node_feats.reshape(-1).astype(np.float32),
                global_feats.astype(np.float32),
            ]
        )
        samples.append(Sample(
            observation=packed,
            plan_indices=plan_idx,
            visits=visits.astype(np.int64),
            sample_log_probs=np.zeros_like(plan_idx, dtype=np.float64),
            outcome=float(outcome),
        ))
    return samples


def _unpack(packed: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    N = int(packed[0]); F = int(packed[1]); G = int(packed[2])
    node_feats = packed[3 : 3 + N * F].reshape(N, F)
    global_feats = packed[3 + N * F : 3 + N * F + G]
    return node_feats, global_feats


# ----- training -----------------------------------------------------------------
@dataclass
class HexTrainerConfig:
    iterations: int = 20
    games_per_iter: int = 16
    train_steps_per_iter: int = 80
    batch_size: int = 64
    lr: float = 1e-3
    weight_decay: float = 1e-4
    replay_capacity: int = 50_000
    num_simulations: int = 80
    dirichlet_alpha: float = 0.3
    temperature_moves: int = 8
    seed: int = 0
    device: str = "cpu"
    log_every: int = 1
    # Hybrid replay sampling: with ``recent_window > 0``, ``recent_fraction``
    # of every minibatch is drawn from the freshest ``recent_window`` samples
    # and the rest from the full buffer. Counters buffer dilution as more
    # iterations accumulate.
    recent_window: int = 0
    recent_fraction: float = 0.5


class HexTrainer:
    def __init__(self, env_factory, model: TinyGNN, cfg: HexTrainerConfig | None = None):
        self.env_factory = env_factory
        self.cfg = cfg or HexTrainerConfig()
        self.device = torch.device(self.cfg.device)
        self.model = model.to(self.device)
        self.optim = torch.optim.AdamW(
            self.model.parameters(), lr=self.cfg.lr, weight_decay=self.cfg.weight_decay
        )
        self.replay = Replay(capacity=self.cfg.replay_capacity, seed=self.cfg.seed)
        self._rng = np.random.default_rng(self.cfg.seed)
        # Hex graph topology is fixed across all states; pre-build the edge_index tensor.
        sample_env = env_factory()
        sample_env.reset()
        self._edge_index = torch.from_numpy(sample_env._edge_index).to(self.device)
        self._num_cells = sample_env.num_cells
        # When swap_rule is enabled the action vocabulary has one extra slot
        # for SWAP. Trainer targets and policy logits are sized to this width.
        self._num_actions = sample_env.num_actions

    def fit(self) -> None:
        for it in range(self.cfg.iterations):
            self._collect()
            stats = self._train_steps()
            if it % self.cfg.log_every == 0:
                print(
                    f"[iter {it:03d}] replay={len(self.replay):5d} "
                    f"policy={stats['policy']:.4f} value={stats['value']:.4f}"
                )

    def _collect(self) -> None:
        policy_fn = make_hex_policy_fn(self.model, self.device)
        for _ in range(self.cfg.games_per_iter):
            env = self.env_factory()
            cfg = MCTSConfig(
                num_simulations=self.cfg.num_simulations,
                dirichlet_alpha=self.cfg.dirichlet_alpha,
                seed=int(self._rng.integers(1, 2**31 - 1)),
            )
            self.replay.extend(collect_hex_game(
                env=env,
                policy_fn=policy_fn,
                mcts_cfg=cfg,
                temperature_moves=self.cfg.temperature_moves,
                rng=self._rng,
            ))

    def _train_steps(self) -> dict[str, float]:
        if len(self.replay) == 0:
            return {"policy": float("nan"), "value": float("nan")}
        self.model.train()
        running = {"policy": 0.0, "value": 0.0, "n": 0}
        for _ in range(self.cfg.train_steps_per_iter):
            if self.cfg.recent_window > 0:
                batch = self.replay.sample_recent_mix(
                    self.cfg.batch_size,
                    recent_window=self.cfg.recent_window,
                    recent_fraction=self.cfg.recent_fraction,
                )
            else:
                batch = self.replay.sample(self.cfg.batch_size)
            node_feats, global_feats, visits_full, legal, outcomes = self._collate(batch)
            policy_logits, values = self.model.forward_batch(
                node_feats, self._edge_index, global_feats
            )
            losses = alphazero_loss(
                policy_logits=policy_logits,
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

    def _collate(self, batch: list[Sample]):
        B = len(batch)
        # Unpack one to get shapes.
        nf0, gf0 = _unpack(batch[0].observation)
        N, Fdim = nf0.shape
        G = gf0.size
        node_feats = np.zeros((B, N, Fdim), dtype=np.float32)
        global_feats = np.zeros((B, G), dtype=np.float32)
        visits_full = np.zeros((B, self._num_actions), dtype=np.int64)
        legal = np.zeros((B, self._num_actions), dtype=bool)
        outcomes = np.zeros(B, dtype=np.float32)
        for i, s in enumerate(batch):
            nf, gf = _unpack(s.observation)
            node_feats[i] = nf
            global_feats[i] = gf
            v, lm = visits_to_full_action_target(s.plan_indices, s.visits, self._num_actions)
            visits_full[i] = v
            legal[i] = lm
            outcomes[i] = s.outcome
        return (
            torch.from_numpy(node_feats).to(self.device),
            torch.from_numpy(global_feats).to(self.device),
            torch.from_numpy(visits_full).float().to(self.device),
            torch.from_numpy(legal).to(self.device),
            torch.from_numpy(outcomes).to(self.device),
        )


# ----- evaluation ---------------------------------------------------------------
@dataclass
class EvalResult:
    games: int
    wins: int
    losses: int

    @property
    def win_rate(self) -> float:
        return self.wins / self.games if self.games else 0.0

    def __str__(self) -> str:
        return f"games={self.games} W/L={self.wins}/{self.losses} win-rate={self.win_rate*100:.1f}%"


def _greedy(env, policy_fn, sims):
    cfg = MCTSConfig(num_simulations=sims, add_root_noise=False, seed=0)
    res = MCTS(policy_fn, cfg).run(env)
    best = int(np.argmax(res.visits))
    return int(res.plans[best][0])


def evaluate_vs_random(model, num_games: int, num_simulations: int, board_size: int, seed: int):
    policy_fn = make_hex_policy_fn(model, "cpu")
    rng = np.random.default_rng(seed)
    wins = losses = 0
    for g in range(num_games):
        env = HexEnv(board_size)
        env.reset()
        agent = g % 2
        while not env.is_terminal():
            if env.current_player() == agent:
                a = _greedy(env, policy_fn, num_simulations)
            else:
                legals = env.legal_subactions()
                a = int(rng.choice(legals))
            env.apply_subaction(a)
        r = env.team_reward(agent)
        if r > 0:
            wins += 1
        elif r < 0:
            losses += 1
    return EvalResult(games=num_games, wins=wins, losses=losses)


# ----- driver -------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser()
    p.add_argument("--board-size", type=int, default=5)
    p.add_argument("--iterations", type=int, default=20)
    p.add_argument("--games-per-iter", type=int, default=16)
    p.add_argument("--train-steps-per-iter", type=int, default=80)
    p.add_argument("--num-simulations", type=int, default=80)
    p.add_argument("--eval-games", type=int, default=100)
    p.add_argument("--eval-sims", type=int, default=200)
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    print("=" * 70)
    print(f"HEX {args.board_size}x{args.board_size} GNN SELF-LEARNING DEMO")
    print("=" * 70)

    model = TinyGNN()

    print("[baseline] evaluating UNTRAINED GNN ...")
    t0 = time.time()
    pre = evaluate_vs_random(
        model,
        num_games=args.eval_games,
        num_simulations=args.eval_sims,
        board_size=args.board_size,
        seed=args.seed,
    )
    print(f"  mcts+gnn vs random : {pre}  ({time.time()-t0:.1f}s)\n")

    cfg = HexTrainerConfig(
        iterations=args.iterations,
        games_per_iter=args.games_per_iter,
        train_steps_per_iter=args.train_steps_per_iter,
        num_simulations=args.num_simulations,
        seed=args.seed,
    )
    trainer = HexTrainer(env_factory=lambda: HexEnv(args.board_size), model=model, cfg=cfg)
    print(f"[train] starting GNN self-play training ...")
    t0 = time.time()
    trainer.fit()
    print(f"[train] done in {time.time()-t0:.1f}s\n")

    print("[final] evaluating TRAINED GNN ...")
    t0 = time.time()
    post = evaluate_vs_random(
        model,
        num_games=args.eval_games,
        num_simulations=args.eval_sims,
        board_size=args.board_size,
        seed=args.seed + 1,
    )
    print(f"  mcts+gnn vs random : {post}  ({time.time()-t0:.1f}s)\n")

    print("=" * 70)
    print("RESULT")
    print("=" * 70)
    print(f"win-rate vs random: {pre.win_rate*100:5.1f}% -> {post.win_rate*100:5.1f}%")
    if post.losses == 0:
        print("\nPASS: trained GNN agent never lost to random opponent.")
    else:
        print(f"\nFAIL: trained GNN agent lost {post.losses} games.")
    raise SystemExit(0 if post.losses == 0 else 1)


if __name__ == "__main__":
    main()
