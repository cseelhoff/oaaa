package oaaa

Buy_ACTIONS_COUNT :: len(Buy_Action)

Land_List :: [dynamic; len(Land_ID)]Land_ID
Canals_Open :: bit_set[Canal_ID;u8]
Unlucky_Teams :: bit_set[Team_ID;u8]
Land_Bitset :: bit_set[Land_ID;u128]
Sea_Bitset :: bit_set[Sea_ID;u128]
Purchase_Bitset :: bit_set[Buy_Action;u16]

Game_Cache :: struct {
	/*
    AI NOTE: Combat Total Caching
    
    Pre-calculated unit totals serve multiple purposes:
    
    1. Performance Optimization:
       - Avoids recounting units repeatedly
       - Updated incrementally during moves
       - Used heavily in threat detection
    
    2. Combat Type Detection:
       enemy_subvuln_ships_total: Ships vulnerable to submarines
       - Transports and other non-combat ships
       - Used to check if submarines have valid targets
       
    3. Combat Resolution:
       friendly_antifighter_ships_total: Ships that can shoot fighters
       - Cruisers, carriers, battleships
       - Used to determine if fighters must retreat
       
    4. Threat Assessment:
       friendly_sea_combatants_total: All combat-capable ships
       - Everything except transports
       - Used for general naval threat checks
    
    These totals are maintained by:
    - Incrementing when units move in
    - Decrementing when units move out
    - Resetting at start of each turn
    */
	using state:                    Game_State,
	team_land_units:                [Land_ID][Team_ID]u8,
	team_sea_units:                 [Sea_ID][Team_ID]u8,
	factory_locations:              [Nation_ID]Land_List,
	enemy_blockade_total:           [Sea_ID]u8,
	enemy_destroyers_total:         [Sea_ID]u8,
	enemy_fighters_total:           [Sea_ID]u8,
	enemy_submarines_total:         [Sea_ID]u8,
	enemy_subvuln_ships_total:      [Sea_ID]u8,
	friendly_fighters_total:          [Sea_ID]u8,
	friendly_carriers_total:          [Sea_ID]u8,
	friendly_destroyers_total:        [Sea_ID]u8,
	friendly_antifighter_ships_total: [Sea_ID]u8,
	friendly_sea_combatants_total:    [Sea_ID]u8,
	income:                         [Nation_ID]u8,
	answers_remaining:              u32,
	max_loops:                      u16,
	valid_actions:                  Action_Bitset,
	dyn_arr_valid_actions:          [dynamic; len(Action_ID)]Action_ID,
	can_bomber_land_here:           Land_Bitset,
	can_bomber_land_in_1_moves:     Region_Bitset,
	can_bomber_land_in_2_moves:     Region_Bitset,
	can_fighter_land_here:          Region_Bitset,
	can_fighter_land_in_1_move:     Region_Bitset,
	region_has_enemies:             Region_Bitset,
	has_bombable_factory:           Land_Bitset,
	has_enemy_factory:              Land_Bitset,
	has_enemy_units:                Land_Bitset,
	has_carrier_space:              Sea_Bitset,
	possible_factory_carriers:      Sea_Bitset,
	canals_open:                    Canals_Open,
	unlucky_teams:                  Unlucky_Teams,
	friendly_owner:                 Land_Bitset,
	selected_action:                Action_ID,
	is_bomber_cache_current:        bool,
	is_fighter_cache_current:       bool,
	clear_history_needed:           bool,
	use_selected_action:            bool,
}

load_cache_from_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gc.state = gs^
	gc.factory_locations = {}
	gc.team_land_units = {}
	gc.friendly_owner = {}
	gc.region_has_enemies = {}
	for land in Land_ID {
		gc.income[gc.owner[land]] += mm.value[land]
		if gc.factory_prod[land] > 0 {
			append(&gc.factory_locations[gc.owner[land]], land)
		}
		if mm.team[gc.owner[land]] == mm.team[gc.acting_nation] {
			gc.friendly_owner += {land}
		}
		for player in Nation_ID {
			for army in gc.roster_armies[land][player] {
				gc.team_land_units[land][mm.team[player]] += army
			}
			for plane in gc.roster_land_planes[land][player] {
				gc.team_land_units[land][mm.team[player]] += plane
			}
		}
		if gc.team_land_units[land][mm.enemy_team[gc.acting_nation]] > 0 {
			gc.has_enemy_units += {land}
			add_region(&gc.region_has_enemies, to_region(land))
		}
	}
	gc.team_sea_units = {}
	for sea in Sea_ID {
		for player in Nation_ID {
			for ship in gc.roster_ships[sea][player] {
				gc.team_sea_units[sea][mm.team[player]] += ship
			}
			for plane in gc.roster_sea_planes[sea][player] {
				gc.team_sea_units[sea][mm.team[player]] += plane
			}
		}
	}
	resfresh_cache(gc)
	count_sea_unit_totals(gc)
	load_open_canals(gc)
	// refresh_landable_planes(gc)
	debug_checks(gc)
}

resfresh_cache :: proc(gc: ^Game_Cache) {
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	gc.clear_history_needed = false
	gc.use_selected_action = false
	for enemy in mm.enemies[gc.acting_nation] {
		for factory_location in gc.factory_locations[enemy] {
			gc.has_enemy_factory += {factory_location}
			if gc.factory_dmg[factory_location] < gc.factory_prod[factory_location] * 2 {
				gc.has_bombable_factory += {factory_location}
			}
		}
	}
}

count_sea_unit_totals :: proc(gc: ^Game_Cache) {
	gc.possible_factory_carriers = {}
	for land in gc.factory_locations[gc.acting_nation] {
		gc.possible_factory_carriers += mm.coastal_seas_bitset[land]
	}
	for sea in Sea_ID {
		gc.enemy_fighters_total[sea] = 0
		gc.enemy_submarines_total[sea] = 0
		gc.enemy_destroyers_total[sea] = 0
		gc.enemy_blockade_total[sea] = 0
		gc.enemy_subvuln_ships_total[sea] = 0
		for enemy in mm.enemies[gc.acting_nation] {
			gc.enemy_fighters_total[sea] += gc.roster_sea_planes[sea][enemy][.Fighter]
			gc.enemy_submarines_total[sea] += gc.roster_ships[sea][enemy][.Submarine]
			gc.enemy_destroyers_total[sea] += gc.roster_ships[sea][enemy][.Destroyer]
			gc.enemy_blockade_total[sea] +=
				gc.roster_ships[sea][enemy][.Carrier] +
				gc.roster_ships[sea][enemy][.Cruiser] +
				gc.roster_ships[sea][enemy][.Battleship] +
				gc.roster_ships[sea][enemy][.Battleship_Damaged]
			gc.enemy_subvuln_ships_total[sea] +=
				gc.roster_ships[sea][enemy][.Transport_Empty] +
				gc.roster_ships[sea][enemy][.Transport_Infantry] +
				gc.roster_ships[sea][enemy][.Transport_Artillery] +
				gc.roster_ships[sea][enemy][.Transport_Tank] +
				gc.roster_ships[sea][enemy][.Transport_Infantry_Artillery] +
				gc.roster_ships[sea][enemy][.Transport_Infantry_Tank] +
				gc.roster_ships[sea][enemy][.Carrier] +
				gc.roster_ships[sea][enemy][.Cruiser] +
				gc.roster_ships[sea][enemy][.Battleship] +
				gc.roster_ships[sea][enemy][.Battleship_Damaged]
		}
		if gc.enemy_subvuln_ships_total[sea] + gc.enemy_fighters_total[sea] > 0{
			add_region(&gc.region_has_enemies, to_region(sea))
		}
		gc.friendly_fighters_total[sea] = 0
		gc.friendly_carriers_total[sea] = 0
		gc.enemy_blockade_total[sea] += gc.enemy_destroyers_total[sea]
		gc.friendly_destroyers_total[sea] = 0
		gc.friendly_antifighter_ships_total[sea] = 0
		gc.friendly_sea_combatants_total[sea] = 0
		gc.has_carrier_space = {}
		for ally in mm.friends[gc.acting_nation] {
			gc.friendly_fighters_total[sea] += gc.roster_sea_planes[sea][ally][.Fighter]
			gc.friendly_carriers_total[sea] += gc.roster_ships[sea][ally][.Carrier]
			gc.friendly_destroyers_total[sea] += gc.roster_ships[sea][ally][.Destroyer]
			gc.friendly_antifighter_ships_total[sea] +=
				gc.roster_ships[sea][ally][.Cruiser] +
				gc.roster_ships[sea][ally][.Battleship] +
				gc.roster_ships[sea][ally][.Battleship_Damaged]
			gc.friendly_sea_combatants_total[sea] +=
				gc.roster_ships[sea][ally][.Submarine] +
				gc.roster_ships[sea][ally][.Cruiser] +
				gc.roster_ships[sea][ally][.Battleship] +
				gc.roster_ships[sea][ally][.Battleship_Damaged] +
				gc.roster_ships[sea][ally][.Destroyer]
		}
		gc.friendly_antifighter_ships_total[sea] +=
			gc.friendly_destroyers_total[sea] +
			gc.friendly_fighters_total[sea] +
			gc.friendly_carriers_total[sea] +
			gc.roster_sea_planes[sea][gc.acting_nation][.Bomber]
		gc.friendly_sea_combatants_total[sea] +=
			gc.friendly_destroyers_total[sea] +
			gc.friendly_fighters_total[sea] +
			gc.friendly_carriers_total[sea] +
			gc.roster_sea_planes[sea][gc.acting_nation][.Bomber]
		if gc.friendly_carriers_total[sea] * 2 > gc.friendly_fighters_total[sea] {
			gc.has_carrier_space += {sea}
		}
	}
}
load_open_canals :: proc(gc: ^Game_Cache) {
	gc.canals_open = {}
	for canal in Canal_ID {
		if mm.team[gc.owner[CANALS[canal].lands[0]]] == mm.team[gc.acting_nation] &&
		   mm.team[gc.owner[CANALS[canal].lands[1]]] == mm.team[gc.acting_nation] {
			gc.canals_open += {Canal_ID(canal)}
		}
	}
}
