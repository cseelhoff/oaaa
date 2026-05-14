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
