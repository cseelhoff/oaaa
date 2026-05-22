"""Hex GNN training with batched MCTS, optional torch.compile, GPU
auto-detect, and a league with Elo leaderboard.

Improvements over the original demo (rationale in chat history):

- **Drops the persistent ``current`` member.** Each snapshot is the
  challenger for exactly one round-robin, so its Elo measures relative
  position at the moment it was taken — no inflation from repeated wins
  against weak baselines.
- **Multiple raw_mcts strength ladders** (60 / 200 / 800 sims) so we always
  have at least one external opponent that hasn't saturated.
- **Wilson 95% CI** on every match outcome — distinguishes "we can't tell"
  from "really equal".
- **Recent-window replay sampling** to counter buffer dilution: half of
  every minibatch comes from the freshest ``--recent-window`` samples.
- **Network capacity exposed** via ``--hidden`` and ``--layers``.

Run:
    python -m train.demo_hex_league --board-size 5 --iterations 30 \\
        --self-play-games 64 --num-simulations 120 \\
        --train-steps-per-iter 200 --batch-size 128 \\
        --hidden 64 --layers 4 \\
        --recent-window 2000 --recent-fraction 0.5 \\
        --league-eval-games 60 --league-eval-sims 200 \\
        --snapshot-every 2

Add ``--compile`` to opt into ``torch.compile``. ``--device auto`` picks
CUDA when available *and* the planned batch size is large enough.
"""

from __future__ import annotations

import argparse
import os
import time

import numpy as np
import torch

from envs.hex import HexEnv
from mcts.batched_search import BatchedMCTSConfig
from model.tiny_gnn import (
    TinyGNN,
    make_batched_hex_policy_fn,
    maybe_compile,
)
from train.batched_self_play import batched_self_play_hex
from train.demo_hex import HexTrainer, HexTrainerConfig
from train.league import League, round_robin_vs, wilson_ci


def auto_device(batch_size: int, threshold: int = 16) -> str:
    if torch.cuda.is_available() and batch_size >= threshold:
        return "cuda"
    return "cpu"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--board-size", type=int, default=5)
    p.add_argument("--iterations", type=int, default=20)
    p.add_argument("--self-play-games", type=int, default=64, help="K parallel games per iteration")
    p.add_argument("--num-simulations", type=int, default=80, help="MCTS sims per move (self-play)")
    p.add_argument("--train-steps-per-iter", type=int, default=100)
    p.add_argument("--batch-size", type=int, default=64, help="SGD batch size")
    # Replay sampling.
    p.add_argument("--recent-window", type=int, default=2000,
                   help="Hybrid sampling: freshest N samples form one half of every batch (0 disables)")
    p.add_argument("--recent-fraction", type=float, default=0.5,
                   help="Fraction of each batch drawn from the recent window")
    # Model.
    p.add_argument("--hidden", type=int, default=64, help="GNN hidden dim")
    p.add_argument("--layers", type=int, default=4, help="GNN message-passing layers")
    # League.
    p.add_argument("--league-eval-games", type=int, default=2,
                   help="Games per pair when evaluating. Eval is fully deterministic"
                        " (greedy argmax + fixed seed + no Dirichlet noise), so 2 games"
                        " — one with each agent moving first — captures the entire"
                        " outcome space when --opening-random-plies is 0. With"
                        " --opening-random-plies>0, bump this to ~10–20 so each"
                        " matchup samples enough distinct openings.")
    p.add_argument("--league-eval-sims", type=int, default=150, help="MCTS sims/move during league eval (model players)")
    p.add_argument("--opening-random-plies", type=int, default=0,
                   help="Force the first N plies of every eval game to uniform-random."
                        " Re-introduces matchup variance when both players are deterministic"
                        " (greedy MCTS + fixed seed). 1–2 is plenty.")
    p.add_argument("--swap-rule", action="store_true",
                   help="Enable Hex's swap rule (a.k.a. pie rule) so P1 may steal"
                        " P0's first move. Eliminates first-mover advantage; required"
                        " on small boards where P0 always wins under perfect play."
                        " Adds one extra action slot (SWAP) to the policy head.")
    p.add_argument("--snapshot-every", type=int, default=2, help="Save a frozen snapshot every N iters")
    p.add_argument("--snapshot-dir", type=str, default="checkpoints/hex_league")
    # Strong external baselines (raw MCTS, no NN). 0 disables a tier.
    p.add_argument("--raw-mcts-low", type=int, default=60)
    p.add_argument("--raw-mcts-mid", type=int, default=200)
    p.add_argument("--raw-mcts-high", type=int, default=800)
    # Runtime.
    p.add_argument("--device", type=str, default="auto", choices=["auto", "cpu", "cuda"])
    p.add_argument("--compile", action="store_true", help="Enable torch.compile on the model")
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    device = auto_device(args.self_play_games) if args.device == "auto" else args.device
    print("=" * 78)
    print("HEX LEAGUE TRAINING")
    print("=" * 78)
    print(
        f"[setup] device={device}  K={args.self_play_games}  sims/move={args.num_simulations}  "
        f"compile={args.compile}  board={args.board_size}x{args.board_size}"
    )
    print(
        f"[setup] gnn hidden={args.hidden} layers={args.layers}  "
        f"replay recent_window={args.recent_window} recent_frac={args.recent_fraction}"
    )

    model = TinyGNN(hidden=args.hidden, num_layers=args.layers, swap_rule=args.swap_rule).to(device)
    model = maybe_compile(model, enabled=args.compile)

    env_factory = lambda: HexEnv(args.board_size, swap_rule=args.swap_rule)  # noqa: E731
    sample_env = env_factory()
    sample_env.reset()
    edge_index_t = torch.from_numpy(sample_env._edge_index).to(device)
    num_cells = sample_env.num_cells
    num_actions = sample_env.num_actions

    trainer_cfg = HexTrainerConfig(
        iterations=1,
        games_per_iter=args.self_play_games,
        train_steps_per_iter=args.train_steps_per_iter,
        batch_size=args.batch_size,
        num_simulations=args.num_simulations,
        seed=args.seed,
        device=device,
        recent_window=args.recent_window,
        recent_fraction=args.recent_fraction,
    )
    trainer = HexTrainer(env_factory=env_factory, model=model, cfg=trainer_cfg)

    batched_policy_fn = make_batched_hex_policy_fn(
        model, edge_index_t, device=device, num_cells=num_actions
    )

    # ---- League setup ----------------------------------------------------------
    league = League(snapshot_dir=args.snapshot_dir)
    league.add_baseline("random", "random", elo=1000.0)
    if args.raw_mcts_low > 0:
        league.add_baseline(f"raw_mcts_{args.raw_mcts_low}", "raw_mcts",
                            elo=1100.0, num_sims=args.raw_mcts_low)
    if args.raw_mcts_mid > 0:
        league.add_baseline(f"raw_mcts_{args.raw_mcts_mid}", "raw_mcts",
                            elo=1300.0, num_sims=args.raw_mcts_mid)
    if args.raw_mcts_high > 0:
        league.add_baseline(f"raw_mcts_{args.raw_mcts_high}", "raw_mcts",
                            elo=1500.0, num_sims=args.raw_mcts_high)

    overall_t0 = time.time()
    last_snap_name: str | None = None
    last_snap_elo: float = 1200.0

    for it in range(args.iterations):
        # ----- batched self-play ------------------------------------------------
        t0 = time.time()
        envs = [env_factory() for _ in range(args.self_play_games)]
        for e in envs:
            e.reset()
        sp_cfg = BatchedMCTSConfig(
            num_simulations=args.num_simulations,
            seed=args.seed + 1000 + it,
            add_root_noise=True,
        )
        samples = batched_self_play_hex(
            envs=envs,
            batch_policy_fn=batched_policy_fn,
            mcts_cfg=sp_cfg,
            temperature_moves=8,
            seed=args.seed + 5000 + it,
        )
        for s in samples:
            trainer.replay.add(s)
        sp_t = time.time() - t0

        # ----- training ---------------------------------------------------------
        t0 = time.time()
        stats = trainer._train_steps()
        tr_t = time.time() - t0

        print(
            f"[iter {it:03d}] self_play={sp_t:5.1f}s ({len(samples):4d} samples, "
            f"{args.self_play_games}g)  train={tr_t:5.1f}s  "
            f"replay={len(trainer.replay):5d}  policy={stats['policy']:.4f} value={stats['value']:.4f}"
        )

        # ----- league eval (every N iters) -------------------------------------
        is_last = (it + 1) == args.iterations
        if (it + 1) % args.snapshot_every == 0 or is_last:
            snap_name = f"iter_{it+1:03d}"
            league.add_snapshot(snap_name, model, elo=last_snap_elo)

            opponents = [n for n in league.members if n != snap_name]
            print(
                f"[league] eval round '{snap_name}' vs {len(opponents)} members  "
                f"({args.league_eval_games} games each, {args.league_eval_sims} sims/move)"
            )
            t0 = time.time()
            results = round_robin_vs(
                league,
                challenger_name=snap_name,
                opponent_names=opponents,
                env_factory=env_factory,
                model_factory=lambda: TinyGNN(
                    hidden=args.hidden,
                    num_layers=args.layers,
                    swap_rule=args.swap_rule,
                ).to(device),
                edge_index=edge_index_t,
                device=device,
                num_sims=args.league_eval_sims,
                games_per_match=args.league_eval_games,
                seed=args.seed + 2000 + it,
                live_model=model,
                opening_random_plies=args.opening_random_plies,
            )

            # Headline: vs the previous snapshot (true delta).
            if last_snap_name is not None and last_snap_name in results:
                a_w, b_w, draws = results[last_snap_name]
                total = a_w + b_w + draws
                wr = (a_w + 0.5 * draws) / total if total else 0.0
                lo, hi = wilson_ci(a_w, total)
                if lo > 0.5:
                    tag = "BETTER"
                elif hi < 0.5:
                    tag = "WORSE "
                else:
                    tag = "TIED  "
                print(
                    f"[delta] {snap_name} vs {last_snap_name}: wr={wr*100:5.1f}% "
                    f"CI[{lo*100:4.1f}%,{hi*100:5.1f}%]  -> {tag}"
                )

            print(f"[league] eval round in {time.time()-t0:.1f}s")
            print(league.leaderboard())
            league.save(os.path.join(args.snapshot_dir, "league.json"))

            last_snap_name = snap_name
            last_snap_elo = league.members[snap_name].elo

    print(f"\n[done] total wall time {time.time()-overall_t0:.1f}s")
    print(league.leaderboard())


if __name__ == "__main__":
    main()
