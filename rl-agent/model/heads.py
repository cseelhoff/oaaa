"""Output heads (plan.md §6.5). The TTT smoke test uses heads embedded inside
``TinyMLP`` directly; this file hosts shared head definitions for the A&A model."""

from __future__ import annotations

import torch
import torch.nn as nn


class ValueHead(nn.Module):
    """``global_emb -> scalar in [-1, +1]``."""

    def __init__(self, in_dim: int, hidden: int = 128) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, hidden),
            nn.ReLU(),
            nn.Linear(hidden, 1),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.tanh(self.net(x)).squeeze(-1)
