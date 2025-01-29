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
	.INF   = Cost_Buy[.BUY_INF],
	.ARTY  = Cost_Buy[.BUY_ARTY],
	.TANK  = Cost_Buy[.BUY_TANK],
	.AAGUN = Cost_Buy[.BUY_AAGUN],
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
        for src_land in Land_ID {
            if gc.active_armies[src_land][army] == 0 do continue
            gc.valid_actions = {to_action(src_land)}
            add_valid_army_moves_1(gc, src_land, army)
            if army == .TANK_2_MOVES do add_valid_army_moves_2(gc, src_land, army)
            for gc.active_armies[src_land][army] > 0 {
                move_next_army_in_land(gc, army, src_land) or_return
            }
        }
        if gc.clear_history_needed do clear_move_history(gc)
    }
    return true
}

move_next_army_in_land :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
) -> (
	ok: bool,
) {
	dst_air := get_move_input(gc, fmt.tprint(army), to_air(src_land)) or_return
    
    // Handle sea movement (transport loading) first
    if ~is_land(dst_air) {
        dst_sea := to_sea(dst_air)
		load_available_transport(gc, army, src_land, dst_sea, gc.cur_player)
		if ~is_boat_available(gc, src_land, dst_sea, army) {
			gc.valid_actions -= {to_action(dst_sea)}
		}
        return true
    }
    
    // Handle land movement
    dst_land := to_land(dst_air)
    if skip_army(gc, src_land, dst_land, army) do return true
    
    next_state := get_next_army_state(gc, src_land, dst_land, army)
    move_single_army_land(gc, src_land, dst_land, army, next_state)
    return true
}

blitz_checks :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
	army: Active_Army,
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
	if !flag_for_land_enemy_combat(gc, dst_land) &&
	   check_for_conquer(gc, dst_land) &&
	   army == .TANK_2_MOVES &&
	   mm.land_distances[src_land][dst_land] == 1 &&
	   gc.factory_prod[dst_land] == 0 {
		return .TANK_1_MOVES //blitz!
	}
	return Armies_Moved[army]
}

move_single_army_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
	src_unit: Active_Army,
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
	gc.active_armies[dst_land][dst_unit] += 1
	gc.idle_armies[dst_land][gc.cur_player][Active_Army_To_Idle[dst_unit]] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_armies[src_land][src_unit] -= 1
	gc.idle_armies[src_land][gc.cur_player][Active_Army_To_Idle[src_unit]] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
}

is_boat_available :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	army: Active_Army,
) -> bool {
	idle_ships := &gc.idle_ships[dst_sea][gc.cur_player]
	for transport in Idle_Ship_Space[Army_Size[army]] {
		if idle_ships[transport] > 0 {
			return true
		}
	}
	return false
}

add_if_boat_available :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	army: Active_Army,
) {
	if to_air(dst_sea) not_in gc.rejected_moves_from[to_air(src_land)] {
		if is_boat_available(gc, src_land, dst_sea, army) {
			gc.valid_actions += {to_action(dst_sea)}
		}
	}
}

are_midlands_blocked :: proc(gc: ^Game_Cache, mid_lands: ^Mid_Lands) -> bool {
	for mid_land in sa.slice(mid_lands) {
		if mid_land in (gc.has_enemy_factory | gc.has_enemy_units) do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	gc.valid_actions += to_action_bitset(
		mm.l2l_1away_via_land_bitset[src_land] & ~to_land_bitset(gc.rejected_moves_from[to_air(src_land)]),
	)
	//todo game_cache bitset for is_boat_available large, small
	for dst_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		add_if_boat_available(gc, src_land, dst_sea, army)
	}
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
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
	for dst_land in (mm.l2l_2away_via_land_bitset[src_land] & to_land_bitset(~gc.rejected_moves_from[to_air(src_land)])) {
		if (mm.l2l_2away_via_midland_bitset[src_land][dst_land] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
			continue
		}
		gc.valid_actions += {to_action(dst_land)}
	}
	// check for moving from land to sea (two moves away)
	for dst_sea in (mm.l2s_2away_via_land_bitset[src_land] & to_sea_bitset(~gc.rejected_moves_from[to_air(src_land)])) {
		if (mm.l2s_2away_via_midland_bitset[src_land][dst_sea] & ~gc.has_enemy_factory & ~gc.has_enemy_units) == {} {
			continue
		}
		add_if_boat_available(gc, src_land, dst_sea, army)
	}
}

skip_army :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
	army: Active_Army,
) -> (
	ok: bool,
) {
	if src_land != dst_land do return false
	gc.active_armies[src_land][Armies_Moved[army]] += gc.active_armies[src_land][army]
	gc.active_armies[src_land][army] = 0
	return true
}

is_sea_destination :: proc(dst_air: Air_ID) -> bool {
    return int(dst_air) >= len(Land_ID)
}

attempt_transport_loading :: proc(
    gc: ^Game_Cache,
    army: Active_Army,
    src_land: Land_ID,
    dst_sea: Sea_ID,
) {
}

get_next_army_state :: proc(
    gc: ^Game_Cache,
    src_land: Land_ID,
    dst_land: Land_ID,
    army: Active_Army,
) -> Active_Army {
    return blitz_checks(gc, src_land, dst_land, army)
}

load_available_transport :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	player: Player_ID,
) {
	for transport in Active_Ship_Space[Army_Size[army]] {
		if gc.active_ships[dst_sea][transport] > 0 {
			load_specific_transport(gc, src_land, dst_sea, transport, army, player)
			return
		}
	}
	fmt.eprintln("Error: No large transport available to load")
}

load_specific_transport :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	ship: Active_Ship,
	army: Active_Army,
	player: Player_ID,
) {
    /*
    AI NOTE: Transport Loading System
    
    This procedure handles the state transitions when loading an army onto a transport:
    
    1. Transport State Transition:
       - Use Transport_Load_Unit[army_type][current_state] to get new transport state
       - Example: [.INF][.TRANS_EMPTY] -> .TRANS_1I
       - Handles all valid combinations within 5-space capacity
    
    2. Game State Updates:
       a) Create new transport in loaded state:
          - Increment active_ships[new_state]
          - Increment idle_ships[new_state]
       
       b) Remove army from source land:
          - Decrement active_armies
          - Decrement idle_armies
          - Decrement team_land_units
       
       c) Remove old empty transport:
          - Decrement active_ships[old_state]
          - Decrement idle_ships[old_state]
    */
	idle_army := Active_Army_To_Idle[army]
	new_ship := Transport_Load_Unit[idle_army][ship]
	gc.active_ships[dst_sea][new_ship] += 1
	gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[new_ship]] += 1
	gc.active_armies[src_land][army] -= 1
	gc.idle_armies[src_land][player][idle_army] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	gc.active_ships[dst_sea][ship] -= 1
	gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[ship]] -= 1
}
