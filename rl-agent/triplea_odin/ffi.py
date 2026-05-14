"""ctypes bindings for the Odin engine shared library.

Mirrors the C-ABI surface in plan.md §4.1. The Odin engine has not yet
exposed these symbols (build mode ``-build-mode:shared`` produces
``build/liboaaa.so`` per ``.vscode/tasks.json`` but the entry points below
are not yet implemented). Loading is therefore lazy: nothing in this file
imports the library at module-load time, so test collection still works.

When the Odin side lands, set ``OAAA_LIB`` to override the search path.
"""

from __future__ import annotations

import ctypes as C
import os
from pathlib import Path
from typing import Any

# ---- types --------------------------------------------------------------------
GameStatePtr = C.c_void_p
c_int = C.c_int
c_double = C.c_double
c_uint64 = C.c_uint64
c_size_t = C.c_size_t


# ---- library loader -----------------------------------------------------------
_LIB: C.CDLL | None = None
_DEFAULT_PATHS = [
    Path(__file__).resolve().parent.parent.parent / "build" / "liboaaa.so",
    Path("/usr/local/lib/liboaaa.so"),
]


def _candidate_paths() -> list[Path]:
    paths: list[Path] = []
    if env := os.environ.get("OAAA_LIB"):
        paths.append(Path(env))
    paths.extend(_DEFAULT_PATHS)
    return paths


def load_library() -> C.CDLL:
    """Locate and load ``liboaaa.so``. Idempotent. Raises FileNotFoundError if missing."""

    global _LIB
    if _LIB is not None:
        return _LIB
    for p in _candidate_paths():
        if p.exists():
            _LIB = C.CDLL(str(p))
            _bind(_LIB)
            return _LIB
    raise FileNotFoundError(
        "liboaaa.so not found. Build with: odin build src -out:build/liboaaa.so "
        "-debug -build-mode:shared (see .vscode/tasks.json)."
    )


# ---- signature table ----------------------------------------------------------
# Each entry: (name, [argtypes], restype). When the Odin side adds a symbol,
# uncomment / add it here. Anything not present in the .so will raise at bind time
# unless we mark it optional.
_SIGNATURES: list[tuple[str, list[Any], Any, bool]] = [
    # name, argtypes, restype, optional
    ("ts_new", [c_int, C.c_char_p, C.c_char_p], GameStatePtr, True),
    ("ts_clone", [GameStatePtr], GameStatePtr, True),
    ("ts_free", [GameStatePtr], None, True),
    ("ts_serialize", [GameStatePtr, C.POINTER(C.c_uint8), c_int], c_int, True),
    ("ts_deserialize", [C.POINTER(C.c_uint8), c_int], GameStatePtr, True),
    ("ts_current_player", [GameStatePtr], c_int, True),
    ("ts_acting_power", [GameStatePtr], c_int, True),
    ("ts_current_phase", [GameStatePtr], c_int, True),
    ("ts_round_number", [GameStatePtr], c_int, True),
    ("ts_is_terminal", [GameStatePtr], c_int, True),
    ("ts_team_reward", [GameStatePtr, c_int], c_double, True),
    ("ts_legal_subactions", [GameStatePtr, C.POINTER(C.c_int32), c_int], c_int, True),
    ("ts_apply_subaction", [GameStatePtr, C.c_int32], c_int, True),
    ("ts_can_finalize_phase", [GameStatePtr], c_int, True),
    ("ts_finalize_phase", [GameStatePtr], c_int, True),
    ("ts_resolve_combat", [GameStatePtr, c_uint64], c_int, True),
    ("ts_combat_outcome_distribution", [GameStatePtr, C.POINTER(c_double), c_int], c_int, True),
    ("ts_observe_node_count", [GameStatePtr], c_int, True),
    ("ts_observe_edge_count", [GameStatePtr], c_int, True),
    (
        "ts_observe_node_features",
        [GameStatePtr, C.POINTER(C.c_float), c_int, c_int],
        None,
        True,
    ),
    (
        "ts_observe_edge_index",
        [GameStatePtr, C.POINTER(C.c_int32), c_int, c_int],
        None,
        True,
    ),
    (
        "ts_observe_edge_features",
        [GameStatePtr, C.POINTER(C.c_float), c_int, c_int],
        None,
        True,
    ),
    ("ts_observe_edge_types", [GameStatePtr, C.POINTER(C.c_int32), c_int], None, True),
    ("ts_observe_global_features", [GameStatePtr, C.POINTER(C.c_float), c_int], None, True),
    (
        "ts_proai_plan_for_phase",
        [GameStatePtr, C.POINTER(C.c_int32), c_int],
        c_int,
        True,
    ),
    ("ts_proai_rollout", [GameStatePtr, c_int, c_uint64], c_double, True),
    ("ts_proai_value_estimate", [GameStatePtr], c_double, True),
]


def _bind(lib: C.CDLL) -> None:
    for name, argtypes, restype, optional in _SIGNATURES:
        sym = getattr(lib, name, None)
        if sym is None:
            if optional:
                continue
            raise AttributeError(f"liboaaa.so is missing required symbol: {name}")
        sym.argtypes = argtypes
        sym.restype = restype


def lib() -> C.CDLL:
    """Return the loaded library. Convenience wrapper around :func:`load_library`."""
    return load_library()


def has(name: str) -> bool:
    """Whether the loaded library exports ``name`` with bound signatures."""

    try:
        L = load_library()
    except FileNotFoundError:
        return False
    sym = getattr(L, name, None)
    return sym is not None and sym.argtypes is not None
