package oaaa

import sa "core:container/small_array"

CARRIER_MAX_FIGHTERS :: 2

carry_allied_fighters::proc(gc: ^Game_Cache, src_sea: ^Sea, dst_sea: ^Sea) {
  fighters_remaining :u8= CARRIER_MAX_FIGHTERS
  for player in sa.slice(&gc.cur_player.team.players) {
    if player == gc.cur_player do continue
		fighters_to_move := src_sea.idle_planes[player.index][Idle_Plane.FIGHTER]
    if fighters_to_move == 0 do continue
    fighters_to_move = min(fighters_to_move, fighters_remaining)
    dst_sea.idle_planes[player.index][Idle_Plane.FIGHTER] += fighters_to_move
		dst_sea.team_units[player.team.index] += fighters_to_move
    src_sea.idle_planes[player.index][Idle_Plane.FIGHTER] -= fighters_to_move
		src_sea.team_units[player.team.index] -= fighters_to_move
    fighters_remaining -= fighters_to_move
		if fighters_remaining == 0 do break
  }
}

is_carrier_available :: proc(gc: ^Game_Cache, dst_sea: ^Sea) -> bool {
	carriers :u8= 0
	fighters :u8= 0
	for player in sa.slice(&gc.cur_player.team.players) {
		carriers += dst_sea.idle_ships[player.index][Idle_Ship.CARRIER]
		fighters += dst_sea.idle_planes[player.index][Idle_Plane.FIGHTER]
	}
	return carriers * 2 > fighters
}

carrier_now_empty :: proc(gc: ^Game_Cache, dst_air_idx: Air_ID) -> bool {
	if int(dst_air_idx) < len(gc.lands) do return false
	dst_sea := get_sea(gc, dst_air_idx)
	dst_sea.can_fighter_land_here = is_carrier_available(gc, dst_sea)
	return !dst_sea.can_fighter_land_here
}
