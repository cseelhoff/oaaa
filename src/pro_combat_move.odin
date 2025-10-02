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
	
	// Check if air units can reach (fighters can reach 4 moves, bombers 6 moves)
	if can_air_units_reach(gc, target) {
		return true
	}
	
	// Check if amphibious assault is possible
	// TODO: Implement transport reach checking
	// For now, check if target is coastal and we have transports
	if is_coastal_and_reachable_by_transport(gc, target) {
		return true
	}
	
	return false
}

// Check if territory is adjacent to any friendly territory
is_adjacent_to_friendly :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	// Check all adjacent land territories using OAAA map graph
	for adjacent in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if gc.owner[adjacent] == gc.cur_player {
			return true
		}
		// Also check allied territories
		if mm.team[gc.owner[adjacent]] == mm.team[gc.cur_player] {
			return true
		}
	}
	
	// Check if we have ships in adjacent seas
	for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[territory]) {
		if has_friendly_ships(gc, adjacent_sea) {
			return true
		}
	}
	
	return false
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
	/*
	Find all units that could potentially reach this territory:
	1. Land units in adjacent territories (1-move infantry/artillery, 2-move tanks)
	2. Air units within range (4-move fighters, 6-move bombers)
	3. Naval bombardment from adjacent seas (cruisers, battleships)
	4. Amphibious units that could be transported
	
	Uses OAAA combat value constants from combat.odin
	*/
	total_strength := 0.0
	target := option.territory
	
	// Land units in adjacent territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player do continue
		
		// Infantry and Artillery (1-move units)
		total_strength += f64(gc.idle_armies[adjacent][gc.cur_player][.INF]) * INFANTRY_ATTACK
		total_strength += f64(gc.idle_armies[adjacent][gc.cur_player][.ARTY]) * ARTILLERY_ATTACK
		// Infantry+Artillery combo bonus
		min_pairs := min(gc.idle_armies[adjacent][gc.cur_player][.INF], 
		                 gc.idle_armies[adjacent][gc.cur_player][.ARTY])
		total_strength += f64(min_pairs) * INFANTRY_ATTACK
	}
	
	// Tanks (2-move units) from extended range
	for land_2away in mm.l2l_2away_via_land_bitset[target] {
		if gc.owner[land_2away] != gc.cur_player do continue
		total_strength += f64(gc.idle_armies[land_2away][gc.cur_player][.TANK]) * TANK_ATTACK
	}
	
	// Air units (fighters 4-move, bombers 6-move)
	target_air := to_air(target)
	target_bitset: Air_Bitset
	add_air(&target_bitset, target_air)
	
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player do continue
		src_air := to_air(land)
		
		// Fighters within 4 moves
		if (mm.a2a_within_4_moves[src_air] & target_bitset) != {} {
			total_strength += f64(gc.idle_land_planes[land][gc.cur_player][.FIGHTER]) * FIGHTER_ATTACK
		}
		
		// Bombers within 6 moves
		if (mm.a2a_within_6_moves[src_air] & target_bitset) != {} {
			total_strength += f64(gc.idle_land_planes[land][gc.cur_player][.BOMBER]) * BOMBER_ATTACK
		}
	}
	
	// Naval bombardment from adjacent seas
	for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[target]) {
		// Cruisers and Battleships can bombard
		total_strength += f64(gc.idle_ships[adjacent_sea][gc.cur_player][.CRUISER]) * CRUISER_ATTACK
		total_strength += f64(gc.idle_ships[adjacent_sea][gc.cur_player][.BATTLESHIP]) * BATTLESHIP_ATTACK
		total_strength += f64(gc.idle_ships[adjacent_sea][gc.cur_player][.BS_DAMAGED]) * BATTLESHIP_ATTACK
	}
	
	return total_strength
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
	
	// Show final attack plan with actual win percentages
	when ODIN_DEBUG {
		if len(options) > 0 {
			fmt.println("[PRO-AI] Final attack plan:")
			for option, i in options {
				fmt.printf("  %d. Territory %v: %d units, win%%=%.1f%%, value=%.1f\n",
					i+1, option.territory, len(option.attackers), 
					option.win_percentage * 100, option.attack_value)
			}
		}
	}
}

// Assign specific units to an attack
assign_units_to_attack :: proc(option: ^Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	Unit Assignment Strategy (based on TripleA Pro AI):
	1. Calculate required attack power to achieve 70%+ win probability
	2. Assign units in order of efficiency (attack power per cost)
	3. Prefer expendable units (infantry) over valuable ones (tanks)
	4. Add air support if needed to tip the odds
	5. Include naval bombardment for amphibious assaults
	
	Unit Assignment Priority:
	- Infantry first (cheapest, 3 IPCs)
	- Artillery second (support bonus, 4 IPCs)
	- Tanks third (expensive but powerful, 6 IPCs)
	- Fighters if air superiority needed (10 IPCs)
	- Bombers as last resort (expensive, 12 IPCs)
	*/
	target := option.territory
	
	// Calculate target attack power (need ~1.5x defender power for 70% win chance)
	defense_power := estimate_defense_power_total(&option.defenders)
	target_attack_power := defense_power * 1.5
	current_attack_power := 0.0
	
	// Phase 1: Assign land units from adjacent territories
	// Prefer infantry → artillery → tanks (cost efficiency order)
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player do continue
		
		// Add infantry (cheapest, most expendable)
		inf_count := gc.idle_armies[adjacent][gc.cur_player][.INF]
		for i in 0..<inf_count {
			if current_attack_power >= target_attack_power do break
			
			unit_info := Unit_Info{
				unit_type = .Infantry,
				from_territory = adjacent,
			}
			append(&option.attackers, unit_info)
			current_attack_power += f64(INFANTRY_ATTACK)
		}
		
		// Add artillery (support bonus + own attack)
		arty_count := gc.idle_armies[adjacent][gc.cur_player][.ARTY]
		for i in 0..<arty_count {
			if current_attack_power >= target_attack_power do break
			
			unit_info := Unit_Info{
				unit_type = .Artillery,
				from_territory = adjacent,
			}
			append(&option.attackers, unit_info)
			// Artillery gives bonus to one infantry and has own attack
			current_attack_power += f64(ARTILLERY_ATTACK + INFANTRY_ATTACK)
		}
	}
	
	// Phase 2: Add tanks from extended range if needed
	if current_attack_power < target_attack_power {
		for land_2away in mm.l2l_2away_via_land_bitset[target] {
			if gc.owner[land_2away] != gc.cur_player do continue
			
			tank_count := gc.idle_armies[land_2away][gc.cur_player][.TANK]
			for i in 0..<tank_count {
				if current_attack_power >= target_attack_power do break
				
				unit_info := Unit_Info{
					unit_type = .Tank,
					from_territory = land_2away,
				}
				append(&option.attackers, unit_info)
				current_attack_power += f64(TANK_ATTACK)
			}
		}
	}
	
	// Phase 3: Add air support if needed
	if current_attack_power < target_attack_power {
		target_air := to_air(target)
		target_bitset: Air_Bitset
		add_air(&target_bitset, target_air)
		
		// Add fighters (better cost efficiency than bombers)
		for land in Land_ID {
			if gc.owner[land] != gc.cur_player do continue
			if current_attack_power >= target_attack_power do break
			
			src_air := to_air(land)
			if (mm.a2a_within_4_moves[src_air] & target_bitset) == {} do continue
			
			fighter_count := gc.idle_land_planes[land][gc.cur_player][.FIGHTER]
			for i in 0..<fighter_count {
				if current_attack_power >= target_attack_power do break
				
				unit_info := Unit_Info{
					unit_type = .Fighter,
					from_territory = land,
				}
				append(&option.attackers, unit_info)
				current_attack_power += f64(FIGHTER_ATTACK)
			}
		}
		
		// Add bombers as last resort
		for land in Land_ID {
			if gc.owner[land] != gc.cur_player do continue
			if current_attack_power >= target_attack_power do break
			
			src_air := to_air(land)
			if (mm.a2a_within_6_moves[src_air] & target_bitset) == {} do continue
			
			bomber_count := gc.idle_land_planes[land][gc.cur_player][.BOMBER]
			for i in 0..<bomber_count {
				if current_attack_power >= target_attack_power do break
				
				unit_info := Unit_Info{
					unit_type = .Bomber,
					from_territory = land,
				}
				append(&option.attackers, unit_info)
				current_attack_power += f64(BOMBER_ATTACK)
			}
		}
	}
	
	// Phase 4: Calculate win percentage based on assigned units
	option.win_percentage = estimate_battle_odds(current_attack_power, defense_power)
	
	when ODIN_DEBUG {
		if len(option.attackers) > 0 {
			fmt.printf("[PRO-AI] Assigned %d units to attack %v (attack=%.1f def=%.1f win=%.1f%%)\n",
				len(option.attackers), target, current_attack_power, defense_power, 
				option.win_percentage * 100)
		}
	}
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
	/*
	Capital Defense Algorithm (based on TripleA ProCombatMoveAi):
	1. Calculate current defenders at capital
	2. Calculate max enemy attack power from reachable territories
	3. Track units we're sending away in planned attacks
	4. Calculate remaining defenders after attacks
	5. If remaining defenders < enemy attack power, cancel lowest priority attacks
	6. Repeat until capital is safe OR we cancel all attacks
	
	Key Insight: We must account for units we're moving AWAY from capital area
	*/
	capital_maybe := get_capital_territory(gc.cur_player)
	if capital_maybe == nil {
		return
	}
	capital := capital_maybe.?
	
	// Calculate current defense power at capital
	current_defense := calculate_capital_defense_power(gc, capital)
	
	// Add potential defenders that could be purchased with remaining money
	// (Following TripleA's ProCombatMoveAi.java line 1808-1813)
	max_purchasable_defenders := calculate_max_purchasable_defenders(gc, capital)
	total_available_defense := current_defense + max_purchasable_defenders
	
	// Calculate maximum enemy attack power on capital
	enemy_attack_power := calculate_enemy_threat_to_capital(gc, capital)
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Capital %v: current_defense=%.1f, purchasable=%.1f, total=%.1f, threat=%.1f\n",
			capital, current_defense, max_purchasable_defenders, total_available_defense, enemy_attack_power)
	}
	
	// If not threatened (even without purchases), no need to adjust
	if enemy_attack_power < total_available_defense * 0.7 {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] Capital is safe, no adjustments needed")
		}
		return
	}
	
	// Calculate how many units we're moving away from capital area
	units_leaving := calculate_units_leaving_capital_area(options, gc, capital)
	
	// Remaining defense after our attacks (includes potential purchases)
	remaining_defense := total_available_defense - units_leaving
	
	// We need at least 1.3x enemy power for safety (defensive advantage)
	required_defense := enemy_attack_power * 1.3
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Remaining defense: %.1f, required: %.1f\n",
			remaining_defense, required_defense)
	}
	
	// If capital is safe after attacks, we're good
	if remaining_defense >= required_defense {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] Capital will remain safe after attacks")
		}
		return
	}
	
	// Capital is threatened - cancel attacks starting from lowest priority
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Capital threatened, canceling low-priority attacks")
	}
	
	// Remove attacks from end (lowest priority) until capital is safe
	for i := len(options) - 1; i >= 0; i -= 1 {
		option := &options[i]
		
		// Calculate how much defense this attack takes away
		attack_cost := calculate_attack_defense_cost(option, capital)
		
		// Cancel this attack
		when ODIN_DEBUG {
			fmt.printf("[PRO-AI] Canceling attack on %v (frees %.1f defense)\n",
				option.territory, attack_cost)
		}
		
		delete(option.attackers)
		delete(option.amphib_attackers)
		delete(option.bombard_units)
		delete(option.defenders)
		ordered_remove(options, i)
		
		// Recalculate remaining defense
		remaining_defense += attack_cost
		
		// Check if capital is now safe
		if remaining_defense >= required_defense {
			when ODIN_DEBUG {
				fmt.println("[PRO-AI] Capital is now safe after cancellations")
			}
			break
		}
	}
	
	// Final warning if we had to cancel all attacks
	if len(options) == 0 && remaining_defense < required_defense {
		when ODIN_DEBUG {
			fmt.println("[PRO-AI] WARNING: Capital still threatened even after canceling all attacks")
		}
	}
}

// Calculate current defense power at capital
calculate_capital_defense_power :: proc(gc: ^Game_Cache, capital: Land_ID) -> f64 {
	defense := 0.0
	
	// Land units (use defense values from combat.odin)
	inf_defense := f64(gc.idle_armies[capital][gc.cur_player][.INF]) * INFANTRY_DEFENSE
	arty_defense := f64(gc.idle_armies[capital][gc.cur_player][.ARTY]) * ARTILLERY_DEFENSE
	tank_defense := f64(gc.idle_armies[capital][gc.cur_player][.TANK]) * TANK_DEFENSE
	// AA guns don't add to defense (special AA role only)
	
	// Air units
	fighter_defense := f64(gc.idle_land_planes[capital][gc.cur_player][.FIGHTER]) * FIGHTER_DEFENSE
	bomber_defense := f64(gc.idle_land_planes[capital][gc.cur_player][.BOMBER]) * BOMBER_DEFENSE
	
	defense = inf_defense + arty_defense + tank_defense + fighter_defense + bomber_defense
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI DEBUG] Capital %v defense:\n", capital)
		if gc.idle_armies[capital][gc.cur_player][.INF] > 0 {
			fmt.printf("  %d INF * %.1f = %.1f\n", 
				gc.idle_armies[capital][gc.cur_player][.INF], INFANTRY_DEFENSE, inf_defense)
		}
		if gc.idle_armies[capital][gc.cur_player][.ARTY] > 0 {
			fmt.printf("  %d ARTY * %.1f = %.1f\n",
				gc.idle_armies[capital][gc.cur_player][.ARTY], ARTILLERY_DEFENSE, arty_defense)
		}
		if gc.idle_armies[capital][gc.cur_player][.TANK] > 0 {
			fmt.printf("  %d TANK * %.1f = %.1f\n",
				gc.idle_armies[capital][gc.cur_player][.TANK], TANK_DEFENSE, tank_defense)
		}
		if gc.idle_land_planes[capital][gc.cur_player][.FIGHTER] > 0 {
			fmt.printf("  %d FIGHTER * %.1f = %.1f\n",
				gc.idle_land_planes[capital][gc.cur_player][.FIGHTER], FIGHTER_DEFENSE, fighter_defense)
		}
		if gc.idle_land_planes[capital][gc.cur_player][.BOMBER] > 0 {
			fmt.printf("  %d BOMBER * %.1f = %.1f\n",
				gc.idle_land_planes[capital][gc.cur_player][.BOMBER], BOMBER_DEFENSE, bomber_defense)
		}
		fmt.printf("  TOTAL DEFENSE: %.1f\n\n", defense)
	}
	
	return defense
}

// Calculate maximum enemy attack power that could reach capital
calculate_enemy_threat_to_capital :: proc(gc: ^Game_Cache, capital: Land_ID) -> f64 {
	/*
	Enemy Threat Calculation (Fixed to match TripleA Pro AI):
	
	KEY INSIGHT: Enemy players cannot coordinate attacks! Each enemy player attacks
	on their own turn. We need to find the MAXIMUM threat from ANY SINGLE enemy player,
	not the sum of all enemies.
	
	For each enemy player, calculate their potential attack power:
	1. Land units that can REACH capital (not just adjacent - need to attack INTO it)
	2. Tanks from territories 2 moves away
	3. Air units within range
	
	Return the maximum threat from any single enemy.
	*/
	max_threat := 0.0
	
	when ODIN_DEBUG {
		fmt.printf("\n[PRO-AI DEBUG] Calculating threat to capital %v:\n", capital)
	}
	
	// Calculate threat from EACH enemy player separately
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		enemy_threat := 0.0
		
		when ODIN_DEBUG {
			fmt.printf("  Analyzing threat from %v:\n", enemy)
		}
		
		// 1. Adjacent land units (can attack capital this turn)
		adjacent_threat := 0.0
		for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
			// Only count if enemy OWNS this territory (can attack FROM it)
			if gc.owner[adjacent] != enemy {
				continue
			}
			
			inf := gc.idle_armies[adjacent][enemy][.INF]
			arty := gc.idle_armies[adjacent][enemy][.ARTY]
			tank := gc.idle_armies[adjacent][enemy][.TANK]
			
			if inf > 0 || arty > 0 || tank > 0 {
				inf_threat := f64(inf) * INFANTRY_ATTACK
				arty_threat := f64(arty) * ARTILLERY_ATTACK
				tank_threat := f64(tank) * TANK_ATTACK
				
				// Infantry+Artillery combo
				min_combo := min(inf, arty)
				combo_bonus := f64(min_combo) * INFANTRY_ATTACK
				
				territory_threat := inf_threat + arty_threat + tank_threat + combo_bonus
				adjacent_threat += territory_threat
				
				when ODIN_DEBUG {
					fmt.printf("    From %v: %d INF=%.1f, %d ARTY=%.1f, %d TANK=%.1f, combo=%.1f (total: %.1f)\n",
						adjacent, inf, inf_threat, arty, arty_threat, tank, tank_threat, combo_bonus, territory_threat)
				}
			}
		}
		enemy_threat += adjacent_threat
		
		when ODIN_DEBUG {
			if adjacent_threat > 0 {
				fmt.printf("    Adjacent land units: %.1f\n", adjacent_threat)
			}
		}
		
		// 2. Tanks from 2-move range (must own territory 1-away from capital to attack through)
		tanks_2away_threat := 0.0
		for land_2away in mm.l2l_2away_via_land_bitset[capital] {
			// Tanks can move 2, but need a valid path through owned/capturable territory
			// Simplified: only count if enemy owns the 2-away territory
			if gc.owner[land_2away] != enemy {
				continue
			}
			
			tanks := gc.idle_armies[land_2away][enemy][.TANK]
			if tanks > 0 {
				tank_threat := f64(tanks) * TANK_ATTACK
				tanks_2away_threat += tank_threat
				when ODIN_DEBUG {
					fmt.printf("    From %v: %d TANK=%.1f (2-move)\n",
						land_2away, tanks, tank_threat)
				}
			}
		}
		enemy_threat += tanks_2away_threat
		
		when ODIN_DEBUG {
			if tanks_2away_threat > 0 {
				fmt.printf("    2-move tanks: %.1f\n", tanks_2away_threat)
			}
		}
		
		// 3. Air units within range
		capital_air := to_air(capital)
		capital_bitset: Air_Bitset
		add_air(&capital_bitset, capital_air)
		
		fighter_threat := 0.0
		bomber_threat := 0.0
		
		for land in Land_ID {
			// Only count planes from territories enemy owns
			if gc.owner[land] != enemy {
				continue
			}
			
			src_air := to_air(land)
			
			// Fighters within 4 moves
			if (mm.a2a_within_4_moves[src_air] & capital_bitset) != {} {
				fighters := gc.idle_land_planes[land][enemy][.FIGHTER]
				if fighters > 0 {
					f_threat := f64(fighters) * FIGHTER_ATTACK
					fighter_threat += f_threat
					when ODIN_DEBUG {
						fmt.printf("    From %v: %d FIGHTER=%.1f (4-move)\n",
							land, fighters, f_threat)
					}
				}
			}
			
			// Bombers within 6 moves
			if (mm.a2a_within_6_moves[src_air] & capital_bitset) != {} {
				bombers := gc.idle_land_planes[land][enemy][.BOMBER]
				if bombers > 0 {
					b_threat := f64(bombers) * BOMBER_ATTACK
					bomber_threat += b_threat
					when ODIN_DEBUG {
						fmt.printf("    From %v: %d BOMBER=%.1f (6-move)\n",
							land, bombers, b_threat)
					}
				}
			}
		}
		enemy_threat += fighter_threat + bomber_threat
		
		when ODIN_DEBUG {
			if fighter_threat > 0 {
				fmt.printf("    Fighters: %.1f\n", fighter_threat)
			}
			if bomber_threat > 0 {
				fmt.printf("    Bombers: %.1f\n", bomber_threat)
			}
			fmt.printf("    %v total threat: %.1f\n", enemy, enemy_threat)
		}
		
		// Track maximum threat from any single enemy
		if enemy_threat > max_threat {
			max_threat = enemy_threat
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("  MAX THREAT (from strongest enemy): %.1f\n\n", max_threat)
	}
	
	return max_threat
}

// Calculate how much defense power we're moving away from capital area
calculate_units_leaving_capital_area :: proc(
	options: ^[dynamic]Attack_Option,
	gc: ^Game_Cache,
	capital: Land_ID,
) -> f64 {
	/*
	A unit "leaves" the capital area if:
	1. It's currently at capital or adjacent to capital
	2. It's being sent to attack a territory
	
	We count its defensive value as "lost" from capital defense.
	*/
	defense_leaving := 0.0
	
	// Create bitset of capital + adjacent territories (capital area)
	capital_area := Land_Bitset{capital}
	for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
		capital_area += {adjacent}
	}
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI DEBUG] Units leaving capital area:\n")
		fmt.print("  Capital area includes: ", capital)
		for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
			fmt.print(", ", adjacent)
		}
		fmt.println()
	}
	
	// Check each attack option
	for option, opt_idx in options {
		option_cost := 0.0
		when ODIN_DEBUG {
			fmt.printf("  Attack on %v:\n", option.territory)
		}
		
		// Check each attacking unit
		for unit in option.attackers {
			// If unit is from capital area and moving away, count its defense
			if unit.from_territory in capital_area && 
			   option.territory not_in capital_area {
				defense_value := get_unit_defense_power(unit.unit_type)
				defense_leaving += defense_value
				option_cost += defense_value
				
				when ODIN_DEBUG {
					fmt.printf("    %v from %v: defense value = %.1f\n",
						unit.unit_type, unit.from_territory, defense_value)
				}
			}
		}
		
		when ODIN_DEBUG {
			if option_cost > 0 {
				fmt.printf("    Subtotal for this attack: %.1f\n", option_cost)
			} else {
				fmt.printf("    (no units leaving capital area)\n")
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("  TOTAL DEFENSE LEAVING: %.1f\n\n", defense_leaving)
	}
	
	return defense_leaving
}

// Calculate how much defense an attack option costs from capital area
calculate_attack_defense_cost :: proc(option: ^Attack_Option, capital: Land_ID) -> f64 {
	cost := 0.0
	
	// Create capital area bitset
	capital_area := Land_Bitset{capital}
	for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
		capital_area += {adjacent}
	}
	
	// Sum up defense value of units leaving capital area
	for unit in option.attackers {
		if unit.from_territory in capital_area && 
		   option.territory not_in capital_area {
			cost += get_unit_defense_power(unit.unit_type)
		}
	}
	
	return cost
}

// Execute the combat moves
execute_combat_moves :: proc(options: ^[dynamic]Attack_Option, gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	Execute all planned combat moves:
	1. Initialize moved units tracker
	2. Execute amphibious assaults (load + move + unload transports)
	3. Move land units to attack positions
	4. Move air units to attack positions
	5. Move naval units to attack positions
	*/
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Executing %d combat moves\n", len(options))
	}
	
	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)
	
	for &option in options {
		when ODIN_DEBUG {
			fmt.printf("[PRO-AI] Attacking territory %v with %d units\n", 
				option.territory, len(option.attackers))
		}
		
		// Handle amphibious assault if needed
		if option.is_amphib && len(option.amphib_attackers) > 0 {
			execute_amphibious_assault(gc, &option, &moved)
		}
		
		// Move land units
		for unit in option.attackers {
			land_unit, ok := convert_unit_type_to_idle_army(unit.unit_type)
			if !ok do continue
			
			success := execute_land_move(
				gc,
				unit.from_territory,
				option.territory,
				land_unit,
				1,  // Move 1 unit at a time (simplification)
				&moved,
			)
			
			if !success {
				when ODIN_DEBUG {
					fmt.eprintfln("[PRO-AI] Failed to move %v from %v to %v",
						land_unit, unit.from_territory, option.territory)
				}
			}
		}
		
		// Move air units
		for unit in option.attackers {
			plane_unit, ok := convert_unit_type_to_idle_plane(unit.unit_type)
			if !ok do continue
			
			src_air := to_air(unit.from_territory)
			dst_air := to_air(option.territory)
			
			success := execute_air_move(
				gc,
				src_air,
				dst_air,
				plane_unit,
				1,  // Move 1 unit at a time
				&moved,
				true,  // Source is land
				true,  // Destination is land
			)
			
			if !success {
				when ODIN_DEBUG {
					fmt.eprintfln("[PRO-AI] Failed to move %v from air %v to air %v",
						plane_unit, src_air, dst_air)
				}
			}
		}
		
		// Naval bombardment units stay in sea zones (don't need to move)
		// They provide support from adjacent seas
	}
}

// Execute amphibious assault using transport system
execute_amphibious_assault :: proc(
	gc: ^Game_Cache,
	option: ^Attack_Option,
	moved: ^Moved_Units,
) {
	/*
	Amphibious Assault Execution:
	1. Create transport plan using pro_transport.odin
	2. Execute plan using pro_transport_execute.odin
	3. Mark units as moved in tracker
	*/
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Executing amphibious assault on %v\n", option.territory)
	}
	
	// Create transport plan for this assault
	// Note: In full implementation, would use proper transport planning
	// For now, this is a placeholder that would call:
	// plan := create_transport_plan(gc, option.territory, pro_data)
	// execute_transport_plan(gc, &plan)
	
	// Mark transported units as moved
	for unit in option.amphib_attackers {
		land_unit, ok := convert_unit_type_to_idle_army(unit.unit_type)
		if !ok do continue
		
		// Track that these units have moved
		if !(unit.from_territory in moved.land_units) {
			moved.land_units[unit.from_territory] = make(map[Idle_Army]u8)
		}
		unit_map := &moved.land_units[unit.from_territory]
		unit_map[land_unit] += 1
	}
}

// Check if air units can reach a territory
can_air_units_reach :: proc(gc: ^Game_Cache, target: Land_ID) -> bool {
	target_air := to_air(target)
	
	// Create a bitset with just the target air position set
	target_bitset: Air_Bitset
	add_air(&target_bitset, target_air)
	
	// Check all territories where we have air units
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player do continue
		
		source_air := to_air(land)
		
		// Check fighters (4 move range)
		if gc.idle_land_planes[land][gc.cur_player][.FIGHTER] > 0 {
			// Check if target is in 4-move range by testing bitwise AND
			reachable := mm.a2a_within_4_moves[source_air] & target_bitset
			if reachable != {} {
				return true
			}
		}
		
		// Check bombers (6 move range)
		if gc.idle_land_planes[land][gc.cur_player][.BOMBER] > 0 {
			// Check if target is in 6-move range
			reachable := mm.a2a_within_6_moves[source_air] & target_bitset
			if reachable != {} {
				return true
			}
		}
	}
	
	// Check air units on carriers in sea zones
	for sea in Sea_ID {
		source_air := to_air(sea)
		
		// Check if we have fighters on carriers
		// Fighters can reach 4 moves from sea zones too
		if gc.idle_sea_planes[sea][gc.cur_player][.FIGHTER] > 0 {
			reachable := mm.a2a_within_4_moves[source_air] & target_bitset
			if reachable != {} {
				return true
			}
		}
	}
	
	return false
}

// Check if territory is coastal and reachable by transport
is_coastal_and_reachable_by_transport :: proc(gc: ^Game_Cache, target: Land_ID) -> bool {
	/*
	Transport Reach Algorithm (based on transport.odin)
	
	Transports can move 1-2 sea zones per turn (MAX_TRANSPORT_MOVES = 2).
	To reach a coastal territory for amphibious assault:
	1. Target must be coastal (has adjacent sea zones)
	2. At least one adjacent sea must be reachable by our transports
	3. Transport reach depends on current sea position and canal state
	4. Transports cannot enter hostile seas without combat ship escort
	
	Key Data Structures:
	- mm.l2s_1away_via_land[target]: Sea zones adjacent to target land
	- mm.s2s_1away_via_sea[canal_state][sea]: Sea zones 1 move from sea
	- mm.s2s_2away_via_sea[canal_state][sea]: Sea zones 2 moves from sea
	- gc.idle_ships[sea][player][.TRANS]: Empty transports at sea
	- gc.active_ships[sea][transport_type]: Loaded/moving transports
	
	Transport States (from transport.odin):
	- Idle: .TRANS (empty), .TRANS_1I/.TRANS_1A/.TRANS_1T (loaded)
	- Active: Various states with move counts (_UNMOVED, _2_MOVES, _1_MOVES, _0_MOVES)
	*/
	
	// Check if territory has coastal access
	adjacent_seas := sa.slice(&mm.l2s_1away_via_land[target])
	if len(adjacent_seas) == 0 {
		return false // Not coastal
	}
	
	// Check each adjacent sea zone to see if transports can reach it
	for target_sea in adjacent_seas {
		// Direct presence: transports already in adjacent sea
		if has_friendly_transports(gc, target_sea) {
			return true
		}
		
		// 1-move reach: transports in seas 1 move away
		for source_sea in Sea_ID {
			if !has_friendly_transports(gc, source_sea) {
				continue
			}
			
			// Check if target_sea is within 1 move from source_sea
			if target_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][source_sea] {
				// Check if path is safe (no enemy blockade without escort)
				if can_transport_safely_move_to(gc, source_sea, target_sea) {
					return true
				}
			}
		}
		
		// 2-move reach: transports in seas 2 moves away
		for source_sea in Sea_ID {
			if !has_friendly_transports(gc, source_sea) {
				continue
			}
			
			// Check if target_sea is within 2 moves from source_sea
			if target_sea in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][source_sea] {
				// Check if path is safe (intermediate seas must be free of enemy blockades)
				if can_transport_safely_move_2_spaces(gc, source_sea, target_sea) {
					return true
				}
			}
		}
	}
	
	return false
}

// Check if transport can safely move to a sea zone (based on transport.odin add_valid_transport_moves)
can_transport_safely_move_to :: proc(gc: ^Game_Cache, from_sea: Sea_ID, to_sea: Sea_ID) -> bool {
	/*
	Transport Safety Rules (from transport.odin line 265-275):
	1. If destination has enemy units (team_sea_units[enemy] > 0)
	2. Then transports can ONLY enter if friendly combat ships present (allied_sea_combatants_total > 0)
	3. This ensures transports don't move through hostile waters without escort
	*/
	
	// Check if destination is hostile
	if gc.team_sea_units[to_sea][mm.enemy_team[gc.cur_player]] > 0 {
		// Hostile sea - need combat ship escort
		if gc.allied_sea_combatants_total[to_sea] == 0 {
			return false // No escort available
		}
	}
	
	return true
}

// Check if transport can safely move 2 spaces (both intermediate and destination must be safe)
can_transport_safely_move_2_spaces :: proc(gc: ^Game_Cache, from_sea: Sea_ID, to_sea: Sea_ID) -> bool {
	/*
	2-Space Movement Rules (from transport.odin line 277-287):
	1. Destination must be safe (no enemies or has escort)
	2. All intermediate sea zones must be free of enemy blockades
	3. Uses mm.s2s_2away_via_midseas to check middle sea zones
	*/
	
	// Check destination safety
	if !can_transport_safely_move_to(gc, from_sea, to_sea) {
		return false
	}
	
	// Check intermediate seas for blockades
	mid_seas := &mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][from_sea]
	for mid_sea in sa.slice(&mid_seas[to_sea]) {
		if gc.enemy_blockade_total[mid_sea] > 0 {
			return false // Path blocked by enemy
		}
	}
	
	return true
}

// Check if we have friendly ships in a sea zone
has_friendly_ships :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	// Check idle ships
	for ship_type in Idle_Ship {
		if gc.idle_ships[sea][gc.cur_player][ship_type] > 0 {
			return true
		}
	}
	
	// Check active ships
	for ship_type in Active_Ship {
		if gc.active_ships[sea][ship_type] > 0 {
			return true
		}
	}
	
	return false
}

// Check if we have friendly transports in a sea zone
has_friendly_transports :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	/*
	Transport Types (from ship.odin and transport.odin):
	
	Idle Transports:
	- .TRANS_EMPTY: Empty transport ready to load
	- .TRANS_1I/.TRANS_1A/.TRANS_1T: Transport with 1 unit loaded
	- .TRANS_2I/.TRANS_1I_1A/.TRANS_1I_1T: Transport with 2 units loaded
	
	Active Transports (from transport.odin line 62-73):
	- States with _UNMOVED, _2_MOVES, _1_MOVES, _0_MOVES suffixes
	- Examples: TRANS_EMPTY_UNMOVED, TRANS_1I_2_MOVES, etc.
	*/
	
	// Check for idle transports (all transport types)
	for transport_type in Idle_Transports {
		if gc.idle_ships[sea][gc.cur_player][transport_type] > 0 {
			return true
		}
	}
	
	// Check for active transports (moving or loaded)
	for ship_type in Active_Ship {
		// Check if it's a transport type (starts with TRANS_)
		ship_name := fmt.tprintf("%v", ship_type)
		if len(ship_name) >= 5 && ship_name[:5] == "TRANS" {
			if gc.active_ships[sea][ship_type] > 0 {
				return true
			}
		}
	}
	
	return false
}

// Estimate battle odds based on attack and defense power
estimate_battle_odds :: proc(attack_power: f64, defense_power: f64) -> f64 {
	/*
	Simplified battle odds estimation based on power ratio:
	- Uses logistic function to estimate win probability
	- Based on TripleA Pro AI's odds calculator
	
	Formula: 1 / (1 + e^(-k * (attack - defense)))
	where k controls steepness of the curve
	
	Interpretation:
	- Ratio > 1.5: ~70-80% win chance
	- Ratio = 1.0: ~50% win chance (even)
	- Ratio < 0.7: ~20-30% win chance
	*/
	if defense_power <= 0.1 {
		return 1.0 // No defenders = guaranteed win
	}
	
	ratio := attack_power / defense_power
	
	// Logistic function for smooth probability curve
	// k=2.5 gives reasonable spread for typical battles
	k := 2.5
	difference := ratio - 1.0
	odds := 1.0 / (1.0 + math.exp(-k * difference))
	
	return math.clamp(odds, 0.0, 1.0)
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
