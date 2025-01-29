package oaaa
import sa "core:container/small_array"

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
	gc.clear_history_needed = false
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] == 0 do return true
		if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		gc.valid_actions = {to_action(src_land)}
		add_valid_unmoved_fighter_moves(gc, to_air(src_land))
		for gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			dst_air := get_move_input(gc, "FIGHTER_UNMOVED", to_air(src_land)) or_return
			if is_land(dst_air) {
				move_unmoved_fighter_from_land_to_land(gc, src_land, to_land(dst_air))
			} else {
				move_unmoved_fighter_from_land_to_sea(gc, src_land, to_sea(dst_air))
			}
		}
	}
	for src_sea in Sea_ID {
		if gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] == 0 do return true
		if ~gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		gc.valid_actions = {to_action(src_sea)}
		add_valid_unmoved_fighter_moves(gc, to_air(src_sea))
		for gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] > 0 {
			dst_air := get_move_input(gc, "FIGHTER_UNMOVED", to_air(src_sea)) or_return
			if is_land(dst_air) {
				move_unmoved_fighter_from_sea_to_land(gc, src_sea, to_land(dst_air))
			} else {
				move_unmoved_fighter_from_sea_to_sea(gc, src_sea, to_sea(dst_air))
			}
		}
	}
	return true
}

add_valid_unmoved_fighter_moves :: #force_inline proc(gc: ^Game_Cache, src_air: Air_ID) {
	gc.valid_actions += to_action_bitset(
		(~gc.rejected_moves_from[src_air] &
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
	if to_air(dst_land) in gc.air_has_enemies {
		gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	} else {
		gc.more_land_combat_needed += {dst_land}
		gc.active_land_planes[dst_land][Fighter_After_Moves[mm.air_distances[to_air(src_land)][to_air(dst_land)]]] +=
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
	if to_air(dst_sea) in gc.air_has_enemies {
		gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	} else {
		gc.more_sea_combat_needed += {dst_sea}
		gc.active_sea_planes[dst_sea][Fighter_After_Moves[mm.air_distances[to_air(src_land)][to_air(dst_sea)]]] +=
		1
	}
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
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
	if to_air(dst_land) in gc.air_has_enemies {
		gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	} else {
		gc.more_land_combat_needed += {dst_land}
		gc.active_land_planes[dst_land][Fighter_After_Moves[mm.air_distances[to_air(src_sea)][to_air(dst_land)]]] +=
		1
	}
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
	return
}

move_unmoved_fighter_from_sea_to_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	if skip_sea_fighter(gc, src_sea, dst_sea) do return
	if to_air(dst_sea) in gc.air_has_enemies {
		gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	} else {
		gc.more_sea_combat_needed += {dst_sea}
		gc.active_sea_planes[dst_sea][Fighter_After_Moves[mm.air_distances[to_air(src_sea)][to_air(dst_sea)]]] +=
		1
	}
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
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
	if to_air(src_sea) in gc.air_has_enemies do return false
	gc.active_sea_planes[src_sea][.FIGHTER_0_MOVES] +=
		gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED]
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] = 0
	return true
}

refresh_can_fighter_land_here :: proc(gc: ^Game_Cache) {
	// is allied owned and not recently conquered?
	gc.can_fighter_land_here =
		to_air_bitset(gc.friendly_owner & ~gc.more_land_combat_needed & ~gc.land_combat_started) |
		to_air_bitset(gc.has_carrier_space | gc.possible_factory_carriers)
	for sea in Sea_ID {
		// if player owns a carrier, then landing area is 2 spaces away
		if gc.active_ships[sea][.CARRIER_2_MOVES] == 0 do continue
		gc.can_fighter_land_here += to_air_bitset(
			mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][sea] |
			mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][sea],
		)
	}
	gc.can_fighter_land_in_1_move = {}
	for air in gc.can_fighter_land_here {
		gc.can_fighter_land_in_1_move += mm.a2a_within_1_moves[air]
	}
	gc.is_fighter_cache_current = true
}

add_valid_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	gc.valid_actions = to_action_bitset(
		~gc.rejected_moves_from[src_air] &
		((mm.a2a_within_2_moves[src_air] & (gc.can_fighter_land_here | gc.air_has_enemies)) |
				(mm.a2a_within_3_moves[src_air] & gc.can_fighter_land_in_1_move) |
				(mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here)),
	)
}

land_remaining_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Fighters {
		gc.clear_history_needed = false
		for src_land in Land_ID {
			land_fighter_from_land(gc, src_land, plane) or_continue
		}
		for src_sea in Sea_ID {
			land_fighter_from_sea(gc, src_sea, plane) or_continue
		}
		if gc.clear_history_needed do clear_move_history(gc)
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
	add_valid_landing_fighter_moves(gc, to_air(src_land), plane)
	for gc.active_land_planes[src_land][plane] > 0 {
		if card(gc.valid_actions) == 0 {
			gc.active_land_planes[src_land][plane] = 0
			gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] = 0
			gc.team_land_units[src_land][mm.team[gc.cur_player]] = 0
			return true
		}
		dst_air := get_move_input(gc, Active_Plane_Names[plane], to_air(src_land)) or_return
		if is_land(dst_air) {
			move_fighter_from_land_to_land(gc, src_land, to_land(dst_air), plane)
		} else {
			move_fighter_from_land_to_sea(gc, src_land, to_sea(dst_air), plane)
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
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
	gc.active_land_planes[src_land][plane] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	assert(false)
	//todo recalculate carrier landings
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
	add_valid_landing_fighter_moves(gc, to_air(src_sea), plane)
	for gc.active_sea_planes[src_sea][plane] > 0 {
		if card(gc.valid_actions) == 0 {
			gc.active_sea_planes[src_sea][plane] = 0
			gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] = 0
			gc.team_sea_units[src_sea][mm.team[gc.cur_player]] = 0
			return true
		}
		dst_air := get_move_input(gc, Active_Plane_Names[plane], to_air(src_sea)) or_return
		if is_land(dst_air) {
			move_fighter_from_sea_to_land(gc, src_sea, to_land(dst_air), plane)
		} else {
			move_fighter_from_sea_to_sea(gc, src_sea, to_sea(dst_air), plane)
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
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
	return
}

move_fighter_from_sea_to_sea :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	dst_sea: Sea_ID,
	plane: Active_Plane,
) {
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
	gc.active_sea_planes[src_sea][plane] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
	assert(false)
	//todo recalculate carrier landings
	return
}

add_valid_landing_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
	#partial switch plane {
	case .FIGHTER_1_MOVES:
		gc.valid_actions = to_action_bitset(
			~gc.rejected_moves_from[src_air] & gc.can_fighter_land_here & mm.a2a_within_1_moves[src_air],
		)
	case .FIGHTER_2_MOVES:
		gc.valid_actions = to_action_bitset(
			~gc.rejected_moves_from[src_air] & gc.can_fighter_land_here & mm.a2a_within_2_moves[src_air],
		)
	case .FIGHTER_3_MOVES:
		gc.valid_actions = to_action_bitset(
			~gc.rejected_moves_from[src_air] & gc.can_fighter_land_here & mm.a2a_within_4_moves[src_air],
		)
	case .FIGHTER_4_MOVES:
		gc.valid_actions = to_action_bitset(
			~gc.rejected_moves_from[src_air] & gc.can_fighter_land_here & mm.a2a_within_4_moves[src_air],
		)
	}
}

add_ally_fighters_to_sea :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID, qty: u8) {
	gc.idle_sea_planes[sea][player][.FIGHTER] += qty
	gc.team_sea_units[sea][mm.team[player]] += qty
	gc.allied_fighters_total[sea] += qty
	gc.allied_antifighter_ships_total[sea] += qty
	gc.allied_sea_combatants_total[sea] += qty
	if gc.allied_carriers_total[sea] * 2 <= gc.allied_fighters_total[sea] {
		gc.has_carrier_space -= {sea}
		gc.is_fighter_cache_current = false
	}
}

remove_ally_fighters_from_sea :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID, qty: u8) {
	gc.idle_sea_planes[sea][player][.FIGHTER] -= qty
	gc.team_sea_units[sea][mm.team[player]] -= qty
	gc.allied_fighters_total[sea] -= qty
	gc.allied_antifighter_ships_total[sea] -= qty
	gc.allied_sea_combatants_total[sea] -= qty
	if gc.allied_carriers_total[sea] * 2 > gc.allied_fighters_total[sea] {
		gc.has_carrier_space += {sea}
		gc.is_fighter_cache_current = false
	}
}
