package oaaa

import "base:intrinsics"

region_positions: [dynamic]Region_ID

Region_Bitset :: distinct [4]u64
get_regions :: proc(region_bitset: Region_Bitset, positions: ^[dynamic]Region_ID) {
	clear(&region_positions)
	for i in 0 ..< len(region_bitset) {
		j:=len(region_bitset) - i - 1
		chunk := region_bitset[j]
		if chunk == 0 do continue
		// Process each set bit in chunk
		// Calculate bit position: (chunk index * 64) + LSB position
		for chunk != 0 {
			trailing_zeros := intrinsics.count_trailing_zeros(int(chunk))
			append(positions, Region_ID(i * 64 + trailing_zeros))
			chunk &= chunk - 1 // Clear least significant set bit
		}
	}
}

add_region :: #force_inline proc(region_bitset: ^Region_Bitset, region: Region_ID) {
	arr_pos := len(Region_Bitset) - (uint(region) / 64) - 1
	remainder := uint(region) % 64
	region_bitset[arr_pos] |= 1 << remainder
}

to_region_bitset :: proc {
	land_bitset_to_region_bitset,
	sea_bitset_to_region_bitset,
}

land_bitset_to_region_bitset :: proc(land_bitset: Land_Bitset) -> (result: Region_Bitset) {
	value := transmute(u128)land_bitset
	result[3] = u64(value)
	result[2] = u64(value >> 64)
	return result
}

sea_bitset_to_region_bitset :: proc(sea_bitset: Sea_Bitset) -> (result: Region_Bitset) {
	value := transmute(u128)sea_bitset
	// result[3] = u64(value)
	// upper := value << (80 - 64)
	// lower := value >> (128 - 80)
	result[2] = u64(value << (len(Land_ID) - 64))
	result[1] = u64(value >> (128 - len(Land_ID)))
	return result
}

// does_air_has_enemies :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> bool {
// 	chunk :=  gc.region_has_enemies[len(Region_Bitset) - 1 - (uint(dst_action) / 64)]
// 	bool_index_in_chunk := uint(dst_action) % 64
// 	if (chunk & (1 << bool_index_in_chunk)) != 0 do return true
// 	return false
// }
