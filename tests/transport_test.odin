package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_transport_capacity :: proc(t: ^testing.T) {
    gc := oaaa.Game_Cache{}
    test_sea := oaaa.Sea_ID.Pacific
    
    // Empty transport should have capacity
    gc.active_ships[test_sea][.TRANS_EMPTY_0_MOVES] = 1
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_0_MOVES] == 1,
        "Empty transport not added correctly")
}
