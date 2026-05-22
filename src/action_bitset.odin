package oaaa

import "base:intrinsics"
import "core:math"

Valid_Actions :: struct {
	destinations_and_unit_count: Region_Bitset[4] // precomputed bitsets for each fraction action, indexed by how many units are at the source
	finalized: bool,
}

// For a 1024-bit integer represented as 16 x i64 chunks
Action_Bitset :: distinct [16]u64
load_dyn_arr_actions :: proc(gc: ^Game_Cache) {
	clear(&gc.dyn_arr_valid_actions)
	starting_index := int(gc.smallest_allowable_action[gc.current_territory]) / 64
	for i in starting_index ..< len(gc.valid_actions) {
		chunk := gc.valid_actions[i]
		if chunk == 0 do continue
		// Process each set bit in chunk
		// Calculate bit position: (chunk index * 64) + LSB position
		for chunk != 0 {
			action := Action_ID(i * 64 + intrinsics.count_trailing_zeros(int(chunk)))
			if action >= gc.smallest_allowable_action[gc.current_territory] {
				append(&gc.dyn_arr_valid_actions, action)
			}
			chunk &= chunk - 1 // Clear least significant set bit
		}
	}
	// return positions
}

reset_valid_actions :: proc(gc: ^Game_Cache) {
	action := Action_ID.Skip_Action
	arr_pos := uint(action) / 64
	remainder := uint(action) % 64
	gc.valid_actions = {}
	gc.valid_actions[arr_pos] = 1 << remainder
}

add_valid_action :: #force_inline proc(gc: ^Game_Cache, action: Action_ID) {
	arr_pos := uint(action) / 64
	remainder := uint(action) % 64
	gc.valid_actions[arr_pos] |= 1 << remainder
}

remove_valid_action :: proc(gc: ^Game_Cache, action: Action_ID) {
	arr_pos := uint(action) / 64
	remainder := uint(action) % 64
	gc.valid_actions[arr_pos] &= ~(1 << remainder)
}

set_valid_actions :: proc(gc: ^Game_Cache, region_bitset: Region_Bitset, qty: u8) {
	gc.valid_actions = {}
	get_regions(region_bitset, &region_positions)
	for region in region_positions {
		add_region_to_valid_actions(gc, region, qty)
	}
	//todo: use a bit shift instead for better performance
}

add_valid_actions_multi :: proc(gc: ^Game_Cache, region_bitset: Region_Bitset, unit_count: u8) {
	for region in region_bitset {
		add_valid_action(gc, Action_ID(region))
	}
	//todo: use a bit shift instead for better performance
}

remove_actions_above :: proc(gc: ^Game_Cache, action: Action_ID) {
	arr_pos := uint(action) / 64
	remainder := uint(action) % 64
	gc.valid_actions[arr_pos] &= ~(1 << remainder)
	for i in arr_pos ..< len(gc.valid_actions) {
		gc.valid_actions[i] = 0
	}
}

add_lands_to_valid_actions :: proc(gc: ^Game_Cache, dst_lands: Land_Bitset, unit_count: u8) {
	//todo optimize with SIMD
	for land in dst_lands {
		if unit_count >= 17 {
			add_valid_action(gc, Action_ID(uint(land)))
		}
		if unit_count >= 9 {
			add_valid_action(gc, Action_ID(uint(land) + len(Region_ID)))
		}
		if unit_count >= 5 {
			add_valid_action(gc, Action_ID(uint(land) + len(Region_ID) * 2))
		}
		if unit_count >= 3 {
			add_valid_action(gc, Action_ID(uint(land) + len(Region_ID) * 3))
		}
		if unit_count >= 2 {
			add_valid_action(gc, Action_ID(uint(land) + len(Region_ID) * 4))
		}
		add_valid_action(gc, Action_ID(uint(land) + len(Region_ID) * 5))
	}
}
add_land_to_valid_actions :: proc(gc: ^Game_Cache, dst_land: Land_ID, unit_count: u8) {
	//todo optimize with SIMD
	if unit_count >= 17 {
		add_valid_action(gc, Action_ID(uint(dst_land)))
	}
	if unit_count >= 9 {
		add_valid_action(gc, Action_ID(uint(dst_land) + len(Region_ID)))
	}
	if unit_count >= 5 {
		add_valid_action(gc, Action_ID(uint(dst_land) + len(Region_ID) * 2))
	}
	if unit_count >= 3 {
		add_valid_action(gc, Action_ID(uint(dst_land) + len(Region_ID) * 3))
	}
	if unit_count >= 2 {
		add_valid_action(gc, Action_ID(uint(dst_land) + len(Region_ID) * 4))
	}
	add_valid_action(gc, Action_ID(uint(dst_land) + len(Region_ID) * 5))
}

add_airs_to_valid_actions :: proc(gc: ^Game_Cache, dst_airs: Region_Bitset, unit_count: u8) {
	get_regions(dst_airs, &region_positions)
	for region in region_positions {
		if unit_count >= 17 {
			add_valid_action(gc, Action_ID(uint(region)))
		}
		if unit_count >= 9 {
			add_valid_action(gc, Action_ID(uint(region) + len(Region_ID)))
		}
		if unit_count >= 5 {
			add_valid_action(gc, Action_ID(uint(region) + len(Region_ID) * 2))
		}
		if unit_count >= 3 {
			add_valid_action(gc, Action_ID(uint(region) + len(Region_ID) * 3))
		}
		if unit_count >= 2 {
			add_valid_action(gc, Action_ID(uint(region) + len(Region_ID) * 4))
		}
		add_valid_action(gc, Action_ID(uint(region) + len(Region_ID) * 5))
	}
}

// Returns the available fraction-action slots for a set of destination
// air regions, given how many units are at the source.
// Layout: [0]=All, [1]=Half, [2]=Quarter, [3]=Only_One.
// Branchless: each slot i is `dst_airs` AND a mask that is all-ones when
// unit_count > i, else all-zeros. Region_Bitset is `distinct [4]u64`, so
// the AND folds into 4 scalar ops per slot (likely auto-vectorized).
airs_action_tiers :: #force_inline proc(dst_airs: Region_Bitset, unit_count: u8) -> [4]Region_Bitset {
	a := transmute([4]u64)dst_airs
	ones := ~u64(0)
	m0 := ones * u64(unit_count > 0)
	m1 := ones * u64(unit_count > 1)
	m2 := ones * u64(unit_count > 2)
	m3 := ones * u64(unit_count > 3)
	return {
		transmute(Region_Bitset)[4]u64{a[0] & m0, a[1] & m0, a[2] & m0, a[3] & m0},
		transmute(Region_Bitset)[4]u64{a[0] & m1, a[1] & m1, a[2] & m1, a[3] & m1},
		transmute(Region_Bitset)[4]u64{a[0] & m2, a[1] & m2, a[2] & m2, a[3] & m2},
		transmute(Region_Bitset)[4]u64{a[0] & m3, a[1] & m3, a[2] & m3, a[3] & m3},
	}
}

add_region_to_valid_actions :: proc(gc: ^Game_Cache, dst_region: Region_ID, unit_count: u8) {
	if unit_count >= 17 {
		add_valid_action(gc, Action_ID(uint(dst_region)))
	}
	if unit_count >= 9 {
		add_valid_action(gc, Action_ID(uint(dst_region) + len(Region_ID)))
	}
	if unit_count >= 5 {
		add_valid_action(gc, Action_ID(uint(dst_region) + len(Region_ID) * 2))
	}
	if unit_count >= 3 {
		add_valid_action(gc, Action_ID(uint(dst_region) + len(Region_ID) * 3))
	}
	if unit_count >= 2 {
		add_valid_action(gc, Action_ID(uint(dst_region) + len(Region_ID) * 4))
	}
	add_valid_action(gc, Action_ID(uint(dst_region) + len(Region_ID) * 5))
}

add_seas_to_valid_actions :: proc(gc: ^Game_Cache, dst_seas: Sea_Bitset, unit_count: u8) {
	//todo optimize with SIMD
	for sea in dst_seas {
		if unit_count >= 17 {
			add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID)))
		}
		if unit_count >= 9 {
			add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID) + len(Region_ID)))
		}
		if unit_count >= 5 {
			add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID) + len(Region_ID) * 2))
		}
		if unit_count >= 3 {
			add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID) + len(Region_ID) * 3))
		}
		if unit_count >= 2 {
			add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID) + len(Region_ID) * 4))
		}
		add_valid_action(gc, Action_ID(uint(sea) + len(Land_ID) + len(Region_ID) * 5))
	}
}

add_sea_to_valid_actions :: proc(gc: ^Game_Cache, dst_sea: Sea_ID, unit_count: u8) {
	//todo optimize with SIMD
	if unit_count >= 17 {
		add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID)))
	}
	if unit_count >= 9 {
		add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID) + len(Region_ID)))
	}
	if unit_count >= 5 {
		add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID) + len(Region_ID) * 2))
	}
	if unit_count >= 3 {
		add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID) + len(Region_ID) * 3))
	}
	if unit_count >= 2 {
		add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID) + len(Region_ID) * 4))
	}
	add_valid_action(gc, Action_ID(uint(dst_sea) + len(Land_ID) + len(Region_ID) * 5))
}

remove_skipped_actions :: proc(gc: ^Game_Cache, src_region: Region_ID) {
	//todo optimize with SIMD
	a := u16(gc.smallest_allowable_action[src_region])
	b := a / 64
	remainder := uint(a % 64)
	for i in b ..< len(gc.valid_actions) {
		gc.valid_actions[i] = 0
	}
	gc.valid_actions[b] |= 1 << remainder
}

is_valid_actions_empty :: proc(gc: ^Game_Cache) -> (empty: bool) {
	//todo optimize with SIMD
	for i in 0 ..< len(gc.valid_actions) {
		if gc.valid_actions[i] != 0 do return false
	}
	return true
}

is_valid_actions_greater_than_one :: proc(gc: ^Game_Cache) -> (empty: bool) {
	//todo optimize with SIMD
	total_count := u8(0)
	for i in 0 ..< len(gc.valid_actions) {
		chunk := gc.valid_actions[i]
		if chunk == 0 do continue
		// Process each set bit in chunk
		// Calculate bit position: (chunk index * 64) + LSB position
		for chunk != 0 {
			//append(&positions, Action_ID(i * 64 + intrinsics.count_trailing_zeros(int(chunk))))
			if total_count > 1 do return false
			total_count += 1
			chunk &= chunk - 1 // Clear least significant set bit
		}
	}
	return total_count > 1
}

Move_Fraction :: enum u8 {
	All,      // 100%
	Half,     // ~50% (50.001% rounded up)
	Quarter,  // ~25% (25.001% rounded up)
	Only_One, // exactly 1
}

// Branchless mapping: given x available units, return how many to move
// for the chosen fraction action. The Half / Quarter cases use a tiny
// bias (0.00001) so that exact multiples round to the next bucket, e.g.
// Half of 4 -> 3, Quarter of 4 -> 2, Half of 100 -> 51.
fraction_move_count :: proc(action: Move_Fraction, x: int) -> int {
	switch action {
	case .All:
		return x
	case .Half:
		return int(math.ceil(f64(x) * 0.50001))
	case .Quarter:
		return int(math.ceil(f64(x) * 0.25001))
	case .Only_One:
		return 1
	}
	return 0
}
