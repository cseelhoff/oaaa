package oaaa

import "core:fmt"

Idle_Army :: enum {
	Infantry,
	Artillery,
	Tank,
	AAGun,
}

COST_IDLE_ARMY := [Idle_Army]u8 {
	.Infantry   = 3,
	.Artillery  = 4,
	.Tank  = 6,
	.AAGun = 5,
}

idle_army_names := [Idle_Army]string {
	.Infantry   = "Infantry",
	.Artillery  = "Artillery",
	.Tank  = "Tank",
	.AAGun = "AAGun",
}

INFANTRY_ATTACK_VALUE :: 1
ARTILLERY_ATTACK_VALUE :: 2
TANK_ATTACK_VALUE :: 3

INFANTRY_DEFENSE_VALUE :: 2
ARTILLERY_DEFENSE_VALUE :: 2
TANK_DEFENSE_VALUE :: 3

Active_Army :: enum {
    /*
    AI NOTE: Army Movement States
    
    Each unit type has different movement capabilities:
    - Infantry: 1 move (Infantry_1_Moves -> Infantry_0_Moves)
    - Artillery: 1 move (Artillery_1_Moves -> Artillery_0_Moves)
    - Tank: 2 moves (Tank_2_Moves -> Tank_1_Moves -> Tank_0_Moves)
    - AA Gun: 1 move (AAGun_1_Moves -> AAGun_0_Moves)
    
    Movement states track remaining moves and are used to:
    1. Validate legal moves based on distance
    2. Handle special cases like tank blitz
    3. Track units that have finished moving
    */
    Infantry_1_Moves,
    Infantry_0_Moves,
    Artillery_1_Moves,
    Artillery_0_Moves,
    Tank_2_Moves,
    Tank_1_Moves,
    Tank_0_Moves,
    AAGun_1_Moves,
    AAGun_0_Moves,
}

active_army_to_idle := [Active_Army]Idle_Army {
	.Infantry_1_Moves   = .Infantry,
	.Infantry_0_Moves   = .Infantry,
	.Artillery_1_Moves  = .Artillery,
	.Artillery_0_Moves  = .Artillery,
	.Tank_2_Moves  = .Tank,
	.Tank_1_Moves  = .Tank,
	.Tank_0_Moves  = .Tank,
	.AAGun_1_Moves = .AAGun,
	.AAGun_0_Moves = .AAGun,
}

armies_moved := [Active_Army]Active_Army {
    /*
    AI NOTE: Movement Exhaustion and Monte Carlo Optimization
    
    Most moves exhaust all movement points immediately (e.g. Tank_2_Moves -> Tank_0_Moves) because:
    1. Forces player to choose final destination in one step
    2. Simplifies the Monte Carlo search tree by eliminating intermediate states
    3. Prevents having to evaluate all possible movement combinations
    
    Blitz moves are the only exception (Tank_2_Moves -> Tank_1_Moves) because:
    1. The path matters - different midland territories can be conquered
    2. Multiple valid paths may exist to same destination
    3. Special moves possible (e.g. blitz forward then move back)
    
    Example scenarios:
    1. Normal move: A->C uses all moves (simpler tree)
    2. Blitz options: A->C via B1 or B2 (must specify path)
       - A->B1->C (conquers B1)
       - A->B2->C (conquers B2)
    3. Blitz special: A->B->A (conquer B, return home)
    */
    .Infantry_1_Moves   = .Infantry_0_Moves,
    .Infantry_0_Moves   = .Infantry_0_Moves,
    .Artillery_1_Moves  = .Artillery_0_Moves,
    .Artillery_0_Moves  = .Artillery_0_Moves,
    .Tank_2_Moves  = .Tank_0_Moves,  // Skip exhausts all moves
    .Tank_1_Moves  = .Tank_0_Moves,  // Skip exhausts remaining move
    .Tank_0_Moves  = .Tank_0_Moves,
    .AAGun_1_Moves = .AAGun_0_Moves,
    .AAGun_0_Moves = .AAGun_0_Moves,
}

unmoved_armies := [?]Active_Army {
    /*
    AI NOTE: Tank Movement Ordering
    
    The order of infantry/artillery movement is not significant.
    However, tanks must be processed in order of remaining movement:
    
    1. Tank_2_Moves must be handled before Tank_1_Moves because:
       - A tank with 2 moves can blitz, becoming Tank_1_Moves
       - That same tank may need to use its remaining move
       - So we must process all potential blitz moves first
    
    Example sequence:
    1. Tank_2_Moves blitzes from A->B, becomes Tank_1_Moves
    2. That same tank, now as Tank_1_Moves, moves B->C
    */
    .Infantry_1_Moves,
    .Artillery_1_Moves,
    .Tank_2_Moves,  // Must process full-movement tanks first
    .Tank_1_Moves,  // Then handle tanks that have already moved/blitzed
    //Active_Army.AAGun_1_Moves, //Moved in later engine version
}

Army_Sizes :: distinct enum u8 {
	SMALL,
	LARGE,
}

army_size := [Active_Army]Army_Sizes {
	.Infantry_1_Moves   = .SMALL,
	.Infantry_0_Moves   = .SMALL,
	.Artillery_1_Moves  = .LARGE,
	.Artillery_0_Moves  = .LARGE,
	.Tank_2_Moves  = .LARGE,
	.Tank_1_Moves  = .LARGE,
	.Tank_0_Moves  = .LARGE,
	.AAGun_1_Moves = .LARGE,
	.AAGun_0_Moves = .LARGE,
}

move_armies :: proc(gc: ^Game_Cache) -> (ok: bool) {
    /*
    AI NOTE: Move History Management
    
    The game tracks which moves have been rejected by the player to:
    1. Avoid re-offering moves the player explicitly declined
    2. Prevent duplicate suggestions for the same move
    
    Move history is preserved within a single unit type's moves,
    but cleared when switching unit types because:
    - Different units have different movement capabilities
    - A path rejected for infantry might be valid for tanks
    - Keeps the AI from being overly constrained by previous decisions
    
    Example:
    1. Player rejects moving infantry from Moscow to Ukraine
    2. That move won't be offered again for other infantry
    3. But will be available when moving tanks (after history clear)
    */
    for army in unmoved_armies {
        gc.clear_history_needed = false
        gc.current_active_unit = to_unit(army)
        for src_land in Land_ID {
            if gc.active_armies[src_land][army] == 0 do continue
            gc.current_territory = to_region(src_land)
            // reset_valid_actions(gc)
            // add_valid_army_moves_1(gc)
            for gc.active_armies[src_land][army] > 0 {
                reset_valid_actions(gc)
                if army == .Tank_2_Moves do add_valid_army_moves_2(gc)
                add_valid_army_moves_1(gc)
                dst_action := get_action_input(gc) or_return
                // Handle sea movement (transport loading) first
                if !is_land(dst_action) {
                    dst_sea := to_sea(dst_action)
                    for transport in active_transport_by_army_size[army_size[army]] {
                        if gc.active_ships[dst_sea][transport] > 0 {
                            idle_army := active_army_to_idle[army]
                            new_ship := transport_after_loading[idle_army][transport]
                            gc.active_ships[dst_sea][new_ship] += 1
                            gc.idle_ships[dst_sea][gc.acting_nation][active_ship_to_idle[new_ship]] += 1
                            gc.active_armies[src_land][army] -= 1
                            gc.idle_armies[src_land][gc.acting_nation][idle_army] -= 1
                            gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= 1
                            gc.active_ships[dst_sea][transport] -= 1
                            gc.idle_ships[dst_sea][gc.acting_nation][active_ship_to_idle[transport]] -= 1
                            break
                        }
                    }
                    if !is_boat_available(gc, to_sea(dst_action)) {
                        remove_valid_action(gc, dst_action)
                    }
                    return true
                }
                
                // Handle land movement
                if skip_army(gc, dst_action) do break
                
                next_state := blitz_checks(gc, dst_action)
                move_single_army_land(gc, dst_action, next_state)
            }
        }
        if gc.clear_history_needed do clear_move_history(gc)
    }
    return true
}

blitz_checks :: proc(
	gc: ^Game_Cache,
    dst_action: Action_ID,
) -> Active_Army {
    /*
    AI NOTE: Tank Blitz Path Selection
    
    When a tank blitzes (moves 2 spaces), the player must explicitly choose
    which territory to conquer on the way to their final destination.
    
    Example:
    Tank in Land A wants to reach Land D
    Can blitz through either:
    1. Land A -> Land B -> Land D
    2. Land A -> Land C -> Land D
    
    The engine requires this to be two separate moves:
    1. First move: Choose which middle territory to conquer (B or C)
    2. Second move: Continue to final destination (D)
    
    This explicit path selection:
    - Avoids engine making assumptions about preferred path
    - Gives player strategic control over which territories to capture
    - Handles cases where different paths have different strategic value
    */
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
    dst_land := to_land(dst_action)
	if !mark_land_for_combat_resolution(gc, dst_land) &&
	   check_and_process_land_conquest(gc, dst_land) &&
	   army == .Tank_2_Moves &&
	   mm.land_distance[src_land][dst_land] == 1 &&
	   gc.factory_prod[dst_land] == 0 {
		return .Tank_1_Moves //blitz!
	}
	return armies_moved[army]
}

move_single_army_land :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
    dst_unit: Active_Army,
) {
    /*
    AI NOTE: Unit Counter Caching
    
    The game maintains three parallel unit counting systems for performance:
    
    1. active_armies[land][state] - Units by movement state
       - Tracks exact movement points remaining (e.g. Tank_2_Moves)
       - Used for movement validation and offering valid moves
    
    2. idle_armies[land][player][type] - Units by base type and owner
       - Simplified view (e.g. just Tank)
       - Used for combat resolution and unit type counting
    
    3. team_land_units[land][team] - Total units by team
       - Quick strength check without looping through unit types
       - Used for territory control and battle resolution
    
    This redundancy optimizes common operations by avoiding:
    - Summing unit counts during battles
    - Converting between unit states when checking strength
    - Looping through owners when checking team control
    */
    src_land := to_land(gc.current_territory)
    src_unit := to_army(gc.current_active_unit)
    dst_land, unit_count := to_land_count(dst_action)
    unit_count = min(unit_count, gc.active_armies[src_land][src_unit])
	gc.active_armies[dst_land][dst_unit] += unit_count
	gc.idle_armies[dst_land][gc.acting_nation][active_army_to_idle[dst_unit]] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += unit_count
	gc.active_armies[src_land][src_unit] -= unit_count
	gc.idle_armies[src_land][gc.acting_nation][active_army_to_idle[src_unit]] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= unit_count
}

is_boat_available :: proc(
	gc: ^Game_Cache,
	dst_sea: Sea_ID,
) -> bool {
    army := to_army(gc.current_active_unit)
	idle_ships := &gc.idle_ships[dst_sea][gc.acting_nation]
	for transport in transport_allowed_by_army_size[army_size[army]] {
		if idle_ships[transport] > 0 {
			return true
		}
	}
	return false
}

add_if_boat_available :: proc(
	gc: ^Game_Cache,
    dst_sea: Sea_ID,
) {
		if is_boat_available(gc, dst_sea) {
			add_sea_to_valid_actions(gc, dst_sea, 1)
		}
}

are_midlands_blocked :: proc(gc: ^Game_Cache, mid_lands: ^Mid_Lands) -> bool {
	for mid_land in mid_lands {
		if mid_land in (gc.has_enemy_factory | gc.has_enemy_units) do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
    add_lands_to_valid_actions(gc, mm.lands_within_1_move_bitset[src_land], gc.active_armies[src_land][army])
	//todo game_cache bitset for is_boat_available large, small
	for dst_sea in mm.coastal_seas[src_land] {
		add_if_boat_available(gc, dst_sea)
	}
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache) {
    /*
    AI NOTE: Territory Control Validation
    
    When validating 2-space army moves, we must check both:
    1. Enemy Units (has_enemy_units):
       - Enemy armies that moved into the territory
       - Blocks movement even without a factory
       - Dynamic, changes as units move
    
    2. Enemy Factories (has_enemy_factory):
       - Permanent structures that indicate territory control
       - Blocks movement even without units present
       - Static, only changes when factories built/destroyed
    
    Both checks are needed since:
    - Territory can have enemy units without factory (from movement)
    - Territory can have enemy factory without units (newly built)
    - Movement blocked if either condition is true
    */
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
	for dst_land in (mm.lands_within_2_moves[src_land]) {
		if (mm.lands_between[src_land][dst_land] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
			continue
		}
		add_land_to_valid_actions(gc, dst_land, gc.active_armies[src_land][army])
        // load_dyn_arr_actions(gc)
        // fmt.println(gc.dyn_arr_valid_actions)
	}
	// check for moving from land to sea (two moves away)
	// for dst_sea in (mm.l2s_2away_via_land_bitset[src_land]) {
	// 	if (mm.l2s_2away_via_midland_bitset[src_land][dst_sea] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
	// 		continue
	// 	}
	// 	add_if_boat_available(gc, dst_sea)
	// }
}

skip_army :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) -> (
	ok: bool,
) {
	if dst_action != .Skip_Action do return false
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
	gc.active_armies[src_land][armies_moved[army]] += gc.active_armies[src_land][army]
	gc.active_armies[src_land][army] = 0
	return true
}

load_available_transport :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) {
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
    dst_sea := to_sea(dst_action)
	
	fmt.eprintln("Error: No large transport available to load")
}
