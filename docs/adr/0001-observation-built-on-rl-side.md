# Observation is built on the RL side, not the engine side

The Odin engine exposes raw `Game_State` across the FFI; the Python RL stack constructs Observations (per-Nation feature rotation into Canonical Form, PyG `HeteroData` graphs, masking) on its own side. The original `perspective.odin` is removed.

We picked this over keeping a compiled Perspective layer because feature extraction on a ~6 000-float Observation is microseconds in numpy and not the bottleneck — the bottleneck is FFI marshaling overhead, which the same regardless. Keeping Perspective in Odin doubled the representation (every new feature meant edits in `Game_State`, `Perspective`, the FFI, and the Python wrapper, plus a rebuild) and leaked RL-side vocabulary (canonical form, feature planes) into a simulator that is otherwise a faithful port of the Java engine.

The decision flips if a non-Python RL client appears that would otherwise re-implement rotation logic. In that case, the right move is a small standalone Odin library shared by clients — not re-attaching Perspective to the engine.
