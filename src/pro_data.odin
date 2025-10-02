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
