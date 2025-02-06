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
	gc.current_active_unit = .FIGHTER_UNMOVED
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] == 0 do continue
		gc.current_territory = to_air(src_land)
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		reset_valid_actions(gc)
		add_valid_unmoved_fighter_moves(gc, gc.active_land_planes[src_land][.FIGHTER_UNMOVED])
		for gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			dst_action := get_action_input(gc) or_return
			if is_land(dst_action) {
				move_unmoved_fighter_from_land_to_land(gc, dst_action)
			} else {
				move_unmoved_fighter_from_land_to_sea(gc, dst_action)
			}
		}
	}
	for src_sea in Sea_ID {
		if gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] == 0 do return true
		gc.current_territory = to_air(src_sea)
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		reset_valid_actions(gc)
		add_valid_unmoved_fighter_moves(gc, gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED])
		for gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] > 0 {
			dst_action := get_action_input(gc) or_return
			if is_land(dst_action) {
				move_unmoved_fighter_from_sea_to_land(gc, dst_action)
			} else {
				move_unmoved_fighter_from_sea_to_sea(gc, dst_action)
			}
		}
	}
	return true
}

add_valid_unmoved_fighter_moves :: #force_inline proc(gc: ^Game_Cache, unit_count: u8) {
	src_air := gc.current_territory
	add_airs_to_valid_actions(
		gc,
		((mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here) |
			(gc.air_has_enemies &
					(mm.a2a_within_2_moves[src_air] |
							(mm.a2a_within_3_moves[src_air] & gc.can_fighter_land_in_1_move)))), unit_count
	)
}

move_unmoved_fighter_from_land_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	if skip_land_fighter(gc, dst_action) do return
	src_land := to_land(gc.current_territory)
	dst_land := to_land(dst_action)
	if air_has_enemies(gc, dst_action) {
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

move_unmoved_fighter_from_land_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	dst_sea := to_sea(dst_action)
	src_land := to_land(gc.current_territory)
	if air_has_enemies(gc, dst_action) {
		gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	} else {
		gc.more_sea_combat_needed += {dst_sea}
		gc.active_sea_planes[dst_sea][Fighter_After_Moves[mm.air_distances[gc.current_territory][to_air(dst_sea)]]] +=
		1
	}
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
	gc.active_land_planes[src_land][.FIGHTER_UNMOVED] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

move_unmoved_fighter_from_sea_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	dst_land, unit_count := to_land_count(dst_action)
	src_sea := to_sea(gc.current_territory)
	if air_has_enemies(gc, dst_action) {
		gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += unit_count
	} else {
		gc.more_land_combat_needed += {dst_land}
		gc.active_land_planes[dst_land][Fighter_After_Moves[mm.air_distances[gc.current_territory][to_air(dst_land)]]] +=
		unit_count
	}
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += unit_count
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
	return
}

move_unmoved_fighter_from_sea_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	if skip_sea_fighter(gc, dst_action) do return
	src_sea := to_sea(gc.current_territory)
	dst_sea := to_sea(dst_action)
	if air_has_enemies(gc, dst_action) {
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

skip_land_fighter :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> (ok: bool) {
	if dst_action != .Skip_Action do return false
	src_land := to_land(gc.current_territory)
	gc.active_land_planes[src_land][.FIGHTER_0_MOVES] +=
		gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
	gc.active_land_planes[src_land][.FIGHTER_UNMOVED] = 0
	return true
}

skip_sea_fighter :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> (ok: bool) {
	if dst_action != .Skip_Action do return false
	src_sea := to_sea(gc.current_territory)
	if air_has_enemies(gc, dst_action) do return false
	gc.active_sea_planes[src_sea][.FIGHTER_0_MOVES] +=
		gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED]
	gc.active_sea_planes[src_sea][.FIGHTER_UNMOVED] = 0
	return true
}

refresh_can_fighter_land_here :: proc(gc: ^Game_Cache) {
	/*
    AI NOTE: Fighter Landing Requirements
    Fighters can land in three types of locations:
    1. Friendly territories (not in combat)
    2. Spaces with available carrier capacity
    3. Spaces within 2 moves of a friendly carrier
       - This allows fighters to land on carriers that move after them
       - Uses current canal state since carriers must navigate canals
    */
	gc.can_fighter_land_here =
		to_air_bitset(gc.friendly_owner & ~gc.more_land_combat_needed & ~gc.land_combat_started) |
		to_air_bitset(gc.has_carrier_space | gc.possible_factory_carriers)
	when ODIN_DEBUG {
		get_airs(gc.can_fighter_land_here, &air_positions)
	}
	for sea in Sea_ID {
		// if player owns a carrier, then landing area is 2 spaces away
		if gc.active_ships[sea][.CARRIER_2_MOVES] == 0 do continue
		gc.can_fighter_land_here += to_air_bitset(
			mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][sea] |
			mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][sea],
		)
	}
	gc.can_fighter_land_in_1_move = {}

	get_airs(gc.can_fighter_land_here, &air_positions)
	for air in air_positions {
		gc.can_fighter_land_in_1_move += mm.a2a_within_1_moves[air]
	}
	gc.is_fighter_cache_current = true
}

add_valid_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	/*
    AI NOTE: Fighter Movement Rules
    Fighters can move in three ways:
    1. Up to 2 spaces if they can land at destination or there are enemies
    2. Up to 3 spaces if they can land 1 space away from destination
    3. Up to 4 spaces if they can land at destination (e.g., carrier will be there)
    
    This ensures fighters always have a valid landing spot within range
    after completing their move, even if they engage in combat.
    */
	set_valid_actions(
		gc,		
		((mm.a2a_within_2_moves[src_air] & (gc.can_fighter_land_here | gc.air_has_enemies)) |
				(mm.a2a_within_3_moves[src_air] & gc.can_fighter_land_in_1_move) |
				(mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here)),
	)
}

land_remaining_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Fighters {
		gc.clear_history_needed = false
		gc.current_active_unit = to_unit(plane)
		for src_land in Land_ID {
			gc.current_territory = to_air(src_land)
			land_fighter_from_land(gc) or_return
		}
		for src_sea in Sea_ID {
			gc.current_territory = to_air(src_sea)
			land_fighter_from_sea(gc) or_return
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

land_fighter_from_land :: proc(gc: ^Game_Cache) -> (ok: bool) {
	src_land := to_land(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	if gc.active_land_planes[src_land][plane] == 0 do return true
	if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_fighter_moves(gc, to_air(src_land), plane)
	for gc.active_land_planes[src_land][plane] > 0 {
		debug_checks(gc)
		if is_valid_actions_empty(gc) {
			// no where for the fighter to land, so remove fighters
			gc.team_land_units[src_land][mm.team[gc.cur_player]] -=
				gc.active_land_planes[src_land][plane]
			gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -=
				gc.active_land_planes[src_land][plane]
			gc.active_land_planes[src_land][plane] = 0
			debug_checks(gc)
			return true
		}
		dst_action := get_action_input(gc) or_return
		if is_land(dst_action) {
			move_fighter_from_land_to_land(gc, dst_action)
		} else {
			move_fighter_from_land_to_sea(gc, dst_action)
		}
		debug_checks(gc)
	}
	return true
}

move_fighter_from_land_to_land :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
	src_land := to_land(gc.current_territory)
	dst_land, unit_count := to_land_count(dst_action)
	plane := to_plane(gc.current_active_unit)
	gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += unit_count
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += unit_count
	gc.active_land_planes[src_land][plane] -= unit_count
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= unit_count
	return
}

move_fighter_from_land_to_sea :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
	//todo: can we move more than 1 fighter at once?
	src_land := to_land(gc.current_territory)
	dst_sea, unit_count := to_sea_count(dst_action)
	plane := to_plane(gc.current_active_unit)
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += unit_count
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, unit_count)
	gc.active_land_planes[src_land][plane] -= unit_count
	gc.idle_land_planes[src_land][gc.cur_player][.FIGHTER] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= unit_count
	//todo optimize recalculate carrier landings
	if gc.allied_carriers_total[dst_sea] * 2 <= gc.allied_fighters_total[dst_sea] {
		gc.has_carrier_space -= {dst_sea}
		// gc.is_fighter_cache_current = false
		refresh_can_fighter_land_here(gc)
	}
	return
}

land_fighter_from_sea :: proc(gc: ^Game_Cache) -> (ok: bool) {
	debug_checks(gc)
	src_sea := to_sea(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	if gc.active_sea_planes[src_sea][plane] == 0 do return true
	if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_fighter_moves(gc, to_air(src_sea), plane)
	for gc.active_sea_planes[src_sea][plane] > 0 {
		if is_valid_actions_empty(gc) {
			gc.idle_sea_planes[src_sea][gc.cur_player][.FIGHTER] -=
				gc.active_sea_planes[src_sea][plane]
			gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -=
				gc.active_sea_planes[src_sea][plane]
			gc.active_sea_planes[src_sea][plane] = 0
			return true
		}
		dst_action := get_action_input(gc) or_return
		if is_land(dst_action) {
			move_fighter_from_sea_to_land(gc, dst_action)
		} else {
			move_fighter_from_sea_to_sea(gc, dst_action)
		}
	}
	debug_checks(gc)
	return true
}

move_fighter_from_sea_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	dst_land := to_land(dst_action)
	src_sea := to_sea(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	gc.active_land_planes[dst_land][.FIGHTER_0_MOVES] += 1
	gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][plane] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, 1)
	return
}

move_fighter_from_sea_to_sea :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
	src_sea := to_sea(gc.current_territory)
	dst_sea, unit_count := to_sea_count(dst_action)
	plane := to_plane(gc.current_active_unit)
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += unit_count
	add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, unit_count)
	gc.active_sea_planes[src_sea][plane] -= unit_count
	remove_ally_fighters_from_sea(gc, src_sea, gc.cur_player, unit_count)
	// assert(false)
	//todo optimize recalculate carrier landings
	if gc.allied_carriers_total[src_sea] * 2 > gc.allied_fighters_total[src_sea] {
		gc.has_carrier_space += {src_sea}
		gc.is_fighter_cache_current = false
	}
	if gc.allied_carriers_total[dst_sea] * 2 <= gc.allied_fighters_total[dst_sea] {
		gc.has_carrier_space -= {dst_sea}
		gc.is_fighter_cache_current = false
	}
	if gc.is_fighter_cache_current == false {
		refresh_can_fighter_land_here(gc)
	}
	return
}

add_valid_landing_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
	#partial switch plane {
	case .FIGHTER_1_MOVES:
		set_valid_actions(
			gc,
			gc.can_fighter_land_here &
			mm.a2a_within_1_moves[src_air],
		)
	case .FIGHTER_2_MOVES:
		set_valid_actions(
			gc,
			gc.can_fighter_land_here &
			mm.a2a_within_2_moves[src_air],
		)
	case .FIGHTER_3_MOVES:
		set_valid_actions(
			gc,
			gc.can_fighter_land_here &
			mm.a2a_within_3_moves[src_air],
		)
	case .FIGHTER_4_MOVES:
		set_valid_actions(
			gc,
			gc.can_fighter_land_here &
			mm.a2a_within_4_moves[src_air],
		)
	}
}

add_ally_fighters_to_sea :: #force_inline proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	player: Player_ID,
	qty: u8,
) {
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

remove_ally_fighters_from_sea :: #force_inline proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	player: Player_ID,
	qty: u8,
) {
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
