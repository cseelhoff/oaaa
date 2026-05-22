"""Tiny graph neural network for Hex (plan.md §6.3 preview).

A self-contained 4-layer GNN built with bare ``torch`` ops — no
``torch_geometric`` dependency. Same shape as the eventual A&A encoder:

    per-node features  ->  k message-passing layers  ->  per-node embeddings
                                                          + global readout
                                                          ↓
                                                   policy & value heads

Message passing uses **mean-aggregation of neighbor messages**. For each
edge (s, d) we compute message m = MLP(h_s) and scatter_add into d, then
divide by the in-degree to get the mean. After K layers we have node
embeddings; mean-pool them with the global features for the value head,
and project each node embedding to a scalar logit for the policy head.

This is the smallest GNN that exercises:
  * edge-driven message passing (the core A&A inductive bias)
  * per-node policy heads (Hex move = pick a cell ↔ A&A move = pick a
    territory/edge)
  * global-readout value head
"""

from __future__ import annotations

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from envs.hex import HexEnv
from mcts.sampling import enumerate_flat_plans


class GNNLayer(nn.Module):
    """One round of mean-aggregated message passing + residual MLP."""

    def __init__(self, hidden: int) -> None:
        super().__init__()
        self.msg = nn.Linear(hidden, hidden)
        self.update = nn.Sequential(
            nn.Linear(hidden * 2, hidden),
            nn.ReLU(),
            nn.Linear(hidden, hidden),
        )
        self.norm = nn.LayerNorm(hidden)

    def forward(self, h: torch.Tensor, edge_index: torch.Tensor) -> torch.Tensor:
        # h: [N, H]; edge_index: [2, E] (src, dst).
        src, dst = edge_index[0], edge_index[1]
        messages = self.msg(h[src])                      # [E, H]
        agg = torch.zeros_like(h)
        agg.index_add_(0, dst, messages)
        # Mean over neighbors: divide by in-degree (>=1 for any cell with at least one neighbor).
        deg = torch.zeros(h.shape[0], device=h.device, dtype=h.dtype)
        ones = torch.ones_like(src, dtype=h.dtype)
        deg.index_add_(0, dst, ones)
        deg = deg.clamp_min(1.0).unsqueeze(-1)
        agg = agg / deg
        new = self.update(torch.cat([h, agg], dim=-1))
        return self.norm(h + new)


class TinyGNN(nn.Module):
    """Four-layer GNN with policy + value heads.

    Output of ``forward(node_feats, edge_index, global_feats)``:
        policy_logits: [N]   — one logit per cell.
        value:         []    — scalar in [-1, +1].
    """

    def __init__(
        self,
        in_dim: int = HexEnv.PER_NODE_FEATURES,
        global_dim: int = HexEnv.GLOBAL_FEATURES,
        hidden: int = 32,
        num_layers: int = 4,
        swap_rule: bool = False,
    ) -> None:
        super().__init__()
        self.swap_rule = swap_rule
        self.in_proj = nn.Linear(in_dim, hidden)
        self.layers = nn.ModuleList([GNNLayer(hidden) for _ in range(num_layers)])
        self.policy_head = nn.Linear(hidden, 1)
        # Optional SWAP-action head: scalar logit derived from the global
        # readout. Only invoked when swap_rule is enabled. Parameters are
        # always allocated so checkpoints stay forward-compatible if the
        # caller flips ``swap_rule`` on later, but they are unused when off.
        self.swap_head = nn.Linear(hidden + global_dim, 1)
        self.value_head = nn.Sequential(
            nn.Linear(hidden + global_dim, hidden),
            nn.ReLU(),
            nn.Linear(hidden, 1),
        )

    def forward(
        self,
        node_feats: torch.Tensor,    # [N, F]
        edge_index: torch.Tensor,    # [2, E]
        global_feats: torch.Tensor,  # [G]
    ) -> tuple[torch.Tensor, torch.Tensor]:
        h = self.in_proj(node_feats)
        for layer in self.layers:
            h = layer(h, edge_index)
        cell_logits = self.policy_head(h).squeeze(-1)    # [N]
        pooled = h.mean(dim=0)                            # [H]
        v_in = torch.cat([pooled, global_feats], dim=-1)
        value = torch.tanh(self.value_head(v_in)).squeeze(-1)
        if self.swap_rule:
            swap_logit = self.swap_head(v_in).squeeze(-1).unsqueeze(0)  # [1]
            policy_logits = torch.cat([cell_logits, swap_logit], dim=0)  # [N+1]
        else:
            policy_logits = cell_logits
        return policy_logits, value

    def forward_batch(
        self,
        node_feats: torch.Tensor,    # [B, N, F]
        edge_index: torch.Tensor,    # [2, E] - shared across batch
        global_feats: torch.Tensor,  # [B, G]
    ) -> tuple[torch.Tensor, torch.Tensor]:
        """Vectorised batched forward; relies on the fact that the Hex graph
        is identical for every state in the batch (board topology is fixed)."""
        B, N, _ = node_feats.shape
        # Flatten batch into the node dimension by offsetting edge_index per item.
        h = self.in_proj(node_feats.reshape(B * N, -1))
        offsets = (torch.arange(B, device=node_feats.device) * N).repeat_interleave(edge_index.shape[1])
        ei = edge_index.repeat(1, B) + offsets.unsqueeze(0)
        for layer in self.layers:
            h = layer(h, ei)
        h = h.view(B, N, -1)
        cell_logits = self.policy_head(h).squeeze(-1)             # [B, N]
        pooled = h.mean(dim=1)                                     # [B, H]
        v_in = torch.cat([pooled, global_feats], dim=-1)
        value = torch.tanh(self.value_head(v_in)).squeeze(-1)      # [B]
        if self.swap_rule:
            swap_logits = self.swap_head(v_in)                     # [B, 1]
            policy_logits = torch.cat([cell_logits, swap_logits], dim=-1)  # [B, N+1]
        else:
            policy_logits = cell_logits
        return policy_logits, value


def make_hex_policy_fn(net: TinyGNN, device: torch.device | str = "cpu"):
    """Adapter ``env -> (plans, log_priors, value)`` for Hex.

    The value is from the side-to-move's POV (matches the
    perspective-aware obs returned by ``HexEnv.observation()``).
    """
    net.eval()
    device = torch.device(device)

    @torch.no_grad()
    def policy_fn(env):
        obs = env.observation()
        graph = obs.graph
        node_feats = torch.from_numpy(graph["node_features"]).to(device)
        edge_index = torch.from_numpy(graph["edge_index"]).to(device)
        global_feats = torch.from_numpy(obs.global_features).to(device)
        logits, value = net(node_feats, edge_index, global_feats)
        legals = obs.legal_subactions
        if legals is None or legals.size == 0:
            return [], np.empty(0), float(value.item())
        plans, log_priors = enumerate_flat_plans(env, logits.cpu().numpy(), legals)
        return plans, log_priors, float(value.item())

    return policy_fn


def make_batched_hex_policy_fn(
    net: TinyGNN,
    edge_index: torch.Tensor,
    device: torch.device | str = "cpu",
    num_cells: int | None = None,
):
    """Adapter ``[envs] -> [(plans, log_priors, value), ...]`` for Hex.

    All Hex states share the same board topology, so we stack node and global
    features into one batched tensor and call :meth:`TinyGNN.forward_batch`
    once per call. ``edge_index`` must already be on ``device``. ``num_cells``
    defaults to ``HexEnv.num_cells`` of the supplied envs (inferred lazily).
    """
    net.eval()
    device = torch.device(device)
    edge_index = edge_index.to(device)

    @torch.no_grad()
    def batch_policy_fn(envs):
        if not envs:
            return []
        # Gather observations.
        node_feats_list = []
        global_feats_list = []
        legals_list = []
        full_logits_size = num_cells
        for env in envs:
            obs = env.observation()
            node_feats_list.append(obs.graph["node_features"])
            global_feats_list.append(obs.global_features)
            legals_list.append(obs.legal_subactions)
            if full_logits_size is None:
                full_logits_size = obs.graph["node_features"].shape[0]

        node_feats = torch.from_numpy(np.stack(node_feats_list, axis=0)).to(device)
        global_feats = torch.from_numpy(np.stack(global_feats_list, axis=0)).to(device)
        logits_b, values_b = net.forward_batch(node_feats, edge_index, global_feats)
        logits_np = logits_b.cpu().numpy()                          # [B, N]
        values_np = values_b.cpu().numpy()                          # [B]

        out = []
        for env, legals, logits, value in zip(envs, legals_list, logits_np, values_np):
            if legals is None or legals.size == 0:
                out.append(([], np.empty(0), float(value)))
                continue
            plans, log_priors = enumerate_flat_plans(env, logits, legals)
            out.append((plans, log_priors, float(value)))
        return out

    return batch_policy_fn


def maybe_compile(model: nn.Module, enabled: bool = False) -> nn.Module:
    """Optionally wrap ``model`` in :func:`torch.compile`.

    Disabled by default because TinyGNN is small enough that compile overhead
    can exceed the speedup at K<=64. Surface the toggle and let the caller
    benchmark.
    """
    if not enabled:
        return model
    try:
        return torch.compile(model)  # type: ignore[attr-defined]
    except Exception as exc:  # pragma: no cover — best effort
        print(f"[maybe_compile] torch.compile failed ({exc}); using eager model.")
        return model
