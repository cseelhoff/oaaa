package oaaa
import sa "core:container/small_array"
import "core:mem"
import "core:slice"

Bomber_After_Moves := [?]Active_Plane {
	.BOMBER_0_MOVES,
	.BOMBER_5_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_1_MOVES,
	.BOMBER_0_MOVES,
}

Unlanded_Bombers := [?]Active_Plane {
	.BOMBER_5_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_1_MOVES,
}

BOMBER_MAX_MOVES :: 6

bomber_enemy_checks :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) -> Active_Plane {
	if dst_air not_in gc.can_bomber_land_here {
		gc.combat_status[dst_air] = .PRE_COMBAT
		return Bomber_After_Moves[mm.air_distances[src_air][dst_air]]
	}
	return .BOMBER_0_MOVES
}

bomber_can_attack_here :: proc(gc: ^Game_Cache, land: Land_ID) {
	landable_bomber_location := gc.friendly_owner && gc.air_no_combat
	bomber_attack_locations := !gc.skipped_air2air[src_air] & (gc.air_has_enemies | gc.air_has_bombable_factory) //&& air_within_6_air_moves[src_air] 
	filtered_bomber_attack_locations := {}
	for dst_air in Air_ID {
		air_bitset : Air_Bitset = 1 << air
		filtered_bomber_attack_locations += (air_bitset & bomber_attack_locations) & (air_within_3_air_moves[src_air] | (air_within_4_air_moves[src_air] & transmute(Air_Bitset)(0- u16(transmute(u8)((mm.air_within_2_air_moves[dst_air] & landable_bomber_location) != 0)))) | (air_within_5_air_moves[src_air] & transmute(Air_Bitset)(0- u16(transmute(u8)((mm.air_within_1_air_moves[dst_air] & landable_bomber_location) != 0)))))
	}
}


	
	gc.can_bomber_land_here += {air}
	gc.can_bomber_land_in_1_move += {mm.adj_l2a[land]}
	gc.can_bomber_land_in_2_moves += {mm.air_l2a_2away[land]}
	// for air in sa.slice(&mm.adj_l2a[air]) {
	// 	gc.can_bomber_land_in_1_move += {air}
	// }
	// for air in sa.slice(&mm.airs_2_moves_away[air]) {
	// 	gc.can_bomber_land_in_2_moves += {air}
	// }
}

refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
	// initialize all to false
	if gc.is_bomber_cache_current do return
	gc.can_bomber_land_here.clear()
	gc.can_bomber_land_in_1_move.clear()
	gc.can_bomber_land_in_2_moves.clear()
	for land in Land_ID {
		// is allied owned and not recently conquered?
		if mm.team[gc.cur_player] == mm.team[gc.owner[land]] && land.combat_status == .NO_COMBAT {
			bomber_can_land_here(gc, land)
		}
	}
	gc.is_bomber_cache_current = true
}

add_valid_attacking_bomber_moves :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	valid_air_moves_bitset := !gc.skipped_air2air[src_air] && air_within_6_air_moves[src_air] && (gc.air_has_enemies || gc.air_has_bombable_factory || gc.can_bomber_land_here)
}

add_valid_landing_bomber_moves :: proc(gc: ^Game_Cache, src_air: Air_ID, nearby_air: ^[Air_ID]bit_set[Air_ID;u16]) {
	valid_air_moves_bitset := !gc.skipped_air2air[src_air] && gc.can_bomber_land_here && nearby_air 
}

land_bomber_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Bombers {
		land_bomber_airs(gc, plane) or_return
	}
	return true
}

land_bomber_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
	gc.clear_needed = false
	for src_air in Air_ID {
		land_bomber_air(gc, src_air, plane) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

land_bomber_air :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> (ok: bool) {
	if gc.active_planes[src_air][plane] == 0 do return true
	refresh_can_bomber_land_here(gc)
	gc.valid_actions.len = 0
	add_valid_bomber_landing(gc, src_air, plane)
	for gc.active_planes[src_air][plane] > 0 {
		land_next_bomber_in_air(gc, src_air, plane) or_return
	}
	return true
}

land_next_bomber_in_air :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	dst_air := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
	move_single_plane(gc, dst_air, Plane_After_Moves[plane], gc.cur_player, plane, src_air)
	return true
}
