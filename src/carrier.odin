package oaaa

import sa "core:container/small_array"

CARRIER_MAX_FIGHTERS :: 2

carry_allied_fighters :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	fighters_remaining: u8 = CARRIER_MAX_FIGHTERS
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if player == gc.cur_player do continue
		fighters_to_move := gc.idle_sea_planes[src_sea][player][.FIGHTER]
		if fighters_to_move == 0 do continue
		fighters_to_move = min(fighters_to_move, fighters_remaining)
		add_ally_fighters_to_sea(gc, dst_sea, player, fighters_to_move)
		remove_ally_fighters_from_sea(gc, src_sea, player, fighters_to_move)
		fighters_remaining -= fighters_to_move
		if fighters_remaining == 0 do break
	}
}
