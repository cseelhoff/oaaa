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
	air_bitset: Air_Bitset = to_air_bitset(land_bitset)
	get_airs(air_bitset, &air_positions)
	assert(air_positions[0] == .Alaska_Air)
	assert(air_positions[1] == .Hawaiian_Islands_Air)
}

get_airs_from_sea_bitset_test :: proc() {
	using oaaa
	sea_bitset: Sea_Bitset = {
        .Sea_1,
        .Sea_65
    }
	air_bitset: Air_Bitset = to_air_bitset(sea_bitset)
	get_airs(air_bitset, &air_positions)
	assert(air_positions[0] == .Sea_1_Air)
	assert(air_positions[1] == .Sea_65_Air)
}

add_air_test :: proc() {
    using oaaa
    air_bitset: Air_Bitset = {}
    add_air(&air_bitset, .Alaska_Air)
    add_air(&air_bitset, .Hawaiian_Islands_Air)
    add_air(&air_bitset, .Sea_1_Air)
    add_air(&air_bitset, .Sea_64_Air)
	get_airs(air_bitset, &air_positions)
    assert(air_positions[0] == .Alaska_Air)
    assert(air_positions[1] == .Hawaiian_Islands_Air)
    assert(air_positions[2] == .Sea_1_Air)
    assert(air_positions[3] == .Sea_64_Air)
}