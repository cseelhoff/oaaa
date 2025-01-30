package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_enemy_conquest_with_sea_units :: proc(t: ^testing.T) {
    // Setup a scenario where Germany conquers London via sea
    gc := oaaa.Game_Cache{}
    test_land := oaaa.Land_ID.London
    test_sea := oaaa.Sea_ID.Atlantic

    // Germany has transports and infantry in the sea
    gc.active_ships[test_sea][.TRANS_1I_0_MOVES] = 1
    gc.idle_ships[test_sea][.Ger][.TRANS_1I] = 1
    
    // Execute unload and conquest
    oaaa.unload_transports(&gc)
    oaaa.check_and_conquer_land(&gc, test_land)
    
    // Verify ownership change
    testing.expect(t, gc.owner[test_land] == .Ger, 
        "Germany should conquer London via unload")
}