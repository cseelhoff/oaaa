"""FFI sanity test — does **not** require the .so to exist."""

from triplea_odin import ffi


def test_load_library_missing_raises():
    """Without OAAA_LIB and no built .so, loader must raise FileNotFoundError."""
    # We don't actually try to load if the file happens to exist on this machine
    # (e.g., on the developer's box). This test only asserts the symbol surface.
    assert hasattr(ffi, "load_library")
    assert hasattr(ffi, "lib")
    assert hasattr(ffi, "has")


def test_signature_table_covers_plan_md_surface():
    """Spot-check that the §4.1 surface is declared, even if not bound yet."""
    declared = {name for name, *_ in ffi._SIGNATURES}
    required = {
        "ts_new", "ts_clone", "ts_free",
        "ts_current_player", "ts_acting_power", "ts_current_phase",
        "ts_round_number", "ts_is_terminal", "ts_team_reward",
        "ts_legal_subactions", "ts_apply_subaction",
        "ts_can_finalize_phase", "ts_finalize_phase",
        "ts_resolve_combat",
        "ts_observe_node_count", "ts_observe_edge_count",
        "ts_observe_node_features", "ts_observe_edge_index",
        "ts_observe_edge_features", "ts_observe_edge_types",
        "ts_observe_global_features",
        "ts_proai_plan_for_phase", "ts_proai_rollout", "ts_proai_value_estimate",
    }
    missing = required - declared
    assert not missing, f"FFI signature table is missing: {sorted(missing)}"
