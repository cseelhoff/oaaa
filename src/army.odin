package oaaa

import sa "core:container/small_array"
import "core:fmt"

Idle_Army :: enum {
	INF,
	ARTY,
	TANK,
	AAGUN,
}

COST_IDLE_ARMY := [Idle_Army]u8 {
	.INF   = Cost_Buy[.BUY_INF_ACTION],
	.ARTY  = Cost_Buy[.BUY_ARTY_ACTION],
	.TANK  = Cost_Buy[.BUY_TANK_ACTION],
	.AAGUN = Cost_Buy[.BUY_AAGUN_ACTION],
}

Idle_Army_Names := [Idle_Army]string {
	.INF   = "INF",
	.ARTY  = "ARTY",
	.TANK  = "TANK",
	.AAGUN = "AAGUN",
}

INFANTRY_ATTACK :: 1
ARTILLERY_ATTACK :: 2
TANK_ATTACK :: 3

INFANTRY_DEFENSE :: 2
ARTILLERY_DEFENSE :: 2
TANK_DEFENSE :: 3

Active_Army :: enum {
    /*
    AI NOTE: Army Movement States
    
    Each unit type has different movement capabilities:
    - Infantry: 1 move (INF_1_MOVES -> INF_0_MOVES)
    - Artillery: 1 move (ARTY_1_MOVES -> ARTY_0_MOVES)
    - Tank: 2 moves (TANK_2_MOVES -> TANK_1_MOVES -> TANK_0_MOVES)
    - AA Gun: 1 move (AAGUN_1_MOVES -> AAGUN_0_MOVES)
    
    Movement states track remaining moves and are used to:
    1. Validate legal moves based on distance
    2. Handle special cases like tank blitz
    3. Track units that have finished moving
    */
    INF_1_MOVES,
    INF_0_MOVES,
    ARTY_1_MOVES,
    ARTY_0_MOVES,
    TANK_2_MOVES,
    TANK_1_MOVES,
    TANK_0_MOVES,
    AAGUN_1_MOVES,
    AAGUN_0_MOVES,
}

Active_Army_To_Idle := [Active_Army]Idle_Army {
	.INF_1_MOVES   = .INF,
	.INF_0_MOVES   = .INF,
	.ARTY_1_MOVES  = .ARTY,
	.ARTY_0_MOVES  = .ARTY,
	.TANK_2_MOVES  = .TANK,
	.TANK_1_MOVES  = .TANK,
	.TANK_0_MOVES  = .TANK,
	.AAGUN_1_MOVES = .AAGUN,
	.AAGUN_0_MOVES = .AAGUN,
}

Armies_Moved := [Active_Army]Active_Army {
    /*
    AI NOTE: Movement Exhaustion and Monte Carlo Optimization
    
    Most moves exhaust all movement points immediately (e.g. TANK_2_MOVES -> TANK_0_MOVES) because:
    1. Forces player to choose final destination in one step
    2. Simplifies the Monte Carlo search tree by eliminating intermediate states
    3. Prevents having to evaluate all possible movement combinations
    
    Blitz moves are the only exception (TANK_2_MOVES -> TANK_1_MOVES) because:
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
    .INF_1_MOVES   = .INF_0_MOVES,
    .INF_0_MOVES   = .INF_0_MOVES,
    .ARTY_1_MOVES  = .ARTY_0_MOVES,
    .ARTY_0_MOVES  = .ARTY_0_MOVES,
    .TANK_2_MOVES  = .TANK_0_MOVES,  // Skip exhausts all moves
    .TANK_1_MOVES  = .TANK_0_MOVES,  // Skip exhausts remaining move
    .TANK_0_MOVES  = .TANK_0_MOVES,
    .AAGUN_1_MOVES = .AAGUN_0_MOVES,
    .AAGUN_0_MOVES = .AAGUN_0_MOVES,
}

Unmoved_Armies := [?]Active_Army {
    /*
    AI NOTE: Tank Movement Ordering
    
    The order of infantry/artillery movement is not significant.
    However, tanks must be processed in order of remaining movement:
    
    1. TANK_2_MOVES must be handled before TANK_1_MOVES because:
       - A tank with 2 moves can blitz, becoming TANK_1_MOVES
       - That same tank may need to use its remaining move
       - So we must process all potential blitz moves first
    
    Example sequence:
    1. TANK_2_MOVES blitzes from A->B, becomes TANK_1_MOVES
    2. That same tank, now as TANK_1_MOVES, moves B->C
    */
    .INF_1_MOVES,
    .ARTY_1_MOVES,
    .TANK_2_MOVES,  // Must process full-movement tanks first
    .TANK_1_MOVES,  // Then handle tanks that have already moved/blitzed
    //Active_Army.AAGUN_1_MOVES, //Moved in later engine version
}

Army_Sizes :: distinct enum u8 {
	SMALL,
	LARGE,
}

Army_Size := [Active_Army]Army_Sizes {
	.INF_1_MOVES   = .SMALL,
	.INF_0_MOVES   = .SMALL,
	.ARTY_1_MOVES  = .LARGE,
	.ARTY_0_MOVES  = .LARGE,
	.TANK_2_MOVES  = .LARGE,
	.TANK_1_MOVES  = .LARGE,
	.TANK_0_MOVES  = .LARGE,
	.AAGUN_1_MOVES = .LARGE,
	.AAGUN_0_MOVES = .LARGE,
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
    for army in Unmoved_Armies {
        gc.clear_history_needed = false
        gc.current_active_unit = to_unit(army)
        for src_land in Land_ID {
            if gc.active_armies[src_land][army] == 0 do continue
            gc.current_territory = to_air(src_land)
            reset_valid_actions(gc)
            add_valid_army_moves_1(gc)
            if army == .TANK_2_MOVES do add_valid_army_moves_2(gc)
            for gc.active_armies[src_land][army] > 0 {
                dst_action := get_action_input(gc) or_return
                // Handle sea movement (transport loading) first
                if !is_land(dst_action) {
                    dst_sea := to_sea(dst_action)
                    for transport in Active_Trans_By_Army_Size[Army_Size[army]] {
                        if gc.active_ships[dst_sea][transport] > 0 {
                            idle_army := Active_Army_To_Idle[army]
                            new_ship := Trans_After_Loading[idle_army][transport]
                            gc.active_ships[dst_sea][new_ship] += 1
                            gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[new_ship]] += 1
                            gc.active_armies[src_land][army] -= 1
                            gc.idle_armies[src_land][gc.cur_player][idle_army] -= 1
                            gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
                            gc.active_ships[dst_sea][transport] -= 1
                            gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[transport]] -= 1
                            break
                        }
                    }
                    if !is_boat_available(gc, dst_action) {
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
	   army == .TANK_2_MOVES &&
	   mm.land_distances[src_land][dst_land] == 1 &&
	   gc.factory_prod[dst_land] == 0 {
		return .TANK_1_MOVES //blitz!
	}
	return Armies_Moved[army]
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
       - Tracks exact movement points remaining (e.g. TANK_2_MOVES)
       - Used for movement validation and offering valid moves
    
    2. idle_armies[land][player][type] - Units by base type and owner
       - Simplified view (e.g. just TANK)
       - Used for combat resolution and unit type counting
    
    3. team_land_units[land][team] - Total units by team
       - Quick strength check without looping through unit types
       - Used for territory control and battle resolution
    
    This redundancy optimizes common operations by avoiding:
    - Summing unit counts during battles
    - Converting between unit states when checking strength
    - Looping through owners when checking team control
    */
    dst_land, unit_count := to_land_count(dst_action)
    src_land := to_land(gc.current_territory)
    src_unit := to_army(gc.current_active_unit)
	gc.active_armies[dst_land][dst_unit] += unit_count
	gc.idle_armies[dst_land][gc.cur_player][Active_Army_To_Idle[dst_unit]] += unit_count
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += unit_count
	gc.active_armies[src_land][src_unit] -= unit_count
	gc.idle_armies[src_land][gc.cur_player][Active_Army_To_Idle[src_unit]] -= unit_count
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= unit_count
}

is_boat_available :: proc(
	gc: ^Game_Cache,
	dst_action: Action_ID,
) -> bool {
    army := to_army(gc.current_active_unit)
	idle_ships := &gc.idle_ships[to_sea(dst_action)][gc.cur_player]
	for transport in Trans_Allowed_By_Army_Size[Army_Size[army]] {
		if idle_ships[transport] > 0 {
			return true
		}
	}
	return false
}

add_if_boat_available :: proc(
	gc: ^Game_Cache,
    dst_action: Action_ID,
) {
		if is_boat_available(gc, dst_action) {
			add_valid_action(gc, dst_action)
		}
}

are_midlands_blocked :: proc(gc: ^Game_Cache, mid_lands: ^Mid_Lands) -> bool {
	for mid_land in sa.slice(mid_lands) {
		if mid_land in (gc.has_enemy_factory | gc.has_enemy_units) do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
    add_lands_to_valid_actions(gc, mm.l2l_1away_via_land_bitset[src_land], gc.active_armies[src_land][army])
	//todo game_cache bitset for is_boat_available large, small
	for dst_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		add_if_boat_available(gc, to_action(dst_sea))
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
	for dst_land in (mm.l2l_2away_via_land_bitset[src_land]) {
		if (mm.l2l_2away_via_midland_bitset[src_land][dst_land] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
			continue
		}
		add_valid_action(gc, to_action(dst_land))
	}
	// check for moving from land to sea (two moves away)
	for dst_sea in (mm.l2s_2away_via_land_bitset[src_land]) {
		if (mm.l2s_2away_via_midland_bitset[src_land][dst_sea] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
			continue
		}
		add_if_boat_available(gc, to_action(dst_sea))
	}
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
	gc.active_armies[src_land][Armies_Moved[army]] += gc.active_armies[src_land][army]
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
