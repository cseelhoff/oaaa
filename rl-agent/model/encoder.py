"""HeteroGNN encoder for A&A states (plan.md §6.3). **Stub.**

Will use ``torch_geometric.nn`` HGT or R-GCN once the FFI surface is wired
and we have a real ``HeteroData`` observation to feed in.
"""

from __future__ import annotations

import torch.nn as nn


class HeteroGNN(nn.Module):
    """Placeholder. Implement after plan.md §8 step 4 (toy A&A env)."""

    def __init__(self, hidden: int = 128, num_layers: int = 4) -> None:
        super().__init__()
        self.hidden = hidden
        self.num_layers = num_layers

    def forward(self, *_args, **_kwargs):  # pragma: no cover — stub
        raise NotImplementedError("HeteroGNN is stubbed; see plan.md §6.3.")
