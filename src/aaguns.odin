package oaaa

import sa "core:container/small_array"

move_aa_guns :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_needed = false
	for &src_land in gc.lands {
		move_aagun_land(gc, &src_land) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_aagun_land :: proc(gc: ^Game_Cache, src_land: ^Land) -> (ok: bool) {
	if src_land.active_armies[Active_Army.AAGUN_UNMOVED] == 0 do return true
	reset_valid_moves(gc, src_land)
	add_valid_aagun_moves(gc, src_land)
	for src_land.active_armies[Active_Army.AAGUN_UNMOVED] > 0 {
		move_next_aagun_in_land(gc, src_land) or_return
	}
	return true
}

move_next_aagun_in_land :: proc(gc: ^Game_Cache, src_land: ^Land) -> (ok: bool) {
	dst_air_idx := get_move_input(
		gc,
		Active_Army_Names[Active_Army.AAGUN_UNMOVED],
		src_land,
	) or_return
	dst_land := &gc.lands[dst_air_idx]
	if skip_army(src_land, dst_land, Active_Army.AAGUN_UNMOVED) do return true
	move_single_army(
		dst_land,
		Active_Army.AAGUN_0_MOVES,
		gc.cur_player,
		Active_Army.AAGUN_UNMOVED,
		src_land,
	)
	return true
}

add_valid_aagun_moves :: proc(gc: ^Game_Cache, src_land: ^Land) {
	for dst_land in sa.slice(&src_land.adjacent_lands) {
		if src_land.skipped_moves[dst_land.territory_index] ||
		   dst_land.owner.team != gc.cur_player.team {
			continue
		}
		sa.push(&gc.valid_actions, int(dst_land.territory_index))
	}
}
