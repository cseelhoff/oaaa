"""Autoregressive plan decoder (plan.md §6.4). **Stub.**

DipNet-shaped: at each step, attend over (encoder output, prefix sub-actions)
and emit a sub-action with legal-mask applied to logits. Implement after the
encoder is real.
"""

from __future__ import annotations

import torch.nn as nn


class PlanDecoder(nn.Module):
    """Placeholder. Implement after plan.md §8 step 4 (toy A&A env)."""

    def __init__(self, hidden: int = 128) -> None:
        super().__init__()
        self.hidden = hidden

    def step(self, *_args, **_kwargs):  # pragma: no cover — stub
        raise NotImplementedError("PlanDecoder is stubbed; see plan.md §6.4.")
