"""Plan sampling — the "Sampled" in Sampled AlphaZero (plan.md §3.3, §6.4).

For TTT and other flat games each plan is a single sub-action; we just
enumerate the legals and use the policy directly. For A&A this module will
later host stochastic beam search and ProAI plan injection (plan.md §6.4).
"""

from __future__ import annotations

from typing import Callable, Sequence

import numpy as np

from .node import Plan

# Signature: env -> (plans, log_priors_over_those_plans, value_estimate_for_state)
PolicyFn = Callable[..., tuple[list[Plan], np.ndarray, float]]


def enumerate_flat_plans(
    env,
    policy_logits: np.ndarray,
    legal_subactions: np.ndarray,
) -> tuple[list[Plan], np.ndarray]:
    """For flat games (one sub-action per plan): return (plans, log_priors).

    ``policy_logits`` is the network's logit vector over the **full** action
    space (size = ``NUM_ACTIONS`` for the env). Illegal entries are masked to
    -inf before softmax.
    """
    masked = np.full_like(policy_logits, -np.inf)
    masked[legal_subactions] = policy_logits[legal_subactions]
    # log-softmax in a numerically-stable way
    m = masked.max()
    log_priors = masked - (m + np.log(np.exp(masked - m).sum()))
    plans = [(int(a),) for a in legal_subactions]
    log_p = log_priors[legal_subactions].astype(np.float64)
    return plans, log_p


def sample_k_plans_with_replacement(
    plans: Sequence[Plan],
    log_priors: np.ndarray,
    k: int,
    rng: np.random.Generator,
    always_include: Sequence[Plan] = (),
) -> tuple[list[Plan], np.ndarray, np.ndarray]:
    """Sample ``k`` plans with replacement; always include ``always_include``.

    Returns (chosen_plans, priors, sample_log_probs). Used for the future A&A
    path where the candidate space is too large to enumerate. Not used by the
    TTT smoke test (which calls :func:`enumerate_flat_plans` instead).
    """
    if not plans:
        return [], np.empty(0), np.empty(0)
    p = np.exp(log_priors - log_priors.max())
    p = p / p.sum()
    idx = rng.choice(len(plans), size=k, replace=True, p=p)
    chosen = [plans[i] for i in idx]
    chosen_priors = p[idx]
    chosen_logp = log_priors[idx]

    # Force-include extras by replacing the lowest-prior slots.
    if always_include:
        order = np.argsort(chosen_priors)
        for slot, extra in zip(order, always_include):
            chosen[slot] = extra
            chosen_priors[slot] = 1.0 / len(plans)  # neutral prior
            chosen_logp[slot] = -np.log(len(plans))
    # Renormalise priors over the K sampled plans.
    chosen_priors = chosen_priors / chosen_priors.sum()
    return chosen, chosen_priors, chosen_logp
