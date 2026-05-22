#+feature using-stmt
package oaaa_test

import oaaa "../src"

main :: proc() {
	get_airs_from_land_bitset_test()
	get_airs_from_sea_bitset_test()
    add_air_test()
}

get_airs_from_land_bitset_test :: proc() {
	using oaaa
	land_bitset: Land_Bitset = {.Alaska, .Hawaiian_Islands}
	region_bitset: Region_Bitset = to_region_bitset(land_bitset)
	get_regions(region_bitset, &region_positions)
	assert(region_positions[0] == .Alaska_Air)
	assert(region_positions[1] == .Hawaiian_Islands_Air)
}

get_airs_from_sea_bitset_test :: proc() {
	using oaaa
	sea_bitset: Sea_Bitset = {
        .Sea_1,
        .Sea_65
    }
	region_bitset: Region_Bitset = to_region_bitset(sea_bitset)
	get_regions(region_bitset, &region_positions)
	assert(region_positions[0] == .Sea_1_Air)
	assert(region_positions[1] == .Sea_65_Air)
}

add_air_test :: proc() {
    using oaaa
    region_bitset: Region_Bitset = {}
    add_region(&region_bitset, .Alaska_Air)
    add_region(&region_bitset, .Hawaiian_Islands_Air)
    add_region(&region_bitset, .Sea_1_Air)
    add_region(&region_bitset, .Sea_64_Air)
	get_regions(region_bitset, &region_positions)
    assert(region_positions[0] == .Alaska_Air)
    assert(region_positions[1] == .Hawaiian_Islands_Air)
    assert(region_positions[2] == .Sea_1_Air)
    assert(region_positions[3] == .Sea_64_Air)
}