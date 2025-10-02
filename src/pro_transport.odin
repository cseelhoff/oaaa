#+feature global-context
package oaaa

/*
Pro AI Transport Planning Utilities

This file implements the high-level transport planning layer for amphibious assaults.
Based on TripleA's ProTransportUtils.java and ProMoveUtils.calculateAmphibRoutes().

Key Responsibilities:
- Find available transports for assault operations
- Select optimal units to load based on attack value and transport cost
- Plan multi-step transport movements (load -> move -> unload)
- Validate transport safety and path feasibility
- Execute transport state transitions

Architecture:
- Uses OAAA's existing transport.odin state machine for low-level operations
- Integrates with pro_combat_move.odin for attack planning
- Leverages map graph data for pathfinding and reach analysis
*/

import "core:fmt"
import "core:slice"
import sa "core:container/small_array"

// Transport_Plan represents a complete amphibious assault plan
Transport_Plan :: struct {
	transport_sea:     Sea_ID,              // Where transport starts
	target_land:       Land_ID,             // Where to unload
	unload_sea:        Sea_ID,              // Sea zone adjacent to target
	units_to_load:     [dynamic]Unit_Load_Info,  // Units to load
	move_path:         [dynamic]Sea_ID,     // Transport movement path
	total_moves_needed: int,                // Total moves required
	is_feasible:       bool,                // Can this plan be executed?
}

// Unit_Load_Info tracks units to load onto transports
Unit_Load_Info :: struct {
	unit_type:       Idle_Army,
	from_territory:  Land_ID,
	transport_cost:  int,      // 2 for infantry, 3 for artillery/tank
	attack_power:    f64,      // For prioritization
}

// Transport_Option describes an available transport
Transport_Option :: struct {
	sea_location:    Sea_ID,
	transport_state: Idle_Ship,  // Or Active_Ship for loaded transports
	remaining_capacity: int,      // Space left (0-5)
	moves_available: int,         // 0, 1, or 2 moves
}

// Find all transports that could potentially reach a target
find_transports_for_target :: proc(
	gc: ^Game_Cache,
	target_land: Land_ID,
	pro_data: ^Pro_Data,
) -> [dynamic]Transport_Option {
	/*
	Algorithm (from ProMoveUtils.calculateAmphibRoutes):
	1. Identify all sea zones adjacent to target land
	2. For each adjacent sea, find transports that can reach it
	3. Check 0-move (already there), 1-move, and 2-move reach
	4. Validate path safety (no enemy blockades without escort)
	5. Calculate remaining capacity for each transport
	*/
	
	options := make([dynamic]Transport_Option)
	
	// Get adjacent seas to target
	adjacent_seas := sa.slice(&mm.l2s_1away_via_land[target_land])
	if len(adjacent_seas) == 0 {
		return options // Not coastal
	}
	
	// Check all sea zones for transports
	for source_sea in Sea_ID {
		// Check each adjacent sea to see if transport can reach it
		for target_sea in adjacent_seas {
			// 0-move reach: transports already in target sea
			if source_sea == target_sea {
				add_transports_at_sea(&options, gc, source_sea, 0)
				continue
			}
			
			// 1-move reach: transports one sea zone away
			if target_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][source_sea] {
				if can_transport_safely_move_to(gc, source_sea, target_sea) {
					add_transports_at_sea(&options, gc, source_sea, 1)
				}
				continue
			}
			
			// 2-move reach: transports two sea zones away
			if target_sea in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][source_sea] {
				if can_transport_safely_move_2_spaces(gc, source_sea, target_sea) {
					add_transports_at_sea(&options, gc, source_sea, 2)
				}
			}
		}
	}
	
	return options
}

// Add transports at a specific sea zone to options list
add_transports_at_sea :: proc(
	options: ^[dynamic]Transport_Option,
	gc: ^Game_Cache,
	sea: Sea_ID,
	moves_needed: int,
) {
	/*
	Transport Capacity Rules (from transport.odin):
	- Total capacity: 5 spaces
	- Infantry: 2 spaces
	- Artillery/Tank: 3 spaces
	
	Idle Transport States:
	- TRANS_EMPTY: 5 spaces available
	- TRANS_1I: 3 spaces available (5 - 2)
	- TRANS_1A/TRANS_1T: 2 spaces available (5 - 3)
	- TRANS_2I: 1 space available (5 - 4)
	- TRANS_1I_1A/TRANS_1I_1T: 0 spaces available (full)
	*/
	
	// Check idle transports
	for transport_type in Idle_Transports {
		count := gc.idle_ships[sea][gc.cur_player][transport_type]
		if count == 0 do continue
		
		capacity := get_transport_remaining_capacity(transport_type)
		moves_available := 2 - moves_needed  // Transports have 2 moves total
		
		// Add one option per transport (could be optimized)
		for i in 0..<count {
			option := Transport_Option{
				sea_location = sea,
				transport_state = transport_type,
				remaining_capacity = capacity,
				moves_available = moves_available,
			}
			append(options, option)
		}
	}
	
	// TODO: Check active transports (moving transports with moves remaining)
	// For now, focus on idle transports for simplicity
}

// Calculate remaining capacity for a transport state
get_transport_remaining_capacity :: proc(transport_state: Idle_Ship) -> int {
	#partial switch transport_state {
	case .TRANS_EMPTY:
		return 5  // Empty, full capacity
	case .TRANS_1I:
		return 3  // 1 infantry loaded (2 spaces used)
	case .TRANS_1A, .TRANS_1T:
		return 2  // 1 artillery or tank (3 spaces used)
	case .TRANS_2I:
		return 1  // 2 infantry (4 spaces used)
	case .TRANS_1I_1A, .TRANS_1I_1T:
		return 0  // Full (5 spaces used)
	case:
		return 0  // Non-transport or unknown
	}
}

// Find loadable units near a sea zone
find_loadable_units_near_sea :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	max_distance: int,
) -> [dynamic]Unit_Load_Info {
	/*
	Algorithm (from ProTransportUtils.getUnitsToTransportFromTerritories):
	1. Find all coastal territories adjacent to sea zone
	2. For each territory, check if we own it
	3. Collect all transportable land units (infantry, artillery, tanks)
	4. Calculate attack value for each unit type
	5. Sort by priority (attack value / transport cost)
	*/
	
	units := make([dynamic]Unit_Load_Info)
	
	// Get lands adjacent to this sea
	adjacent_lands := sa.slice(&mm.s2l_1away_via_sea[sea])
	
	for land in adjacent_lands {
		// Must be friendly or allied territory
		if gc.owner[land] != gc.cur_player {
			if mm.team[gc.owner[land]] != mm.team[gc.cur_player] {
				continue  // Not friendly
			}
		}
		
		// Check for idle infantry
		inf_count := gc.idle_armies[land][gc.cur_player][.INF]
		for i in 0..<inf_count {
			info := Unit_Load_Info{
				unit_type = .INF,
				from_territory = land,
				transport_cost = 2,
				attack_power = 1.0,  // Infantry attack = 1
			}
			append(&units, info)
		}
		
		// Check for idle artillery
		arty_count := gc.idle_armies[land][gc.cur_player][.ARTY]
		for i in 0..<arty_count {
			info := Unit_Load_Info{
				unit_type = .ARTY,
				from_territory = land,
				transport_cost = 3,
				attack_power = 2.0,  // Artillery attack = 2
			}
			append(&units, info)
		}
		
		// Check for idle tanks
		tank_count := gc.idle_armies[land][gc.cur_player][.TANK]
		for i in 0..<tank_count {
			info := Unit_Load_Info{
				unit_type = .TANK,
				from_territory = land,
				transport_cost = 3,
				attack_power = 3.0,  // Tank attack = 3
			}
			append(&units, info)
		}
	}
	
	return units
}

// Select best units to load on a transport
select_units_to_load :: proc(
	available_units: ^[dynamic]Unit_Load_Info,
	transport_capacity: int,
	prioritize_by_attack: bool,
) -> [dynamic]Unit_Load_Info {
	/*
	Algorithm (from ProTransportUtils.selectUnitsToTransportFromList):
	1. Sort units by priority:
	   - If prioritize_by_attack: attack_power / transport_cost (efficiency)
	   - Otherwise: by transport_cost, then attack_power
	2. Greedily select units that fit in capacity
	3. Try to fill remaining space by replacing last unit with better fit
	4. Return selected units
	*/
	
	selected := make([dynamic]Unit_Load_Info)
	
	if len(available_units) == 0 {
		return selected
	}
	
	// Sort units by priority
	if prioritize_by_attack {
		// Sort by attack efficiency (attack / cost)
		slice.sort_by(available_units[:], proc(a, b: Unit_Load_Info) -> bool {
			eff_a := a.attack_power / f64(a.transport_cost)
			eff_b := b.attack_power / f64(b.transport_cost)
			return eff_a > eff_b  // Higher efficiency first
		})
	} else {
		// Sort by transport cost, then attack power
		slice.sort_by(available_units[:], proc(a, b: Unit_Load_Info) -> bool {
			if a.transport_cost != b.transport_cost {
				return a.transport_cost < b.transport_cost  // Smaller cost first
			}
			return a.attack_power > b.attack_power  // Higher attack first
		})
	}
	
	// Greedily select units
	capacity_used := 0
	for unit in available_units {
		if unit.transport_cost <= (transport_capacity - capacity_used) {
			append(&selected, unit)
			capacity_used += unit.transport_cost
			if capacity_used >= transport_capacity {
				break
			}
		}
	}
	
	// Try to optimize by replacing last unit
	if len(selected) > 0 && capacity_used < transport_capacity {
		last_unit := selected[len(selected) - 1]
		last_cost := last_unit.transport_cost
		
		// Try to find a better unit that fits in the extra space
		for unit in available_units {
			// Skip units already selected
			is_selected := false
			for sel in selected {
				if sel.unit_type == unit.unit_type && sel.from_territory == unit.from_territory {
					is_selected = true
					break
				}
			}
			if is_selected do continue
			
			// Check if this unit is better and fits
			new_capacity := capacity_used - last_cost + unit.transport_cost
			if new_capacity <= transport_capacity && unit.attack_power > last_unit.attack_power {
				// Replace last unit with this better unit
				pop(&selected)
				append(&selected, unit)
				break
			}
		}
	}
	
	return selected
}

// Create a complete transport plan for an amphibious assault
create_transport_plan :: proc(
	gc: ^Game_Cache,
	target_land: Land_ID,
	transport: Transport_Option,
	pro_data: ^Pro_Data,
) -> Maybe(Transport_Plan) {
	/*
	Algorithm (from ProMoveUtils.calculateAmphibRoutes):
	1. Find units to load from territories near transport
	2. Select best units that fit in transport capacity
	3. Calculate movement path from transport to target
	4. Validate entire plan is feasible
	5. Return complete plan or nil if not feasible
	*/
	
	// Find adjacent sea to target where we'll unload
	adjacent_seas := sa.slice(&mm.l2s_1away_via_land[target_land])
	if len(adjacent_seas) == 0 {
		return nil  // Not coastal
	}
	
	// Find closest adjacent sea to transport location
	unload_sea := find_closest_unload_sea(gc, transport.sea_location, adjacent_seas[:])
	if unload_sea == nil {
		return nil  // No reachable unload point
	}
	
	// Find units to load
	available_units := find_loadable_units_near_sea(gc, transport.sea_location, 1)
	defer delete(available_units)
	
	if len(available_units) == 0 {
		return nil  // No units to load
	}
	
	// Select best units
	selected_units := select_units_to_load(&available_units, transport.remaining_capacity, true)
	
	if len(selected_units) == 0 {
		return nil  // Couldn't select any units
	}
	
	// Calculate movement path
	move_path := calculate_transport_path(gc, transport.sea_location, unload_sea.?)
	
	plan := Transport_Plan{
		transport_sea = transport.sea_location,
		target_land = target_land,
		unload_sea = unload_sea.?,
		units_to_load = selected_units,
		move_path = move_path,
		total_moves_needed = len(move_path),
		is_feasible = len(move_path) > 0 && len(move_path) <= transport.moves_available,
	}
	
	return plan
}

// Find closest unload sea from transport to target adjacent seas
find_closest_unload_sea :: proc(
	gc: ^Game_Cache,
	transport_sea: Sea_ID,
	adjacent_seas: []Sea_ID,
) -> Maybe(Sea_ID) {
	closest_sea: Maybe(Sea_ID) = nil
	min_distance := 999
	
	for sea in adjacent_seas {
		distance := int(mm.sea_distances[transmute(u8)gc.canals_open][transport_sea][sea])
		if distance < min_distance && distance <= 2 {  // Transport can move max 2
			min_distance = distance
			closest_sea = sea
		}
	}
	
	return closest_sea
}

// Calculate movement path for transport
calculate_transport_path :: proc(
	gc: ^Game_Cache,
	from_sea: Sea_ID,
	to_sea: Sea_ID,
) -> [dynamic]Sea_ID {
	/*
	Simple pathfinding for transport movement.
	For now, returns direct path if within 2 moves.
	TODO: Implement proper A* pathfinding for complex scenarios.
	*/
	
	path := make([dynamic]Sea_ID)
	
	if from_sea == to_sea {
		// Already there
		return path
	}
	
	// Check 1-move distance
	if to_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][from_sea] {
		append(&path, to_sea)
		return path
	}
	
	// Check 2-move distance
	if to_sea in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][from_sea] {
		// Find intermediate sea
		mid_seas := &mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][from_sea]
		for mid_sea in sa.slice(&mid_seas[to_sea]) {
			// Check if path is safe
			if gc.enemy_blockade_total[mid_sea] == 0 {
				append(&path, mid_sea)
				append(&path, to_sea)
				return path
			}
		}
	}
	
	// No valid path found
	clear(&path)
	return path
}

// Calculate total attack value of units in a plan
calculate_plan_attack_value :: proc(plan: ^Transport_Plan) -> f64 {
	total := 0.0
	for unit in plan.units_to_load {
		total += unit.attack_power
	}
	return total
}

// Cleanup transport plan
transport_plan_destroy :: proc(plan: ^Transport_Plan) {
	delete(plan.units_to_load)
	delete(plan.move_path)
}

// ===== Transport Safety Validation Functions =====

// Helper: Check if transport can safely move to target sea (1 move)
can_transport_safely_move_to :: proc(gc: ^Game_Cache, from_sea: Sea_ID, to_sea: Sea_ID) -> bool {
// Check if path is blocked by enemy destroyers or blockade
canal_state := transmute(u8)gc.canals_open

// Check if seas are actually adjacent
if !(to_sea in mm.s2s_1away_via_sea[canal_state][from_sea]) {
return false
}

// Check if destination has enemy blockade (would sink transport)
if gc.enemy_blockade_total[to_sea] > 0 {
return false // Too dangerous
}

return true
}

// Helper: Check if transport can safely move 2 spaces
can_transport_safely_move_2_spaces :: proc(gc: ^Game_Cache, from_sea: Sea_ID, to_sea: Sea_ID) -> bool {
canal_state := transmute(u8)gc.canals_open

// Check if seas are in 2-move range
if !(to_sea in mm.s2s_2away_via_sea[canal_state][from_sea]) {
return false
}

// Check all intermediate seas for enemy blockades/destroyers
for mid_sea in sa.slice(&mm.s2s_2away_via_midseas[canal_state][from_sea][to_sea]) {
if gc.enemy_destroyer_total[mid_sea] > 0 {
return false // Blocked by enemy destroyer
}
if gc.enemy_blockade_total[mid_sea] > 0 {
return false // Blocked by enemy fleet
}
}

// Check destination
if gc.enemy_blockade_total[to_sea] > 0 {
return false
}

return true
}
