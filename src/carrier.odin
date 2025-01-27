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
		gc.idle_sea_planes[dst_sea][player][.FIGHTER] += fighters_to_move
		gc.team_sea_units[dst_sea][mm.team[player]] += fighters_to_move
		gc.allied_fighters_total[dst_sea] += fighters_to_move
		gc.allied_antifighter_ships_total[dst_sea] += fighters_to_move
		gc.allied_sea_combatants_total[dst_sea] += fighters_to_move
		gc.idle_sea_planes[src_sea][player][.FIGHTER] -= fighters_to_move
		gc.team_sea_units[src_sea][mm.team[player]] -= fighters_to_move
		gc.allied_fighters_total[src_sea] -= fighters_to_move
		gc.allied_antifighter_ships_total[src_sea] -= fighters_to_move
		gc.allied_sea_combatants_total[src_sea] -= fighters_to_move
		fighters_remaining -= fighters_to_move
		if fighters_remaining == 0 do break
	}
}
