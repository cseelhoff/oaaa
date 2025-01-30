package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_skip_army_movement :: proc(t: ^testing.T) {
    gc := oaaa.Game_Cache{}
    test_land := oaaa.Land_ID.Washington

    // Army with 0 moves should skip
    gc.active_armies[test_land][.INF_0_MOVES] = 2
    oaaa.skip_army(&gc, test_land, test_land, .INF_0_MOVES)
    testing.expect(t, gc.active_armies[test_land][.INF_0_MOVES] == 2,
        "Army with 0 moves should not move")
}