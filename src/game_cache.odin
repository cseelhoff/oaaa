package oaaa
import sa "core:container/small_array"

BUY_ACTIONS_COUNT :: len(Buy_Action)

SA_Land :: sa.Small_Array(len(Land_ID), Land_ID)
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
       enemy_subvuln_ships_total: Ships vulnerable to subs
       - Transports and other non-combat ships
       - Used to check if subs have valid targets
       
    3. Combat Resolution:
       allied_antifighter_ships_total: Ships that can shoot fighters
       - Cruisers, carriers, battleships
       - Used to determine if fighters must retreat
       
    4. Threat Assessment:
       allied_sea_combatants_total: All combat-capable ships
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
	factory_locations:              [Player_ID]SA_Land,
	enemy_blockade_total:           [Sea_ID]u8,
	enemy_destroyer_total:          [Sea_ID]u8,
	enemy_fighters_total:           [Sea_ID]u8,
	enemy_subs_total:               [Sea_ID]u8,
	enemy_subvuln_ships_total:      [Sea_ID]u8,
	allied_fighters_total:          [Sea_ID]u8,
	allied_carriers_total:          [Sea_ID]u8,
	allied_destroyers_total:        [Sea_ID]u8,
	allied_antifighter_ships_total: [Sea_ID]u8,
	allied_sea_combatants_total:    [Sea_ID]u8,
	income:                         [Player_ID]u8,
	answers_remaining:              u16,
	max_loops:                      u16,
	valid_actions:                  Action_Bitset,
	dyn_arr_valid_actions:          [dynamic]Action_ID,
	can_bomber_land_here:           Land_Bitset,
	can_bomber_land_in_1_moves:     Air_Bitset,
	can_bomber_land_in_2_moves:     Air_Bitset,
	can_fighter_land_here:          Air_Bitset,
	can_fighter_land_in_1_move:     Air_Bitset,
	air_has_enemies:                Air_Bitset,
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
	for land in Land_ID {
		gc.income[gc.owner[land]] += mm.value[land]
		if gc.factory_prod[land] > 0 {
			sa.push(&gc.factory_locations[gc.owner[land]], land)
		}
		if mm.team[gc.owner[land]] == mm.team[gc.cur_player] {
			gc.friendly_owner += {land}
		}
		for player in Player_ID {
			for army in gc.idle_armies[land][player] {
				gc.team_land_units[land][mm.team[player]] += army
			}
			for plane in gc.idle_land_planes[land][player] {
				gc.team_land_units[land][mm.team[player]] += plane
			}
		}
		if gc.team_land_units[land][mm.team[gc.cur_player]] > 0 {
			gc.has_enemy_units += {land}
		} else {
			gc.has_enemy_units -= {land}
		}
	}
	gc.team_sea_units = {}
	for sea in Sea_ID {
		for player in Player_ID {
			for ship in gc.idle_ships[sea][player] {
				gc.team_sea_units[sea][mm.team[player]] += ship
			}
			for plane in gc.idle_sea_planes[sea][player] {
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
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		for factory_location in sa.slice(&gc.factory_locations[enemy]) {
			gc.has_enemy_factory += {factory_location}
			if gc.factory_dmg[factory_location] < gc.factory_prod[factory_location] * 2 {
				gc.has_bombable_factory += {factory_location}
			}
		}
	}
}

count_sea_unit_totals :: proc(gc: ^Game_Cache) {
	gc.possible_factory_carriers = {}
	for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
		gc.possible_factory_carriers += mm.l2s_1away_via_land_bitset[land]
	}
	for sea in Sea_ID {
		gc.enemy_fighters_total[sea] = 0
		gc.enemy_subs_total[sea] = 0
		gc.enemy_destroyer_total[sea] = 0
		gc.enemy_blockade_total[sea] = 0
		gc.enemy_subvuln_ships_total[sea] = 0
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			gc.enemy_fighters_total[sea] += gc.idle_sea_planes[sea][enemy][.FIGHTER]
			gc.enemy_subs_total[sea] += gc.idle_ships[sea][enemy][.SUB]
			gc.enemy_destroyer_total[sea] += gc.idle_ships[sea][enemy][.DESTROYER]
			gc.enemy_blockade_total[sea] +=
				gc.idle_ships[sea][enemy][.CARRIER] +
				gc.idle_ships[sea][enemy][.CRUISER] +
				gc.idle_ships[sea][enemy][.BATTLESHIP] +
				gc.idle_ships[sea][enemy][.BS_DAMAGED]
			gc.enemy_subvuln_ships_total[sea] +=
				gc.idle_ships[sea][enemy][.TRANS_EMPTY] +
				gc.idle_ships[sea][enemy][.TRANS_1I] +
				gc.idle_ships[sea][enemy][.TRANS_1A] +
				gc.idle_ships[sea][enemy][.TRANS_1T] +
				gc.idle_ships[sea][enemy][.TRANS_1I_1A] +
				gc.idle_ships[sea][enemy][.TRANS_1I_1T] +
				gc.idle_ships[sea][enemy][.CARRIER] +
				gc.idle_ships[sea][enemy][.CRUISER] +
				gc.idle_ships[sea][enemy][.BATTLESHIP] +
				gc.idle_ships[sea][enemy][.BS_DAMAGED]
		}
		gc.allied_fighters_total[sea] = 0
		gc.allied_carriers_total[sea] = 0
		gc.enemy_blockade_total[sea] += gc.enemy_destroyer_total[sea]
		gc.allied_destroyers_total[sea] = 0
		gc.allied_antifighter_ships_total[sea] = 0
		gc.allied_sea_combatants_total[sea] = 0
		gc.has_carrier_space = {}
		for ally in sa.slice(&mm.allies[gc.cur_player]) {
			gc.allied_fighters_total[sea] += gc.idle_sea_planes[sea][ally][.FIGHTER]
			gc.allied_carriers_total[sea] += gc.idle_ships[sea][ally][.CARRIER]
			gc.allied_destroyers_total[sea] += gc.idle_ships[sea][ally][.DESTROYER]
			gc.allied_antifighter_ships_total[sea] +=
				gc.idle_ships[sea][ally][.CRUISER] +
				gc.idle_ships[sea][ally][.BATTLESHIP] +
				gc.idle_ships[sea][ally][.BS_DAMAGED]
			gc.allied_sea_combatants_total[sea] +=
				gc.idle_ships[sea][ally][.SUB] +
				gc.idle_ships[sea][ally][.CRUISER] +
				gc.idle_ships[sea][ally][.BATTLESHIP] +
				gc.idle_ships[sea][ally][.BS_DAMAGED] +
				gc.idle_ships[sea][ally][.DESTROYER]
		}
		gc.allied_antifighter_ships_total[sea] +=
			gc.allied_destroyers_total[sea] +
			gc.allied_fighters_total[sea] +
			gc.allied_carriers_total[sea] +
			gc.idle_sea_planes[sea][gc.cur_player][.BOMBER]
		gc.allied_sea_combatants_total[sea] +=
			gc.allied_destroyers_total[sea] +
			gc.allied_fighters_total[sea] +
			gc.allied_carriers_total[sea] +
			gc.idle_sea_planes[sea][gc.cur_player][.BOMBER]
		if gc.allied_carriers_total[sea] * 2 > gc.allied_fighters_total[sea] {
			gc.has_carrier_space += {sea}
		}
	}
}
load_open_canals :: proc(gc: ^Game_Cache) {
	gc.canals_open = {}
	for canal in Canal_ID {
		if mm.team[gc.owner[CANALS[canal].lands[0]]] == mm.team[gc.cur_player] &&
		   mm.team[gc.owner[CANALS[canal].lands[1]]] == mm.team[gc.cur_player] {
			gc.canals_open += {Canal_ID(canal)}
		}
	}
}
