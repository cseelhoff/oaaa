package oaaa

import sa "core:container/small_array"

move_aa_guns :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_land in Land_ID {
		if gc.active_armies[src_land][.AAGUN_UNMOVED] == 0 do continue
		gc.valid_actions = {to_action(src_land)}
		gc.valid_actions += to_action_bitset(
			mm.l2l_1away_via_land_bitset[src_land] &
			gc.friendly_owner &
			~to_land_bitset(gc.skipped_a2a[to_air(src_land)]),
		)
		for gc.active_armies[src_land][Active_Army.AAGUN_UNMOVED] > 0 {
			dst_air := get_move_input(
				gc,
				Active_Army_Names[.AAGUN_UNMOVED],
				to_air(src_land),
			) or_return
			if skip_army(gc, src_land, to_land(dst_air), .AAGUN_UNMOVED) do continue
			move_single_army_land(
				gc,
				to_land(dst_air),
				.AAGUN_0_MOVES,
				gc.cur_player,
				src_land,
				.AAGUN_UNMOVED,
			)
		}
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}
