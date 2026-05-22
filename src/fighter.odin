package oaaa
import "core:fmt"

fighter_after_moves := [?]Active_Plane {
	.Fighter_4_Moves,
	.Fighter_3_Moves,
	.Fighter_2_Moves,
	.Fighter_1_Moves,
	.Fighter_0_Moves,
}

unlanded_fighters := [?]Active_Plane {
	.Fighter_1_Moves,
	.Fighter_2_Moves,
	.Fighter_3_Moves,
	.Fighter_4_Moves,
}

FIGHTER_MAX_MOVES :: 4

move_unmoved_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_history_needed = false
	gc.current_active_unit = .Fighter_Unmoved
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.Fighter_Unmoved] == 0 do continue
		gc.current_territory = to_region(src_land)
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		for gc.active_land_planes[src_land][.Fighter_Unmoved] > 0 {
			reset_valid_actions(gc)
			add_valid_unmoved_fighter_moves(gc, gc.active_land_planes[src_land][.Fighter_Unmoved])
			dst_action := get_action_input(gc) or_return
			if skip_land_fighter(gc, dst_action) do return
			if is_land(dst_action) {
				move_unmoved_fighter_from_land_to_land(gc, dst_action)
			} else {
				move_unmoved_fighter_from_land_to_sea(gc, dst_action)
			}
		}
	}
	for src_sea in Sea_ID {
		if gc.active_sea_planes[src_sea][.Fighter_Unmoved] == 0 do return true
		gc.current_territory = to_region(src_sea)
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		for gc.active_sea_planes[src_sea][.Fighter_Unmoved] > 0 {
			reset_valid_actions(gc)
			add_valid_unmoved_fighter_moves(gc, gc.active_sea_planes[src_sea][.Fighter_Unmoved])
			dst_action := get_action_input(gc) or_return
			if skip_sea_fighter(gc, dst_action) do return
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
	src_region := gc.current_territory
	add_airs_to_valid_actions(
		gc,
		((mm.regions_within_4_air_moves[src_region] & gc.can_fighter_land_here) |
			(gc.region_has_enemies &
					(mm.regions_within_2_air_moves[src_region] |
							(mm.regions_within_3_air_moves[src_region] & gc.can_fighter_land_in_1_move)))),
		unit_count,
	)
}

move_unmoved_fighter_from_land_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	// if skip_land_fighter(gc, dst_action) do return
	src_land := to_land(gc.current_territory)
	dst_land := to_land(dst_action)
	if gc.team_land_units[dst_land][mm.enemy_team[gc.acting_nation]] == 0 {
		gc.active_land_planes[dst_land][.Fighter_0_Moves] += 1
	} else {
		gc.more_land_battles_needed += {dst_land}
		gc.active_land_planes[dst_land][fighter_after_moves[mm.air_distance[to_region(src_land)][to_region(dst_land)]]] +=
		1
	}
	gc.roster_land_planes[dst_land][gc.acting_nation][.Fighter] += 1
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += 1
	gc.active_land_planes[src_land][.Fighter_Unmoved] -= 1
	gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -= 1
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= 1
	return
}

move_unmoved_fighter_from_land_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	// if skip_land_fighter(gc, dst_action) do return
	dst_sea := to_sea(dst_action)
	src_land := to_land(gc.current_territory)
	if gc.team_sea_units[dst_sea][mm.enemy_team[gc.acting_nation]] == 0 {
		gc.active_sea_planes[dst_sea][.Fighter_0_Moves] += 1
	} else {
		gc.more_sea_battles_needed += {dst_sea}
		gc.active_sea_planes[dst_sea][fighter_after_moves[mm.air_distance[gc.current_territory][to_region(dst_sea)]]] +=
		1
	}
	add_ally_fighters_to_sea(gc, dst_sea, gc.acting_nation, 1)
	gc.active_land_planes[src_land][.Fighter_Unmoved] -= 1
	gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -= 1
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= 1
	return
}

move_unmoved_fighter_from_sea_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	src_sea := to_sea(gc.current_territory)
	dst_land, unit_count := to_land_count(dst_action)
	unit_count = min(unit_count, gc.active_sea_planes[src_sea][.Fighter_Unmoved])
	if gc.team_land_units[dst_land][mm.enemy_team[gc.acting_nation]] == 0 {
		gc.active_land_planes[dst_land][.Fighter_0_Moves] += unit_count
	} else {
		gc.more_land_battles_needed += {dst_land}
		// dst_region := to_region(dst_land)
		// mmdist := mm.air_distance[gc.current_territory][dst_region]
		// fighter_after_moves := fighter_after_moves[mmdist]
		// // GLOBAL_TICK += 1
		// // if GLOBAL_TICK >= 10 {
		// // 	fmt.println(dst_action)
		// // 	fmt.println(mmdist)
		// // }
		// gc.active_land_planes[dst_land][fighter_after_moves] += unit_count
		gc.active_land_planes[dst_land][fighter_after_moves[mm.air_distance[gc.current_territory][to_region(dst_land)]]] +=
			unit_count
	}
	gc.roster_land_planes[dst_land][gc.acting_nation][.Fighter] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += unit_count
	gc.active_sea_planes[src_sea][.Fighter_Unmoved] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.acting_nation, 1)
	return
}

move_unmoved_fighter_from_sea_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	if skip_sea_fighter(gc, dst_action) do return
	src_sea := to_sea(gc.current_territory)
	dst_sea := to_sea(dst_action)
	if gc.team_sea_units[dst_sea][mm.enemy_team[gc.acting_nation]] == 0 {
		gc.active_sea_planes[dst_sea][.Fighter_0_Moves] += 1
	} else {
		gc.more_sea_battles_needed += {dst_sea}
		gc.active_sea_planes[dst_sea][fighter_after_moves[mm.air_distance[to_region(src_sea)][to_region(dst_sea)]]] +=
		1
	}
	add_ally_fighters_to_sea(gc, dst_sea, gc.acting_nation, 1)
	gc.active_sea_planes[src_sea][.Fighter_Unmoved] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.acting_nation, 1)
	return
}

skip_land_fighter :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> (ok: bool) {
	if dst_action != .Skip_Action do return false
	src_land := to_land(gc.current_territory)
	gc.active_land_planes[src_land][.Fighter_0_Moves] +=
		gc.active_land_planes[src_land][.Fighter_Unmoved]
	gc.active_land_planes[src_land][.Fighter_Unmoved] = 0
	return true
}

skip_sea_fighter :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> (ok: bool) {
	if dst_action != .Skip_Action do return false
	src_sea := to_sea(gc.current_territory)
	if gc.team_sea_units[src_sea][mm.enemy_team[gc.acting_nation]] > 0  {//do return false
		gc.active_sea_planes[src_sea][.Fighter_4_Moves] +=
		gc.active_sea_planes[src_sea][.Fighter_Unmoved]
		gc.active_sea_planes[src_sea][.Fighter_Unmoved] = 0
		gc.more_sea_battles_needed += {src_sea}
	} else {
		gc.active_sea_planes[src_sea][.Fighter_0_Moves] +=
		gc.active_sea_planes[src_sea][.Fighter_Unmoved]
		gc.active_sea_planes[src_sea][.Fighter_Unmoved] = 0
	}
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
		to_region_bitset(gc.friendly_owner & ~gc.more_land_battles_needed & ~gc.land_battle_started) |
		to_region_bitset(gc.has_carrier_space | gc.possible_factory_carriers)
	debug_checks(gc)
	
	for sea in Sea_ID {
		// if player owns a carrier, then landing area is 2 spaces away
		if gc.active_ships[sea][.Carrier_2_Moves] == 0 do continue
		new_fighter_land_here := to_region_bitset(
			mm.seas_within_1_move[transmute(u8)gc.canals_open][sea] |
			mm.seas_within_2_moves[transmute(u8)gc.canals_open][sea],
		)
		get_regions(new_fighter_land_here, &region_positions)
		for region in region_positions {
			add_region(&gc.can_fighter_land_here, region)
		}
		get_regions(gc.can_fighter_land_here, &region_positions)
	}
	gc.can_fighter_land_in_1_move = {}

	get_regions(gc.can_fighter_land_here, &region_positions)
	for region in region_positions {
		gc.can_fighter_land_in_1_move += mm.regions_within_1_air_move[region]
	}
	gc.is_fighter_cache_current = true
}

add_valid_fighter_moves :: proc(gc: ^Game_Cache, src_region: Region_ID) {
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
		((mm.regions_within_2_air_moves[src_region] & (gc.can_fighter_land_here | gc.region_has_enemies)) |
			(mm.regions_within_3_air_moves[src_region] & gc.can_fighter_land_in_1_move) |
			(mm.regions_within_4_air_moves[src_region] & gc.can_fighter_land_here)),
		1,
	)
}

land_remaining_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in unlanded_fighters {
		gc.clear_history_needed = false
		gc.current_active_unit = to_unit(plane)
		for src_land in Land_ID {
			gc.current_territory = to_region(src_land)
			land_fighter_from_land(gc) or_return
		}
		for src_sea in Sea_ID {
			gc.current_territory = to_region(src_sea)
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
	for gc.active_land_planes[src_land][plane] > 0 {
		reset_valid_actions(gc)
		add_valid_landing_fighter_moves(gc, to_region(src_land), plane, 1) //gc.active_land_planes[src_land][plane])
		debug_checks(gc)
		load_dyn_arr_actions(gc)
		if len(gc.dyn_arr_valid_actions) == 0 {
			// no where for the fighter to land, so remove fighters
			gc.team_land_units[src_land][mm.team[gc.acting_nation]] -=
				gc.active_land_planes[src_land][plane]
			gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -=
				gc.active_land_planes[src_land][plane]
			gc.active_land_planes[src_land][plane] = 0
			debug_checks(gc)
			return true
		}
		load_dyn_arr_actions(gc)
		if len(gc.dyn_arr_valid_actions) == 0 {
			// no where for the fighter to land, so remove fighters
			gc.team_land_units[src_land][mm.team[gc.acting_nation]] -=
				gc.active_land_planes[src_land][plane]
			gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -=
				gc.active_land_planes[src_land][plane]
			gc.active_land_planes[src_land][plane] = 0
			debug_checks(gc)
			continue
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

move_fighter_from_land_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	src_land := to_land(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	dst_land, unit_count := to_land_count(dst_action)
	unit_count = min(unit_count, gc.active_land_planes[src_land][plane])
	gc.active_land_planes[dst_land][.Fighter_0_Moves] += unit_count
	gc.roster_land_planes[dst_land][gc.acting_nation][.Fighter] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += unit_count
	gc.active_land_planes[src_land][plane] -= unit_count
	gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= unit_count
	return
}

move_fighter_from_land_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	//todo: can we move more than 1 fighter at once?
	src_land := to_land(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	dst_sea, unit_count := to_sea_count(dst_action)
	unit_count = min(unit_count, gc.active_land_planes[src_land][plane])
	gc.active_sea_planes[dst_sea][.Fighter_0_Moves] += unit_count
	add_ally_fighters_to_sea(gc, dst_sea, gc.acting_nation, unit_count)
	gc.active_land_planes[src_land][plane] -= unit_count
	gc.roster_land_planes[src_land][gc.acting_nation][.Fighter] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= unit_count
	//todo optimize recalculate carrier landings
	if gc.friendly_carriers_total[dst_sea] * 2 <= gc.friendly_fighters_total[dst_sea] {
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
	for gc.active_sea_planes[src_sea][plane] > 0 {
		reset_valid_actions(gc)
		add_valid_landing_fighter_moves(gc, to_region(src_sea), plane, 1)
		load_dyn_arr_actions(gc)
		if len(gc.dyn_arr_valid_actions) == 0 {
			// no where for the fighter to land, so remove fighters
			gc.roster_sea_planes[src_sea][gc.acting_nation][.Fighter] -=
				gc.active_sea_planes[src_sea][plane]
			gc.team_sea_units[src_sea][mm.team[gc.acting_nation]] -=
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
	gc.active_land_planes[dst_land][.Fighter_0_Moves] += 1
	gc.roster_land_planes[dst_land][gc.acting_nation][.Fighter] += 1
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += 1
	gc.active_sea_planes[src_sea][plane] -= 1
	remove_ally_fighters_from_sea(gc, src_sea, gc.acting_nation, 1)
	return
}

move_fighter_from_sea_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
	src_sea := to_sea(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	dst_sea, unit_count := to_sea_count(dst_action)
	unit_count = min(unit_count, gc.active_sea_planes[src_sea][plane])
	gc.active_sea_planes[dst_sea][.Fighter_0_Moves] += unit_count
	add_ally_fighters_to_sea(gc, dst_sea, gc.acting_nation, unit_count)
	gc.active_sea_planes[src_sea][plane] -= unit_count
	remove_ally_fighters_from_sea(gc, src_sea, gc.acting_nation, unit_count)
	// assert(false)
	//todo optimize recalculate carrier landings
	if gc.friendly_carriers_total[src_sea] * 2 > gc.friendly_fighters_total[src_sea] {
		gc.has_carrier_space += {src_sea}
		gc.is_fighter_cache_current = false
	}
	if gc.friendly_carriers_total[dst_sea] * 2 <= gc.friendly_fighters_total[dst_sea] {
		gc.has_carrier_space -= {dst_sea}
		gc.is_fighter_cache_current = false
	}
	if gc.is_fighter_cache_current == false {
		refresh_can_fighter_land_here(gc)
	}
	return
}

add_valid_landing_fighter_moves :: proc(
	gc: ^Game_Cache,
	src_region: Region_ID,
	plane: Active_Plane,
	qty: u8,
) {
	#partial switch plane {
	case .Fighter_1_Moves:
		set_valid_actions(gc, gc.can_fighter_land_here & mm.regions_within_1_air_move[src_region], qty)
	case .Fighter_2_Moves:
		set_valid_actions(gc, gc.can_fighter_land_here & mm.regions_within_2_air_moves[src_region], qty)
	case .Fighter_3_Moves:
		set_valid_actions(gc, gc.can_fighter_land_here & mm.regions_within_3_air_moves[src_region], qty)
	case .Fighter_4_Moves:
		set_valid_actions(gc, gc.can_fighter_land_here & mm.regions_within_4_air_moves[src_region], qty)
	}
}

add_ally_fighters_to_sea :: #force_inline proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	player: Nation_ID,
	qty: u8,
) {
	gc.roster_sea_planes[sea][player][.Fighter] += qty
	gc.team_sea_units[sea][mm.team[player]] += qty
	gc.friendly_fighters_total[sea] += qty
	gc.friendly_antifighter_ships_total[sea] += qty
	gc.friendly_sea_combatants_total[sea] += qty
	if gc.friendly_carriers_total[sea] * 2 <= gc.friendly_fighters_total[sea] {
		gc.has_carrier_space -= {sea}
		gc.is_fighter_cache_current = false
	}
}

remove_ally_fighters_from_sea :: #force_inline proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	player: Nation_ID,
	qty: u8,
) {
	gc.roster_sea_planes[sea][player][.Fighter] -= qty
	gc.team_sea_units[sea][mm.team[player]] -= qty
	gc.friendly_fighters_total[sea] -= qty
	gc.friendly_antifighter_ships_total[sea] -= qty
	gc.friendly_sea_combatants_total[sea] -= qty
	if gc.friendly_carriers_total[sea] * 2 > gc.friendly_fighters_total[sea] {
		gc.has_carrier_space += {sea}
		gc.is_fighter_cache_current = false
	}
}
