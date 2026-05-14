"""PUCT formula and exploration helpers (plan.md §6.6)."""

from __future__ import annotations

import math

import numpy as np

# AlphaZero defaults from Silver et al. 2017.
C_BASE = 19652.0
C_INIT = 1.25


def c_puct(parent_visits: int) -> float:
    """Adaptive ``c_puct`` that grows logarithmically with parent visits."""
    return math.log((parent_visits + C_BASE + 1.0) / C_BASE) + C_INIT


def puct_score(
    q_value: float,
    prior: float,
    parent_visits: int,
    child_visits: int,
    c: float | None = None,
) -> float:
    """Standard PUCT.

    ``q_value`` is from the *parent's* perspective (i.e. the side that selects
    this child). The caller must apply the sign flip.
    """
    if c is None:
        c = c_puct(parent_visits)
    u = c * prior * math.sqrt(max(parent_visits, 1)) / (1.0 + child_visits)
    return q_value + u


def add_dirichlet_noise(
    priors: np.ndarray,
    alpha: float,
    epsilon: float = 0.25,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """Mix Dirichlet noise into ``priors`` (root-only; plan.md §12.1)."""

    if priors.size == 0:
        return priors
    rng = rng if rng is not None else np.random.default_rng()
    noise = rng.dirichlet([alpha] * priors.size)
    return (1.0 - epsilon) * priors + epsilon * noise
