"""Chance-node single-sample expansion (plan.md §6.6, "single-sample mode")."""

from __future__ import annotations

import hashlib

from .node import ChanceNode, DecisionNode, TerminalNode


def _outcome_key(env) -> int:
    """Stable key for a sampled outcome state. Uses observation bytes; falls
    back to ``id(env)`` when the env doesn't support observation."""
    try:
        feats = env.observation().global_features
        return int.from_bytes(hashlib.blake2b(feats.tobytes(), digest_size=8).digest(), "little")
    except Exception:
        return id(env)


def expand_chance(node: ChanceNode, seed: int):
    """Sample one combat outcome and return the resulting child node."""
    sampled = node.env.clone()
    sampled.resolve_combat(seed)
    key = _outcome_key(sampled)
    if key in node.outcomes:
        entry = node.outcomes[key]
        return entry[1]  # child node
    if sampled.is_terminal():
        # Value from POV of the player who *would* move next at the parent.
        # We just record the team-0 reward and let the search loop flip it.
        child = TerminalNode(sampled, value=sampled.team_reward(0), parent=node, depth=node.depth + 1)
    else:
        child = DecisionNode(sampled, parent=node, depth=node.depth + 1)
    node.outcomes[key] = [sampled, child, 0, 0.0]
    return child
