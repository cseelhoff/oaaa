package oaaa

/*
Pro AI Non-Combat Move Phase Implementation

This file implements non-combat movement logic following TripleA's ProNonCombatMoveAi.java.
The Pro AI moves units to defensive positions, lands planes safely, and repositions forces
for future attacks.

Key Responsibilities:
- Find territories that need defense
- Move units to best defensive positions
- Land fighters and bombers safely
- Move transports to loading positions
- Consolidate forces for future attacks
- Ensure capital remains defended

Algorithm Overview (from ProNonCombatMoveAi.java):
1. Find units that can't move and infrastructure units
2. Move one defender to land territories bordering enemy
3. Determine max enemy attackers and if territories can be held
4. Prioritize territories to defend
5. Move units to defend territories
6. Move units to best value territories (sea, land, air)
7. Move infrastructure units (AA guns, factories if mobile)
8. Execute non-combat moves
*/

import "core:fmt"
import "core:math"
import "core:slice"
import sa "core:container/small_array"

// Main non-combat move phase entry point
proai_noncombat_move_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Starting non-combat move phase")
	}
	
	pro_data := pro_data_init(gc)
	
	// Step 1: Find territories that need defense
	defense_targets := find_noncombat_defense_targets(gc, &pro_data)
	defer pro_noncombat_move_cleanup(&defense_targets)
	
	if len(defense_targets) == 0 {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] No territories need defense")
		}
		return true
	}
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Found %d territories needing defense\n", len(defense_targets))
	}
	
	// Step 2: Prioritize defense targets by strategic value
	prioritize_defense_targets(&defense_targets, gc, &pro_data)
	
	// Step 3: Move units to defend priority territories
	move_units_to_defense(&defense_targets, gc, &pro_data)
	
	// Step 4: Land fighters in safe territories
	land_fighters_noncombat(gc, &pro_data)
	
	// Step 5: Land bombers in safe territories
	land_bombers_noncombat(gc, &pro_data)
	
	// Step 6: Move remaining sea units to safe positions
	move_sea_units_noncombat(gc, &pro_data)
	
	// Step 7: Move remaining land units to consolidate
	move_land_units_noncombat(gc, &pro_data)
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Completed non-combat move phase")
	}
	
	return true
}

// Defense_Target represents a territory that needs defensive units
Defense_Target :: struct {
	territory: Land_ID,
	enemy_threat: f64,          // Enemy attack strength
	current_defense: f64,        // Current defensive strength
	defense_needed: f64,         // Additional defense needed
	strategic_value: f64,        // Strategic importance (factory, capital, etc)
	priority: f64,               // Overall priority for defense
	is_capital: bool,
	has_factory: bool,
}

// Find territories that need defensive reinforcement
find_noncombat_defense_targets :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) -> [dynamic]Defense_Target {
	targets := make([dynamic]Defense_Target)
	
	// Check all friendly territories
	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}
		
		// Calculate enemy threat
		enemy_threat := calculate_enemy_threat(gc, land_id, pro_data)
		if enemy_threat <= 0 {
			continue // No enemy threat
		}
		
		// Calculate current defense
		current_defense := calculate_current_defense(gc, land_id)
		
		// Check if we need more defense
		if current_defense >= enemy_threat * 1.2 {
			continue // Already well defended
		}
		
		// Calculate strategic value
		territory_value := calculate_territory_value(gc, land_id)
		is_capital := is_player_capital(gc, land_id, gc.cur_player)
		has_factory := gc.factory_prod[land_id] > 0
		
		strategic_value := territory_value
		if is_capital {
			strategic_value *= 10.0
		}
		if has_factory {
			strategic_value *= 3.0
		}
		
		target := Defense_Target{
			territory = land_id,
			enemy_threat = enemy_threat,
			current_defense = current_defense,
			defense_needed = enemy_threat * 1.2 - current_defense,
			strategic_value = strategic_value,
			is_capital = is_capital,
			has_factory = has_factory,
		}
		
		append(&targets, target)
	}
	
	return targets
}

// Calculate enemy threat to a territory
calculate_enemy_threat :: proc(gc: ^Game_Cache, territory: Land_ID, pro_data: ^Pro_Data) -> f64 {
	threat := 0.0
	
	// Count enemy units in adjacent territories
	// Simplified - would use map graph for proper adjacency
	for player in Player_ID {
		if player == gc.cur_player {
			continue
		}
		if mm.team[player] == mm.team[gc.cur_player] {
			continue
		}
		
		// Check for enemy land units
		for army_type in Idle_Army {
			count := gc.idle_armies[territory][player][army_type]
			threat += f64(count) * get_army_threat_value(army_type)
		}
		
		// Check for enemy air units
		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[territory][player][plane_type]
			threat += f64(count) * get_plane_threat_value(plane_type)
		}
	}
	
	return threat
}

// Get threat value for army types
get_army_threat_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF: return 1.0
	case .ARTY: return 2.0
	case .TANK: return 3.0
	case .AAGUN: return 0.5
	case: return 1.0
	}
}

// Get threat value for plane types
get_plane_threat_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER: return 3.0
	case .BOMBER: return 4.0
	case: return 2.0
	}
}

// Calculate current defensive strength
calculate_current_defense :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	defense := 0.0
	
	// Count friendly units
	for army_type in Idle_Army {
		count := gc.idle_armies[territory][gc.cur_player][army_type]
		defense += f64(count) * get_army_defense_value(army_type)
	}
	
	for plane_type in Idle_Plane {
		count := gc.idle_land_planes[territory][gc.cur_player][plane_type]
		defense += f64(count) * get_plane_defense_value(plane_type)
	}
	
	return defense
}

// Get defense value for army types
get_army_defense_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF: return 2.0
	case .ARTY: return 2.0
	case .TANK: return 3.0
	case .AAGUN: return 0.5
	case: return 1.0
	}
}

// Get defense value for plane types
get_plane_defense_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER: return 4.0
	case .BOMBER: return 1.0
	case: return 2.0
	}
}

// Check if territory is a player's capital
is_player_capital :: proc(gc: ^Game_Cache, territory: Land_ID, player: Player_ID) -> bool {
	capital_maybe := get_capital_territory(player)
	if capital_maybe == nil {
		return false
	}
	return capital_maybe.? == territory
}

// Prioritize defense targets by strategic importance
prioritize_defense_targets :: proc(targets: ^[dynamic]Defense_Target, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Calculate priority for each target
	for &target in targets {
		// Priority = strategic value * threat ratio
		threat_ratio := target.enemy_threat / max(target.current_defense, 1.0)
		target.priority = target.strategic_value * threat_ratio
		
		// Extra priority for capital
		if target.is_capital {
			target.priority *= 5.0
		}
		
		// Extra priority for factories
		if target.has_factory {
			target.priority *= 2.0
		}
	}
	
	// Sort by priority (highest first)
	slice.sort_by(targets[:], proc(a, b: Defense_Target) -> bool {
		return a.priority > b.priority
	})
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized defense targets:")
		for target, i in targets {
			if i >= 5 { break } // Only show top 5
			fmt.printf("  %d. Territory %v: priority=%.1f, threat=%.1f, defense=%.1f\n",
				i+1, target.territory, target.priority, target.enemy_threat, target.current_defense)
		}
	}
}

// Move units to defend priority territories
move_units_to_defense :: proc(targets: ^[dynamic]Defense_Target, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	Move units to defensive positions:
	1. Initialize moved units tracker
	2. For each high-priority target needing defense
	3. Find nearby units that can reach
	4. Move units until defense requirement met
	*/
	
	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)
	
	// For each high priority target, find nearby units that can move there
	for &target in targets {
		if target.defense_needed <= 0 {
			continue
		}
		
		// Find units that can reach this territory
		units_moved := move_nearby_units_to_defense(gc, target.territory, target.defense_needed, &moved)
		
		when ODIN_DEBUG {
			if units_moved > 0 {
				fmt.printf("[PRO-AI] Moved %d units to defend territory %v\n", 
					units_moved, target.territory)
			}
		}
	}
}

// Move nearby units to defend a territory
move_nearby_units_to_defense :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	defense_needed: f64,
	moved: ^Moved_Units,
) -> int {
	/*
	Find and move units to defend a territory:
	1. Check adjacent territories for friendly units
	2. Prioritize: Infantry < Artillery < Tanks
	3. Move units until defense requirement met
	4. Use map graph for adjacency checking
	*/
	
	units_moved := 0
	defense_provided := f64(0)
	
	// Check all adjacent land territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if gc.owner[adjacent] != gc.cur_player do continue
		if adjacent == territory do continue
		
		// Try to move infantry first (most expendable)
		inf_available := get_available_unit_count(gc, adjacent, .INF, moved)
		if inf_available > 0 && defense_provided < defense_needed {
			inf_to_move := min(inf_available, u8((defense_needed - defense_provided) / 2) + 1)
			
			success := execute_land_move(gc, adjacent, territory, .INF, inf_to_move, moved)
			if success {
				units_moved += int(inf_to_move)
				defense_provided += f64(inf_to_move) * 2.0  // Infantry has 2 defense
			}
		}
		
		// Try artillery if still need defense
		if defense_provided < defense_needed {
			arty_available := get_available_unit_count(gc, adjacent, .ARTY, moved)
			if arty_available > 0 {
				arty_to_move := min(arty_available, u8((defense_needed - defense_provided) / 2) + 1)
				
				success := execute_land_move(gc, adjacent, territory, .ARTY, arty_to_move, moved)
				if success {
					units_moved += int(arty_to_move)
					defense_provided += f64(arty_to_move) * 2.0  // Artillery has 2 defense
				}
			}
		}
		
		// Try tanks if still need defense
		if defense_provided < defense_needed {
			tank_available := get_available_unit_count(gc, adjacent, .TANK, moved)
			if tank_available > 0 {
				tank_to_move := min(tank_available, u8((defense_needed - defense_provided) / 3) + 1)
				
				success := execute_land_move(gc, adjacent, territory, .TANK, tank_to_move, moved)
				if success {
					units_moved += int(tank_to_move)
					defense_provided += f64(tank_to_move) * 3.0  // Tanks have 3 defense
				}
			}
		}
		
		// Stop if we've met defense requirement
		if defense_provided >= defense_needed {
			break
		}
	}
	
	// Check territories 2 moves away (tanks only - they have 2 movement)
	if defense_provided < defense_needed {
		for land_2_away in Land_ID {
			if gc.owner[land_2_away] != gc.cur_player do continue
			if land_2_away == territory do continue
			
			// Check if territory is 2 moves away
			// TODO: Fix 2-move bitset check
			continue
// 			// Only tanks can move 2 spaces
// 			tank_available := get_available_unit_count(gc, land_2_away, .TANK, moved)
// 			if tank_available > 0 {
// 				tank_to_move := min(tank_available, u8((defense_needed - defense_provided) / 3) + 1)
// 				
// 				// Note: Direct 2-move not supported by execute_land_move yet
// 				// Would need intermediate territory calculation
// 				// For now, skip 2-move tank movements
// 				
// 				// success := execute_land_move(gc, land_2_away, territory, .TANK, tank_to_move, moved)
// 				// if success {
// 				// 	units_moved += int(tank_to_move)
// 				// 	defense_provided += f64(tank_to_move) * 3.0
// 				// }
// 			}
// 			
// 			if defense_provided >= defense_needed {
// 				break
// 			}
		}
	}
	
	return units_moved
}

// Land fighters in safe territories
land_fighters_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing fighters in safe territories")
	}
	
	// Find all fighters that need landing
	// Simplified - would track which fighters are in air and need landing
	
	// For each fighter, find safest landing spot
	// Priority: Friendly territories > Carriers > Allied territories
	
	// Placeholder - use existing landing logic
	// In full implementation, this would:
	// 1. Identify all fighters in the air
	// 2. Find valid landing territories (friendly land, carriers)
	// 3. Choose safest landing spot
	// 4. Execute landing moves
}

// Land bombers in safe territories  
land_bombers_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing bombers in safe territories")
	}
	
	// Find all bombers that need landing
	// Similar to fighters but with longer range
	
	// For each bomber, find best landing spot
	// Consider: Future attack positions, safety, strategic value
	
	// Placeholder - use existing landing logic
	// In full implementation, this would:
	// 1. Identify all bombers in the air
	// 2. Find valid landing territories
	// 3. Choose landing spot that provides good offensive reach for next turn
	// 4. Execute landing moves
}

// Move sea units to safe positions
move_sea_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving sea units to safe positions")
	}
	
	// For each sea zone with friendly ships:
	// 1. Calculate if zone is safe from enemy attack
	// 2. If unsafe, move to safer adjacent zone
	// 3. If safe, consider moving to better strategic position
	
	// Priority considerations:
	// - Protect transports
	// - Position carriers for fighter landing
	// - Stage for future amphibious assaults
	// - Blockade enemy territories
	
	// Placeholder - simplified implementation
	for sea_id in Sea_ID {
		// Check if we have ships here
		has_ships := false
		for ship_type in Idle_Ship {
			if gc.idle_ships[sea_id][gc.cur_player][ship_type] > 0 {
				has_ships = true
				break
			}
		}
		
		if !has_ships {
			continue
		}
		
		// Calculate if this zone is safe
		// Would check for enemy attackers
		// If unsafe, would move to adjacent safer zone
	}
}

// Move land units to consolidate positions
move_land_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving land units to consolidate")
	}
	
	// For each territory with friendly land units:
	// 1. Check if units are needed for defense elsewhere
	// 2. If not, move towards strategic positions
	// 3. Consolidate scattered forces
	
	// Strategic positions:
	// - Adjacent to enemy territories (for future attacks)
	// - Near factories (for loading onto transports)
	// - On important defensive lines
	
	// Placeholder - simplified implementation
	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}
		
		// Check if we have idle units here
		has_units := false
		for army_type in Idle_Army {
			if gc.idle_armies[land_id][gc.cur_player][army_type] > 0 {
				has_units = true
				break
			}
		}
		
		if !has_units {
			continue
		}
		
		// Determine if units should move
		// Would check: enemy threats, strategic value, consolidation opportunities
		// If beneficial, would move to better position
	}
}

// Helper: Move one unit to each territory bordering enemy
move_one_defender_to_border_territories :: proc(gc: ^Game_Cache) {
	// Find all friendly territories adjacent to enemy
	// For each, ensure at least one defender present
	// This prevents enemy from easily capturing undefended border territories
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving one defender to each border territory")
	}
	
	// Placeholder - simplified implementation
	// Would identify border territories and ensure minimal defense
}

// Helper: Check if territory can be held after reinforcement
can_hold_territory_after_reinforcement :: proc(gc: ^Game_Cache, territory: Land_ID, additional_defense: f64, pro_data: ^Pro_Data) -> bool {
	enemy_threat := calculate_enemy_threat(gc, territory, pro_data)
	current_defense := calculate_current_defense(gc, territory)
	total_defense := current_defense + additional_defense
	
	// Can hold if defense is 20% stronger than threat
	return total_defense >= enemy_threat * 1.2
}

// Helper: Find best territory to move a unit to
find_best_noncombat_move :: proc(gc: ^Game_Cache, from: Land_ID, unit_strength: f64) -> Maybe(Land_ID) {
	best_territory: Maybe(Land_ID) = nil
	best_value := 0.0
	
	// Check all territories unit can reach
	// Would use movement range and map graph
	// For now, simplified to adjacent territories
	
	// Evaluate each potential destination
	// Consider: strategic value, defensive need, safety
	
	return best_territory
}

// Cleanup
pro_noncombat_move_cleanup :: proc(targets: ^[dynamic]Defense_Target) {
	delete(targets^)
}


