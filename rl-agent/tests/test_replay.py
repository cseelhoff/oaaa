"""Tests for replay buffer hybrid sampling."""

from __future__ import annotations

import numpy as np

from train.replay import Replay, Sample


def _mk_sample(idx: int) -> Sample:
    """Make a uniquely-tagged sample (observation[0] = idx)."""
    return Sample(
        observation=np.array([float(idx)], dtype=np.float32),
        plan_indices=np.array([0], dtype=np.int32),
        visits=np.array([1], dtype=np.int64),
        sample_log_probs=np.array([0.0], dtype=np.float64),
        outcome=0.0,
    )


def test_sample_recent_mix_basic_shape():
    rb = Replay(capacity=10_000, seed=0)
    for i in range(5_000):
        rb.add(_mk_sample(i))
    batch = rb.sample_recent_mix(batch_size=64, recent_window=2_000, recent_fraction=0.5)
    assert len(batch) == 64
    # ~32 should come from idx >= 3000 (the recent window of 2000).
    recent_count = sum(1 for s in batch if s.observation[0] >= 3000)
    assert recent_count >= 28  # allow a little slack


def test_sample_recent_mix_falls_back_when_buffer_smaller_than_window():
    rb = Replay(capacity=1_000, seed=0)
    for i in range(500):
        rb.add(_mk_sample(i))
    batch = rb.sample_recent_mix(batch_size=64, recent_window=2_000, recent_fraction=0.5)
    assert len(batch) == 64
    # All draws are valid (no out-of-range), and we still get a real sample.
    for s in batch:
        assert 0 <= s.observation[0] < 500


def test_sample_recent_mix_disabled_when_window_zero():
    rb = Replay(capacity=10_000, seed=0)
    for i in range(2_000):
        rb.add(_mk_sample(i))
    batch = rb.sample_recent_mix(batch_size=32, recent_window=0, recent_fraction=0.5)
    assert len(batch) == 32  # uniform fallback, still works


def test_sample_recent_mix_recent_fraction_zero_is_uniform():
    rb = Replay(capacity=10_000, seed=0)
    for i in range(5_000):
        rb.add(_mk_sample(i))
    batch = rb.sample_recent_mix(batch_size=128, recent_window=500, recent_fraction=0.0)
    # Should be roughly uniform over [0, 5000); with 128 samples, mean idx
    # should be far from the recent-only mean of ~4750.
    mean_idx = float(np.mean([s.observation[0] for s in batch]))
    assert 1500 < mean_idx < 3500
