#+feature global-context
package oaaa

/*
Pro AI Movement Execution Layer

This file implements the execution layer for Pro AI combat and non-combat moves,
translating high-level movement plans into actual game state modifications.

Based on OAAA's execution patterns from:
- army.odin: move_single_army_land() - land unit movement
- fighter.odin, bomber.odin: Air unit movement patterns
- ship.odin: Naval unit movement patterns

Key Responsibilities:
- Execute land unit movements (infantry, artillery, tanks)
- Execute air unit movements (fighters, bombers)
- Execute naval unit movements (ships)
- Track which units have moved (prevent double-moves)
- Maintain all parallel tracking structures (active, idle, team counts)
- Integrate with transport execution for amphibious assaults

Architecture:
- Follows OAAA's counter update pattern (active + idle + team)
- Uses existing movement validation from map graph
- Coordinates with pro_transport_execute.odin for amphibious assaults
*/

import "core:fmt"
import sa "core:container/small_array"

// Moved_Units tracks which units have already moved this phase
Moved_Units :: struct {
	land_units: map[Land_ID]map[Idle_Army]u8,  // land -> unit_type -> count
	air_units: map[Air_ID]map[Idle_Plane]u8,   // air -> plane_type -> count
	sea_units: map[Sea_ID]map[Idle_Ship]u8,    // sea -> ship_type -> count
}

// Initialize moved units tracker
init_moved_units :: proc() -> Moved_Units {
	return Moved_Units{
		land_units = make(map[Land_ID]map[Idle_Army]u8),
		air_units = make(map[Air_ID]map[Idle_Plane]u8),
		sea_units = make(map[Sea_ID]map[Idle_Ship]u8),
	}
}

// Cleanup moved units tracker
cleanup_moved_units :: proc(moved: ^Moved_Units) {
	// Clean up nested maps
	for _, unit_map in moved.land_units {
		delete(unit_map)
	}
	delete(moved.land_units)
	
	for _, plane_map in moved.air_units {
		delete(plane_map)
	}
	delete(moved.air_units)
	
	for _, ship_map in moved.sea_units {
		delete(ship_map)
	}
	delete(moved.sea_units)
}

// Execute land unit movement from src to dst
execute_land_move :: proc(
	gc: ^Game_Cache,
	src: Land_ID,
	dst: Land_ID,
	unit_type: Idle_Army,
	count: u8,
	moved: ^Moved_Units,
) -> bool {
	/*
	Land Movement Algorithm (from army.odin lines 273-287):
	
	1. Validate movement is legal:
	   - Check adjacency or 2-move path exists
	   - Check unit has not already moved
	   - Check sufficient units available
	
	2. Update game state:
	   - Decrement source: gc.idle_armies[src], gc.team_land_units[src]
	   - Increment destination: gc.idle_armies[dst], gc.team_land_units[dst]
	   - Also update gc.active_armies with movement state
	
	3. Track moved units to prevent double-moves
	*/
	
	// Validate unit availability
	available := gc.idle_armies[src][gc.cur_player][unit_type]
	
	// Check how many already moved
	already_moved: u8 = 0
	if src in moved.land_units {
		if unit_type in moved.land_units[src] {
			already_moved = moved.land_units[src][unit_type]
		}
	}
	
	if available - already_moved < count {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-MOVE] Not enough %v at %v (available: %d, moved: %d, need: %d)",
				unit_type, src, available, already_moved, count)
		}
		return false
	}
	
	// Validate movement is legal using map graph
	max_moves := idle_army_to_max_moves(unit_type)
	if !can_land_units_move(gc, src, dst, max_moves) {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-MOVE] Invalid land move: %v cannot reach %v from %v (max_moves: %d)",
				unit_type, dst, src, max_moves)
		}
		return false
	}
	
	// Execute movement (following army.odin pattern)
	// Determine active army state based on distance
	active_state := get_active_army_state(unit_type, src, dst)
	
	// Update destination
	gc.active_armies[dst][active_state] += count
	gc.idle_armies[dst][gc.cur_player][unit_type] += count
	gc.team_land_units[dst][mm.team[gc.cur_player]] += count
	
	// Update source
	gc.idle_armies[src][gc.cur_player][unit_type] -= count
	gc.team_land_units[src][mm.team[gc.cur_player]] -= count
	
	// Track moved units
	if !(src in moved.land_units) {
		moved.land_units[src] = make(map[Idle_Army]u8)
	}
	unit_map := &moved.land_units[src]
	unit_map[unit_type] += count
	
	when ODIN_DEBUG {
		fmt.eprintfln("[PRO-MOVE] Moved %d %v from %v to %v (state: %v)",
			count, unit_type, src, dst, active_state)
	}
	
	return true
}

// Get maximum moves for idle army type
idle_army_to_max_moves :: proc(unit_type: Idle_Army) -> int {
	switch unit_type {
	case .INF, .ARTY, .AAGUN:
		return 1
	case .TANK:
		return 2
	}
	return 1
}

// Get active army state based on movement distance
get_active_army_state :: proc(unit_type: Idle_Army, src: Land_ID, dst: Land_ID) -> Active_Army {
	/*
	Movement States (from army.odin):
	- 2_MOVES: Unit has 2 moves remaining (just started turn)
	- 1_MOVES: Unit used 1 move
	- 0_MOVES: Unit used all moves
	
	Simplified: Assume combat moves use all movement (0_MOVES)
	In full implementation, would calculate actual distance
	*/
	
	switch unit_type {
	case .INF:
		return .INF_0_MOVES  // Infantry moves 1, assumes combat move
	case .ARTY:
		return .ARTY_0_MOVES
	case .TANK:
		// Tanks can move 2, check if adjacent or 2-away
		// For now, default to 0 moves (used all movement)
		return .TANK_0_MOVES
	case .AAGUN:
		return .AAGUN_0_MOVES
	}
	
	return .INF_0_MOVES  // Fallback
}

// Get maximum range for idle plane type
idle_plane_to_max_range :: proc(plane_type: Idle_Plane) -> int {
	switch plane_type {
	case .FIGHTER:
		return 4
	case .BOMBER:
		return 6
	}
	return 4
}

// Execute air unit movement
execute_air_move :: proc(
	gc: ^Game_Cache,
	src: Air_ID,
	dst: Air_ID,
	plane_type: Idle_Plane,
	count: u8,
	moved: ^Moved_Units,
	is_land_src: bool,  // true if source is land, false if sea
	is_land_dst: bool,  // true if destination is land, false if sea
) -> bool {
	/*
	Air Movement Algorithm (from fighter.odin, bomber.odin):
	
	Fighters: 4 movement range
	Bombers: 6 movement range
	
	Can move from/to:
	- Land territories
	- Sea zones (on carriers)
	
	Movement tracking:
	- gc.idle_land_planes[land][player][plane_type]
	- gc.idle_sea_planes[sea][player][plane_type]
	- gc.active_land_planes[land][active_plane_state]
	- gc.active_sea_planes[sea][active_plane_state]
	*/
	
	// Determine source and destination based on land/sea
	available: u8
	already_moved: u8 = 0
	
	if is_land_src {
		src_land := to_land(src)
		available = gc.idle_land_planes[src_land][gc.cur_player][plane_type]
		
		if src in moved.air_units {
			if plane_type in moved.air_units[src] {
				already_moved = moved.air_units[src][plane_type]
			}
		}
	} else {
		src_sea := to_sea(src)
		available = gc.idle_sea_planes[src_sea][gc.cur_player][plane_type]
		
		if src in moved.air_units {
			if plane_type in moved.air_units[src] {
				already_moved = moved.air_units[src][plane_type]
			}
		}
	}
	
	if available - already_moved < count {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-MOVE] Not enough %v at air %v (available: %d, moved: %d, need: %d)",
				plane_type, src, available, already_moved, count)
		}
		return false
	}
	
	// Validate range using map graph
	max_range := idle_plane_to_max_range(plane_type)
	if !can_air_reach(gc, src, dst, max_range) {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-MOVE] Invalid air move: %v cannot reach %v from %v (max_range: %d)",
				plane_type, dst, src, max_range)
		}
		return false
	}
	
	// Execute movement
	if is_land_src && is_land_dst {
		// Land to land
		src_land := to_land(src)
		dst_land := to_land(dst)
		
		gc.idle_land_planes[src_land][gc.cur_player][plane_type] -= count
		gc.idle_land_planes[dst_land][gc.cur_player][plane_type] += count
		
	} else if is_land_src && !is_land_dst {
		// Land to sea (landing on carrier)
		src_land := to_land(src)
		dst_sea := to_sea(dst)
		
		gc.idle_land_planes[src_land][gc.cur_player][plane_type] -= count
		gc.idle_sea_planes[dst_sea][gc.cur_player][plane_type] += count
		
	} else if !is_land_src && is_land_dst {
		// Sea to land (taking off from carrier)
		src_sea := to_sea(src)
		dst_land := to_land(dst)
		
		gc.idle_sea_planes[src_sea][gc.cur_player][plane_type] -= count
		gc.idle_land_planes[dst_land][gc.cur_player][plane_type] += count
		
	} else {
		// Sea to sea (carrier to carrier)
		src_sea := to_sea(src)
		dst_sea := to_sea(dst)
		
		gc.idle_sea_planes[src_sea][gc.cur_player][plane_type] -= count
		gc.idle_sea_planes[dst_sea][gc.cur_player][plane_type] += count
	}
	
	// Track moved units
	if !(src in moved.air_units) {
		moved.air_units[src] = make(map[Idle_Plane]u8)
	}
	plane_map := &moved.air_units[src]
	plane_map[plane_type] += count
	
	when ODIN_DEBUG {
		fmt.eprintfln("[PRO-MOVE] Moved %d %v from air %v to air %v",
			count, plane_type, src, dst)
	}
	
	return true
}

// Execute sea unit movement
execute_sea_move :: proc(
	gc: ^Game_Cache,
	src: Sea_ID,
	dst: Sea_ID,
	ship_type: Idle_Ship,
	count: u8,
	moved: ^Moved_Units,
) -> bool {
	/*
	Sea Movement Algorithm (from ship.odin):
	
	Most ships: 2 movement range
	Movement tracked in:
	- gc.idle_ships[sea][player][ship_type]
	- gc.active_ships[sea][active_ship_state]
	
	Validation:
	- Check sea connectivity via mm.s2s_1away_via_sea or mm.s2s_2away_via_sea
	- Consider canal states (mm.sea_distances[canal_state][src][dst])
	*/
	
	// Validate unit availability
	available := gc.idle_ships[src][gc.cur_player][ship_type]
	
	// Check how many already moved
	already_moved: u8 = 0
	if src in moved.sea_units {
		if ship_type in moved.sea_units[src] {
			already_moved = moved.sea_units[src][ship_type]
		}
	}
	
	if available - already_moved < count {
		when ODIN_DEBUG {
			fmt.eprintfln("[PRO-MOVE] Not enough %v at %v (available: %d, moved: %d, need: %d)",
				ship_type, src, available, already_moved, count)
		}
		return false
	}
	
	// Validate movement is legal using map graph
	// Convert Idle_Ship to Active_Ship for validation
	active_ship_for_validation := idle_ship_to_active_ship(ship_type)
	max_moves := 2  // Most ships have 2 moves
	
	// Check if transport (needs escort validation)
	is_transport := ship_type == .TRANS_EMPTY || ship_type == .TRANS_1I || 
	                ship_type == .TRANS_1A || ship_type == .TRANS_1T ||
	                ship_type == .TRANS_2I || ship_type == .TRANS_1I_1A || 
	                ship_type == .TRANS_1I_1T
	
	if is_transport {
		if !can_transport_reach(gc, src, dst, max_moves) {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-MOVE] Invalid transport move: %v cannot reach %v from %v (escort/blockade)",
					ship_type, dst, src)
			}
			return false
		}
	} else {
		if !can_sea_reach(gc, src, dst, max_moves, active_ship_for_validation) {
			when ODIN_DEBUG {
				fmt.eprintfln("[PRO-MOVE] Invalid sea move: %v cannot reach %v from %v",
					ship_type, dst, src)
			}
			return false
		}
	}
	
	// Get active ship state (simplified - use 0 moves)
	active_state := get_active_ship_state(ship_type)
	
	// Execute movement
	gc.active_ships[dst][active_state] += count
	gc.idle_ships[dst][gc.cur_player][ship_type] += count
	
	gc.idle_ships[src][gc.cur_player][ship_type] -= count
	
	// Track moved units
	if !(src in moved.sea_units) {
		moved.sea_units[src] = make(map[Idle_Ship]u8)
	}
	ship_map := &moved.sea_units[src]
	ship_map[ship_type] += count
	
	when ODIN_DEBUG {
		fmt.eprintfln("[PRO-MOVE] Moved %d %v from %v to %v (state: %v)",
			count, ship_type, src, dst, active_state)
	}
	
	return true
}

// Convert Idle_Ship to Active_Ship for validation purposes
idle_ship_to_active_ship :: proc(ship_type: Idle_Ship) -> Active_Ship {
	#partial switch ship_type {
	case .SUB:
		return .SUB_2_MOVES
	case .DESTROYER:
		return .DESTROYER_2_MOVES
	case .CARRIER:
		return .CARRIER_2_MOVES
	case .CRUISER:
		return .CRUISER_2_MOVES
	case .BATTLESHIP:
		return .BATTLESHIP_2_MOVES
	case .BS_DAMAGED:
		return .BS_DAMAGED_2_MOVES
	case:
		return .SUB_2_MOVES  // Fallback
	}
}

// Get active ship state for idle ship type
get_active_ship_state :: proc(ship_type: Idle_Ship) -> Active_Ship {
	/*
	Simplified: All ships end with 0 moves after combat move
	In full implementation, would track actual movement used
	*/
	
	#partial switch ship_type {
	case .SUB:
		return .SUB_0_MOVES
	case .DESTROYER:
		return .DESTROYER_0_MOVES
	case .CARRIER:
		return .CARRIER_0_MOVES
	case .CRUISER:
		return .CRUISER_0_MOVES
	case .BATTLESHIP:
		return .BATTLESHIP_0_MOVES
	case .BS_DAMAGED:
		return .BS_DAMAGED_0_MOVES
	case .TRANS_EMPTY:
		return .TRANS_EMPTY_0_MOVES
	case:
		return .SUB_0_MOVES  // Fallback
	}
}

// Check if unit has available movement
has_available_units :: proc(
	gc: ^Game_Cache,
	location: Land_ID,
	unit_type: Idle_Army,
	count: u8,
	moved: ^Moved_Units,
) -> bool {
	available := gc.idle_armies[location][gc.cur_player][unit_type]
	
	already_moved: u8 = 0
	if location in moved.land_units {
		if unit_type in moved.land_units[location] {
			already_moved = moved.land_units[location][unit_type]
		}
	}
	
	return available - already_moved >= count
}

// Get number of available (unmoved) units at location
get_available_unit_count :: proc(
	gc: ^Game_Cache,
	location: Land_ID,
	unit_type: Idle_Army,
	moved: ^Moved_Units,
) -> u8 {
	available := gc.idle_armies[location][gc.cur_player][unit_type]
	
	already_moved: u8 = 0
	if location in moved.land_units {
		if unit_type in moved.land_units[location] {
			already_moved = moved.land_units[location][unit_type]
		}
	}
	
	return available - already_moved
}

// Helper: Convert unit type from Pro AI enum to OAAA enum
convert_unit_type_to_idle_army :: proc(unit_type: Unit_Type) -> (Idle_Army, bool) {
	#partial switch unit_type {
	case .Infantry:
		return .INF, true
	case .Artillery:
		return .ARTY, true
	case .Tank:
		return .TANK, true
	case .AAGun:
		return .AAGUN, true
	case:
		return .INF, false  // Not a land unit
	}
}

// Helper: Convert unit type to idle plane
convert_unit_type_to_idle_plane :: proc(unit_type: Unit_Type) -> (Idle_Plane, bool) {
	#partial switch unit_type {
	case .Fighter:
		return .FIGHTER, true
	case .Bomber:
		return .BOMBER, true
	case:
		return .FIGHTER, false  // Not an air unit
	}
}

// Helper: Convert unit type to idle ship
convert_unit_type_to_idle_ship :: proc(unit_type: Unit_Type) -> (Idle_Ship, bool) {
	#partial switch unit_type {
	case .Transport:
		return .TRANS_EMPTY, true
	case .Submarine:
		return .SUB, true
	case .Destroyer:
		return .DESTROYER, true
	case .Carrier:
		return .CARRIER, true
	case .Battleship:
		return .BATTLESHIP, true
	case .Cruiser:
		return .CRUISER, true
	case:
		return .SUB, false  // Not a sea unit
	}
}
