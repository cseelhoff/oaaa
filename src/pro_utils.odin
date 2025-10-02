package oaaa

/*
Pro AI Utility Functions

Modeled after TripleA's Pro AI utility files:
- ProBattleUtils.java - Battle strength estimation and combat calculations
- ProOddsCalculator.java - Battle odds calculation
- ProTerritoryValueUtils.java - Territory value assessment
- ProPurchaseUtils.java - Purchase option evaluation

Key functions:
- Battle odds estimation
- Territory value calculation
- Unit strength comparison
- TUV (Total Unit Value) calculations
*/

import "core:fmt"
import "core:math"
import sa "core:container/small_array"

// Territory value calculation - how important is this territory?
// Based on IPC value, strategic position, and tactical importance
calculate_territory_value :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	value := f64(0)
	
	// Base value: IPC income (from map data, not gc)
	// TODO: Need to add IPC values to map_data or calculate from ownership
	value += 1.0  // Placeholder - all territories have base value
	
	// Bonus value: Factories are highly valuable
	has_factory := false
	for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if land == territory {
			has_factory = true
			break
		}
	}
	if has_factory {
		value += 10.0
	}
	
	// Strategic value: Capitals worth extra
	if is_capital_territory(territory) {
		value += 20.0
	}
	
	return value
}

is_capital_territory :: proc(territory: Land_ID) -> bool {
	#partial switch territory {
	case .Germany, .Russia, .Japan, .United_Kingdom, .Eastern_United_States:
		return true
	}
	return false
}

// Estimate attack power of units
// Maps to TripleA's estimatePower function
estimate_attack_power :: proc(
	gc: ^Game_Cache,
	infantry: u8,
	artillery: u8,
	tanks: u8,
	fighters: u8,
	bombers: u8,
) -> f64 {
	power := f64(0)
	
	// Infantry: 1 attack (2 if supported by artillery)
	artillery_support := min(artillery, infantry)
	supported_inf := artillery_support
	unsupported_inf := infantry - supported_inf
	power += f64(supported_inf) * 2.0  // Supported inf attacks at 2
	power += f64(unsupported_inf) * 1.0  // Unsupported inf attacks at 1
	
	// Artillery: 2 attack
	power += f64(artillery) * 2.0
	
	// Tanks: 3 attack
	power += f64(tanks) * 3.0
	
	// Fighters: 3 attack
	power += f64(fighters) * 3.0
	
	// Bombers: 4 attack
	power += f64(bombers) * 4.0
	
	return power
}

// Estimate defense power of units
estimate_defense_power :: proc(
	gc: ^Game_Cache,
	infantry: u8,
	artillery: u8,
	tanks: u8,
	aa_guns: u8,
	fighters: u8,
	bombers: u8,
) -> f64 {
	power := f64(0)
	
	// Infantry: 2 defense
	power += f64(infantry) * 2.0
	
	// Artillery: 2 defense
	power += f64(artillery) * 2.0
	
	// Tanks: 3 defense
	power += f64(tanks) * 3.0
	
	// AA Guns: 0 normal defense (but shoot at planes)
	// For now, count AA guns as small defensive value
	power += f64(aa_guns) * 0.5
	
	// Fighters: 4 defense
	power += f64(fighters) * 4.0
	
	// Bombers: 1 defense
	power += f64(bombers) * 1.0
	
	return power
}

// Estimate strength difference between attacker and defender
// Returns > 0 if attacker stronger, < 0 if defender stronger
// Maps to TripleA's estimateStrengthDifference
estimate_strength_difference :: proc(
	attacker_inf: u8, attacker_art: u8, attacker_tanks: u8,
	attacker_fighters: u8, attacker_bombers: u8,
	defender_inf: u8, defender_art: u8, defender_tanks: u8,
	defender_aa: u8, defender_fighters: u8, defender_bombers: u8,
) -> f64 {
	attacker_power := estimate_attack_power(nil, attacker_inf, attacker_art, attacker_tanks, attacker_fighters, attacker_bombers)
	defender_power := estimate_defense_power(nil, defender_inf, defender_art, defender_tanks, defender_aa, defender_fighters, defender_bombers)
	
	// Also consider hit points (each unit can take hits)
	attacker_hp := f64(attacker_inf + attacker_art + attacker_tanks + attacker_fighters + attacker_bombers)
	defender_hp := f64(defender_inf + defender_art + defender_tanks + defender_aa + defender_fighters + defender_bombers)
	
	// Combined strength: 2*HP + Power (matches TripleA formula)
	attacker_strength := 2.0 * attacker_hp + attacker_power
	defender_strength := 2.0 * defender_hp + defender_power
	
	// Return difference as percentage (TripleA formula)
	if defender_strength == 0 {
		return 99999  // Overwhelming attacker advantage
	}
	
	return (attacker_strength - defender_strength) / math.pow(defender_strength, 0.85) * 50.0 + 50.0
}

// Calculate TUV (Total Unit Value) - sum of unit costs
calculate_tuv :: proc(
	inf: u8, art: u8, tanks: u8, aa: u8,
	fighters: u8, bombers: u8,
) -> int {
	tuv := 0
	tuv += int(inf) * 3
	tuv += int(art) * 4
	tuv += int(tanks) * 6
	tuv += int(aa) * 5
	tuv += int(fighters) * 10
	tuv += int(bombers) * 12
	return tuv
}

// Calculate win percentage for a battle (simplified)
// Full implementation would use Monte Carlo battle simulation like TripleA
// For now, use strength difference as proxy
estimate_win_percentage :: proc(strength_diff: f64) -> f64 {
	// Convert strength difference to win percentage
	// strength_diff of 50 = 50% win
	// strength_diff of 70 = 70% win
	// Clamp to 0-100 range
	win_pct := strength_diff
	if win_pct < 0 do win_pct = 0
	if win_pct > 100 do win_pct = 100
	return win_pct
}

// Check if an attack is worthwhile
// Maps to TripleA's logic for determining attack viability
is_attack_worthwhile :: proc(
	win_percentage: f64,
	attacker_tuv: int,
	defender_tuv: int,
	territory_value: f64,
) -> bool {
	// Need reasonable win chance (at least 60%)
	if win_percentage < 60.0 do return false
	
	// Calculate expected TUV swing
	// Simplified: win% * defender_tuv - (1-win%) * attacker_tuv
	expected_tuv_swing := (win_percentage / 100.0) * f64(defender_tuv) - 
	                     (1.0 - win_percentage / 100.0) * f64(attacker_tuv)
	
	// Attack if expected TUV swing positive AND territory valuable
	return expected_tuv_swing > 0 || territory_value >= 3.0
}

// Count enemy units in adjacent territories (threat assessment)
count_adjacent_enemy_units :: proc(gc: ^Game_Cache, territory: Land_ID, player: Player_ID) -> int {
	// TODO: Implement by checking neighbors in map_graph
	// For now, return 0 (will be implemented when integrating with map_graph.odin)
	return 0
}

// Find best factory location based on strategic value
find_best_factory_location :: proc(gc: ^Game_Cache) -> Maybe(Land_ID) {
	best_territory: Maybe(Land_ID) = nil
	best_value := f64(0)
	
	for territory in Land_ID {
		// Can only build factory if we own it and don't have one
		if gc.owner[territory] != gc.cur_player do continue
		
		// Check if already has factory
		has_factory := false
		for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
			if land == territory {
				has_factory = true
				break
			}
		}
		if has_factory do continue
		
		// Calculate strategic value for factory placement
		value := calculate_territory_value(gc, territory)
		
		if value > best_value {
			best_value = value
			best_territory = territory
		}
	}
	
	return best_territory
}
