package oaaa

import sa "core:container/small_array"

CARRIER_MAX_FIGHTERS :: 2

carry_allied_fighters :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	fighters_remaining: u8 = CARRIER_MAX_FIGHTERS
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if player == gc.cur_player do continue
		fighters_to_move := gc.idle_planes[to_air_id(src_sea)][player][.FIGHTER]
		if fighters_to_move == 0 do continue
		fighters_to_move = min(fighters_to_move, fighters_remaining)
		gc.idle_planes[to_air_id(dst_sea)][player][.FIGHTER] += fighters_to_move
		gc.team_units[to_air_id(dst_sea)][mm.team[player]] += fighters_to_move
		gc.idle_planes[to_air_id(src_sea)][player][.FIGHTER] -= fighters_to_move
		gc.team_units[to_air_id(src_sea)][mm.team[player]] -= fighters_to_move
		fighters_remaining -= fighters_to_move
		if fighters_remaining == 0 do break
	}
}

is_carrier_available :: proc(gc: ^Game_Cache, dst_sea: Sea_ID) -> bool {
	carriers: u8 = 0
	fighters: u8 = 0
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		carriers += gc.idle_ships[dst_sea][player][Idle_Ship.CARRIER]
		fighters += gc.idle_planes[dst_sea][player][Idle_Plane.FIGHTER]
	}
	return carriers * 2 > fighters
}

carrier_now_empty :: proc(gc: ^Game_Cache, dst_air_idx: Air_ID) -> bool {
	if int(dst_air_idx) < len(Land_ID) do return false
	dst_sea := get_sea_id(dst_air_idx)
	if is_carrier_available(gc, dst_sea) {
		gc.can_fighter_land_here += {to_air_id(dst_sea)}
	}
	return to_air_id(dst_sea) not_in gc.can_fighter_land_here
}
