package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:strings"

BUY_ACTIONS_COUNT :: len(Buy_Action)

Action_ID :: distinct enum u8 {
	Washington_Action,
	London_Action,
	Berlin_Action,
	Moscow_Action,
	Tokyo_Action,
	Pacific_Action,
	Atlantic_Action,
	Baltic_Action,
	Skip_Action,
	Inf_Action,
	Arty_Action,
	Tank_Action,
	AAGun_Action,
	Fighter_Action,
	Bomber_Action,
	Trans_Action,
	Sub_Action,
	Destroyer_Action,
	Carrier_Action,
	Cruiser_Action,
	Battleship_Action,
}

// Territory_Pointers :: [TERRITORIES_COUNT]Air_ID
SA_Territory_Pointers :: sa.Small_Array(len(Air_ID), Air_ID)
SA_Land :: sa.Small_Array(len(Land_ID), Land_ID)
SA_Player_Pointers :: sa.Small_Array(PLAYERS_COUNT, ^Player)
Canals_Open :: bit_set[Canal_ID;u8]
Unlucky_Teams :: bit_set[Team_ID;u8]
Land_Bitset :: bit_set[Land_ID;u8]
Sea_Bitset :: bit_set[Sea_ID;u8]
Purchase_Bitset :: bit_set[Buy_Action;u16]
Actions_Bitset :: bit_set[Action_ID;u32]
Air_Bitset :: bit_set[Air_ID;u16]

Game_Cache :: struct {
	using state:                   Game_State,
	land_team_units:               [Land_ID][Team_ID]u8,
	sea_team_units:                [Sea_ID][Team_ID]u8,
	can_bomber_land_here:          Land_Bitset,
	can_bomber_land_in_1_moves:    Air_Bitset,
	can_bomber_land_in_2_moves:    Air_Bitset,
	can_fighter_land_here:         Land_Bitset,
	can_fighter_land_in_1_move:    Air_Bitset,
	can_fighter_sealand_here:      Sea_Bitset,
	can_fighter_sealand_in_1_move: Air_Bitset,
	air_has_enemies:               Air_Bitset,
	// land_has_enemies:              Land_Bitset,
	has_bombable_factory:          Land_Bitset,
	// sea_has_enemies:               Sea_Bitset,
	factory_locations:             [Player_ID]SA_Land,
	valid_actions:                 Actions_Bitset,
	enemy_blockade_total:          [Sea_ID]u8,
	enemy_fighters_total:          [Sea_ID]u8,
	enemy_submarines_total:        [Sea_ID]u8,
	enemy_destroyer_total:         [Sea_ID]u8,
	answers_remaining:             u16,
	max_loops:                     u16,
	canals_open:                   Canals_Open, //[CANALS_COUNT]bool,
	unlucky_teams:                 Unlucky_Teams,
	selected_action:               Action_ID,
	is_bomber_cache_current:       bool,
	is_fighter_cache_current:      bool,
	clear_needed:                  bool,
	use_selected_action:           bool,
	allied_carriers:               [Sea_ID]u8,
	// air_no_combat:                 Air_Bitset,
	land_no_combat:                Land_Bitset,
	sea_no_combat:                 Sea_Bitset,
	friendly_owner:                Land_Bitset,
}

push_land_action :: #force_inline proc(gc: ^Game_Cache, land: Land_ID) {
	gc.valid_actions += {l2act(land)}
}

push_sea_action :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) {
	gc.valid_actions += {s2act(sea)}
}

l2a_bitset :: #force_inline proc(land: Land_Bitset) -> Air_Bitset {
	return transmute(Air_Bitset)u16(transmute(u8)land)
}

save_cache_to_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gs.seed = gc.seed
	gs.cur_player = gc.cur_player
	for i in Player_ID {
		gs.money[i] = player.money
	}
	for i in Land_ID {
		land_state := &gs.land_states[i]
		land_state.owner = u8(land.owner.index)
		land_state.factory_prod = land.factory_prod
		land_state.factory_dmg = gc.factory_dmg[land]
		land_state.max_bombards = land.max_bombards
		land_state.active_armies = land.active_armies
		land_state.builds_left = gc.builds_left[land]
		land_state.idle_armies = land.idle_armies
		save_territory_to_state(&land_state.territory_state, &land.territory)
	}
	for &sea, i in Sea_ID {
		sea_state := &gs.sea_states[i]
		sea_state.idle_ships = sea.idle_ships
		sea_state.active_ships = sea.active_ships
		save_territory_to_state(&sea_state.territory_state, &sea.territory)
	}
}

load_cache_from_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gc.state = gs^
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	gc.factory_locations = {}
	gc.team_units = {}
	for land in Land_ID {
		if gc.factory_prod[land] > 0 {
			sa.push(&gc.factory_locations[gc.owner[land]], land)
		}
		for player in Player_ID {
			for army in gc.idle_armies[land][player] {
				gc.team_units[land][mm.team[player]] += army
			}
			for plane in gc.idle_planes[land][player] {
				gc.team_units[land][mm.team[player]] += plane
			}
		}
	}
	for sea in Sea_ID {
		for player in Player_ID {
			for ship in gc.idle_ships[sea][player] {
				sea.team_units[mm.team[player]] += ship
			}
			for plane in gc.idle_planes[sea][player] {
				sea.team_units[mm.team[player]] += plane
			}
		}
	}
	count_sea_unit_totals(gc)
	load_open_canals(gc)
	refresh_landable_planes(gc)
	debug_checks(gc)
}

count_sea_unit_totals :: proc(gc: ^Game_Cache) {
	for sea in Sea_ID {
		gc.enemy_fighters_total[sea] = 0
		gc.enemy_submarines_total[sea] = 0
		gc.enemy_destroyer_total[sea] = 0
		gc.enemy_blockade_total[sea] = 0
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			gc.enemy_fighters_total[sea] += gc.idle_planes[s2aid(sea)][enemy][.FIGHTER]
			gc.enemy_submarines_total[sea] += gc.idle_ships[sea][enemy][.SUB]
			gc.enemy_destroyer_total[sea] += gc.idle_ships[sea][enemy][.DESTROYER]
			gc.enemy_blockade_total[sea] +=
				gc.idle_ships[sea][enemy][.CARRIER] +
				gc.idle_ships[sea][enemy][.CRUISER] +
				gc.idle_ships[sea][enemy][.BATTLESHIP] +
				gc.idle_ships[sea][enemy][.BS_DAMAGED]
		}
		gc.enemy_blockade_total[sea] += gc.enemy_destroyer_total[sea]
		gc.allied_carriers[sea] = 0
		for ally in sa.slice(&mm.allies[gc.cur_player]) {
			sea.allied_carriers += sea.idle_ships[ally][.CARRIER]
		}
	}
}
load_open_canals :: proc(gc: ^Game_Cache) {
	gc.canals_open = {}
	for canal, canal_idx in Canal_Lands {
		if mm.team[gc.owner[canal[0]]] == mm.team[gc.cur_player] &&
		   mm.team[gc.owner[canal[1]]] == mm.team[gc.cur_player] {
			gc.canals_open += {Canal_ID(canal_idx)}
		}
	}
}
