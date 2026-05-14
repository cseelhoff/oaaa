"""Tiny MLP policy/value net for the TTT smoke test (plan.md §8 step 1)."""

from __future__ import annotations

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from envs.tictactoe import NUM_ACTIONS, OBS_DIM
from mcts.sampling import enumerate_flat_plans


class TinyMLP(nn.Module):
    """Two-headed MLP: shared trunk → policy logits + scalar value (tanh-bounded)."""

    def __init__(self, in_dim: int = OBS_DIM, hidden: int = 64, num_actions: int = NUM_ACTIONS) -> None:
        super().__init__()
        self.trunk = nn.Sequential(
            nn.Linear(in_dim, hidden),
            nn.ReLU(),
            nn.Linear(hidden, hidden),
            nn.ReLU(),
        )
        self.policy_head = nn.Linear(hidden, num_actions)
        self.value_head = nn.Linear(hidden, 1)

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        h = self.trunk(x)
        logits = self.policy_head(h)
        value = torch.tanh(self.value_head(h)).squeeze(-1)
        return logits, value


def make_tictactoe_policy_fn(net: TinyMLP, device: torch.device | str = "cpu"):
    """Adapter: ``env -> (plans, log_priors, value)``.

    Output value is from the perspective of the side to move (the obs is
    already in that POV — see :class:`envs.tictactoe.TicTacToeEnv.observation`).
    """
    net.eval()
    device = torch.device(device)

    @torch.no_grad()
    def policy_fn(env):
        obs = env.observation()
        x = torch.from_numpy(obs.global_features).to(device).unsqueeze(0)
        logits, value = net(x)
        legals = obs.legal_subactions
        if legals is None or legals.size == 0:
            return [], np.empty(0), float(value.item())
        plans, log_priors = enumerate_flat_plans(env, logits[0].cpu().numpy(), legals)
        return plans, log_priors, float(value.item())

    return policy_fn
