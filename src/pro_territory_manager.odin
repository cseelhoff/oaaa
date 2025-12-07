package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

/*
=============================================================================
Pro_My_Move_Options Population Functions
=============================================================================

These functions populate the attack_options and defend_options for the current player.
Maps to Java TripleA's ProTerritoryManager.populateAttackOptions() and populateDefendOptions()
*/

// Populate attack options for combat move phase
// Fills in where our units can attack enemy territories
// Maps to: ProTerritoryManager.populateAttackOptions()
populate_attack_options :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options) {
	pro_my_move_options_clear(options)
	
	player := gc.cur_player
	
	// Find territories where we have units
	my_land_territories := get_friendly_army_territories(gc)
	my_sea_territories := get_friendly_ship_territories(gc)
	
	// Find land unit attack destinations
	find_land_attack_destinations(gc, options, my_land_territories)
	
	// Find air unit attack destinations
	find_air_attack_destinations(gc, options, my_land_territories)
	
	// Find naval attack options (including transports and bombard)
	find_naval_attack_destinations(gc, options, my_sea_territories)
	
	// Find amphibious attack options
	find_amphib_attack_destinations(gc, options)
	
	// Find bomber strategic raid targets
	find_bomber_raid_destinations(gc, options)
}

// Populate defend options for non-combat move phase
// Fills in where our units can move to reinforce friendly territories
// Maps to: ProTerritoryManager.populateDefendOptions()
populate_defend_options :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, cleared_territories: Land_Bitset) {
	pro_my_move_options_clear(options)
	
	player := gc.cur_player
	
	// Find territories where we have units
	my_land_territories := get_friendly_army_territories(gc)
	my_sea_territories := get_friendly_ship_territories(gc)
	
	// Find land unit defend destinations (friendly territories only)
	find_land_defend_destinations(gc, options, my_land_territories, cleared_territories)
	
	// Find air unit defend destinations
	find_air_defend_destinations(gc, options, my_land_territories, cleared_territories)
	
	// Find naval defend options
	find_naval_defend_destinations(gc, options, my_sea_territories, cleared_territories)
	
	// Find transport movement options for reinforcement
	find_transport_defend_destinations(gc, options, cleared_territories)
}

// Helper: Get territories with friendly armies
get_friendly_army_territories :: proc(gc: ^Game_Cache) -> Land_Bitset {
	result: Land_Bitset = {}
	for land in Land_ID {
		for army in Idle_Army {
			if gc.idle_armies[land][gc.cur_player][army] > 0 {
				result += {land}
				break
			}
		}
		// Also check active armies
		for army in Active_Army {
			if gc.active_armies[land][army] > 0 {
				result += {land}
				break
			}
		}
	}
	return result
}

// Helper: Get sea zones with friendly ships
get_friendly_ship_territories :: proc(gc: ^Game_Cache) -> Sea_Bitset {
	result: Sea_Bitset = {}
	for sea in Sea_ID {
		for ship in Idle_Ship {
			if gc.idle_ships[sea][gc.cur_player][ship] > 0 {
				result += {sea}
				break
			}
		}
	}
	return result
}

// Helper: Populate land unit attack destinations
find_land_attack_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Land_Bitset) {
	for src_land in my_territories {
		// Infantry and Artillery can move 1 space
		if gc.active_armies[src_land][.INF_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				// Can attack enemy or neutral territories
				if mm.team[gc.owner[dst]] != mm.team[gc.cur_player] {
					options.land_unit_destinations[src_land][.INF_1_MOVES] += {dst}
					options.land_territory_map[dst].can_attack = true
					options.land_territory_map[dst].max_infantry += gc.active_armies[src_land][.INF_1_MOVES]
				}
			}
		}
		
		if gc.active_armies[src_land][.ARTY_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] != mm.team[gc.cur_player] {
					options.land_unit_destinations[src_land][.ARTY_1_MOVES] += {dst}
					options.land_territory_map[dst].can_attack = true
					options.land_territory_map[dst].max_artillery += gc.active_armies[src_land][.ARTY_1_MOVES]
				}
			}
		}
		
		// Tanks can move 2 spaces (blitz through empty territories)
		if gc.active_armies[src_land][.TANK_2_MOVES] > 0 {
			// 1 space away
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] != mm.team[gc.cur_player] {
					options.land_unit_destinations[src_land][.TANK_2_MOVES] += {dst}
					options.land_territory_map[dst].can_attack = true
					options.land_territory_map[dst].max_tanks += gc.active_armies[src_land][.TANK_2_MOVES]
				}
			}
			// 2 spaces away (blitz) - only if midland is empty/friendly
			for dst in mm.l2l_2away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] != mm.team[gc.cur_player] {
					// Check if there's a valid blitz path
					midlands := mm.l2l_2away_via_midland_bitset[src_land][dst]
					can_blitz := (midlands & ~gc.has_enemy_armies & ~gc.has_enemy_factory) != {}
					if can_blitz {
						options.land_unit_destinations[src_land][.TANK_2_MOVES] += {dst}
						options.land_territory_map[dst].can_attack = true
						options.land_territory_map[dst].max_tanks += gc.active_armies[src_land][.TANK_2_MOVES]
					}
				}
			}
		}
		
		// AA guns typically don't attack but can move
		if gc.active_armies[src_land][.AAGUN_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] != mm.team[gc.cur_player] {
					options.land_unit_destinations[src_land][.AAGUN_1_MOVES] += {dst}
					options.land_territory_map[dst].max_aa_guns += gc.active_armies[src_land][.AAGUN_1_MOVES]
				}
			}
		}
	}
}

// Helper: Find air unit attack destinations
find_air_attack_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Land_Bitset) {
	air_array: Air_ID_Array
	
	refresh_can_fighter_land_here(gc)
	refresh_can_bomber_land_here(gc)
	
	for src_land in my_territories {
		gc.current_territory = to_air(src_land)
		
		// Fighters
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_fighter_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {
				if is_land(dst) {
					dst_land := to_land(dst)
					// Attack enemy territories with units
					if mm.team[gc.owner[dst_land]] != mm.team[gc.cur_player] &&
					   gc.team_land_units[dst_land][mm.enemy_team[gc.cur_player]] > 0 {
						add_air(&options.air_unit_destinations[src_land][.FIGHTER_UNMOVED], dst)
						options.land_territory_map[dst_land].can_attack = true
						options.land_territory_map[dst_land].max_fighters += gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
					}
				} else {
					dst_sea := to_sea(dst)
					// Attack sea zones with enemy ships
					if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 {
						add_air(&options.air_unit_destinations[src_land][.FIGHTER_UNMOVED], dst)
						options.sea_territory_map[dst_sea].can_attack = true
						options.sea_territory_map[dst_sea].max_carriers += gc.active_land_planes[src_land][.FIGHTER_UNMOVED] // Using carriers field for fighters temporarily
					}
				}
			}
		}
		
		// Bombers
		if gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_bomber_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {
				if is_land(dst) {
					dst_land := to_land(dst)
					if mm.team[gc.owner[dst_land]] != mm.team[gc.cur_player] &&
					   (gc.team_land_units[dst_land][mm.enemy_team[gc.cur_player]] > 0 ||
					    gc.factory_prod[dst_land] > gc.factory_dmg[dst_land]) {
						add_air(&options.air_unit_destinations[src_land][.BOMBER_UNMOVED], dst)
						options.land_territory_map[dst_land].can_attack = true
						options.land_territory_map[dst_land].max_bombers += gc.active_land_planes[src_land][.BOMBER_UNMOVED]
					}
				} else {
					dst_sea := to_sea(dst)
					if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 {
						add_air(&options.air_unit_destinations[src_land][.BOMBER_UNMOVED], dst)
						options.sea_territory_map[dst_sea].can_attack = true
						options.sea_territory_map[dst_sea].max_subs += gc.active_land_planes[src_land][.BOMBER_UNMOVED] // Using subs field for bombers temporarily
					}
				}
			}
		}
	}
}

// Helper: Find naval attack destinations
find_naval_attack_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Sea_Bitset) {
	// TODO: Implement naval movement and attack options
	// This includes ships moving to attack enemy sea zones and bombard options
	canal_state := transmute(u8)gc.canals_open
	for src_sea in my_territories {
		// Find adjacent sea zones with enemies
		for dst_sea in mm.s2s_1away_via_sea[canal_state][src_sea] {
			if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 {
				options.transport_destinations[src_sea] += {dst_sea}
				options.sea_territory_map[dst_sea].can_attack = true
			}
		}
		
		// Bombard options - ships can bombard adjacent land
		for dst_land in sa.slice(&mm.s2l_1away_via_sea[src_sea]) {
			if mm.team[gc.owner[dst_land]] != mm.team[gc.cur_player] {
				options.bombard_targets[src_sea] += {dst_land}
			}
		}
	}
}

// Helper: Find amphibious attack destinations
find_amphib_attack_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options) {
	// TODO: Full implementation of amphibious transport options
	// For each transport, determine which land territories can be attacked
	// and which territories units can be loaded from
}

// Helper: Find bomber strategic raid targets
find_bomber_raid_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options) {
	// Find enemy factories that bombers can reach
	for land in Land_ID {
		if gc.factory_prod[land] > 0 && mm.team[gc.owner[land]] != mm.team[gc.cur_player] {
			add_air(&options.bomber_raid_targets, to_air(land))
		}
	}
}

// Helper: Find land unit defend destinations (non-combat)
find_land_defend_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Land_Bitset, cleared_territories: Land_Bitset) {
	for src_land in my_territories {
		// Infantry and Artillery can move 1 space to friendly territories
		if gc.active_armies[src_land][.INF_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] || dst in cleared_territories {
					options.land_unit_destinations[src_land][.INF_1_MOVES] += {dst}
					options.land_territory_map[dst].max_infantry += gc.active_armies[src_land][.INF_1_MOVES]
				}
			}
		}
		
		if gc.active_armies[src_land][.ARTY_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] || dst in cleared_territories {
					options.land_unit_destinations[src_land][.ARTY_1_MOVES] += {dst}
					options.land_territory_map[dst].max_artillery += gc.active_armies[src_land][.ARTY_1_MOVES]
				}
			}
		}
		
		// Tanks can move 2 spaces in non-combat
		if gc.active_armies[src_land][.TANK_2_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] || dst in cleared_territories {
					options.land_unit_destinations[src_land][.TANK_2_MOVES] += {dst}
					options.land_territory_map[dst].max_tanks += gc.active_armies[src_land][.TANK_2_MOVES]
				}
			}
			for dst in mm.l2l_2away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] || dst in cleared_territories {
					// Check path is through friendly territory
					midlands := mm.l2l_2away_via_midland_bitset[src_land][dst]
					can_pass := false
					for mid in midlands {
						if mm.team[gc.owner[mid]] == mm.team[gc.cur_player] || mid in cleared_territories {
							can_pass = true
							break
						}
					}
					if can_pass {
						options.land_unit_destinations[src_land][.TANK_2_MOVES] += {dst}
						options.land_territory_map[dst].max_tanks += gc.active_armies[src_land][.TANK_2_MOVES]
					}
				}
			}
		}
		
		if gc.active_armies[src_land][.AAGUN_1_MOVES] > 0 {
			for dst in mm.l2l_1away_via_land_bitset[src_land] {
				if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] || dst in cleared_territories {
					options.land_unit_destinations[src_land][.AAGUN_1_MOVES] += {dst}
					options.land_territory_map[dst].max_aa_guns += gc.active_armies[src_land][.AAGUN_1_MOVES]
				}
			}
		}
	}
}

// Helper: Find air unit defend destinations (non-combat)
find_air_defend_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Land_Bitset, cleared_territories: Land_Bitset) {
	air_array: Air_ID_Array
	
	refresh_can_fighter_land_here(gc)
	refresh_can_bomber_land_here(gc)
	
	for src_land in my_territories {
		gc.current_territory = to_air(src_land)
		
		// Fighters - can land on friendly territories or carriers
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_fighter_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {
				if is_land(dst) {
					dst_land := to_land(dst)
					if mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] || dst_land in cleared_territories {
						add_air(&options.air_unit_destinations[src_land][.FIGHTER_UNMOVED], dst)
						options.land_territory_map[dst_land].max_fighters += gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
					}
				} else {
					// Can land on friendly carriers in sea zones
					dst_sea := to_sea(dst)
					if gc.idle_ships[dst_sea][gc.cur_player][.CARRIER] > 0 {
						add_air(&options.air_unit_destinations[src_land][.FIGHTER_UNMOVED], dst)
					}
				}
			}
		}
		
		// Bombers
		if gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_bomber_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {
				if is_land(dst) {
					dst_land := to_land(dst)
					if mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] || dst_land in cleared_territories {
						add_air(&options.air_unit_destinations[src_land][.BOMBER_UNMOVED], dst)
						options.land_territory_map[dst_land].max_bombers += gc.active_land_planes[src_land][.BOMBER_UNMOVED]
					}
				}
			}
		}
	}
}

// Helper: Find naval defend destinations (non-combat)
find_naval_defend_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, my_territories: Sea_Bitset, cleared_territories: Land_Bitset) {
	// Ships can move to any friendly or neutral sea zone
	canal_state := transmute(u8)gc.canals_open
	for src_sea in my_territories {
		for dst_sea in mm.s2s_1away_via_sea[canal_state][src_sea] {
			// Can move to sea zones without enemies
			if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] == 0 {
				options.transport_destinations[src_sea] += {dst_sea}
			}
		}
	}
}

// Helper: Find transport defend destinations for reinforcement
find_transport_defend_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, cleared_territories: Land_Bitset) {
	// TODO: Implement transport loading and unloading for non-combat reinforcement
}
