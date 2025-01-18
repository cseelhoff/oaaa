package oaaa
import sa "core:container/small_array"
import "core:mem"
import "core:slice"

Fighter_After_Moves := [?]Active_Plane {
	.FIGHTER_4_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_1_MOVES,
	.FIGHTER_0_MOVES,
}

Unlanded_Fighters := [?]Active_Plane {
	.FIGHTER_1_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_4_MOVES,
}

FIGHTER_MAX_MOVES :: 4

move_unmoved_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_needed = false
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] == 0 do return true
		if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		gc.valid_actions = {l2act(src_land)}
		add_valid_unmoved_fighter_moves(gc, l2aid(src_land))
		for gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			dst_air := get_move_input(gc, "FIGHTER_UNMOVED", l2aid(src_land)) or_return
			if is_land(dst_air) {
				move_unmoved_fighter_from_land_to_land(gc, src_land, a2lid(dst_air))
			} else {
				move_unmoved_fighter_from_land_to_sea(gc, src_land, a2sid(dst_air))
			}
		}
	}
	for src_sea in Sea_ID {
		if gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] == 0 do return true
		if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		gc.valid_actions = {s2act(src_sea)}
		add_valid_unmoved_fighter_moves(gc, s2aid(src_sea))
		for gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] > 0 {
			dst_air := get_move_input(gc, "FIGHTER_UNMOVED", s2aid(src_sea)) or_return
			if is_land(dst_air) {
				move_unmoved_fighter_from_sea_to_land(gc, src_sea, a2lid(dst_air))
			} else {
				move_unmoved_fighter_from_sea_to_sea(gc, src_sea, a2sid(dst_air))
			}
		}
	}
	return true
}

add_valid_unmoved_fighter_moves :: #force_inline proc(gc: ^Game_Cache, src_air: Air_ID) {
	gc.valid_actions += air2action_bitset(
		(~gc.skipped_a2a[src_air] &
			((mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here) |
					(gc.air_has_enemies &
							(mm.a2a_within_2_moves[src_air] |
									(mm.a2a_within_3_moves[src_air] &
											gc.can_fighter_land_in_1_move))))),
	)
}

move_unmoved_fighter_from_land_to_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
) {
	if skip_land_fighter(gc, src_land, dst_land) do return
	if l2aid(dst_land) in gc.air_has_enemies {
		gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	} else {
		gc.land_combat_status[dst_land] = .PRE_COMBAT
		gc.active_land_planes[dst_land][Fighter_After_Moves[mm.air_distances[l2aid(src_land)][l2aid(dst_land)]]] +=
		1
	}
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][.FIGHTER_UNMOVED] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

move_unmoved_fighter_from_land_to_sea :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
) {
	if s2aid(dst_sea) in gc.air_has_enemies {
		gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	} else {
		gc.sea_combat_status[dst_sea] = .PRE_COMBAT
		gc.active_sea_planes[dst_sea][Fighter_After_Moves[mm.air_distances[l2aid(src_land)][s2aid(dst_sea)]]] +=
		1
	}
	gc.idle_sea_planes[dst_sea][gc.cur_player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][.FIGHTER_UNMOVED] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

move_unmoved_fighter_from_sea_to_land :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	dst_land: Land_ID,
) {
	if l2aid(dst_land) in gc.air_has_enemies {
		gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	} else {
		gc.land_combat_status[dst_land] = .PRE_COMBAT
		gc.active_land_planes[dst_land][Fighter_After_Moves[mm.air_distances[s2aid(src_sea)][l2aid(dst_land)]]] +=
		1
	}
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] -= 1
	gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
	return
}

move_unmoved_fighter_from_sea_to_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	if skip_sea_fighter(gc, src_sea, dst_sea) do return
	if s2aid(dst_sea) in gc.air_has_enemies {
		gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	} else {
		gc.sea_combat_status[dst_sea] = .PRE_COMBAT
		gc.active_sea_planes[dst_sea][Fighter_After_Moves[mm.air_distances[s2aid(src_sea)][s2aid(dst_sea)]]] +=
		1
	}
	gc.idle_sea_planes[dst_sea][gc.cur_player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] -= 1
	gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
	return
}

skip_land_fighter :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) -> (ok: bool) {
	if src_land != dst_land do return false
	gc.active_land_planes[src_land][.FIGHTER_0_MOVES] +=
		gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
	gc.active_land_planes[src_land][.FIGHTER_UNMOVED] = 0
	return true
}

skip_sea_fighter :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) -> (ok: bool) {
	if src_sea != dst_sea do return false
	if s2aid(src_sea) in gc.air_has_enemies do return false
	gc.active_sea_planes[src_sea][.FIGHTER_0_MOVES] +=
		gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED]
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] = 0
	return true
}

refresh_can_fighter_land_here :: proc(gc: ^Game_Cache) {
	// is allied owned and not recently conquered?
	gc.can_fighter_land_here = gc.friendly_owner & gc.land_no_combat
	// check for possiblity to build carrier under fighter
	for land in gc.factory_locations {
		gc.can_fighter_land_here += l2s_1away_via_land[land]
	}
	for sea in Sea_ID {
		if gc.allied_carriers[sea] > 0 {
			gc.can_fighter_land_here += {s2aid(sea)}
		}
		// if player owns a carrier, then landing area is 2 spaces away
		if gc.active_ships[sea][.CARRIER_UNMOVED] > 0 {
			gc.can_fighter_land_here +=
				mm.s2s_1away_via_sea[gc.canals_open][sea] |
				mm.s2s_2away_via_sea[gc.canals_open][sea]
		}
	}
	gc.can_fighter_land_in_1_move = {}
	for air in gc.can_fighter_land_here {
		gc.can_fighter_land_in_1_move += mm.a2a_within_1_moves[air]
	}
	gc.is_fighter_cache_current = true
}

add_valid_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	gc.valid_actions =
		~gc.skipped_a2a[src_air] &
		((mm.a2a_within_2_air_moves[src_air] &
					(mm.can_fighter_land_here[dst_air] | gc.air_has_enemies[dst_air])) |
				(mm.airs_3_moves_away[src_air] & gc.can_fighter_land_in_1_move) |
				(mm.airs_4_moves_away[src_air] & gc.can_fighter_land_here))
}

// add_meaningful_fighter_move :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
// 	if dst_air.can_fighter_land_here ||
// 	   dst_air.team_units[gc.cur_player.team.enemy_team.index] != 0 {
// 		add_move_if_not_skipped(gc, src_air, dst_air)
// 	}
// }

land_remaining_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Fighters {
		gc.clear_needed = false
		for src_land in Land_ID {
			land_fighter_from_land(gc, src_land, plane) or_continue
		}
		for src_sea in Sea_ID {
			land_fighter_from_sea(gc, src_sea, plane) or_continue
		}
		if gc.clear_needed do clear_move_history(gc)
	}
	return true
}

land_fighter_from_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	if gc.active_land_planes[src_land][plane] == 0 do return true
	if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_fighter_moves(gc, l2aid(src_land), plane)
	for gc.active_land_planes[src_land][plane] > 0 {
		if card(gc.valid_actions) == 0 {
			gc.active_land_planes[src_land][plane] = 0
			gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] = 0
			gc.team_land_units[src_land][mm.team[gc.cur_player]] = 0
			return true
		}
		dst_air := get_move_input(gc, Active_Plane_Names[plane], l2aid(src_land)) or_return
		if is_land(dst_air) {
			move_fighter_from_land_to_land(gc, src_land, a2lid(dst_air), plane)
		} else {
			move_fighter_from_land_to_sea(gc, src_land, a2sid(dst_air), plane)
		}
	}
	return true
}

move_fighter_from_land_to_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
	plane: Active_Plane,
) {
	gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][plane] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

move_fighter_from_land_to_sea :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	plane: Active_Plane,
) {
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	gc.idle_sea_planes[dst_sea][gc.cur_player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][plane] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

land_fighter_from_sea :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	if gc.active_sea_planes[src_sea][plane] == 0 do return true
	if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_fighter_moves(gc, s2aid(src_sea), plane)
	for gc.active_sea_planes[src_sea][plane] > 0 {
		if card(gc.valid_actions) == 0 {
			gc.active_sea_planes[src_sea][plane] = 0
			gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] = 0
			gc.team_sea_units[src_sea][mm.team[gc.cur_player]] = 0
			return true
		}
		dst_air := get_move_input(gc, Active_Plane_Names[plane], s2aid(src_sea)) or_return
		if is_land(dst_air) {
			move_fighter_from_sea_to_land(gc, src_sea, a2lid(dst_air), plane)
		} else {
			move_fighter_from_sea_to_sea(gc, src_sea, a2sid(dst_air), plane)
		}
	}
	return true
}

move_fighter_from_sea_to_land :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	dst_land: Land_ID,
	plane: Active_Plane,
) {
	gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][plane] -= 1
	gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
	return
}

move_fighter_from_sea_to_sea :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	dst_sea: Sea_ID,
	plane: Active_Plane,
) {
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	gc.idle_sea_planes[dst_sea][gc.cur_player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][plane] -= 1
	gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
	return
}
add_valid_landing_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
	#partial switch plane {
	case .FIGHTER_1_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] & 
			gc.can_fighter_land_here & 
			mm.a2a_within_1_moves[src_air],
		)
	case .FIGHTER_2_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] & 
			gc.can_fighter_land_here & 
			mm.a2a_within_2_moves[src_air],
		)
	case .FIGHTER_3_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] & 
			gc.can_fighter_land_here & 
			mm.a2a_within_4_moves[src_air],
		)
	case .FIGHTER_4_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] & 
			gc.can_fighter_land_here & 
			mm.a2a_within_4_moves[src_air],
		)	
	}
}
// land_fighter_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
// 	for plane in Unlanded_Fighters {
// 		land_fighter_airs(gc, plane) or_return
// 	}
// 	return true
// }

// land_fighter_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
// 	gc.clear_needed = false
// 	for src_air in Air_ID {
// 		land_fighter_air(gc, src_air, plane) or_return
// 	}
// 	if gc.clear_needed do clear_move_history(gc)
// 	return true
// }

// land_fighter_air :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> (ok: bool) {
// 	if gc.active_planes[src_air][plane] == 0 do return true
// 	refresh_can_fighter_land_here(gc)
// 	gc.valid_actions.len = 0
// 	add_valid_fighter_landing(gc, src_air, plane)
// 	for gc.active_planes[src_air][plane] > 0 {
// 		land_next_fighter_in_air(gc, src_air, plane) or_return
// 	}
// 	return true
// }

// add_valid_fighter_landing :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
// 	for dst_air in sa.slice(&mm.adjacent_airs[src_air]) {
// 		if dst_air.can_fighter_land_here {
// 			add_move_if_not_skipped(gc, src_air, dst_air)
// 		}
// 	}
// 	if plane == .FIGHTER_1_MOVES do return
// 	for dst_air in sa.slice(&mm.airs_2_moves_away[src_air]) {
// 		if dst_air.can_fighter_land_here {
// 			add_move_if_not_skipped(gc, src_air, dst_air)
// 		}
// 	}
// 	if plane == .FIGHTER_2_MOVES do return
// 	for dst_air in sa.slice(&mm.airs_3_moves_away[src_air]) {
// 		if dst_air.can_fighter_land_here {
// 			add_move_if_not_skipped(gc, src_air, dst_air)
// 		}
// 	}
// 	if plane == .FIGHTER_3_MOVES do return
// 	for dst_air in sa.slice(&mm.airs_4_moves_away[src_air]) {
// 		if dst_air.can_fighter_land_here {
// 			add_move_if_not_skipped(gc, src_air, dst_air)
// 		}
// 	}
// }

// land_next_fighter_in_air :: proc(
// 	gc: ^Game_Cache,
// 	src_air: Air_ID,
// 	plane: Active_Plane,
// ) -> (
// 	ok: bool,
// ) {
// 	if crash_unlandable_fighters(gc, src_air, plane) do return true
// 	dst_air := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
// 	move_single_plane(gc, dst_air, Plane_After_Moves[plane], gc.cur_player, plane, src_air)
// 	if carrier_now_empty(gc, dst_air_idx) {
// 		valid_move_index := slice.linear_search(
// 			sa.slice(&gc.valid_actions),
// 			u8(dst_air_idx),
// 		) or_return
// 		sa.unordered_remove(&gc.valid_actions, valid_move_index)
// 	}
// 	return true
// }
