"""Tic-Tac-Toe env implementing the :class:`triplea_odin.env_base.Env` contract.

Used as the smoke test in plan.md §8 step 1: validates PUCT, Dirichlet,
replay buffer, training loop, and checkpointing without any of the A&A
machinery (no GNN, no plan decoder, no chance nodes).

State convention:
- Board is a length-9 ``int8`` vector, row-major, values in {0, 1, 2}
  where 0=empty, 1=Player-0 (X), 2=Player-1 (O).
- Player-0 always moves first.
- Sub-action ids = board index 0..8. There is no FINALIZE token: each plan
  contains exactly one sub-action and is auto-finalized.

Observation features (perspective of the side to move):
- 9 floats: 1.0 where current player has a piece.
- 9 floats: 1.0 where opponent has a piece.
- 1 float:  current player index (0/1) — useful sanity feature.

Total feature length: 19.
"""

from __future__ import annotations

import numpy as np

from triplea_odin.env_base import Env, Observation


_LINES: tuple[tuple[int, int, int], ...] = (
    (0, 1, 2), (3, 4, 5), (6, 7, 8),  # rows
    (0, 3, 6), (1, 4, 7), (2, 5, 8),  # cols
    (0, 4, 8), (2, 4, 6),             # diagonals
)

OBS_DIM = 19
NUM_ACTIONS = 9


class TicTacToeEnv(Env):
    """Two-player deterministic Tic-Tac-Toe."""

    def __init__(self) -> None:
        self._board = np.zeros(9, dtype=np.int8)
        self._to_move = 0  # 0 or 1
        self._winner: int | None = None  # 0, 1, or None (draw / in-progress)
        self._terminal = False

    # -- lifecycle -----------------------------------------------------------------
    def reset(self, seed: int = 0) -> Observation:  # noqa: ARG002 — deterministic
        self._board[:] = 0
        self._to_move = 0
        self._winner = None
        self._terminal = False
        return self.observation()

    def clone(self) -> "TicTacToeEnv":
        new = TicTacToeEnv()
        new._board = self._board.copy()
        new._to_move = self._to_move
        new._winner = self._winner
        new._terminal = self._terminal
        return new

    # -- queries -------------------------------------------------------------------
    def current_player(self) -> int:
        return self._to_move

    def is_terminal(self) -> bool:
        return self._terminal

    def team_reward(self, team: int) -> float:
        if not self._terminal or self._winner is None:
            return 0.0
        return 1.0 if self._winner == team else -1.0

    # -- sub-actions ---------------------------------------------------------------
    def legal_subactions(self) -> np.ndarray:
        if self._terminal:
            return np.empty(0, dtype=np.int32)
        return np.flatnonzero(self._board == 0).astype(np.int32)

    def apply_subaction(self, sub: int) -> None:
        if self._terminal:
            raise ValueError("game is terminal")
        if not (0 <= sub < 9):
            raise ValueError(f"out-of-range sub-action {sub}")
        if self._board[sub] != 0:
            raise ValueError(f"square {sub} is already occupied")
        self._board[sub] = self._to_move + 1
        self._update_terminal()
        if not self._terminal:
            self._to_move ^= 1

    # -- observation ---------------------------------------------------------------
    def observation(self) -> Observation:
        me = self._to_move + 1
        opp = (self._to_move ^ 1) + 1
        feats = np.zeros(OBS_DIM, dtype=np.float32)
        feats[0:9] = (self._board == me).astype(np.float32)
        feats[9:18] = (self._board == opp).astype(np.float32)
        feats[18] = float(self._to_move)
        return Observation(
            global_features=feats,
            graph=None,
            legal_subactions=self.legal_subactions(),
        )

    # -- helpers -------------------------------------------------------------------
    def _update_terminal(self) -> None:
        for a, b, c in _LINES:
            v = self._board[a]
            if v != 0 and self._board[b] == v and self._board[c] == v:
                self._winner = int(v) - 1
                self._terminal = True
                return
        if not (self._board == 0).any():
            self._winner = None  # draw
            self._terminal = True

    # -- debug ---------------------------------------------------------------------
    def render(self) -> str:
        chars = {0: ".", 1: "X", 2: "O"}
        rows = []
        for r in range(3):
            rows.append(" ".join(chars[int(self._board[3 * r + c])] for c in range(3)))
        return "\n".join(rows)
