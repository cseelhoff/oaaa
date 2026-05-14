# oaaa-rl

Reinforcement-learning agent for the Odin Axis & Allies engine. See [`../plan.md`](../plan.md) for the full design document.

## Status

This is the **first-commit skeleton** described in plan.md §15. It contains:

- A working **Tic-Tac-Toe** environment + custom MCTS + tiny MLP model + training loop. This validates the framework end-to-end before any A&A integration. See plan.md §8 Step 1.
- The `AAEnv` interface (plan.md §6.1) with the TTT env as its first concrete implementation.
- A `ctypes` FFI stub matching the C-ABI surface in plan.md §4.1. All entry points raise `NotImplementedError` until the Odin shared library exposes them.
- MCTS (PUCT + Dirichlet noise + virtual loss + chance nodes) — usable today on TTT, ready for A&A once the engine FFI lands.
- Skeletons for the GNN encoder, autoregressive plan decoder, replay buffer, losses, self-play, BC pretraining and value pretraining.

## Quick start

```bash
cd rl-agent
python3 -m venv .venv && source .venv/bin/activate
pip install numpy pytest
pip install torch --index-url https://download.pytorch.org/whl/cpu  # CPU build is fine for TTT
pytest                              # runs the 12-test TTT smoke suite
```

Quick training-loop sanity check (TTT, ~20s on CPU):

```python
from envs.tictactoe import TicTacToeEnv
from model.tiny_mlp import TinyMLP
from train.trainer import Trainer, TrainerConfig

Trainer(env_factory=TicTacToeEnv, model=TinyMLP(),
        cfg=TrainerConfig(iterations=5, games_per_iter=8, num_simulations=64)).fit()
```

### NixOS note

`pip`-installed wheels expect `libstdc++.so.6` / `libz.so.1` on `LD_LIBRARY_PATH`. If imports fail with `cannot open shared object file`, add them from the nix store, e.g.:

```bash
export LD_LIBRARY_PATH="$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib:$(nix eval --raw nixpkgs#zlib)/lib:$LD_LIBRARY_PATH"
```

## Layout

See plan.md §5. Top-level packages:

- `triplea_odin/` — Python wrapper around the Odin engine (FFI + `AAEnv` for A&A).
- `envs/` — Concrete env implementations (TTT for now; A&A wired through `triplea_odin`).
- `model/` — Encoder, plan decoder, value head.
- `mcts/` — Sampled AlphaZero MCTS with chance nodes.
- `train/` — Self-play, replay buffer, losses, trainer, eval, pretraining scripts.
- `tests/` — Tests; run with `pytest`.
- `tools/` — Dataset generation, benchmarking, replay rendering.

## Build order

Follow `plan.md` §8 strictly. Do not skip ahead. The current skeleton lands you at the **start of Step 1**; the TTT smoke test is the gate.
