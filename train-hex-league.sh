#!/usr/bin/env bash
# Hex GNN league training run. Handles NixOS LD_LIBRARY_PATH and venv activation
# automatically so you don't hit `libstdc++.so.6: cannot open shared object`.
#
# Pass extra args through, e.g.:
#   ./train-hex-league.sh --iterations 50 --snapshot-dir checkpoints/hex_run3
set -euo pipefail

# Resolve repo root from this script's location (so it works from anywhere).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}/rl-agent"

# Activate the venv.
# shellcheck source=/dev/null
source .venv/bin/activate

# NixOS: PyTorch wheels need libstdc++ + libz on LD_LIBRARY_PATH.
export LD_LIBRARY_PATH="$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib:$(nix eval --raw nixpkgs#zlib)/lib:${LD_LIBRARY_PATH:-}"

# Unbuffer Python so progress lines appear in real time when piped to tee.
export PYTHONUNBUFFERED=1

exec python -m train.demo_hex_league \
    --board-size 7 --iterations 30 \
    --self-play-games 64 --num-simulations 120 \
    --train-steps-per-iter 200 --batch-size 128 \
    --hidden 64 --layers 4 \
    --recent-window 2000 --recent-fraction 0.5 \
    --swap-rule \
    --opening-random-plies 2 \
    --league-eval-games 12 --league-eval-sims 200 \
    --snapshot-every 2 \
    --raw-mcts-low 60 --raw-mcts-mid 200 --raw-mcts-high 800 \
    --snapshot-dir checkpoints/hex_run3 \
    "$@"