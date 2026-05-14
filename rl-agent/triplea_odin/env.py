"""Concrete Odin-engine-backed env. **Stubbed** — the FFI surface is not
implemented yet on the Odin side (see plan.md §4 and §8 step 3).

Every method that needs the engine raises :class:`NotImplementedError` with a
pointer to the missing FFI symbol so the failure mode is obvious. The
class structure is the final shape; only the bodies are stubs.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from . import ffi
from .env_base import Env, Observation, Phase


def _need(symbol: str) -> NotImplementedError:
    return NotImplementedError(
        f"Odin engine FFI symbol '{symbol}' is not implemented yet "
        f"(see plan.md §4.1)."
    )


class AAEnv(Env):
    """Axis & Allies environment backed by the Odin engine via ctypes.

    Construction does **not** load the .so so that pytest collection works on a
    machine where the engine has not been built yet. The FFI is loaded on the
    first call that actually needs it.
    """

    def __init__(self, map_name: str = "1942.2", ruleset: str = "standard") -> None:
        self._map_name = map_name
        self._ruleset = ruleset
        self._handle: Any = None  # ctypes c_void_p once allocated

    # -- lifecycle -----------------------------------------------------------------
    def reset(self, seed: int = 0) -> Observation:
        L = ffi.load_library()
        if not ffi.has("ts_new"):
            raise _need("ts_new")
        self._handle = L.ts_new(seed, self._map_name.encode(), self._ruleset.encode())
        return self.observation()

    def clone(self) -> "AAEnv":
        if not ffi.has("ts_clone"):
            raise _need("ts_clone")
        new = AAEnv(self._map_name, self._ruleset)
        new._handle = ffi.lib().ts_clone(self._handle)
        return new

    def __del__(self) -> None:
        # Best-effort free; avoid raising during interpreter shutdown.
        try:
            if self._handle is not None and ffi.has("ts_free"):
                ffi.lib().ts_free(self._handle)
                self._handle = None
        except Exception:
            pass

    # -- queries -------------------------------------------------------------------
    def current_player(self) -> int:
        if not ffi.has("ts_current_player"):
            raise _need("ts_current_player")
        return int(ffi.lib().ts_current_player(self._handle))

    def acting_power(self) -> int:
        if not ffi.has("ts_acting_power"):
            raise _need("ts_acting_power")
        return int(ffi.lib().ts_acting_power(self._handle))

    def current_phase(self) -> Phase:
        if not ffi.has("ts_current_phase"):
            raise _need("ts_current_phase")
        return Phase(int(ffi.lib().ts_current_phase(self._handle)))

    def round_number(self) -> int:
        if not ffi.has("ts_round_number"):
            raise _need("ts_round_number")
        return int(ffi.lib().ts_round_number(self._handle))

    def is_terminal(self) -> bool:
        if not ffi.has("ts_is_terminal"):
            raise _need("ts_is_terminal")
        return bool(ffi.lib().ts_is_terminal(self._handle))

    def team_reward(self, team: int) -> float:
        if not ffi.has("ts_team_reward"):
            raise _need("ts_team_reward")
        return float(ffi.lib().ts_team_reward(self._handle, team))

    # -- sub-actions ---------------------------------------------------------------
    def legal_subactions(self) -> np.ndarray:
        raise _need("ts_legal_subactions")

    def apply_subaction(self, sub: int) -> None:
        raise _need("ts_apply_subaction")

    def can_finalize_phase(self) -> bool:
        if not ffi.has("ts_can_finalize_phase"):
            raise _need("ts_can_finalize_phase")
        return bool(ffi.lib().ts_can_finalize_phase(self._handle))

    def finalize_phase(self) -> None:
        if not ffi.has("ts_finalize_phase"):
            raise _need("ts_finalize_phase")
        ffi.lib().ts_finalize_phase(self._handle)

    def is_chance(self) -> bool:
        return self.current_phase() == Phase.COMBAT

    def resolve_combat(self, seed: int) -> None:
        if not ffi.has("ts_resolve_combat"):
            raise _need("ts_resolve_combat")
        ffi.lib().ts_resolve_combat(self._handle, seed)

    # -- observation ---------------------------------------------------------------
    def observation(self) -> Observation:
        raise _need("ts_observe_*")

    # -- ProAI ---------------------------------------------------------------------
    def proai_plan(self) -> list[int] | None:
        if not ffi.has("ts_proai_plan_for_phase"):
            return None
        raise _need("ts_proai_plan_for_phase")  # body when wired

    def proai_rollout(self, max_turns: int, seed: int) -> float | None:
        if not ffi.has("ts_proai_rollout"):
            return None
        return float(ffi.lib().ts_proai_rollout(self._handle, max_turns, seed))

    def proai_value(self) -> float | None:
        if not ffi.has("ts_proai_value_estimate"):
            return None
        return float(ffi.lib().ts_proai_value_estimate(self._handle))
