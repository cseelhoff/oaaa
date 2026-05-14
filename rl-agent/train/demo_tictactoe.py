"""End-to-end TTT demo: self-play training, then evaluation vs a random opponent.

Run:
    python -m train.demo_tictactoe

Demonstrates plan.md §8 step 1: the framework self-learns and reaches 100%
no-loss play against a random opponent.
"""

from __future__ import annotations

import argparse
import time

import numpy as np
import torch

from envs.tictactoe import TicTacToeEnv
from model.tiny_mlp import TinyMLP
from train.eval import evaluate_raw_policy_vs_random, evaluate_vs_random
from train.trainer import Trainer, TrainerConfig


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--iterations", type=int, default=15)
    p.add_argument("--games-per-iter", type=int, default=20)
    p.add_argument("--train-steps-per-iter", type=int, default=80)
    p.add_argument("--num-simulations", type=int, default=50)
    p.add_argument("--eval-games", type=int, default=200)
    p.add_argument("--eval-sims", type=int, default=64)
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    print("=" * 70)
    print("TIC-TAC-TOE SELF-LEARNING DEMO (plan.md §8 step 1)")
    print("=" * 70)
    print(f"iterations          : {args.iterations}")
    print(f"games_per_iter      : {args.games_per_iter}")
    print(f"train_steps_per_iter: {args.train_steps_per_iter}")
    print(f"mcts simulations    : {args.num_simulations}")
    print(f"eval games          : {args.eval_games}")
    print(f"eval mcts sims      : {args.eval_sims}")
    print()

    model = TinyMLP()

    # ---- baseline: untrained network --------------------------------------------
    print("[baseline] evaluating UNTRAINED network ...")
    t0 = time.time()
    raw_pre = evaluate_raw_policy_vs_random(model, num_games=args.eval_games, seed=args.seed)
    mcts_pre = evaluate_vs_random(
        model,
        num_games=args.eval_games,
        num_simulations=args.eval_sims,
        seed=args.seed,
    )
    print(f"  raw policy   vs random : {raw_pre}")
    print(f"  mcts+net     vs random : {mcts_pre}")
    print(f"  ({time.time() - t0:.1f}s)")
    print()

    # ---- training ---------------------------------------------------------------
    cfg = TrainerConfig(
        iterations=args.iterations,
        games_per_iter=args.games_per_iter,
        train_steps_per_iter=args.train_steps_per_iter,
        num_simulations=args.num_simulations,
        batch_size=64,
        seed=args.seed,
    )
    trainer = Trainer(env_factory=TicTacToeEnv, model=model, cfg=cfg)
    print(f"[train] starting self-play training ...")
    t0 = time.time()
    trainer.fit()
    print(f"[train] done in {time.time() - t0:.1f}s")
    print()

    # ---- final eval -------------------------------------------------------------
    print("[final] evaluating TRAINED model ...")
    t0 = time.time()
    raw_post = evaluate_raw_policy_vs_random(model, num_games=args.eval_games, seed=args.seed + 1)
    mcts_post = evaluate_vs_random(
        model,
        num_games=args.eval_games,
        num_simulations=args.eval_sims,
        seed=args.seed + 1,
    )
    print(f"  raw policy   vs random : {raw_post}")
    print(f"  mcts+net     vs random : {mcts_post}")
    print(f"  ({time.time() - t0:.1f}s)")
    print()

    # ---- verdict ----------------------------------------------------------------
    print("=" * 70)
    print("RESULT")
    print("=" * 70)
    print(f"raw-policy  no-loss-rate: {raw_pre.no_loss_rate*100:5.1f}%  ->  {raw_post.no_loss_rate*100:5.1f}%")
    print(f"mcts+net    no-loss-rate: {mcts_pre.no_loss_rate*100:5.1f}%  ->  {mcts_post.no_loss_rate*100:5.1f}%")
    if mcts_post.losses == 0:
        print("\nPASS: trained MCTS+net agent never lost to random opponent.")
    else:
        print(f"\nFAIL: trained MCTS+net agent lost {mcts_post.losses} games.")
    raise SystemExit(0 if mcts_post.losses == 0 else 1)


if __name__ == "__main__":
    main()
