package oaaa

/*
Pro AI Data Structures

This file contains the data structures used by the Pro AI system, modeled after
TripleA's ProData.java and ProTerritory.java

Key differences from TripleA:
- Uses OAAA's Game_Cache instead of TripleA's GameData
- Data-oriented design for performance
- Simplified structure for fast rollouts
*/

import "core:fmt"

// Pro_Territory represents analysis data for a single territory
// Maps to TripleA's ProTerritory class
Pro_Territory :: struct {
	territory: Land_ID,
	
	// Battle analysis
	can_attack: bool,
	can_hold: bool,
	currently_wins: bool,
	value: f64,
	strength_estimate: f64,
	
	// Battle results
	win_percentage: f64,
	tuv_swing: f64,
	has_land_unit_remaining: bool,
	
	// Units available for attack
	max_fighters: u8,
	max_bombers: u8,
	max_infantry: u8,
	max_artillery: u8,
	max_tanks: u8,
	max_aa_guns: u8,
	
	// Enemy defenders estimate
	enemy_fighters: u8,
	enemy_bombers: u8,
	enemy_infantry: u8,
	enemy_artillery: u8,
	enemy_tanks: u8,
	enemy_aa_guns: u8,
}

// Pro_Sea_Territory represents analysis data for a sea zone
Pro_Sea_Territory :: struct {
	sea_zone: Sea_ID,
	
	// Battle analysis
	can_attack: bool,
	can_hold: bool,
	currently_wins: bool,
	value: f64,
	
	// Battle results
	win_percentage: f64,
	tuv_swing: f64,
	
	// Units available for attack
	max_destroyers: u8,
	max_cruisers: u8,
	max_battleships: u8,
	max_carriers: u8,
	max_subs: u8,
	max_transports: u8,
	
	// Enemy defenders estimate
	enemy_destroyers: u8,
	enemy_cruisers: u8,
	enemy_battleships: u8,
	enemy_carriers: u8,
	enemy_subs: u8,
	enemy_transports: u8,
}

// Pro_Purchase_Option represents a unit type that can be purchased
// Maps to TripleA's ProPurchaseOption class
Pro_Purchase_Option :: struct {
	action: Action_ID,  // Which buy action (BUY_INF_ACTION, etc.)
	cost: u8,
	attack_power: f64,
	defense_power: f64,
	movement: u8,
	quantity: u8,  // How many to buy
}

// Pro_Purchase_Territory represents where units can be placed
// Maps to TripleA's ProPurchaseTerritory class
Pro_Purchase_Territory :: struct {
	territory: Land_ID,
	can_place_land: bool,
	can_place_factory: bool,
	unit_production: u8,  // How many units can be placed here
	
	// Defensive needs
	needs_defense: bool,
	defense_value: f64,
	
	// Units to place here
	infantry_to_place: u8,
	artillery_to_place: u8,
	tanks_to_place: u8,
	aa_guns_to_place: u8,
	fighters_to_place: u8,
	bombers_to_place: u8,
	factories_to_place: u8,

	can_place_territories: Land_Bitset,
}

// Pro_Data is the main data container for Pro AI analysis
// Maps to TripleA's ProData class
Pro_Data :: struct {
	gc: ^Game_Cache,
	player: Player_ID,
	
	// Territory analysis
	land_territories: [Land_ID]Pro_Territory,
	sea_territories: [Sea_ID]Pro_Sea_Territory,
	
	// Purchase planning
	purchase_territories: [Land_ID]Pro_Purchase_Territory,
	money_available: u8,
	
	// Strategic state
	is_defensive_stance: bool,
	capital_threatened: bool,
	
	// Win percentage threshold for attacking
	win_percentage_threshold: f64,
}

// Initialize Pro_Data from Game_Cache
pro_data_init :: proc(gc: ^Game_Cache) -> Pro_Data {
	pd := Pro_Data{
		gc = gc,
		player = gc.cur_player,
		money_available = gc.money[gc.cur_player],
		win_percentage_threshold = 70.0,  // Default: need 70% win chance to attack
	}
	
	// Determine if we're in defensive stance
	// (capital threatened or significantly outmatched)
	pd.is_defensive_stance = is_capital_threatened(gc)
	pd.capital_threatened = pd.is_defensive_stance
	
	return pd
}

// Check if our capital is threatened
is_capital_threatened :: proc(gc: ^Game_Cache) -> bool {
	// Find our capital
	capital, ok := get_capital_territory(gc.cur_player).?
	if !ok do return false
	
	// Check if enemy units are nearby (simplified check)
	// In TripleA this uses ProBattleUtils.territoryHasLocalLandSuperiority
	// For now, just check if we have fewer units than normal
	our_units := count_friendly_units_in_territory(gc, capital)
	
	// If capital has very few defenders, we're threatened
	return our_units < 3
}

// Helper functions
get_capital_territory :: proc(player: Player_ID) -> Maybe(Land_ID) {
	// Map player to their capital territory
	#partial switch player {
	case .Ger:  return Land_ID.Germany
	case .Rus:  return Land_ID.Russia
	case .Jap:  return Land_ID.Japan
	case .Eng:  return Land_ID.United_Kingdom
	case .USA:  return Land_ID.Eastern_United_States
	}
	return nil
}

count_friendly_units_in_territory :: proc(gc: ^Game_Cache, territory: Land_ID) -> int {
	count := 0
	count += int(gc.idle_armies[territory][gc.cur_player][.INF])
	count += int(gc.idle_armies[territory][gc.cur_player][.ARTY])
	count += int(gc.idle_armies[territory][gc.cur_player][.TANK])
	count += int(gc.idle_armies[territory][gc.cur_player][.AAGUN])
	count += int(gc.idle_land_planes[territory][gc.cur_player][.FIGHTER])
	count += int(gc.idle_land_planes[territory][gc.cur_player][.BOMBER])
	return count
}

/*
Pro_My_Move_Options represents the AI's own movement analysis.
Maps to TripleA's ProMyMoveOptions class.

Note: potentialAttackOptions is omitted since OAAA doesn't implement diplomacy/alliances.
This struct is used for both attack_options (combat move) and defend_options (non-combat move).

Key differences from TripleA:
- Uses fixed-size arrays indexed by territory instead of hash maps for cache efficiency
- Uses unit counts instead of per-unit tracking (no Unit objects)
- Optimized for fast MCTS rollouts
*/

// Pro_Transport represents amphibious transport options for a single transport
// Maps to TripleA's ProTransport class
Pro_Transport :: struct {
	transport_sea: Sea_ID,                    // Where the transport is located
	transport_moves_remaining: u8,            // How many movement points left
	
	// For each attack territory, which territories can we load from
	// attack_territory -> load_from_territories
	land_attack_options: [Land_ID]Land_Bitset,
	
	// For sea zone attacks
	sea_attack_options: [Sea_ID]Sea_Bitset,
	
	// Units currently loaded
	loaded_infantry: u8,
	loaded_artillery: u8,
	loaded_tanks: u8,
}

// Pro_My_Move_Options represents the AI's own movement analysis
// Maps to TripleA's ProMyMoveOptions class
Pro_My_Move_Options :: struct {
	// Territory analysis - what can we do at each territory
	// Maps to: Map<Territory, ProTerritory> territoryMap
	land_territory_map: [Land_ID]Pro_Territory,
	sea_territory_map: [Sea_ID]Pro_Sea_Territory,
	
	// Unit move options - which territories can units reach from each source
	// Uses counts per source/unit-type instead of per-unit tracking for performance
	// Maps to: Map<Unit, Set<Territory>> unitMoveMap
	land_unit_destinations: [Land_ID][Active_Army]Land_Bitset,  // src land → army type → reachable land destinations
	air_unit_destinations: [Land_ID][Active_Plane]Air_Bitset,   // src land → plane type → reachable air destinations (land or sea)
	
	// Transport move options
	// Maps to: Map<Unit, Set<Territory>> transportMoveMap
	transport_destinations: [Sea_ID]Sea_Bitset,  // src sea → reachable sea zones for transports
	
	// Bombard options - which land territories can ships bombard from each sea zone
	// Maps to: Map<Unit, Set<Territory>> bombardMap  
	bombard_targets: [Sea_ID]Land_Bitset,  // sea zone with bombard-capable ships → adjacent land targets
	
	// Transport loading and unloading options
	// Maps to: List<ProTransport> transportList
	transport_list: [dynamic]Pro_Transport,
	
	// Bomber strategic targets (for bombing raids on factories)
	// Maps to: Map<Unit, Set<Territory>> bomberMoveMap
	bomber_raid_targets: Air_Bitset,  // territories with factories we can bomb
}

// Initialize a new Pro_My_Move_Options with empty data
pro_my_move_options_init :: proc() -> Pro_My_Move_Options {
	return Pro_My_Move_Options{
		transport_list = make([dynamic]Pro_Transport),
	}
}

// Clear and reset Pro_My_Move_Options for reuse
pro_my_move_options_clear :: proc(options: ^Pro_My_Move_Options) {
	// Clear territory maps
	for land in Land_ID {
		options.land_territory_map[land] = {}
	}
	for sea in Sea_ID {
		options.sea_territory_map[sea] = {}
	}
	
	// Clear unit destinations
	for land in Land_ID {
		for army in Active_Army {
			options.land_unit_destinations[land][army] = {}
		}
		for plane in Active_Plane {
			options.air_unit_destinations[land][plane] = {}
		}
	}
	
	// Clear transport and bombard options
	for sea in Sea_ID {
		options.transport_destinations[sea] = {}
		options.bombard_targets[sea] = {}
	}
	
	// Clear transport list
	clear(&options.transport_list)
	
	// Clear bomber targets
	options.bomber_raid_targets = {}
}

// Free memory used by Pro_My_Move_Options
pro_my_move_options_destroy :: proc(options: ^Pro_My_Move_Options) {
	delete(options.transport_list)
}

/*
=============================================================================
Enemy Attack Options - Per-Enemy and Aggregated Structures
=============================================================================

These structures track what enemy units can attack our territories.
Designed to keep per-enemy data separate for debugging and potential
advanced AI features (like considering allied moves in between enemies).

Maps to TripleA's ProOtherMoveOptions class, but with per-enemy storage.
*/

// Enemy_Territory_Threat represents the max units a single enemy can bring to attack a territory
// This is per-enemy, per-territory analysis
Enemy_Territory_Threat :: struct {
	// Max units this enemy can attack with
	max_fighters: u8,
	max_bombers: u8,
	max_infantry: u8,
	max_artillery: u8,
	max_tanks: u8,
	max_aa_guns: u8,
	
	// For sea territories
	max_destroyers: u8,
	max_cruisers: u8,
	max_battleships: u8,
	max_carriers: u8,
	max_subs: u8,
	max_transports: u8,
	
	// Strength estimate for comparison
	strength_estimate: f64,
	has_land_units: bool,
}

// Per_Enemy_Attack_Options stores attack options for a single enemy player
// Each enemy gets their own instance during analysis
Per_Enemy_Attack_Options :: struct {
	enemy_player: Player_ID,
	
	// What this enemy can attack - indexed by Air_ID for unified land/sea handling
	// Using fixed arrays for cache efficiency
	land_threats: [Land_ID]Enemy_Territory_Threat,
	sea_threats: [Sea_ID]Enemy_Territory_Threat,
}

// Initialize per-enemy attack options
per_enemy_attack_options_init :: proc(enemy: Player_ID) -> Per_Enemy_Attack_Options {
	return Per_Enemy_Attack_Options{
		enemy_player = enemy,
	}
}

// Clear per-enemy attack options for reuse
per_enemy_attack_options_clear :: proc(options: ^Per_Enemy_Attack_Options) {
	for land in Land_ID {
		options.land_threats[land] = {}
	}
	for sea in Sea_ID {
		options.sea_threats[sea] = {}
	}
}

// All_Enemy_Attack_Options stores attack options for ALL enemies, kept separate
// This allows debugging and potential advanced AI features
All_Enemy_Attack_Options :: struct {
	// Per-enemy attack data - indexed by enemy player ID
	per_enemy: [Player_ID]Per_Enemy_Attack_Options,
	
	// Track which enemies have been analyzed
	enemies_analyzed: Player_Bitset,
}

// Initialize all-enemy attack options
all_enemy_attack_options_init :: proc() -> All_Enemy_Attack_Options {
	result := All_Enemy_Attack_Options{}
	for player in Player_ID {
		result.per_enemy[player] = per_enemy_attack_options_init(player)
	}
	return result
}

// Clear all-enemy attack options for reuse
all_enemy_attack_options_clear :: proc(options: ^All_Enemy_Attack_Options) {
	for player in Player_ID {
		per_enemy_attack_options_clear(&options.per_enemy[player])
	}
	options.enemies_analyzed = {}
}

// Pro_Other_Move_Options is the aggregated "totals" structure
// Maps to TripleA's ProOtherMoveOptions class
// This contains the MAX threat across all enemies for each territory
Pro_Other_Move_Options :: struct {
	// Max threat to each territory (aggregated across all enemies)
	// Maps to: Map<Territory, ProTerritory> maxMoveMap in Java
	land_max: [Land_ID]Enemy_Territory_Threat,
	sea_max: [Sea_ID]Enemy_Territory_Threat,
}

// Initialize Pro_Other_Move_Options
pro_other_move_options_init :: proc() -> Pro_Other_Move_Options {
	return Pro_Other_Move_Options{}
}

// Clear Pro_Other_Move_Options for reuse
pro_other_move_options_clear :: proc(options: ^Pro_Other_Move_Options) {
	for land in Land_ID {
		options.land_max[land] = {}
	}
	for sea in Sea_ID {
		options.sea_max[sea] = {}
	}
}

// Calculate strength estimate for a territory threat
// Used for comparing which enemy's attack is strongest
calculate_threat_strength :: proc(threat: ^Enemy_Territory_Threat, is_land: bool) -> f64 {
	if is_land {
		// Land attack strength (attack values)
		return f64(threat.max_infantry) * 1.0 +
		       f64(threat.max_artillery) * 2.0 +
		       f64(threat.max_tanks) * 3.0 +
		       f64(threat.max_fighters) * 3.0 +
		       f64(threat.max_bombers) * 4.0
	} else {
		// Sea attack strength
		return f64(threat.max_subs) * 2.0 +
		       f64(threat.max_destroyers) * 2.0 +
		       f64(threat.max_cruisers) * 3.0 +
		       f64(threat.max_battleships) * 4.0 +
		       f64(threat.max_carriers) * 1.0 +  // Carriers have low attack
		       f64(threat.max_fighters) * 3.0 +
		       f64(threat.max_bombers) * 4.0
	}
}

// Aggregate per-enemy attack options into the totals structure
// Uses max-strength logic matching Java's ProOtherMoveOptions.newMaxMoveMap()
aggregate_enemy_attack_options :: proc(
	all_enemies: ^All_Enemy_Attack_Options,
	totals: ^Pro_Other_Move_Options,
) {
	pro_other_move_options_clear(totals)
	
	// For each land territory, find the max threat across all analyzed enemies
	for land in Land_ID {
		max_strength: f64 = 0
		max_has_land_units := false
		
		for enemy in all_enemies.enemies_analyzed {
			threat := &all_enemies.per_enemy[enemy].land_threats[land]
			current_strength := calculate_threat_strength(threat, true)
			current_has_land := threat.max_infantry > 0 || threat.max_artillery > 0 || threat.max_tanks > 0
			
			// Java logic: prefer threats with land units, then by strength
			should_replace := false
			if current_has_land && !max_has_land_units {
				should_replace = true
			} else if current_has_land == max_has_land_units && current_strength > max_strength {
				should_replace = true
			}
			
			if should_replace {
				totals.land_max[land] = threat^
				totals.land_max[land].strength_estimate = current_strength
				totals.land_max[land].has_land_units = current_has_land
				max_strength = current_strength
				max_has_land_units = current_has_land
			}
		}
	}
	
	// For each sea territory, find the max threat across all analyzed enemies
	for sea in Sea_ID {
		max_strength: f64 = 0
		
		for enemy in all_enemies.enemies_analyzed {
			threat := &all_enemies.per_enemy[enemy].sea_threats[sea]
			current_strength := calculate_threat_strength(threat, false)
			
			if current_strength > max_strength {
				totals.sea_max[sea] = threat^
				totals.sea_max[sea].strength_estimate = current_strength
				max_strength = current_strength
			}
		}
	}
}

// Get max threat to a land territory (convenience function matching Java's getMax())
get_max_land_threat :: proc(options: ^Pro_Other_Move_Options, land: Land_ID) -> ^Enemy_Territory_Threat {
	return &options.land_max[land]
}

// Get max threat to a sea territory (convenience function matching Java's getMax())
get_max_sea_threat :: proc(options: ^Pro_Other_Move_Options, sea: Sea_ID) -> ^Enemy_Territory_Threat {
	return &options.sea_max[sea]
}

// Check if a territory has any enemy threat
has_enemy_threat_land :: proc(options: ^Pro_Other_Move_Options, land: Land_ID) -> bool {
	threat := &options.land_max[land]
	return threat.max_infantry > 0 || threat.max_artillery > 0 || threat.max_tanks > 0 ||
	       threat.max_fighters > 0 || threat.max_bombers > 0
}

has_enemy_threat_sea :: proc(options: ^Pro_Other_Move_Options, sea: Sea_ID) -> bool {
	threat := &options.sea_max[sea]
	return threat.max_subs > 0 || threat.max_destroyers > 0 || threat.max_cruisers > 0 ||
	       threat.max_battleships > 0 || threat.max_carriers > 0 ||
	       threat.max_fighters > 0 || threat.max_bombers > 0
}
