package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:math"

/*
Enemy Attack Options Generation

This module calculates what enemy units can attack our territories.
It maintains per-enemy data separately, then aggregates into totals.

Workflow:
1. generate_all_enemy_attack_options() - Main entry point
2. For each enemy: generate_single_enemy_attack_options() - Populates per-enemy data
3. aggregate_enemy_attack_options() - Combines into totals (max across all enemies)
*/

// Main entry point: Generate attack options for ALL enemies, then aggregate
// This replaces the old generate_enemy_attack_options
generate_all_enemy_attack_options :: proc(
	gc: ^Game_Cache,
	all_enemies: ^All_Enemy_Attack_Options,
	totals: ^Pro_Other_Move_Options,
) {
	all_enemy_attack_options_clear(all_enemies)
	
	// Generate attack options for each enemy separately
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		generate_single_enemy_attack_options(gc, enemy, &all_enemies.per_enemy[enemy])
		all_enemies.enemies_analyzed += {enemy}
	}
	
	// Aggregate per-enemy data into totals
	aggregate_enemy_attack_options(all_enemies, totals)
}

// Generate attack options for a single enemy player
// Populates the per-enemy attack data structure
generate_single_enemy_attack_options :: proc(
	gc: ^Game_Cache,
	enemy: Player_ID,
	enemy_options: ^Per_Enemy_Attack_Options,
) {
	per_enemy_attack_options_clear(enemy_options)
	enemy_options.enemy_player = enemy
	
	// Create a copy of game cache with enemy as current player
	enemy_gc := gc^
	enemy_gc.cur_player = enemy
	rotate_turns_reset(&enemy_gc)
	refresh_can_fighter_land_here(&enemy_gc)
	refresh_can_bomber_land_here(&enemy_gc)
	
	air_array: Air_ID_Array
	
	// Process each land territory for enemy units
	for src_land in Land_ID {
		enemy_gc.current_territory = to_air(src_land)
		
		// Process fighters from this territory
		if enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			process_enemy_fighters(gc, &enemy_gc, src_land, enemy_options, &air_array)
		}
		
		// Process bombers from this territory
		if enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
			process_enemy_bombers(gc, &enemy_gc, src_land, enemy_options, &air_array)
		}
		
		// Process land units from this territory
		process_enemy_land_units(gc, &enemy_gc, src_land, enemy_options)
	}
	
	// Process sea-based units
	for src_sea in Sea_ID {
		process_enemy_naval_units(gc, &enemy_gc, src_sea, enemy_options)
	}
}

// Check if we care about threats to this land territory
// (only care about our own territories or territories with our units)
is_land_worth_defending :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> bool {
	// Care if we own it
	if gc.owner[dst_land] == gc.cur_player {
		return true
	}
	// Care if we have units there
	if gc.active_armies[dst_land][.INF_1_MOVES] > 0 ||
	   gc.active_armies[dst_land][.ARTY_1_MOVES] > 0 ||
	   gc.active_armies[dst_land][.TANK_2_MOVES] > 0 ||
	   gc.active_armies[dst_land][.AAGUN_1_MOVES] > 0 ||
	   gc.active_land_planes[dst_land][.FIGHTER_UNMOVED] > 0 ||
	   gc.active_land_planes[dst_land][.BOMBER_UNMOVED] > 0 {
		return true
	}
	return false
}

// Check if we care about threats to this sea zone
// (only care if we have ships there)
is_sea_worth_defending :: proc(gc: ^Game_Cache, dst_sea: Sea_ID) -> bool {
	// Check if we have any ships there
	if gc.active_ships[dst_sea][.TRANS_EMPTY_UNMOVED] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_1A_UNMOVED] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_1T_UNMOVED] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_2I_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_1I_1A_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.TRANS_1I_1T_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.SUB_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.DESTROYER_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.CARRIER_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.CRUISER_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.BATTLESHIP_2_MOVES] > 0 ||
	   gc.active_ships[dst_sea][.BS_DAMAGED_2_MOVES] > 0 ||
	   gc.active_sea_planes[dst_sea][.FIGHTER_UNMOVED] > 0 {
		return true
	}
	return false
}

// Process enemy fighters and add threats to destinations
process_enemy_fighters :: proc(
	gc: ^Game_Cache,
	enemy_gc: ^Game_Cache,
	src_land: Land_ID,
	enemy_options: ^Per_Enemy_Attack_Options,
	air_array: ^Air_ID_Array,
) {
	fighter_count := enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
	
	get_airs(get_valid_unmoved_fighter_moves(enemy_gc), air_array)
	for dst in sa.slice(air_array) {
		if is_land(dst) {
			dst_land := to_land(dst)
			if !is_land_worth_defending(gc, dst_land) {
				continue
			}
			enemy_options.land_threats[dst_land].max_fighters += fighter_count
		} else {
			dst_sea := to_sea(dst)
			if !is_sea_worth_defending(gc, dst_sea) {
				continue
			}
			enemy_options.sea_threats[dst_sea].max_fighters += fighter_count
		}
	}
}

// Process enemy bombers and add threats to destinations
process_enemy_bombers :: proc(
	gc: ^Game_Cache,
	enemy_gc: ^Game_Cache,
	src_land: Land_ID,
	enemy_options: ^Per_Enemy_Attack_Options,
	air_array: ^Air_ID_Array,
) {
	bomber_count := enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED]
	
	get_airs(get_valid_unmoved_bomber_moves(enemy_gc), air_array)
	for dst in sa.slice(air_array) {
		if is_land(dst) {
			dst_land := to_land(dst)
			if !is_land_worth_defending(gc, dst_land) {
				continue
			}
			enemy_options.land_threats[dst_land].max_bombers += bomber_count
		} else {
			dst_sea := to_sea(dst)
			if !is_sea_worth_defending(gc, dst_sea) {
				continue
			}
			enemy_options.sea_threats[dst_sea].max_bombers += bomber_count
		}
	}
}

// Process enemy land units (infantry, artillery, tanks) and add threats
process_enemy_land_units :: proc(
	gc: ^Game_Cache,
	enemy_gc: ^Game_Cache,
	src_land: Land_ID,
	enemy_options: ^Per_Enemy_Attack_Options,
) {
	infantry_count := enemy_gc.active_armies[src_land][.INF_1_MOVES]
	artillery_count := enemy_gc.active_armies[src_land][.ARTY_1_MOVES]
	tank_count := enemy_gc.active_armies[src_land][.TANK_2_MOVES]
	
	// 1-space land movement for infantry, artillery, tanks
	for dst in mm.l2l_1away_via_land_bitset[src_land] {
		if !is_land_worth_defending(gc, dst) {
			continue
		}
		enemy_options.land_threats[dst].max_infantry += infantry_count
		enemy_options.land_threats[dst].max_artillery += artillery_count
		enemy_options.land_threats[dst].max_tanks += tank_count
	}
	
	// 2-space movement for tanks (blitz)
	for dst in mm.l2l_2away_via_land_bitset[src_land] {
		if !is_land_worth_defending(gc, dst) {
			continue
		}
		// Check if there's a valid blitz path (midland not blocked by our units/factories)
		midlands := mm.l2l_2away_via_midland_bitset[src_land][dst]
		// Enemy can blitz through if midland doesn't have our units or factories
		// From enemy perspective: their "enemy" is us, so check if midland is clear
		can_blitz := (midlands & ~enemy_gc.has_enemy_factory & ~enemy_gc.has_enemy_armies) != {}
		if can_blitz {
			enemy_options.land_threats[dst].max_tanks += tank_count
		}
	}
}

// Process enemy naval units and add threats to sea zones
process_enemy_naval_units :: proc(
	gc: ^Game_Cache,
	enemy_gc: ^Game_Cache,
	src_sea: Sea_ID,
	enemy_options: ^Per_Enemy_Attack_Options,
) {
	// Get enemy ship counts
	sub_count := enemy_gc.active_ships[src_sea][.SUB_2_MOVES]
	destroyer_count := enemy_gc.active_ships[src_sea][.DESTROYER_2_MOVES]
	cruiser_count := enemy_gc.active_ships[src_sea][.CRUISER_2_MOVES]
	carrier_count := enemy_gc.active_ships[src_sea][.CARRIER_2_MOVES]
	battleship_count := enemy_gc.active_ships[src_sea][.BATTLESHIP_2_MOVES] + 
	                    enemy_gc.active_ships[src_sea][.BS_DAMAGED_2_MOVES]
	transport_count := enemy_gc.active_ships[src_sea][.TRANS_EMPTY_UNMOVED] +
	                   enemy_gc.active_ships[src_sea][.TRANS_1I_UNMOVED] +
	                   enemy_gc.active_ships[src_sea][.TRANS_1A_UNMOVED] +
	                   enemy_gc.active_ships[src_sea][.TRANS_1T_UNMOVED] +
	                   enemy_gc.active_ships[src_sea][.TRANS_2I_2_MOVES] +
	                   enemy_gc.active_ships[src_sea][.TRANS_1I_1A_2_MOVES] +
	                   enemy_gc.active_ships[src_sea][.TRANS_1I_1T_2_MOVES]
	
	// Get canal state for movement
	canal_state := transmute(u8)enemy_gc.canals_open
	
	// 1-space sea movement
	for dst_sea in mm.s2s_1away_via_sea[canal_state][src_sea] {
		if !is_sea_worth_defending(gc, dst_sea) {
			continue
		}
		enemy_options.sea_threats[dst_sea].max_subs += sub_count
		enemy_options.sea_threats[dst_sea].max_destroyers += destroyer_count
		enemy_options.sea_threats[dst_sea].max_cruisers += cruiser_count
		enemy_options.sea_threats[dst_sea].max_carriers += carrier_count
		enemy_options.sea_threats[dst_sea].max_battleships += battleship_count
		enemy_options.sea_threats[dst_sea].max_transports += transport_count
	}
	
	// 2-space sea movement for combat ships (not transports typically, but subs/destroyers/etc)
	for dst_sea in mm.s2s_2away_via_sea[canal_state][src_sea] {
		if !is_sea_worth_defending(gc, dst_sea) {
			continue
		}
		enemy_options.sea_threats[dst_sea].max_subs += sub_count
		enemy_options.sea_threats[dst_sea].max_destroyers += destroyer_count
		enemy_options.sea_threats[dst_sea].max_cruisers += cruiser_count
		enemy_options.sea_threats[dst_sea].max_carriers += carrier_count
		enemy_options.sea_threats[dst_sea].max_battleships += battleship_count
	}
}

// Legacy wrapper for compatibility - generates and aggregates in one call
// Deprecated: Use generate_all_enemy_attack_options instead for access to per-enemy data
generate_enemy_attack_options :: proc(gc: ^Game_Cache, enemy_attack_options: ^Pro_Other_Move_Options) {
	all_enemies := all_enemy_attack_options_init()
	generate_all_enemy_attack_options(gc, &all_enemies, enemy_attack_options)
}
