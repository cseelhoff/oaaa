package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_conquer_and_reset_units :: proc(t: ^testing.T) {
    // Setup a scenario where Germany conquers London
    gc := oaaa.Game_Cache{}
    gc.cur_player = .Ger
    test_land := oaaa.Land_ID.London
    
    // Germany has tanks in London
    gc.active_armies[test_land][.TANK_0_MOVES] = 2
    gc.idle_armies[test_land][.Ger][.TANK] = 2
    gc.team_land_units[test_land][.Axis] = 2
    
    // Original owner is England
    gc.owner[test_land] = .Eng
    
    // Transfer ownership and reset units
    oaaa.transfer_land_ownership(&gc, test_land)
    
    // Verify ownership change
    testing.expect(t, gc.owner[test_land] == .Ger, "Germany did not conquer London")
    
    // Verify enemy units are cleared
    testing.expect(t, gc.idle_armies[test_land][.Eng][.INF] == 0, "Enemy infantry not cleared")
    testing.expect(t, gc.idle_armies[test_land][.Eng][.ARTY] == 0, "Enemy artillery not cleared")
}