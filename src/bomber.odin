package oaaa

bomber_after_moves := [?]Active_Plane {
	/*
    AI NOTE: Bomber Movement State Transitions
    
    When a bomber moves, its state transitions to show remaining moves:
    - Bomber_Unmoved -> Bomber_5_Moves (after first move)
    - Bomber_5_Moves -> Bomber_4_Moves (and so on)
    - If no combat intended, transitions directly to Bomber_0_Moves
    
    After combat resolution:
    - Remaining moves can be used to reach friendly territory
    - If bomber doesn't/can't move after combat, stays at Bomber_0_Moves
    */
	.Bomber_0_Moves, // No moves remaining
	.Bomber_5_Moves, // After first move if combat intended
	.Bomber_4_Moves, // After second move
	.Bomber_3_Moves, // After third move
	.Bomber_2_Moves, // After fourth move
	.Bomber_1_Moves, // After fifth move
	.Bomber_0_Moves, // After final move or if no combat
}

unlanded_bombers := [?]Active_Plane {
	.Bomber_5_Moves,
	.Bomber_4_Moves,
	.Bomber_3_Moves,
	.Bomber_2_Moves,
	.Bomber_1_Moves,
}

BOMBER_MAX_MOVES :: 6

move_unmoved_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_history_needed = false
    gc.current_active_unit = .Bomber_Unmoved
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.Bomber_Unmoved] == 0 do continue
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
        gc.current_territory = to_region(src_land)
		for gc.active_land_planes[src_land][.Bomber_Unmoved] > 0 {
			reset_valid_actions(gc)
			add_valid_unmoved_bomber_moves(gc)
			dst_action := get_action_input(gc) or_return
			if is_land(dst_action) {
				move_unmoved_bomber_to_land(gc, dst_action)
			} else {
				move_unmoved_bomber_to_sea(gc, dst_action)
			}
		}
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}

add_valid_unmoved_bomber_moves :: #force_inline proc(gc: ^Game_Cache) {
	/*
    AI NOTE: Unmoved Bomber Move Validation
    
    Bombers can move in two ways:
    1. Simple Relocation (no combat):
       - Can move up to 6 spaces to friendly territory
       - Moves set to 0 after relocation
    
    2. Combat Mission:
       - Can move up to 3 spaces to attack enemies/factories
       - Can move up to 4 spaces if landing spot within 2 moves
       - Can move up to 5 spaces if landing spot within 1 move
       - Remaining moves saved for post-combat landing
    */
    src_land := to_land(gc.current_territory)
	valid_bomber_destinations :=
		(mm.regions_within_6_air_moves[to_region(src_land)] & to_region_bitset(gc.can_bomber_land_here)) |
		((gc.region_has_enemies | to_region_bitset(gc.has_bombable_factory)) &
				(mm.regions_within_3_air_moves[to_region(src_land)] |
						(mm.regions_within_4_air_moves[to_region(src_land)] & gc.can_bomber_land_in_2_moves) |
						(mm.regions_within_5_air_moves[to_region(src_land)] & gc.can_bomber_land_in_1_moves)))

}

move_unmoved_bomber_to_land :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
    src_land := to_land(gc.current_territory)
	if skip_bomber(gc, dst_action) do return
    dst_land := to_land(dst_action)
	if dst_land in gc.can_bomber_land_here {
		gc.active_land_planes[dst_land][.Bomber_0_Moves] += 1
	} else {
		gc.more_land_battles_needed += {dst_land}
		gc.active_land_planes[dst_land][bomber_after_moves[mm.air_distance[to_region(src_land)][to_region(dst_land)]]] +=
		1
	}
	gc.idle_land_planes[dst_land][gc.acting_nation][.Bomber] += 1
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += 1
	gc.active_land_planes[src_land][.Bomber_Unmoved] -= 1
	gc.idle_land_planes[src_land][gc.acting_nation][.Bomber] -= 1
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= 1
	return
}

skip_bomber :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> (ok: bool) {
	if dst_action != .Skip_Action do return false
    src_land := to_land(gc.current_territory)
	gc.active_land_planes[src_land][.Bomber_0_Moves] +=
		gc.active_land_planes[src_land][.Bomber_Unmoved]
	gc.active_land_planes[src_land][.Bomber_Unmoved] = 0
	return true
}

move_unmoved_bomber_to_sea :: proc(gc: ^Game_Cache, dst_action: Action_ID) {
    src_land := to_land(gc.current_territory)
	dst_sea := to_sea(dst_action)
    gc.more_sea_battles_needed += {dst_sea}
	gc.active_sea_planes[dst_sea][bomber_after_moves[mm.air_distance[to_region(src_land)][to_region(dst_sea)]]] +=
	1
	add_my_bomber_to_sea(gc, dst_sea)
	gc.active_land_planes[src_land][.Bomber_Unmoved] -= 1
	gc.idle_land_planes[src_land][gc.acting_nation][.Bomber] -= 1
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= 1
}

refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
	gc.can_bomber_land_here = gc.friendly_owner & ~gc.land_battle_started
	gc.can_bomber_land_in_1_moves = {}
	gc.can_bomber_land_in_2_moves = {}
	for dst_land in gc.can_bomber_land_here {
		gc.can_bomber_land_in_1_moves += mm.regions_within_1_air_move[to_region(dst_land)]
		gc.can_bomber_land_in_2_moves += mm.regions_within_2_air_moves[to_region(dst_land)]
	}
	gc.is_bomber_cache_current = true
}

refresh_can_bomber_land_here_directly :: proc(gc: ^Game_Cache) {
	gc.can_bomber_land_here = gc.friendly_owner & ~gc.land_battle_started
	gc.is_bomber_cache_current = true
}

land_remaining_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in unlanded_bombers {
		gc.clear_history_needed = false
        gc.current_active_unit = to_unit(plane)
		for src_land in Land_ID {
            gc.current_territory = to_region(src_land)
			land_bomber_from_land(gc, src_land, plane) or_return
		}
		for src_sea in Sea_ID {
            gc.current_territory = to_region(src_sea)
			land_bomber_from_sea(gc, src_sea, plane) or_return
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

land_bomber_from_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	if gc.active_land_planes[src_land][plane] == 0 do return true
	if !gc.is_bomber_cache_current do refresh_can_bomber_land_here_directly(gc)
	gc.valid_actions = {}
	for gc.active_land_planes[src_land][plane] > 0 {
		reset_valid_actions(gc)
		add_valid_landing_bomber_moves(gc, to_region(src_land), plane, gc.active_land_planes[src_land][plane])
		dst_action := get_action_input(gc) or_return
		move_bomber_from_land_to_land(gc, dst_action)
	}
	return true
}

move_bomber_from_land_to_land :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
	plane := to_plane(gc.current_active_unit)
	src_land := to_land(gc.current_territory)
	dst_land, unit_count := to_land_count(dst_action)
	unit_count = min(unit_count, gc.active_land_planes[src_land][plane])
	gc.active_land_planes[dst_land][.Bomber_0_Moves] += unit_count
	gc.idle_land_planes[dst_land][gc.acting_nation][.Bomber] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += unit_count
	gc.active_land_planes[src_land][plane] -= unit_count
	gc.idle_land_planes[src_land][gc.acting_nation][.Bomber] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= unit_count
	return
}

land_bomber_from_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, plane: Active_Plane) -> (ok: bool) {
	if gc.active_sea_planes[src_sea][plane] == 0 do return true
	if ~gc.is_bomber_cache_current do refresh_can_bomber_land_here_directly(gc)
	gc.valid_actions = {}
	for gc.active_sea_planes[src_sea][plane] > 0 {
		reset_valid_actions(gc)
		add_valid_landing_bomber_moves(gc, to_region(src_sea), plane, gc.active_sea_planes[src_sea][plane])
		dst_action := get_action_input(gc) or_return
		move_bomber_from_sea_to_land(gc, dst_action)
	}
	return true
}

move_bomber_from_sea_to_land :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
	src_sea := to_sea(gc.current_territory)
	plane := to_plane(gc.current_active_unit)
	dst_land, unit_count := to_land_count(dst_action)
	unit_count = min(unit_count, gc.active_sea_planes[src_sea][plane])
	gc.active_land_planes[dst_land][.Bomber_0_Moves] += unit_count
	gc.idle_land_planes[dst_land][gc.acting_nation][.Bomber] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += unit_count
	gc.active_sea_planes[src_sea][plane] -= unit_count
	gc.idle_sea_planes[src_sea][gc.acting_nation][.Bomber] -= unit_count
	gc.team_sea_units[src_sea][mm.team[gc.acting_nation]] -= unit_count
	gc.friendly_antifighter_ships_total[src_sea] -= unit_count
	gc.friendly_sea_combatants_total[src_sea] -= unit_count
	return
}

add_valid_landing_bomber_moves :: proc(
	gc: ^Game_Cache,
	src_region: Region_ID,
	plane: Active_Plane,
	qty: u8,
) -> (
	valid_region_moves_bitset: Region_Bitset,
) {
	/*
    AI NOTE: Bomber Movement System
    
    Movement happens in phases:
    1. Initial Move Phase:
       - Bomber moves to target location
       - If no combat, remaining moves set to 0 (simple relocation)
       - If combat, remaining moves saved for landing
    
    2. Landing Phase (after combat):
       - Uses remaining moves to reach friendly territory
       - Cannot land on carriers (simpler than fighters)
       - Has up to 6 total moves (more than fighters' 4)
    
    Movement states track the bomber's remaining moves,
    from Bomber_0_Moves to Bomber_6_Moves
    */
	#partial switch plane {
	case .Bomber_1_Moves:
		set_valid_actions(
			gc,
			to_region_bitset(gc.can_bomber_land_here) &
			mm.regions_within_1_air_move[src_region], qty
		)
	case .Bomber_2_Moves:
		set_valid_actions(
			gc,
			to_region_bitset(gc.can_bomber_land_here) &
			mm.regions_within_2_air_moves[src_region], qty
		)
	case .Bomber_3_Moves:
		set_valid_actions(
			gc,
			to_region_bitset(gc.can_bomber_land_here) &
			mm.regions_within_3_air_moves[src_region], qty
		)
	case .Bomber_4_Moves:
		set_valid_actions(
			gc,
			to_region_bitset(gc.can_bomber_land_here) &
			mm.regions_within_4_air_moves[src_region], qty
		)
	case .Bomber_5_Moves:
		set_valid_actions(
			gc,
			to_region_bitset(gc.can_bomber_land_here) &
			mm.regions_within_5_air_moves[src_region], qty
		)
	}
	return valid_region_moves_bitset
}

add_my_bomber_to_sea :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) {
	gc.idle_sea_planes[sea][gc.acting_nation][.Bomber] += 1
	gc.team_sea_units[sea][mm.team[gc.acting_nation]] += 1
	gc.friendly_antifighter_ships_total[sea] += 1
	gc.friendly_sea_combatants_total[sea] += 1
}

remove_my_bomber_from_sea :: #force_inline proc(gc: ^Game_Cache) {
	sea := to_sea(gc.current_territory)

}
