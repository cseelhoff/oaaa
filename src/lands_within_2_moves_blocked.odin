package oaaa

// Precomputed runtime variant of mm.lands_within_2_moves[src]: returns the
// Lands reachable from src in exactly 2 Moves, given which of src's <=6
// Adjacent Lands are currently blocked (enemy Factory or enemy Units).
//
// Key per source Land = 6 bits, one per Adjacent slot (slot order matches
// mm.lands_within_1_move[src]). Table size = len(Land_ID) * 64 * 16 B.

LANDS_WITHIN_2_MOVES_KEY_COUNT :: 1 << MAX_LAND_TO_LAND_CONNECTIONS

initialize_lands_within_2_moves_blocked_table :: proc() {
	for src_land in Land_ID {
		adjacents := mm.lands_within_1_move[src_land][:]
		for i in 0 ..< len(adjacents) {
			mm.adjacent_bit_positions[src_land][i] = u8(adjacents[i])
		}
		for key in 0 ..< LANDS_WITHIN_2_MOVES_KEY_COUNT {
			reach: Land_Bitset
			for i in 0 ..< len(adjacents) {
				if (key >> uint(i)) & 1 != 0 do continue // Adjacent blocked
				reach |= mm.lands_within_1_move_bitset[adjacents[i]]
			}
			mm.lands_within_2_moves_blocked_table[src_land][key] =
				reach & mm.lands_within_2_moves[src_land]
		}
	}
}

get_unblocked_lands_within_2_moves :: #force_inline proc(
	src_land: Land_ID,
	blocked_lands: Land_Bitset,
) -> Land_Bitset {
	b := transmute(u128)blocked_lands
	p := &mm.adjacent_bit_positions[src_land]
	key :=
		(uint(b >> p[0]) & 1) << 0 |
		(uint(b >> p[1]) & 1) << 1 |
		(uint(b >> p[2]) & 1) << 2 |
		(uint(b >> p[3]) & 1) << 3 |
		(uint(b >> p[4]) & 1) << 4 |
		(uint(b >> p[5]) & 1) << 5
	return mm.lands_within_2_moves_blocked_table[src_land][key]
}
