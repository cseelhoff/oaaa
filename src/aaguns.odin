package oaaa

import sa "core:container/small_array"

move_aa_guns :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_needed = false
	for src_land in Land_ID {
		move_aagun_land(gc, src_land) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true 
}

move_aagun_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> (ok: bool) {
	if gc.active_armies[src_land][.AAGUN_UNMOVED] == 0 do return true
	reset_valid_moves(gc, l2aid(src_land))
	add_valid_aagun_moves(gc, src_land)
	for gc.active_armies[src_land][Active_Army.AAGUN_UNMOVED] > 0 {
		move_next_aagun_in_land(gc, src_land) or_return
	}
	return true
}

move_next_aagun_in_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> (ok: bool) {
	dst_air_idx := get_move_input(
		gc,
		Active_Army_Names[.AAGUN_UNMOVED],
		l2aid(src_land),
	) or_return
	dst_land := Land_ID(dst_air_idx)
	if skip_army(gc, src_land, dst_land, .AAGUN_UNMOVED) do return true
	move_single_army(gc, dst_land, .AAGUN_0_MOVES, gc.cur_player, .AAGUN_UNMOVED, src_land)
	return true
}

add_valid_aagun_moves :: proc(gc: ^Game_Cache, src_land: Land_ID) {
	for dst_land in sa.slice(&mm.adj_l2l[src_land]) {
		if l2aid(dst_land) in gc.skipped_moves[l2aid(src_land)] ||
		   mm.team[gc.owner[dst_land]] != mm.team[gc.cur_player] {
			continue
		}
		sa.push(&gc.valid_actions, l2act(dst_land))
	}
}
