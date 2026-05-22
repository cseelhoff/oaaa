"""Replay buffer (plan.md §5 ``train/replay.py``).

Stores tuples produced by self-play and sampled in mini-batches by the trainer.
For the TTT smoke test we keep things in plain Python lists; for A&A this will
move to a Ray actor with disk-backed shards.
"""

from __future__ import annotations

import random
from collections import deque
from dataclasses import dataclass

import numpy as np


@dataclass
class Sample:
    """One MCTS-decision training tuple.

    Fields:
        observation     : flat float32 vector (TTT) or HeteroData (A&A).
        plan_indices    : int32 array of length K — indices into the action space
                          for each plan considered at the root. For TTT (one
                          sub-action per plan) these are simply the action ids.
        visits          : int64[K] — MCTS visit counts at the root.
        sample_log_probs: float64[K] — log-prob each plan was sampled with
                          (Sampled-AZ IS correction; plan.md §6.7).
        outcome         : float in {-1, 0, +1} — game result from the POV of the
                          player who acted at this state (plan.md §12.3).
    """

    observation: np.ndarray
    plan_indices: np.ndarray
    visits: np.ndarray
    sample_log_probs: np.ndarray
    outcome: float


class Replay:
    def __init__(self, capacity: int = 100_000, seed: int = 0) -> None:
        self.capacity = capacity
        self._buf: deque[Sample] = deque(maxlen=capacity)
        self._rng = random.Random(seed)

    def __len__(self) -> int:
        return len(self._buf)

    def add(self, sample: Sample) -> None:
        self._buf.append(sample)

    def extend(self, samples: list[Sample]) -> None:
        self._buf.extend(samples)

    def sample(self, batch_size: int) -> list[Sample]:
        if not self._buf:
            return []
        n = min(batch_size, len(self._buf))
        return self._rng.sample(list(self._buf), n)

    def sample_recent_mix(
        self,
        batch_size: int,
        recent_window: int = 2000,
        recent_fraction: float = 0.5,
    ) -> list[Sample]:
        """Sample a mix of recent + uniform-over-buffer.

        Counters replay-buffer dilution: when the buffer is large (e.g.,
        20k samples) and per-iter additions are small (e.g., 1k), uniform
        sampling makes new self-play data <5% of any minibatch. Setting
        ``recent_window=2000, recent_fraction=0.5`` guarantees half of every
        minibatch comes from the freshest 2000 samples.

        Falls back to plain uniform sampling when the buffer is smaller
        than ``recent_window``.
        """
        if not self._buf:
            return []
        n = min(batch_size, len(self._buf))
        if recent_fraction <= 0.0 or recent_window <= 0:
            return self._rng.sample(list(self._buf), n)
        n_recent = min(int(round(n * recent_fraction)), len(self._buf))
        n_uniform = n - n_recent
        all_buf = list(self._buf)
        if recent_window >= len(all_buf):
            recent_pool = all_buf
        else:
            recent_pool = all_buf[-recent_window:]
        recent_pick = self._rng.sample(recent_pool, min(n_recent, len(recent_pool)))
        uniform_pick = (
            self._rng.sample(all_buf, n_uniform) if n_uniform > 0 else []
        )
        return recent_pick + uniform_pick
