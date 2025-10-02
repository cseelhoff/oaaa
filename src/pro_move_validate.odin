package oaaa

import "core:fmt"
import sa "core:container/small_array"

/*
Pro AI Movement Validation

This module provides validation functions for unit movement in the Pro AI system.
It ensures that all movements respect game rules including:
- Unit movement ranges
- Path blockages (enemy territories, blockades, etc.)
- Canal states
- Escort requirements for transports
- Landing requirements for air units

These validation functions are based on patterns discovered from OAAA's movement
system (fighter.odin, bomber.odin, army.odin, ship.odin, transport.odin).
*/

// ============================================================================
// Land Unit Validation
// ============================================================================

/*
Check if land units can legally move from src to dst.

Movement Rules:
- 1-move units (Infantry, Artillery, AAGun): Adjacent territories only
- 2-move units (Tanks): Can move through one midland territory
- Paths must not be blocked by occupied enemy territories

Uses OAAA patterns:
- 1-move: dst in mm.l2l_1away_via_land[src]
- 2-move: dst in mm.l2l_2away_via_midland_bitset[src][dst]
*/
can_land_units_move :: proc(
	gc: ^Game_Cache,
	src: Land_ID,
	dst: Land_ID,
	max_moves: int,
) -> bool {
	if max_moves == 1 {
		// Check adjacency using Small_Array
		for adj in sa.slice(&mm.l2l_1away_via_land[src]) {
			if adj == dst {
				return true
			}
		}
		return false
	} else if max_moves == 2 {
		// Check 2-move range
		if !(dst in mm.l2l_2away_via_midland_bitset[src][dst]) {
			return false
		}

		// Validate at least one passable path exists
		// Movement through friendly, neutral, or empty enemy territories is allowed
		// Movement through occupied enemy territories is blocked
		for midland in mm.l2l_2away_via_midland_bitset[src][dst] {
			// Friendly territory - always passable
			if gc.owner[midland] == gc.cur_player {
				return true
			}

			// Enemy territory with no units - passable (conquest)
			if gc.team_land_units[midland][mm.enemy_team[gc.cur_player]] == 0 {
				return true
			}

			// Enemy territory with units - blocked
			// Continue checking other paths
		}

		return false // All paths blocked
	}

	return false
}

/*
Find all territories within max_moves range from src.

Returns a dynamic array of Land_IDs that can be reached within the given move range.
Caller is responsible for deleting the returned array.

Uses pre-computed bitsets from map graph for efficiency:
- 1-move: mm.l2l_1away_via_land_bitset[src]
- 2-move: mm.l2l_2away_via_land_bitset[src]

Example usage:
    territories := find_territories_within_range(gc, Land_ID.GERMANY, 2)
    defer delete(territories)
    
    for land in territories {
        // Process reachable territory
    }
*/
find_territories_within_range :: proc(
	gc: ^Game_Cache,
	src: Land_ID,
	max_moves: int,
	allocator := context.allocator,
) -> [dynamic]Land_ID {
	territories := make([dynamic]Land_ID, allocator)

	// Use pre-computed bitsets from map graph (much faster)
	range_bitset: Land_Bitset
	
	if max_moves >= 2 {
		// 2-move includes all territories within 2 moves
		range_bitset = mm.l2l_2away_via_land_bitset[src]
	} else if max_moves >= 1 {
		// 1-move only
		range_bitset = mm.l2l_1away_via_land_bitset[src]
	} else {
		return territories // No movement
	}

	// Convert bitset to dynamic array
	for land in range_bitset {
		// Validate path isn't blocked (for 2-move)
		if max_moves >= 2 && !(land in mm.l2l_1away_via_land_bitset[src]) {
			// 2-move territory - check paths aren't blocked
			if !can_land_units_move(gc, src, land, 2) {
				continue
			}
		}
		append(&territories, land)
	}

	return territories
}

// ============================================================================
// Air Unit Validation
// ============================================================================

/*
Check if air unit can reach destination within max_range.

Uses mm.air_distances for direct distance calculation.

Fighter range: 4 moves
Bomber range: 6 moves
*/
can_air_reach :: proc(gc: ^Game_Cache, src: Air_ID, dst: Air_ID, max_range: int) -> bool {
	distance := mm.air_distances[src][dst]
	return distance <= u8(max_range)
}

/*
Alternative bitset-based air reachability check.

This is faster when checking many destinations from the same source,
as it uses pre-computed bitsets.

Pattern from fighter.odin:
    mm.a2a_within_4_moves[src] & target_bitset
*/
can_air_reach_bitset :: proc(gc: ^Game_Cache, src: Air_ID, dst: Air_ID, max_range: int) -> bool {
	dst_bitset: Air_Bitset
	add_air(&dst_bitset, dst)

	switch max_range {
	case 1:
		return (mm.a2a_within_1_moves[src] & dst_bitset) != {}
	case 2:
		return (mm.a2a_within_2_moves[src] & dst_bitset) != {}
	case 3:
		return (mm.a2a_within_3_moves[src] & dst_bitset) != {}
	case 4:
		return (mm.a2a_within_4_moves[src] & dst_bitset) != {}
	case 5:
		return (mm.a2a_within_5_moves[src] & dst_bitset) != {}
	case 6:
		return (mm.a2a_within_6_moves[src] & dst_bitset) != {}
	}

	return false
}

/*
Find all air territories within max_range from src.

Returns a dynamic array of Air_IDs reachable within the given range.
Caller is responsible for deleting the returned array.

Uses pre-computed bitsets from map graph for efficiency.
*/
find_air_territories_within_range :: proc(
	gc: ^Game_Cache,
	src: Air_ID,
	max_range: int,
	allocator := context.allocator,
) -> [dynamic]Air_ID {
	territories := make([dynamic]Air_ID, allocator)

	// Get appropriate range bitset from map graph
	range_bitset: Air_Bitset
	switch max_range {
	case 1:
		range_bitset = mm.a2a_within_1_moves[src]
	case 2:
		range_bitset = mm.a2a_within_2_moves[src]
	case 3:
		range_bitset = mm.a2a_within_3_moves[src]
	case 4:
		range_bitset = mm.a2a_within_4_moves[src]
	case 5:
		range_bitset = mm.a2a_within_5_moves[src]
	case 6:
		range_bitset = mm.a2a_within_6_moves[src]
	case:
		return territories
	}

	// Convert bitset to dynamic array using helper function
	get_airs(range_bitset, &territories)

	return territories
}

/*
Check if fighter can land at destination.

Considers both friendly territories and carrier capacity.

Pattern from fighter.odin:
    mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here
*/
can_fighter_land :: proc(gc: ^Game_Cache, dst: Air_ID) -> bool {
	dst_bitset: Air_Bitset
	add_air(&dst_bitset, dst)
	// gc.can_fighter_land_here is already an Air_Bitset
	return (gc.can_fighter_land_here & dst_bitset) != {}
}

/*
Check if bomber can land at destination.

Bombers can only land on friendly territories (no carriers).

Pattern from bomber.odin:
    gc.can_bomber_land_here = gc.friendly_owner & ~gc.land_combat_started
*/
can_bomber_land :: proc(gc: ^Game_Cache, dst: Air_ID) -> bool {
	dst_bitset: Air_Bitset
	add_air(&dst_bitset, dst)
	// gc.can_bomber_land_here is a Land_Bitset, convert to Air_Bitset
	bomber_land_air := land_bitset_to_air_bitset(gc.can_bomber_land_here)
	return (bomber_land_air & dst_bitset) != {}
}

/*
Calculate remaining moves for fighter after moving to combat.

Uses air distance and landing availability to determine if fighter
can reach combat and still land safely.

Pattern from fighter.odin:
    Fighter_After_Moves[air_distances[src][dst]]
*/
get_fighter_moves_after_combat :: proc(
	gc: ^Game_Cache,
	src: Air_ID,
	combat_dst: Air_ID,
) -> int {
	distance := mm.air_distances[src][combat_dst]
	if distance > 4 {
		return -1 // Cannot reach
	}
	return 4 - int(distance) // Remaining moves
}

/*
Calculate remaining moves for bomber after moving to combat.

Bombers have 6-move range, more forgiving than fighters.

Pattern from bomber.odin:
    Bomber_After_Moves[air_distances[src][dst]]
*/
get_bomber_moves_after_combat :: proc(
	gc: ^Game_Cache,
	src: Air_ID,
	combat_dst: Air_ID,
) -> int {
	distance := mm.air_distances[src][combat_dst]
	if distance > 6 {
		return -1 // Cannot reach
	}
	return 6 - int(distance) // Remaining moves
}

// ============================================================================
// Sea Unit Validation
// ============================================================================

/*
Check if sea unit can reach destination within max_moves.

Handles:
- Canal states (open/closed canals affect movement)
- Blockades (enemy ships blocking paths)
- Destroyer vs submarine rules
- 1-move and 2-move validation

Pattern from ship.odin:
    mm.s2s_1away_via_sea[canal_state][src]
    mm.s2s_2away_via_sea[canal_state][src]
    mm.s2s_2away_via_midseas[canal_state][src][dst]
*/
can_sea_reach :: proc(
	gc: ^Game_Cache,
	src: Sea_ID,
	dst: Sea_ID,
	max_moves: int,
	ship_type: Active_Ship = {},
) -> bool {
	canal_state := transmute(u8)gc.canals_open

	if max_moves == 1 {
		return dst in mm.s2s_1away_via_sea[canal_state][src]
	} else if max_moves == 2 {
		// Check 2-move range
		if !(dst in mm.s2s_2away_via_sea[canal_state][src]) {
			return false
		}

		// Determine if ship is submarine
		is_submarine: bool
		#partial switch ship_type {
		case .SUB_2_MOVES:
			is_submarine = true
		case:
			is_submarine = false
		}

		// Validate at least one unblocked path exists
		for mid_sea in sa.slice(&mm.s2s_2away_via_midseas[canal_state][src][dst]) {
			if is_submarine {
				// Submarines only blocked by destroyers
				if gc.enemy_destroyer_total[mid_sea] > 0 {
					continue // This path blocked
				}
			} else {
				// Other ships blocked by any enemy blockade
				if gc.enemy_blockade_total[mid_sea] > 0 {
					continue // This path blocked
				}
			}

			return true // Found valid path
		}

		return false // All paths blocked
	}

	return false
}

/*
Check if transport can reach destination.

Transports have additional restriction: they need escort in hostile waters.

Pattern from transport.odin:
    if gc.team_sea_units[dst][mm.enemy_team[gc.cur_player]] > 0 &&
       gc.allied_sea_combatants_total[dst] == 0 {
        // Cannot enter without escort
    }
*/
can_transport_reach :: proc(
	gc: ^Game_Cache,
	src: Sea_ID,
	dst: Sea_ID,
	max_moves: int,
) -> bool {
	canal_state := transmute(u8)gc.canals_open

	if max_moves == 1 {
		if !(dst in mm.s2s_1away_via_sea[canal_state][src]) {
			return false
		}

		// Check escort requirement
		// If destination has enemy ships and no friendly combat ships, cannot enter
		if gc.team_sea_units[dst][mm.enemy_team[gc.cur_player]] > 0 &&
		   gc.allied_sea_combatants_total[dst] == 0 {
			return false
		}

		return true
	} else if max_moves == 2 {
		if !(dst in mm.s2s_2away_via_sea[canal_state][src]) {
			return false
		}

		// Check escort requirement at destination
		if gc.team_sea_units[dst][mm.enemy_team[gc.cur_player]] > 0 &&
		   gc.allied_sea_combatants_total[dst] == 0 {
			return false
		}

		// Check intermediate seas for blockades
		for mid_sea in sa.slice(&mm.s2s_2away_via_midseas[canal_state][src][dst]) {
			if gc.enemy_blockade_total[mid_sea] == 0 {
				return true // Found valid path
			}
		}

		return false // All paths blocked
	}

	return false
}

/*
Find all seas within max_moves range from src.

Returns a dynamic array of Sea_IDs reachable within the given move range.
Caller is responsible for deleting the returned array.

Note: This does not validate blockades or escort requirements.
Use can_sea_reach() or can_transport_reach() for full validation.
*/
find_seas_within_range :: proc(
	gc: ^Game_Cache,
	src: Sea_ID,
	max_moves: int,
	allocator := context.allocator,
) -> [dynamic]Sea_ID {
	territories := make([dynamic]Sea_ID, allocator)
	canal_state := transmute(u8)gc.canals_open

	// Use pre-computed bitsets from map graph for efficiency
	if max_moves >= 2 {
		// For 2-move range, iterate the 2-move bitset directly
		for sea in mm.s2s_2away_via_sea[canal_state][src] {
			append(&territories, sea)
		}
	} else if max_moves >= 1 {
		// For 1-move range, iterate the 1-move bitset directly
		for sea in mm.s2s_1away_via_sea[canal_state][src] {
			append(&territories, sea)
		}
	}

	return territories
}

// ============================================================================
// Helper Functions
// ============================================================================

/*
Get maximum moves for unit type.

Returns the standard movement range for each unit type.
This does not account for state (e.g., TANK_1_MOVES vs TANK_2_MOVES).
*/
get_unit_max_moves :: proc(unit_type: Unit_Type) -> int {
	#partial switch unit_type {
	case .Infantry, .Artillery, .AAGun:
		return 1
	case .Tank:
		return 2
	case .Fighter:
		return 4
	case .Bomber:
		return 6
	case .Carrier, .Battleship, .Submarine, .Destroyer, .Cruiser, .Transport:
		return 2
	}
	return 0
}

/*
Convert unit type to initial active army state.

Returns the active army state with maximum moves available.
For example, TANK → TANK_2_MOVES.
*/
unit_type_to_active_army :: proc(unit_type: Unit_Type) -> (Active_Army, bool) #optional_ok {
	#partial switch unit_type {
	case .Infantry:
		return .INF_1_MOVES, true
	case .Artillery:
		return .ARTY_1_MOVES, true
	case .Tank:
		return .TANK_2_MOVES, true
	case .AAGun:
		return .AAGUN_1_MOVES, true
	}
	return {}, false
}

/*
Convert unit type to initial active plane state.

Returns the unmoved active plane state.
*/
unit_type_to_active_plane :: proc(unit_type: Unit_Type) -> (Active_Plane, bool) #optional_ok {
	#partial switch unit_type {
	case .Fighter:
		return .FIGHTER_UNMOVED, true
	case .Bomber:
		return .BOMBER_UNMOVED, true
	}
	return {}, false
}

/*
Convert unit type to initial active ship state.

Returns the active ship state with maximum moves available.
For transport, returns empty transport with 2 moves.
*/
unit_type_to_active_ship :: proc(unit_type: Unit_Type) -> (Active_Ship, bool) #optional_ok {
	#partial switch unit_type {
	case .Transport:
		return .TRANS_EMPTY_2_MOVES, true
	case .Carrier:
		return .CARRIER_2_MOVES, true
	case .Battleship:
		return .BATTLESHIP_2_MOVES, true
	case .Submarine:
		return .SUB_2_MOVES, true
	case .Destroyer:
		return .DESTROYER_2_MOVES, true
	case .Cruiser:
		return .CRUISER_2_MOVES, true
	}
	return {}, false
}

/*
Get destination active army state after moving.

For simplicity, assumes all moves are used (MCTS optimization).
Exception: Tank blitz would return TANK_1_MOVES, but that's handled
in the movement execution logic, not here.
*/
get_destination_army_state :: proc(unit_type: Unit_Type) -> (Active_Army, bool) #optional_ok {
	#partial switch unit_type {
	case .Infantry:
		return .INF_0_MOVES, true
	case .Artillery:
		return .ARTY_0_MOVES, true
	case .Tank:
		return .TANK_0_MOVES, true
	case .AAGun:
		return .AAGUN_0_MOVES, true
	}
	return {}, false
}

/*
Get destination active plane state after moving.

For simplicity, assumes plane lands after combat (0 moves remaining).
*/
get_destination_plane_state :: proc(unit_type: Unit_Type) -> (Active_Plane, bool) #optional_ok {
	#partial switch unit_type {
	case .Fighter:
		return .FIGHTER_0_MOVES, true
	case .Bomber:
		return .BOMBER_0_MOVES, true
	}
	return {}, false
}

/*
Get destination active ship state after moving.

For simplicity, assumes all moves are used.
*/
get_destination_ship_state :: proc(unit_type: Unit_Type) -> (Active_Ship, bool) #optional_ok {
	#partial switch unit_type {
	case .Transport:
		return .TRANS_EMPTY_0_MOVES, true
	case .Carrier:
		return .CARRIER_0_MOVES, true
	case .Battleship:
		return .BATTLESHIP_0_MOVES, true
	case .Submarine:
		return .SUB_0_MOVES, true
	case .Destroyer:
		return .DESTROYER_0_MOVES, true
	case .Cruiser:
		return .CRUISER_0_MOVES, true
	}
	return {}, false
}
