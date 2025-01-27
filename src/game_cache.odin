package oaaa
import sa "core:container/small_array"
// import "core:fmt"
// import "core:strings"

BUY_ACTIONS_COUNT :: len(Buy_Action)

// Territory_Pointers :: [len(Air_ID)]Air_ID
SA_Territory_Pointers :: sa.Small_Array(len(Air_ID), Air_ID)
SA_Land :: sa.Small_Array(len(Land_ID), Land_ID)
Canals_Open :: bit_set[Canal_ID;u8]
Unlucky_Teams :: bit_set[Team_ID;u8]
Land_Bitset :: bit_set[Land_ID;u8]
Sea_Bitset :: bit_set[Sea_ID;u8]
Purchase_Bitset :: bit_set[Buy_Action;u16]
Action_Bitset :: bit_set[Action_ID;u32]
Air_Bitset :: bit_set[Air_ID;u16]

Game_Cache :: struct {
	using state:                    Game_State,
	team_land_units:                [Land_ID][Team_ID]u8,
	team_sea_units:                 [Sea_ID][Team_ID]u8,
	factory_locations:              [Player_ID]SA_Land,
	enemy_blockade_total:           [Sea_ID]u8,
	enemy_destroyer_total:          [Sea_ID]u8,
	enemy_fighters_total:           [Sea_ID]u8,
	enemy_subs_total:               [Sea_ID]u8,
	enemy_subvuln_ships_total:      [Sea_ID]u8,
	allied_fighters_total:    			[Sea_ID]u8,
	allied_carriers_total:          [Sea_ID]u8,
	allied_destroyers_total:        [Sea_ID]u8,
	allied_antifighter_ships_total: [Sea_ID]u8,
	allied_sea_combatants_total:    [Sea_ID]u8,
	answers_remaining:              u16,
	max_loops:                      u16,
	valid_actions:                  Action_Bitset,
	can_bomber_land_here:           Land_Bitset,
	can_bomber_land_in_1_moves:     Air_Bitset,
	can_bomber_land_in_2_moves:     Air_Bitset,
	can_fighter_land_here:          Air_Bitset,
	can_fighter_land_in_1_move:     Air_Bitset,
	air_has_enemies:                Air_Bitset,
	has_bombable_factory:           Land_Bitset,
	has_carrier_space:              Sea_Bitset,
	canals_open:                    Canals_Open, //[CANALS_COUNT]bool,
	unlucky_teams:                  Unlucky_Teams,
	land_no_combat:                 Land_Bitset,
	sea_no_combat:                  Sea_Bitset,
	friendly_owner:                 Land_Bitset,
	selected_action:                Action_ID,
	is_bomber_cache_current:        bool,
	is_fighter_cache_current:       bool,
	clear_needed:                   bool,
	use_selected_action:            bool,
}

load_cache_from_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gc.state = gs^
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	gc.factory_locations = {}
	gc.team_land_units = {}
	for land in Land_ID {
		if gc.factory_prod[land] > 0 {
			sa.push(&gc.factory_locations[gc.owner[land]], land)
		}
		for player in Player_ID {
			for army in gc.idle_armies[land][player] {
				gc.team_land_units[land][mm.team[player]] += army
			}
			for plane in gc.idle_land_planes[land][player] {
				gc.team_land_units[land][mm.team[player]] += plane
			}
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
	count_sea_unit_totals(gc)
	load_open_canals(gc)
	// refresh_landable_planes(gc)
	debug_checks(gc)
}

count_sea_unit_totals :: proc(gc: ^Game_Cache) {
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
		gc.allied_antifighter_ships_total[sea] += gc.allied_destroyers_total[sea] + gc.allied_fighters_total[sea] + gc.allied_carriers_total[sea]
		gc.allied_sea_combatants_total[sea] += gc.allied_destroyers_total[sea] + gc.allied_fighters_total[sea] + gc.allied_carriers_total[sea]
		if gc.allied_carriers_total[sea] * 2 > gc.allied_fighters_total[sea] {
			gc.has_carrier_space += {sea}
		}
		// gc.allied_carriers[sea] = 0
		// for ally in sa.slice(&mm.allies[gc.cur_player]) {
		// 	sea.allied_carriers += sea.idle_ships[ally][.CARRIER]
		// }
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
