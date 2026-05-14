"""AlphaZero-style policy + value losses.

For the TTT smoke test we use the standard AlphaZero policy CE (no Sampled-AZ
importance correction needed because we enumerate the full action space at the
root). The Sampled-AZ correction (plan.md §6.7) is implemented in
:func:`sampled_alphazero_policy_loss` for the future A&A path.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F


def alphazero_loss(
    policy_logits: torch.Tensor,   # [B, A] over the *full* action space
    target_visits: torch.Tensor,   # [B, A] — visit counts; 0 for non-considered actions
    pred_value: torch.Tensor,      # [B] in [-1, +1]
    target_outcome: torch.Tensor,  # [B] in {-1, 0, +1}
    legal_mask: torch.Tensor,      # [B, A] bool — True where action is legal
) -> dict[str, torch.Tensor]:
    """Standard AlphaZero loss with legal-action masking.

    Returns dict with ``policy``, ``value``, ``total``.
    """
    # Mask illegal actions in the prediction.
    masked_logits = policy_logits.masked_fill(~legal_mask, float("-inf"))
    log_probs = F.log_softmax(masked_logits, dim=-1)
    # log_probs is -inf at illegal slots; the matching target is 0 but
    # ``0 * -inf == NaN`` in floating-point. Zero out illegal slots after the
    # softmax so the dot product stays finite.
    log_probs = log_probs.masked_fill(~legal_mask, 0.0)

    visits_sum = target_visits.sum(dim=-1, keepdim=True).clamp_min(1.0)
    target_policy = target_visits / visits_sum
    # Cross-entropy: -sum target * log_probs. Skip rows where no visits collected.
    valid_rows = (target_visits.sum(dim=-1) > 0).float()
    policy_loss = -(target_policy * log_probs).sum(dim=-1)
    policy_loss = (policy_loss * valid_rows).sum() / valid_rows.sum().clamp_min(1.0)

    value_loss = F.mse_loss(pred_value, target_outcome)
    total = policy_loss + value_loss
    return {"policy": policy_loss, "value": value_loss, "total": total}


def sampled_alphazero_policy_loss(
    pred_plan_logits: torch.Tensor,   # [B, K]
    target_visits: torch.Tensor,       # [B, K]
    sample_log_probs: torch.Tensor,    # [B, K] — log-prob each plan was sampled with
    is_clip: float = 10.0,
) -> torch.Tensor:
    """Sampled AlphaZero policy CE with importance correction (plan.md §6.7).

    Implements Hubert et al. 2021 §4. Cross-check before relying on this path
    (plan.md §12.4).
    """
    target_policy = target_visits / target_visits.sum(dim=-1, keepdim=True).clamp_min(1.0)
    sample_probs = sample_log_probs.exp().clamp_min(1e-8)
    is_weights = (target_policy.detach() / sample_probs).clamp(max=is_clip)
    log_pred = F.log_softmax(pred_plan_logits, dim=-1)
    return -(is_weights * target_policy * log_pred).sum(dim=-1).mean()
