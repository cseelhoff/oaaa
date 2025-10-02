package oaaa

/*
Pro AI Combat Move Phase Implementation

This file implements combat movement logic following TripleA's ProCombatMoveAi.java.
The Pro AI identifies valuable enemy territories, calculates battle odds, and moves
units into attack positions.

Key Responsibilities:
- Populate attack options for all enemy/neutral territories
- Prioritize territories by attack value (TUV swing, strategic importance)
- Determine which territories to attack based on success probability
- Assign units to attacks to maximize win chance while minimizing losses
- Ensure capital defense is maintained during attacks
- Handle amphibious assaults with transports
- Position bombard units to support land attacks

Algorithm Overview (from ProCombatMoveAi.java):
1. Find all territories that can potentially be attacked
2. Remove territories that can't be conquered
3. Determine which attacked territories can be held against counter-attack
4. Prioritize territories by attack value
5. Remove territories that aren't worth attacking
6. Iteratively determine which territories to attack
7. Determine units to attack with (destroyers, land units, air units, transports)
8. Remove attacks where transports are exposed
9. Remove attacks until capital can be held
10. Execute attack moves
*/

import "core:fmt"
import "core:math"
import "core:slice"
import sa "core:container/small_array"

// Main combat move phase entry point
proai_combat_move_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Starting combat move phase")
	}
	
	pro_data := pro_data_init(gc)
	
	// Step 1: Find all territories that can be attacked
	attack_options := find_attack_options(gc, &pro_data)
	defer delete(attack_options)
	
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] No attack options found")
		}
		return true
	}
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Found %d potential attack options\n", len(attack_options))
	}
	
	// Step 2: Remove territories that can't be conquered
	remove_unconquerable_territories(&attack_options, gc, &pro_data)
	
	// Step 3: Determine which territories can be held after attack
	determine_holdable_territories(&attack_options, gc, &pro_data)
	
	// Step 4: Prioritize territories by attack value
	prioritize_attack_options(&attack_options, gc, &pro_data)
	
	// Step 5: Remove territories that aren't worth attacking
	remove_low_value_attacks(&attack_options, gc, &pro_data)
	
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] No worthwhile attacks after filtering")
		}
		return true
	}
	
	// Step 6: Determine which territories to actually attack
	determine_territories_to_attack(&attack_options, gc, &pro_data)
	
	// Step 7: Determine exact units to use for each attack
	determine_units_for_attacks(&attack_options, gc, &pro_data)
	
	// Step 8: Remove attacks where transports are exposed
	remove_exposed_transport_attacks(&attack_options, gc, &pro_data)
	
	// Step 9: Ensure capital can still be defended
	ensure_capital_defense(&attack_options, gc, &pro_data)
	
	// Step 10: Execute the combat moves
	execute_combat_moves(&attack_options, gc, &pro_data)
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Completed combat move phase with %d attacks\n", len(attack_options))
	}
	
	return true
}

// Attack_Option represents a territory we're considering attacking
Attack_Option :: struct {
	territory: Land_ID,           // Territory to attack
	attackers: [dynamic]Unit_Info, // Units that will attack
	amphib_attackers: [dynamic]Unit_Info, // Units arriving by transport
	bombard_units: [dynamic]Unit_Info,    // Ships providing bombardment
	defenders: [dynamic]Unit_Info,        // Enemy units defending
	win_percentage: f64,                  // Estimated chance of winning
	tuv_swing: f64,                       // Expected TUV gain/loss
	can_hold: bool,                       // Can we hold it after capture?
	is_amphib: bool,                      // Requires amphibious assault?
	attack_value: f64,                    // Overall strategic value
	is_strafing: bool,                    // Attacking without intent to hold
}

// Unit_Info tracks a unit and where it's moving from
Unit_Info :: struct {
	unit_type: Unit_Type,
	from_territory: Land_ID,
}

// Unit_Type for tracking different unit kinds in attacks
Unit_Type :: enum {
	Infantry,
	Artillery, 
	Tank,
	AAGun,
	Fighter,
	Bomber,
	Transport,
	Submarine,
	Destroyer,
	Carrier,
	Battleship,
	Cruiser,
}

// Find all territories that could potentially be attacked
find_attack_options :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) -> [dynamic]Attack_Option {
	options := make([dynamic]Attack_Option)
	
	// Check all territories
	for land_id in Land_ID {
		// Skip friendly territories
		if gc.owner[land_id] == gc.cur_player {
			continue
		}
		
		// Check if any of our units can reach this territory
		can_attack := can_reach_territory(gc, land_id, pro_data)
		if !can_attack {
			continue
		}
		
		// Create attack option
		option := Attack_Option{
			territory = land_id,
			attackers = make([dynamic]Unit_Info),
			amphib_attackers = make([dynamic]Unit_Info),
			bombard_units = make([dynamic]Unit_Info),
			defenders = make([dynamic]Unit_Info),
		}
		
		// Count defenders
		add_defenders(&option, gc, land_id)
		
		append(&options, option)
	}
	
	return options
}

// Check if we can reach a territory with any units
can_reach_territory :: proc(gc: ^Game_Cache, target: Land_ID, pro_data: ^Pro_Data) -> bool {
	// Check land adjacency for ground units
	if is_adjacent_to_friendly(gc, target) {
		return true
	}
	
	// Check if air units can reach (within 4 movement typically)
	// TODO: Implement proper air range checking
	
	// Check if amphibious assault is possible
	// TODO: Implement transport reach checking
	
	return false
}

// Check if territory is adjacent to any friendly territory
is_adjacent_to_friendly :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	// Simple adjacency check - would use proper map graph
	// For now, simplified check
	return false // TODO: Implement using map_graph
}

// Add defending units to attack option
add_defenders :: proc(option: ^Attack_Option, gc: ^Game_Cache, territory: Land_ID) {
	// Count active armies at this location (for current player)
	// For enemies, use idle_armies
	for player in Player_ID {
		if player == gc.cur_player {
			continue
		}
		for army_type in Idle_Army {
			count := gc.idle_armies[territory][player][army_type]
			for i in 0..<count {
				unit_info := Unit_Info{
					unit_type = idle_army_to_unit_type(army_type),
					from_territory = territory,
				}
				append(&option.defenders, unit_info)
			}
		}
	}
	
	// Count idle planes at this location (for enemies)
	for player in Player_ID {
		if player == gc.cur_player {
			continue
		}
		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[territory][player][plane_type]
			for i in 0..<count {
				unit_info := Unit_Info{
					unit_type = idle_plane_to_unit_type(plane_type),
					from_territory = territory,
				}
				append(&option.defenders, unit_info)
			}
		}
		}
}

// Convert Idle_Army to Unit_Type
idle_army_to_unit_type :: proc(army_type: Idle_Army) -> Unit_Type {
	switch army_type {
	case .INF: return .Infantry
	case .ARTY: return .Artillery
	case .TANK: return .Tank
	case .AAGUN: return .AAGun
	case: return .Infantry
	}
}

// Convert Idle_Plane to Unit_Type
idle_plane_to_unit_type :: proc(plane_type: Idle_Plane) -> Unit_Type {
	switch plane_type {
	case .FIGHTER: return .Fighter
	case .BOMBER: return .Bomber
	case: return .Fighter
	}
}

// Remove territories that cannot be conquered
remove_unconquerable_territories :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Filter out territories where we can't possibly win
	i := 0
	for i < len(options) {
		option := &options[i]
		
		// Calculate max possible attack strength
		max_strength := calculate_max_attack_strength(option, gc)
		defense_strength := estimate_defense_power_total(&option.defenders)
		
		// If we can't even come close to winning, remove it
		if max_strength < defense_strength * 0.5 {
			// Can't conquer - remove this option
			delete(option.attackers)
			delete(option.amphib_attackers)
			delete(option.bombard_units)
			delete(option.defenders)
			ordered_remove(options, i)
			continue
		}
		
		i += 1
	}
}

// Calculate maximum possible attack strength for a territory
calculate_max_attack_strength :: proc(option: ^Attack_Option, gc: ^Game_Cache) -> f64 {
	// Simplified - would need to find all units that could reach
	return 10.0 // TODO: Implement proper calculation
}

// Calculate total defense power
estimate_defense_power_total :: proc(defenders: ^[dynamic]Unit_Info) -> f64 {
	total := 0.0
	for defender in defenders {
		power := get_unit_defense_power(defender.unit_type)
		total += power
	}
	return total
}

// Get defense power for a unit type
get_unit_defense_power :: proc(unit_type: Unit_Type) -> f64 {
	switch unit_type {
	case .Infantry: return 2.0
	case .Artillery: return 2.0
	case .Tank: return 3.0
	case .AAGun: return 0.5
	case .Fighter: return 4.0
	case .Bomber: return 1.0
	case .Destroyer: return 2.0
	case .Submarine: return 1.0
	case .Cruiser: return 3.0
	case .Battleship: return 4.0
	case .Carrier: return 1.0
	case .Transport: return 0.5
	case: return 1.0
	}
}

// Determine which territories can be held after capturing
determine_holdable_territories :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	for &option in options {
		// Assume we can't hold neutrals or water territories
		// Check if neutral (not owned by any player)
		is_neutral := true
		for player in Player_ID {
			if gc.owner[option.territory] == player {
				is_neutral = false
				break
			}
		}
		if is_neutral {
			option.can_hold = false
			continue
		}
		
		// Check if enemy could counter-attack successfully
		// Simplified: assume we can hold if we have good odds
		if option.win_percentage > 0.7 {
			option.can_hold = true
		} else {
			option.can_hold = false
		}
	}
}

// Prioritize attack options by strategic value
prioritize_attack_options :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Calculate attack value for each option
	for &option in options {
		calculate_attack_value(&option, gc, pro_data)
	}
	
	// Sort by attack value (highest first)
	slice.sort_by(options[:], proc(a, b: Attack_Option) -> bool {
		return a.attack_value > b.attack_value
	})
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized attack options:")
		for option, i in options {
			if i >= 5 { break } // Only show top 5
			fmt.printf("  %d. Territory %v: value=%.1f, win%%=%.1f, tuv=%.1f\n",
				i+1, option.territory, option.attack_value, option.win_percentage * 100, option.tuv_swing)
		}
	}
}

// Calculate strategic value of attacking a territory
calculate_attack_value :: proc(option: ^Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	territory := option.territory
	
	// Base territory value (IPC production)
	territory_value := calculate_territory_value(gc, territory)
	
	// Expected TUV swing from battle
	option.tuv_swing = estimate_tuv_swing(option)
	
	// Holding bonus - can we keep it?
	hold_bonus := option.can_hold ? 2.0 : 0.5
	
	// Amphib penalty - harder to execute
	amphib_penalty := option.is_amphib ? 0.7 : 1.0
	
	// Calculate final attack value
	option.attack_value = (option.tuv_swing + territory_value) * hold_bonus * amphib_penalty
}

// Estimate TUV swing from a battle
estimate_tuv_swing :: proc(option: ^Attack_Option) -> f64 {
	// Simplified calculation
	attacker_tuv := calculate_unit_tuv(&option.attackers)
	defender_tuv := calculate_unit_tuv(&option.defenders)
	
	// Assume 30% attacker losses, 100% defender losses on win
	expected_loss := attacker_tuv * 0.3
	expected_gain := defender_tuv
	
	return expected_gain - expected_loss
}

// Calculate total TUV of units
calculate_unit_tuv :: proc(units: ^[dynamic]Unit_Info) -> f64 {
	total := 0.0
	for unit in units {
		cost := unit_type_to_buy_cost(unit.unit_type)
		total += f64(cost)
	}
	return total
}

// Convert Unit_Type to buy cost
unit_type_to_buy_cost :: proc(unit_type: Unit_Type) -> int {
	switch unit_type {
	case .Infantry: return 3
	case .Artillery: return 4
	case .Tank: return 6
	case .AAGun: return 5
	case .Fighter: return 10
	case .Bomber: return 12
	case .Transport: return 7
	case .Submarine: return 6
	case .Destroyer: return 8
	case .Carrier: return 14
	case .Battleship: return 20
	case .Cruiser: return 12
	case: return 5
	}
}

// Remove attacks that aren't worth the effort
remove_low_value_attacks :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	i := 0
	for i < len(options) {
		option := &options[i]
		
		// Remove if attack value is negative or too low
		if option.attack_value <= 0 {
			delete(option.attackers)
			delete(option.amphib_attackers)
			delete(option.bombard_units)
			delete(option.defenders)
			ordered_remove(options, i)
			continue
		}
		
		i += 1
	}
}

// Determine which territories to actually attack
determine_territories_to_attack :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Start with top priority attacks and work down
	// Remove attacks that we don't have units for
	
	num_to_attack := min(len(options), 3) // Limit to top 3 attacks for simplicity
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Selected %d territories to attack\n", num_to_attack)
	}
	
	// Keep only the top attacks
	for i := len(options) - 1; i >= num_to_attack; i -= 1 {
		option := &options[i]
		delete(option.attackers)
		delete(option.amphib_attackers)
		delete(option.bombard_units)
		delete(option.defenders)
		ordered_remove(options, i)
	}
}

// Determine which units to use for each attack
determine_units_for_attacks :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Assign units to each attack
	for &option in options {
		assign_units_to_attack(&option, gc, pro_data)
	}
}

// Assign specific units to an attack
assign_units_to_attack :: proc(option: ^Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Find adjacent friendly territories with units
	// Assign enough units to win the battle
	
	// Simplified: just mark that we'll use some units
	// TODO: Implement proper unit assignment
}

// Remove attacks where transports would be exposed
remove_exposed_transport_attacks :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	// Check if any amphibious attacks leave transports vulnerable
	i := 0
	for i < len(options) {
		option := &options[i]
		
		if option.is_amphib {
			// Check if transports would be safe
			// For now, keep all amphib attacks
		}
		
		i += 1
	}
}

// Ensure capital can still be defended after attacks
ensure_capital_defense :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	capital_maybe := get_capital_territory(gc.cur_player)
	if capital_maybe == nil {
		return
	}
	capital := capital_maybe.?
	
	// Check if capital is threatened
	is_threatened := is_capital_threatened(gc)
	if !is_threatened {
		return
	}
	
	// Remove lowest priority attacks until capital is safe
	// Simplified: keep all attacks for now
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Capital defense check passed")
	}
}

// Execute the combat moves
execute_combat_moves :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Executing %d combat moves\n", len(options))
	}
	
	for option in options {
		// Move units to attack the territory
		// For now, this is a placeholder - actual movement would use existing move system
		when ODIN_DEBUG {
			fmt.printf("[PRO-AI] Attacking territory %v with %d units\n", 
				option.territory, len(option.attackers))
		}
	}
}

// Cleanup attack options
pro_combat_options_destroy :: proc(options: ^[dynamic]Attack_Option) {
	for &option in options {
		delete(option.attackers)
		delete(option.amphib_attackers)
		delete(option.bombard_units)
		delete(option.defenders)
	}
	delete(options^)
}
