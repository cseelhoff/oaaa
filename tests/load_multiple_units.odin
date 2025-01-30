package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_transport_loading_multiple_units :: proc(t: ^testing.T) {
    gc := oaaa.Game_Cache{}
    test_sea := oaaa.Sea_ID.Pacific

    // Load infantry and artillery
    gc.active_ships[test_sea][.TRANS_1I_0_MOVES] = 1
    loaded_ship := oaaa.Trans_After_Loading[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1I_0_MOVES]
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_0_MOVES, loaded_ship)

    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1I_1A_0_MOVES,
        "Infantry + Artillery loading failed")
}