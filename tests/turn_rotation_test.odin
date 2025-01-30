package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_rotate_turns :: proc(t: ^testing.T) {
    // Start with USA as current player
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA

    // Rotate turns
    oaaa.rotate_turns(&gc)

    // Next player should be GER
    testing.expect(t, gc.cur_player == .Ger, "Turn not rotated correctly")
}