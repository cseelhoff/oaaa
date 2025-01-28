package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_army_costs :: proc(t: ^testing.T) {
    testing.expect(t, oaaa.COST_IDLE_ARMY[oaaa.Idle_Army.INF] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_INF], "Infantry cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_ARMY[oaaa.Idle_Army.ARTY] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_ARTY], "Artillery cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_ARMY[oaaa.Idle_Army.TANK] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_TANK], "Tank cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_ARMY[oaaa.Idle_Army.AAGUN] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_AAGUN], "AA Gun cost mismatch")
}

@(test)
test_active_to_idle_army_conversion :: proc(t: ^testing.T) {
    testing.expect(t, oaaa.Active_Army_To_Idle[oaaa.Active_Army.INF_UNMOVED] == oaaa.Idle_Army.INF, "Infantry unmoved conversion failed")
    testing.expect(t, oaaa.Active_Army_To_Idle[oaaa.Active_Army.INF_0_MOVES] == oaaa.Idle_Army.INF, "Infantry 0 moves conversion failed")
    testing.expect(t, oaaa.Active_Army_To_Idle[oaaa.Active_Army.ARTY_UNMOVED] == oaaa.Idle_Army.ARTY, "Artillery unmoved conversion failed")
    testing.expect(t, oaaa.Active_Army_To_Idle[oaaa.Active_Army.ARTY_0_MOVES] == oaaa.Idle_Army.ARTY, "Artillery 0 moves conversion failed")
}

@(test)
test_army_stats :: proc(t: ^testing.T) {
    testing.expect(t, oaaa.INFANTRY_ATTACK == 1, "Infantry attack value incorrect")
    testing.expect(t, oaaa.INFANTRY_DEFENSE == 2, "Infantry defense value incorrect")
    testing.expect(t, oaaa.ARTILLERY_ATTACK == 2, "Artillery attack value incorrect")
    testing.expect(t, oaaa.ARTILLERY_DEFENSE == 2, "Artillery defense value incorrect")
    testing.expect(t, oaaa.TANK_ATTACK == 3, "Tank attack value incorrect")
    testing.expect(t, oaaa.TANK_DEFENSE == 3, "Tank defense value incorrect")
}
