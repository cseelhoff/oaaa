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

// is_carrier_available :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
// 	return gc.allied_carriers_total[sea] * 2 > gc.allied_fighters_total[sea]
// }

// carrier_now_empty :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
// 	if is_carrier_available(gc, sea) {
// 		gc.can_fighter_land_here += {to_air(sea)}
// 	}
// 	return to_air(sea) not_in gc.can_fighter_land_here
// }

// refresh_can_fighter_land_on_carrier :: proc(gc: ^Game_Cache, sea: Sea_ID) {
// 	if is_carrier_available(gc, sea) {
// 		gc.can_fighter_land_here += {to_air(sea)}
// 	} else {
// 		gc.can_fighter_land_here -= {to_air(sea)}
// 	}
// }
