"""Python wrapper around the Odin Axis & Allies engine.

Public surface:

- :mod:`triplea_odin.env_base` — the abstract :class:`Env` contract used everywhere.
- :class:`triplea_odin.env.AAEnv` — concrete A&A env (FFI-backed, currently stubbed).
- :mod:`triplea_odin.ffi` — raw ctypes bindings.
"""

from .env_base import Env, Observation, Phase

__all__ = ["Env", "Observation", "Phase"]
