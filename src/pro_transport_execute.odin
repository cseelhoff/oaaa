#+feature global-context
package oaaa

/*
Pro AI Transport Execution Layer

This file implements the execution layer for amphibious assaults, translating
high-level Transport_Plan structures into actual game state modifications.

Based on OAAA's execution patterns from:
- army.odin: move_single_army_land() - state transition pattern
- transport.odin: Trans_After_Loading state machine, unload_unit()

Key Responsibilities:
- Load units onto transports (modify idle_armies, active_ships)
- Move loaded transports through sea zones (modify active_ships locations)
- Unload units onto target territories (create active_armies)
- Maintain all parallel tracking structures (idle counts, team counts)

Architecture:
- Follows OAAA's counter update pattern (active + idle + team)
- Uses transport.odin state machines (Trans_After_Loading, Trans_After_Move_Used)
- Integrates with combat system (mark_land_for_combat_resolution)
*/

import "core:fmt"
import sa "core:container/small_array"

// Execute a complete transport plan (load -> move -> unload)
execute_transport_plan :: proc(
	gc: ^Game_Cache,
	plan: ^Transport_Plan,
) -> bool {
	/*
	Full execution sequence from Java ProMoveUtils.calculateAmphibRoutes():
	1. Load units from coastal territories onto transport
	2. Move transport through planned sea zones
	3. Unload units onto target territory
	4. Handle combat/conquest at target
	
	OAAA Pattern (from army.odin line 273-287):
	- Update active counts (current state)
	- Update idle counts (base type)
	- Update team counts (alliance totals)
	*/
	
	if !plan.is_feasible {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Plan not feasible, skipping execution")
		}
		return false
	}
	
	// Step 1: Load units onto transport
	if !execute_transport_loading(gc, plan) {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Failed to load units")
		}
		return false
	}
	
	// Step 2: Move transport to unload position
	if !execute_transport_movement(gc, plan) {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Failed to move transport")
		}
		return false
	}
	
	// Step 3: Unload units onto target
	if !execute_transport_unloading(gc, plan) {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Failed to unload units")
		}
		return false
	}
	
	return true
}

// Load units onto a transport
execute_transport_loading :: proc(
	gc: ^Game_Cache,
	plan: ^Transport_Plan,
) -> bool {
	/*
	Loading Algorithm (from transport.odin Trans_After_Loading state machine):
	
	1. Start with transport in idle state (e.g., TRANS_EMPTY)
	2. For each unit to load:
	   - Look up new transport state: Trans_After_Loading[unit_type][current_state]
	   - Update active_ships[sea][new_state]
	   - Update idle_ships[sea][player][new_idle_state]
	3. Remove units from source territories:
	   - Decrement idle_armies[land][player][unit_type]
	   - Decrement team_land_units[land][team]
	
	OAAA Pattern (from army.odin lines 210-221, transport loading):
	- Check transport availability via Trans_Allowed_By_Army_Size
	- Use Trans_After_Loading for state transition
	- Update both ship and army counters
	*/
	
	// Find the transport to load
	transport_sea := plan.transport_sea
	
	// Determine initial transport state (assume empty for simplicity)
	// TODO: Handle partially loaded transports
	current_transport_state: Active_Ship = .TRANS_EMPTY_UNMOVED
	
	// Check if transport exists
	if gc.idle_ships[transport_sea][gc.cur_player][.TRANS_EMPTY] == 0 {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] No empty transport available at", transport_sea)
		}
		return false
	}
	
	// Remove empty transport from idle pool
	gc.idle_ships[transport_sea][gc.cur_player][.TRANS_EMPTY] -= 1
	
	// Add to active pool with UNMOVED state
	gc.active_ships[transport_sea][current_transport_state] += 1
	
	// Load each unit
	for unit_info in plan.units_to_load {
		// Get next transport state after loading this unit
		next_transport_state := Trans_After_Loading[unit_info.unit_type][current_transport_state]
		
		// Validate state transition is legal
		if !is_valid_transport_state(next_transport_state) {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-TRANSPORT] Invalid loading: %v onto %v", 
					unit_info.unit_type, current_transport_state)
			}
			return false
		}
		
		// Remove unit from source territory
		src_land := unit_info.from_territory
		if gc.idle_armies[src_land][gc.cur_player][unit_info.unit_type] == 0 {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-TRANSPORT] No %v available at %v", 
					unit_info.unit_type, src_land)
			}
			return false
		}
		
		gc.idle_armies[src_land][gc.cur_player][unit_info.unit_type] -= 1
		gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
		
		// Update transport state
		gc.active_ships[transport_sea][current_transport_state] -= 1
		gc.active_ships[transport_sea][next_transport_state] += 1
		
		current_transport_state = next_transport_state
		
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-TRANSPORT] Loaded %v from %v onto transport (now %v)", 
				unit_info.unit_type, src_land, current_transport_state)
		}
	}
	
	return true
}

// Move transport through sea zones
execute_transport_movement :: proc(
	gc: ^Game_Cache,
	plan: ^Transport_Plan,
) -> bool {
	/*
	Movement Algorithm (from transport.odin stage_next_ship_in_sea):
	
	1. Calculate sea distance traveled
	2. Look up new state: Trans_After_Move_Used[current_state][distance]
	3. Update active_ships at source (decrement)
	4. Update active_ships at destination (increment)
	5. Update idle_ships accordingly
	
	Movement Validation (from transport.odin add_valid_transport_moves):
	- Check enemy units need escort: team_sea_units[enemy] > 0
	- Check escort available: allied_sea_combatants_total[sea] > 0
	- Check blockades on 2-move path: enemy_blockade_total[mid_sea] == 0
	*/
	
	if len(plan.move_path) == 0 {
		// Already at destination
		return true
	}
	
	current_sea := plan.transport_sea
	
	// Find current transport state
	// After loading, transport should be in a loaded state with UNMOVED suffix
	// We need to find which loaded state it's in
	current_state, found := find_loaded_transport_state(gc, current_sea, plan)
	if !found {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Could not find loaded transport")
		}
		return false
	}
	
	// Move through each sea zone in path
	for next_sea in plan.move_path {
		// Calculate distance (should be 1 for adjacent moves)
		distance := int(mm.sea_distances[transmute(u8)gc.canals_open][current_sea][next_sea])
		
		if distance > MAX_TRANSPORT_MOVES {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-TRANSPORT] Invalid move distance: %d", distance)
			}
			return false
		}
		
		// Get next transport state after movement
		next_state := Trans_After_Move_Used[current_state][distance]
		
		if !is_valid_transport_state(next_state) {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-TRANSPORT] Invalid movement: %v by %d spaces", 
					current_state, distance)
			}
			return false
		}
		
		// Move transport from current sea to next sea
		gc.active_ships[current_sea][current_state] -= 1
		gc.active_ships[next_sea][next_state] += 1
		
		// Update idle counts
		gc.idle_ships[current_sea][gc.cur_player][Active_Ship_To_Idle[current_state]] -= 1
		gc.idle_ships[next_sea][gc.cur_player][Active_Ship_To_Idle[next_state]] += 1
		
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-TRANSPORT] Moved transport from %v to %v (state %v -> %v)", 
				current_sea, next_sea, current_state, next_state)
		}
		
		current_sea = next_sea
		current_state = next_state
	}
	
	return true
}

// Unload units onto target territory
execute_transport_unloading :: proc(
	gc: ^Game_Cache,
	plan: ^Transport_Plan,
) -> bool {
	/*
	Unloading Algorithm (from transport.odin unload_unit lines 424-433):
	
	1. Get army state from Transport_Unload_Unit[transport_state]
	2. Create active_armies[land][army_state] (with 0 moves)
	3. Update idle_armies[land][player][army_type]
	4. Update team_land_units[land][team]
	5. Update max_bombards[land] (for naval support)
	6. Check for combat: mark_land_for_combat_resolution()
	7. If no combat, check for conquest: check_and_process_land_conquest()
	
	Key: Units unload with _0_MOVES state (game rule, not optimization)
	*/
	
	unload_sea := plan.unload_sea
	target_land := plan.target_land
	
	// Find transport state at unload position
	transport_state, found := find_loaded_transport_at_sea(gc, unload_sea, plan)
	if !found {
		when ODIN_DEBUG {
			fmt.eprintln("[PRO-TRANSPORT] Could not find transport at unload position")
		}
		return false
	}
	
	// Transport must have 0 moves to unload (game rule)
	if !is_transport_ready_to_unload(transport_state) {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-TRANSPORT] Transport %v not ready to unload (needs 0 moves)", 
				transport_state)
		}
		return false
	}
	
	// Unload each unit (one at a time, following transport.odin pattern)
	for unit_info in plan.units_to_load {
		// Determine which transport state corresponds to this unit
		// For simplicity, unload all units from the transport
		
		// Get army state for unloaded unit
		army_state := get_army_state_for_unit(unit_info.unit_type)
		
		// Add unit to target territory (with 0 moves)
		gc.active_armies[target_land][army_state] += 1
		gc.idle_armies[target_land][gc.cur_player][unit_info.unit_type] += 1
		gc.team_land_units[target_land][mm.team[gc.cur_player]] += 1
		
		// Increment bombardment support counter
		gc.max_bombards[target_land] += 1
		
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-TRANSPORT] Unloaded %v onto %v (state %v)", 
				unit_info.unit_type, target_land, army_state)
		}
	}
	
	// Update transport state (now empty with 0 moves)
	next_transport_state := get_empty_transport_after_unload(transport_state)
	gc.active_ships[unload_sea][transport_state] -= 1
	gc.active_ships[unload_sea][next_transport_state] += 1
	gc.idle_ships[unload_sea][gc.cur_player][Active_Ship_To_Idle[transport_state]] -= 1
	gc.idle_ships[unload_sea][gc.cur_player][Active_Ship_To_Idle[next_transport_state]] += 1
	
	// Handle combat or conquest at target
	if !mark_land_for_combat_resolution(gc, target_land) {
		check_and_process_land_conquest(gc, target_land)
	}
	
	return true
}

// Helper: Find loaded transport state after loading units
find_loaded_transport_state :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	plan: ^Transport_Plan,
) -> (Active_Ship, bool) {
	/*
	After loading, transport should be in one of these states:
	- TRANS_1I_UNMOVED (1 infantry)
	- TRANS_1A_UNMOVED (1 artillery)
	- TRANS_1T_UNMOVED (1 tank)
	- TRANS_2I_UNMOVED (2 infantry)
	- TRANS_1I_1A_UNMOVED (1 inf + 1 arty)
	- TRANS_1I_1T_UNMOVED (1 inf + 1 tank)
	*/
	
	// Try to match loaded state based on units
	// Simplified: check each possible loaded state
	possible_states := [?]Active_Ship{
		.TRANS_1I_UNMOVED,
		.TRANS_1A_UNMOVED,
		.TRANS_1T_UNMOVED,
		.TRANS_2I_2_MOVES,
		.TRANS_1I_1A_2_MOVES,
		.TRANS_1I_1T_2_MOVES,
	}
	
	for state in possible_states {
		if gc.active_ships[sea][state] > 0 {
			return state, true
		}
	}
	
	return .TRANS_EMPTY_UNMOVED, false
}

// Helper: Find loaded transport at specific sea
find_loaded_transport_at_sea :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	plan: ^Transport_Plan,
) -> (Active_Ship, bool) {
	/*
	At unload position, transport should have 0 moves:
	- TRANS_1I_0_MOVES
	- TRANS_1A_0_MOVES
	- TRANS_1T_0_MOVES
	- TRANS_2I_0_MOVES
	- TRANS_1I_1A_0_MOVES
	- TRANS_1I_1T_0_MOVES
	*/
	
	possible_states := [?]Active_Ship{
		.TRANS_1I_0_MOVES,
		.TRANS_1A_0_MOVES,
		.TRANS_1T_0_MOVES,
		.TRANS_2I_0_MOVES,
		.TRANS_1I_1A_0_MOVES,
		.TRANS_1I_1T_0_MOVES,
	}
	
	for state in possible_states {
		if gc.active_ships[sea][state] > 0 {
			return state, true
		}
	}
	
	return .TRANS_EMPTY_0_MOVES, false
}

// Helper: Check if transport state is valid (not a combat ship)
is_valid_transport_state :: proc(state: Active_Ship) -> bool {
	#partial switch state {
	case .SUB_2_MOVES, .SUB_0_MOVES,
	     .DESTROYER_2_MOVES, .DESTROYER_0_MOVES,
	     .CARRIER_2_MOVES, .CARRIER_0_MOVES,
	     .CRUISER_2_MOVES, .CRUISER_0_MOVES, .CRUISER_BOMBARDED,
	     .BATTLESHIP_2_MOVES, .BATTLESHIP_0_MOVES, .BATTLESHIP_BOMBARDED,
	     .BS_DAMAGED_2_MOVES, .BS_DAMAGED_0_MOVES, .BS_DAMAGED_BOMBARDED:
		return false
	case:
		return true
	}
}

// Helper: Check if transport is ready to unload (has 0 moves)
is_transport_ready_to_unload :: proc(transport_state: Active_Ship) -> bool {
	#partial switch transport_state {
	case .TRANS_1I_0_MOVES, .TRANS_1A_0_MOVES, .TRANS_1T_0_MOVES,
	     .TRANS_2I_0_MOVES, .TRANS_1I_1A_0_MOVES, .TRANS_1I_1T_0_MOVES:
		return true
	case:
		return false
	}
}

// Helper: Get army state for unloaded unit (always 0 moves)
get_army_state_for_unit :: proc(unit_type: Idle_Army) -> Active_Army {
	switch unit_type {
	case .INF:
		return .INF_0_MOVES
	case .ARTY:
		return .ARTY_0_MOVES
	case .TANK:
		return .TANK_0_MOVES
	case .AAGUN:
		return .AAGUN_0_MOVES
	}
	return .INF_0_MOVES  // Fallback
}

// Helper: Get empty transport state after unloading
get_empty_transport_after_unload :: proc(loaded_state: Active_Ship) -> Active_Ship {
	// All transports become TRANS_EMPTY_0_MOVES after unloading
	// (Following Trans_After_Unload pattern from transport.odin)
	return .TRANS_EMPTY_0_MOVES
}

// Execute multiple transport plans (for coordinated amphibious assaults)
execute_transport_plans :: proc(
	gc: ^Game_Cache,
	plans: ^[dynamic]Transport_Plan,
) -> int {
	/*
	Execute multiple transport plans in sequence.
	Used when attacking a territory from multiple directions.
	Returns number of successfully executed plans.
	*/
	
	successful := 0
	for &plan in plans {
		if execute_transport_plan(gc, &plan) {
			successful += 1
		}
	}
	
	return successful
}
