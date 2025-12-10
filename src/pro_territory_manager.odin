package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

/*
=============================================================================
Pro Territory Manager - Attack and Defense Option Population

Maps to Java TripleA's ProTerritoryManager.java (1,277 lines)
This is the central hub for calculating what units can move where.

=============================================================================
JAVA ProTerritoryManager.java STRUCTURE (1,277 lines)
=============================================================================

ATTACK OPTIONS:
├── populateAttackOptions() (lines 50-85) - [IMPLEMENTED]
│   └── findAttackOptions() (lines 600-900) - [PARTIAL]
│       ├── LOOP: for each land unit with movement - [IMPLEMENTED]
│       ├── LOOP: for each air unit - [IMPLEMENTED]
│       ├── LOOP: for each transport for amphib - [PARTIAL]
│       ├── LOOP: for each naval unit - [PARTIAL]
│       └── findBombardOptions() - [PARTIAL]

DEFENSE OPTIONS:
├── populateDefendOptions() (lines 86-120) - [IMPLEMENTED]
│   └── findDefendOptions() (lines 400-580) - [PARTIAL]
│       ├── LOOP: for each friendly land unit - [IMPLEMENTED]
│       ├── LOOP: for each friendly air unit - [IMPLEMENTED]
│       └── LOOP: for each transport for reinforcement - [PARTIAL]

ENEMY OPTIONS:
├── populateEnemyAttackOptions() (lines 125-131) - [IMPLEMENTED]
│   └── findEnemyAttackOptions() (lines 300-400) - [IMPLEMENTED in pro_enemy_attacks.odin]
│
├── [MISSING] populateEnemyDefenseOptions() (lines 132-135)
│   └── findScrambleOptions() - [NOT IMPLEMENTED]
│   └── findEnemyDefendOptions() - [PARTIAL]

TERRITORY ANALYSIS:
├── removeTerritoriesThatCantBeConquered() (lines 140-300) - [PARTIAL]
│   └── Battle simulation for each potential attack - [IMPLEMENTED]
│   └── Strafing check for allied attacks - [NOT IMPLEMENTED]
│
├── [MISSING] findScrambleOptions() (lines 500-580)
│   └── Airbase scramble calculation
│
└── Various utility methods

=============================================================================
TODO REVIEW: Missing from ProTerritoryManager.java:

1. populateEnemyDefenseOptions() - NOT IMPLEMENTED
   - Calculates enemy reinforcement potential
   - Used for determining if conquered territories can be held

2. findScrambleOptions() - NOT IMPLEMENTED
   - Scrambling fighters from airbases
   - Important for accurate sea zone defense calculation

3. Strafing attack coordination - NOT IMPLEMENTED
   - Checking if we should strafe to help allied attacks
   - Lines 170-280 in Java

4. Allied attack options integration - PARTIAL
   - alliedAttackOptions used in canConquer calculations
=============================================================================
*/

// TM-001: populateAttackOptions() - Entry point to build attack map with attackers
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
// TM-011: Identifies transports that could bring amphibious reinforcements to threatened coastal territories
find_transport_defend_destinations :: proc(gc: ^Game_Cache, options: ^Pro_My_Move_Options, cleared_territories: Land_Bitset) {
	player := gc.cur_player
	canal_state := transmute(u8)gc.canals_open
	
	// Find all sea zones with our transports
	for sea in Sea_ID {
		// Count transports (any transport state indicates a transport is present)
		transport_count := gc.idle_ships[sea][player][.TRANS_EMPTY] +
		                   gc.idle_ships[sea][player][.TRANS_1I] +
		                   gc.idle_ships[sea][player][.TRANS_1A] +
		                   gc.idle_ships[sea][player][.TRANS_1T] +
		                   gc.idle_ships[sea][player][.TRANS_2I] +
		                   gc.idle_ships[sea][player][.TRANS_1I_1A] +
		                   gc.idle_ships[sea][player][.TRANS_1I_1T]
		
		if transport_count == 0 do continue
		
		// Find land territories adjacent to sea zones our transports can reach
		// Transports have 2 movement
		reachable_seas: Sea_Bitset = {sea}  // Can stay in place
		
		// 1 move away
		for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
			// Check if sea is safe (no enemy combat ships)
			enemy_combat := gc.team_sea_units[adj_sea][mm.enemy_team[player]]
			enemy_subs := u8(0)
			for p in Player_ID {
				if mm.team[p] != mm.team[player] {
					enemy_subs += gc.idle_ships[adj_sea][p][.SUB]
				}
			}
			// Can pass if no enemies or only subs
			if enemy_combat == 0 || enemy_combat == enemy_subs {
				reachable_seas += {adj_sea}
			}
		}
		
		// 2 moves away (through safe intermediates)
		for mid_sea in mm.s2s_1away_via_sea[canal_state][sea] {
			if mid_sea not_in reachable_seas do continue
			for far_sea in mm.s2s_1away_via_sea[canal_state][mid_sea] {
				if far_sea == sea do continue
				enemy_combat := gc.team_sea_units[far_sea][mm.enemy_team[player]]
				enemy_subs := u8(0)
				for p in Player_ID {
					if mm.team[p] != mm.team[player] {
						enemy_subs += gc.idle_ships[far_sea][p][.SUB]
					}
				}
				if enemy_combat == 0 || enemy_combat == enemy_subs {
					reachable_seas += {far_sea}
				}
			}
		}
		
		// Mark all reachable seas in transport_destinations
		options.transport_destinations[sea] = reachable_seas
	}
}

// =============================================================================
// TM-021: findEnemyDefendOptions() - Enemy reinforcement potential
// =============================================================================

// TM-021: Calculate enemy units that could reinforce a territory on enemy's turn
// Used for determining if conquered territories can be held
find_enemy_defend_options :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	/*
	From Java ProTerritoryManager.findEnemyDefendOptions():
	
	Calculates how much defensive strength the enemy could bring to
	defend a territory on their next turn. This includes:
	- Adjacent land units that could move in
	- Air units within range
	- Naval units that could bombard (for coastal territories)
	
	Used to determine if we can hold a territory after conquering it.
	*/
	
	total_reinforcement: f64 = 0.0
	my_team := mm.team[gc.cur_player]
	
	// Check adjacent land territories for enemy units
	for adj in sa.slice(&mm.l2l_1away_via_land[territory]) {
		owner := gc.owner[adj]
		if mm.team[owner] == my_team {
			continue  // Skip friendly
		}
		
		// Add enemy units that could reinforce (1-move infantry/artillery)
		total_reinforcement += f64(gc.idle_armies[adj][owner][.INF]) * 2.0    // Defense value
		total_reinforcement += f64(gc.idle_armies[adj][owner][.ARTY]) * 2.0   // Defense value
		
		// Tanks have 2 movement, check 2-away as well
		total_reinforcement += f64(gc.idle_armies[adj][owner][.TANK]) * 3.0
	}
	
	// Check 2-away territories for tank reinforcements
	for adj_2 in mm.l2l_2away_via_land_bitset[territory] {
		owner := gc.owner[adj_2]
		if mm.team[owner] == my_team {
			continue
		}
		// Only tanks can reach from 2 away
		total_reinforcement += f64(gc.idle_armies[adj_2][owner][.TANK]) * 3.0
	}
	
	// Check enemy air units (fighters have 4 range, bombers have 6)
	// Simplified: check territories within 2 land distance for fighters
	for land in Land_ID {
		if mm.land_distances[territory][land] > 2 {
			continue
		}
		for player in Player_ID {
			if mm.team[player] == my_team {
				continue  // Skip friendly
			}
			// Fighters can defend
			total_reinforcement += f64(gc.idle_land_planes[land][player][.FIGHTER]) * 4.0
		}
	}
	
	return total_reinforcement
}

// =============================================================================
// TM-025: Strafing check for allies
// =============================================================================

// TM-025: Check if a strafing attack is worthwhile
// Strafing = attack and retreat to weaken enemy without conquering
check_strafing_attack_worthwhile :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	attack_strength: f64,
	defense_strength: f64,
) -> bool {
	/*
	From Java ProTerritoryManager lines 210-280:
	
	For allies (not the main attacker), checks if strafing attack 
	(attack and retreat) is worthwhile when conquest isn't possible.
	
	Strafing is worthwhile when:
	1. We can inflict significant casualties
	2. We won't take too many losses
	3. An ally can follow up to capture
	4. The territory is strategically valuable
	
	Returns true if strafing attack should be attempted.
	*/
	
	// Don't strafe if we're too weak
	if attack_strength < defense_strength * 0.5 {
		return false
	}
	
	// Estimate TUV exchange
	// Simplified: favorable if attack strength > defense * 0.75
	if attack_strength < defense_strength * 0.75 {
		return false
	}
	
	// Check if there are allied units nearby that could follow up
	my_team := mm.team[gc.cur_player]
	allied_follow_up := false
	
	for adj in sa.slice(&mm.l2l_1away_via_land[territory]) {
		owner := gc.owner[adj]
		// Check for allied (same team but different player) units
		if mm.team[owner] == my_team && owner != gc.cur_player {
			// Check if ally has units there
			for army in Idle_Army {
				if gc.idle_armies[adj][owner][army] > 0 {
					allied_follow_up = true
					break
				}
			}
		}
		if allied_follow_up {
			break
		}
	}
	
	// Only strafe if an ally can follow up
	return allied_follow_up
}

// Check if we should strafe or attack to conquer
should_strafe_instead_of_conquer :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	can_hold: bool,
) -> bool {
	/*
	Determines if strafing is better than conquering.
	
	Strafe when:
	- We can't hold the territory after capture
	- But we can still inflict good casualties
	- Territory isn't critical (not a capital or factory)
	*/
	
	// If we can hold, always try to conquer
	if can_hold {
		return false
	}
	
	// If it's a capital or factory, try to conquer anyway (high value)
	if gc.factory_prod[territory] > 0 {
		return false
	}
	for player in Player_ID {
		if mm.capital[player] == territory {
			return false
		}
	}
	
	// Otherwise, strafe if we can't hold
	return true
}
