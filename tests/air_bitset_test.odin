#+feature using-stmt
package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
air_bitset_test :: proc(t: ^testing.T) {
    using oaaa
    land_bitset: Land_Bitset = {.Alaska}
    region_bitset: Region_Bitset = to_region_bitset(land_bitset)
    get_regions(region_bitset, &region_positions)
    testing.expect(t, region_positions[0] == .Alaska_Air, "land bitset element should round-trip through Region_Bitset")
}
