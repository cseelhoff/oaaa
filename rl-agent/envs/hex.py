"""Hex env (plan.md §8 step 2 substitute — see chat history for rationale).

Hex is the canonical GNN-validating game: the board is literally a graph,
the win condition is graph connectivity (top↔bottom for player 0,
left↔right for player 1), and there are no draws. A GNN with k message-
passing layers can detect connections of length ≤ k, mirroring the
"k layers ≈ k territories of foresight" property A&A needs (plan.md §3.4).

Board is an N×N parallelogram of hex cells; default N=5 keeps MCTS fast
on CPU. Cell at (r, c) has up to 6 neighbors:
    (r-1, c), (r-1, c+1), (r, c-1), (r, c+1), (r+1, c-1), (r+1, c)

Player 0 (call it "Red") wins by connecting row 0 to row N-1.
Player 1 (call it "Blue") wins by connecting col 0 to col N-1.

Sub-action ids = cell index 0..N²-1 (row-major).
"""

from __future__ import annotations

import numpy as np

from triplea_odin.env_base import Env, Observation


HEX_NEIGHBOR_OFFSETS: tuple[tuple[int, int], ...] = (
    (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0),
)


def _build_adjacency(n: int) -> np.ndarray:
    """Return a directed edge_index ``[2, E]`` over the N² cells.

    Each interior cell has 6 neighbors; we store both directions for
    symmetric message passing.
    """
    src: list[int] = []
    dst: list[int] = []
    for r in range(n):
        for c in range(n):
            v = r * n + c
            for dr, dc in HEX_NEIGHBOR_OFFSETS:
                rr, cc = r + dr, c + dc
                if 0 <= rr < n and 0 <= cc < n:
                    src.append(v)
                    dst.append(rr * n + cc)
    return np.array([src, dst], dtype=np.int64)


class _UnionFind:
    """Compact union-find for win detection. Two extra virtual nodes per
    player anchor the relevant edges."""

    __slots__ = ("parent", "rank")

    def __init__(self, size: int) -> None:
        self.parent = list(range(size))
        self.rank = [0] * size

    def find(self, x: int) -> int:
        # Iterative path compression.
        root = x
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[x] != root:
            self.parent[x], x = root, self.parent[x]
        return root

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra == rb:
            return
        if self.rank[ra] < self.rank[rb]:
            ra, rb = rb, ra
        self.parent[rb] = ra
        if self.rank[ra] == self.rank[rb]:
            self.rank[ra] += 1


class HexEnv(Env):
    """Two-player deterministic Hex.

    Per-cell observation features (perspective of side to move):
        0: 1.0 where current player has a stone
        1: 1.0 where opponent has a stone
        2: 1.0 where empty
        3: 1.0 if cell touches the *current player's* "start" edge
        4: 1.0 if cell touches the *current player's* "end" edge
    Total per-cell feature width: 5.

    Global features (length 3): [current_player, ply / max_plies, swap_used].

    Swap rule (a.k.a. "pie rule"): when ``swap_rule=True``, P1's response to
    P0's first move may be the special action ``SWAP_ACTION_ID = num_cells``.
    SWAP mirrors P0's stone across the main diagonal and recolors it to P1;
    play continues with P0 to move. This neutralises P0's first-move
    advantage by giving P1 the option to steal a too-strong opening.
    The action space is ``num_cells + 1`` when ``swap_rule=True`` (the SWAP
    slot is permanently in the action vocabulary but only legal at ply 1 by
    P1). Disabled by default to keep existing tests/checkpoints unchanged.
    """

    PER_NODE_FEATURES = 5
    GLOBAL_FEATURES = 3

    def __init__(self, board_size: int = 5, swap_rule: bool = False) -> None:
        self.n = board_size
        self.num_cells = board_size * board_size
        self.swap_rule = swap_rule
        # Action vocabulary size including the SWAP slot when enabled.
        self.num_actions = self.num_cells + (1 if swap_rule else 0)
        self.SWAP_ACTION_ID = self.num_cells  # only meaningful when swap_rule is on
        self._board = np.zeros(self.num_cells, dtype=np.int8)  # 0=empty, 1=P0, 2=P1
        self._to_move = 0
        self._winner: int | None = None
        self._terminal = False
        self._ply = 0
        self._swap_used = False
        self._first_move_cell: int | None = None
        # Adjacency is fixed per board size; cache it.
        self._edge_index = _build_adjacency(board_size)
        # Union-find with two virtual nodes per player:
        #   index = num_cells + 0,1 (P0 top/bottom), 2,3 (P1 left/right).
        self._uf = _UnionFind(self.num_cells + 4)

    # -- lifecycle -----------------------------------------------------------------
    def reset(self, seed: int = 0) -> Observation:  # noqa: ARG002
        self._board[:] = 0
        self._to_move = 0
        self._winner = None
        self._terminal = False
        self._ply = 0
        self._swap_used = False
        self._first_move_cell = None
        self._uf = _UnionFind(self.num_cells + 4)
        return self.observation()

    def clone(self) -> "HexEnv":
        new = HexEnv(self.n, swap_rule=self.swap_rule)
        new._board = self._board.copy()
        new._to_move = self._to_move
        new._winner = self._winner
        new._terminal = self._terminal
        new._ply = self._ply
        new._swap_used = self._swap_used
        new._first_move_cell = self._first_move_cell
        # Union-find: copy the parent/rank arrays.
        new._uf.parent = list(self._uf.parent)
        new._uf.rank = list(self._uf.rank)
        # edge_index is immutable / cacheable; share it.
        new._edge_index = self._edge_index
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

    def legal_subactions(self) -> np.ndarray:
        if self._terminal:
            return np.empty(0, dtype=np.int32)
        cells = np.flatnonzero(self._board == 0).astype(np.int32)
        if self._can_swap_now():
            return np.concatenate([cells, np.array([self.SWAP_ACTION_ID], dtype=np.int32)])
        return cells

    def _can_swap_now(self) -> bool:
        return (
            self.swap_rule
            and not self._swap_used
            and self._ply == 1
            and self._to_move == 1
            and self._first_move_cell is not None
        )

    def apply_subaction(self, sub: int) -> None:
        if self._terminal:
            raise ValueError("game is terminal")
        # SWAP path -------------------------------------------------------------
        if sub == self.SWAP_ACTION_ID and self.swap_rule:
            if not self._can_swap_now():
                raise ValueError("SWAP is only legal as P1's response to P0's first move")
            assert self._first_move_cell is not None
            r, c = divmod(self._first_move_cell, self.n)
            mirrored = c * self.n + r  # transpose across the main diagonal
            # Wipe board and union-find; place a single P1 stone at the mirror.
            self._board[:] = 0
            self._uf = _UnionFind(self.num_cells + 4)
            self._board[mirrored] = 2  # belongs to P1 (Blue)
            self._merge_with_neighbors(mirrored, 1)
            # P1 already "played" by swapping; back to P0.
            self._to_move = 0
            self._swap_used = True
            self._ply += 1
            return
        # Regular cell placement ------------------------------------------------
        if not (0 <= sub < self.num_cells):
            raise ValueError(f"out-of-range sub-action {sub}")
        if self._board[sub] != 0:
            raise ValueError(f"cell {sub} is already occupied")
        player = self._to_move
        self._board[sub] = player + 1
        self._merge_with_neighbors(sub, player)
        if self._check_winner(player):
            self._winner = player
            self._terminal = True
        else:
            self._to_move ^= 1
        if self._ply == 0:
            self._first_move_cell = sub
        self._ply += 1

    # -- observation ---------------------------------------------------------------
    def observation(self) -> Observation:
        n = self.n
        me = self._to_move + 1
        opp = (self._to_move ^ 1) + 1
        feats = np.zeros((self.num_cells, self.PER_NODE_FEATURES), dtype=np.float32)
        feats[:, 0] = (self._board == me).astype(np.float32)
        feats[:, 1] = (self._board == opp).astype(np.float32)
        feats[:, 2] = (self._board == 0).astype(np.float32)
        # Edge proximity from CURRENT player's POV.
        if self._to_move == 0:
            for c in range(n):
                feats[0 * n + c, 3] = 1.0           # top edge
                feats[(n - 1) * n + c, 4] = 1.0     # bottom edge
        else:
            for r in range(n):
                feats[r * n + 0, 3] = 1.0           # left edge
                feats[r * n + (n - 1), 4] = 1.0     # right edge

        global_feats = np.array(
            [
                float(self._to_move),
                self._ply / max(self.num_cells, 1),
                1.0 if self._swap_used else 0.0,
            ],
            dtype=np.float32,
        )
        legal = self.legal_subactions()
        # Stash node features + edge_index + globals on the Observation.
        # `graph` is a dict (not a HeteroData yet) to avoid a torch_geometric dep.
        return Observation(
            global_features=global_feats,
            graph={
                "node_features": feats,             # [N, F]
                "edge_index": self._edge_index,     # [2, E]
                "num_cells": self.num_cells,
            },
            legal_subactions=legal,
        )

    # -- internal helpers ----------------------------------------------------------
    def _merge_with_neighbors(self, cell: int, player: int) -> None:
        """Union ``cell`` with same-color neighbors and the two virtual edges."""
        n = self.n
        r, c = divmod(cell, n)
        v = player + 1
        for dr, dc in HEX_NEIGHBOR_OFFSETS:
            rr, cc = r + dr, c + dc
            if 0 <= rr < n and 0 <= cc < n:
                nb = rr * n + cc
                if self._board[nb] == v:
                    self._uf.union(cell, nb)
        # Virtual nodes:
        if player == 0:
            top, bot = self.num_cells, self.num_cells + 1
            if r == 0:
                self._uf.union(cell, top)
            if r == n - 1:
                self._uf.union(cell, bot)
        else:
            left, right = self.num_cells + 2, self.num_cells + 3
            if c == 0:
                self._uf.union(cell, left)
            if c == n - 1:
                self._uf.union(cell, right)

    def _check_winner(self, player: int) -> bool:
        if player == 0:
            top, bot = self.num_cells, self.num_cells + 1
            return self._uf.find(top) == self._uf.find(bot)
        left, right = self.num_cells + 2, self.num_cells + 3
        return self._uf.find(left) == self._uf.find(right)

    # -- debug ---------------------------------------------------------------------
    def render(self) -> str:
        chars = {0: ".", 1: "R", 2: "B"}
        rows = []
        for r in range(self.n):
            row = " ".join(chars[int(self._board[r * self.n + c])] for c in range(self.n))
            rows.append(" " * r + row)
        return "\n".join(rows)
