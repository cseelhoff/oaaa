package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
air_bitset_test :: proc(t: ^testing.T) {
    land_bitset : Land_Bitset = {
        .Alaska = true,
    }
    air_bitset : Air_Bitset = to_air_bitset(land_bitset)
    get_airs(air_bitset, &air_positions)
    testing.expect(t, air_positions[0] == .Alaska, "Enemy land should disallow bomber landing")
}
