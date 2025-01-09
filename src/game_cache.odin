package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:strings"

BUY_ACTIONS_COUNT :: len(Buy_Action)
MAX_VALID_ACTIONS :: TERRITORIES_COUNT + BUY_ACTIONS_COUNT

Territory_Pointers :: [TERRITORIES_COUNT]^Territory
SA_Territory_Pointers :: sa.Small_Array(TERRITORIES_COUNT, ^Territory)
SA_Land_Pointers :: sa.Small_Array(LANDS_COUNT, ^Land)
SA_Player_Pointers :: sa.Small_Array(PLAYERS_COUNT, ^Player)
CANALS_OPEN :: bit_set[Canal_ID;u8]
UNLUCKY_TEAMS :: bit_set[Team_ID;u8]
VALID_ACTIONS_SA :: sa.Small_Array(MAX_VALID_ACTIONS, int)

Game_Cache :: struct {
	//state:             Game_State,
	teams:                    Teams,
	seas:                     Seas,
	lands:                    Lands,
	players:                  Players,
	territories:              Territory_Pointers,
	valid_actions:            VALID_ACTIONS_SA,
	unlucky_teams:            UNLUCKY_TEAMS,
	cur_player:               ^Player,
	seed:                     int,
	//canal_state:              int, //array of bools / bit_set is probably best
	canals_open:              CANALS_OPEN, //[CANALS_COUNT]bool,
	step_id:                  int,
	answers_remaining:        int,
	selected_action:          int,
	max_loops:                int,
	user_input:               int,
	actually_print:           bool,
	is_bomber_cache_current:  bool,
	is_fighter_cache_current: bool,
	clear_needed:             bool,
	use_selected_action:      bool,
}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_teams(&gc.teams, &gc.players)
	initialize_territories(&gc.lands, &gc.seas, &gc.territories)
	initialize_player_lands(&gc.lands, &gc.players)
	initialize_land_connections(&gc.lands) or_return
	//initialize_sea_connections(&gc.canal_paths, &gc.seas) or_return
	initialize_sea_connections(&gc.seas) or_return
	initialize_costal_connections(&gc.lands, &gc.seas) or_return
	initialize_canals(&gc.lands) or_return
	initialize_lands_2_moves_away(&gc.lands)
	// initialize_seas_2_moves_away(&gc.seas, &gc.canal_paths)
	initialize_seas_2_moves_away(&gc.seas)
	initialize_air_dist(&gc.lands, &gc.seas, &gc.territories)
	// initialize_land_path()
	// initialize_sea_path()
	// initialize_within_x_moves()
	// intialize_airs_x_to_4_moves_away()
	// initialize_skip_4air_precals()
	return true
}

save_cache_to_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gs.seed = gc.seed
	gs.cur_player = int(gc.cur_player.index)
	for &player, i in gc.players {
		gs.money[i] = player.money
	}
	for &land, i in gc.lands {
		land_state := &gs.land_states[i]
		land_state.owner = int(land.owner.index)
		land_state.factory_prod = land.factory_prod
		land_state.factory_dmg = land.factory_dmg
		land_state.max_bombards = land.max_bombards
		land_state.active_armies = land.active_armies
		land_state.builds_left = land.builds_left
		land_state.idle_armies = land.idle_armies
		save_territory_to_state(&land_state.territory_state, &land.territory)
	}
	for &sea, i in gc.seas {
		sea_state := &gs.sea_states[i]
		sea_state.idle_ships = sea.idle_ships
		sea_state.active_ships = sea.active_ships
		save_territory_to_state(&sea_state.territory_state, &sea.territory)
	}
}

load_cache_from_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gc.seed = gs.seed
	gc.cur_player = &gc.players[gs.cur_player]
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	for &player, i in gc.players {
		player.money = gs.money[i]
		player.income_per_turn = 0
	}
	for &land, i in gc.lands {
		land_state := &gs.land_states[i]
		load_territory_from_state(&land.territory, &land_state.territory_state)
		gc.players[land_state.owner].income_per_turn += land.value
		land.owner = &gc.players[land_state.owner]
		land.factory_prod = land_state.factory_prod
		if land.factory_prod > 0 {
			sa.push(&land.owner.factory_locations, &land)
		}
		land.factory_dmg = land_state.factory_dmg
		land.max_bombards = land_state.max_bombards
		land.active_armies = land_state.active_armies
		land.builds_left = land_state.builds_left
		land.idle_armies = land_state.idle_armies
		land.team_units = {}
		for player in gc.players {
			for army in land.idle_armies[player.index] {
				land.team_units[player.team.index] += army
			}
			for plane in land.idle_planes[player.index] {
				land.team_units[player.team.index] += plane
			}
		}
	}
	for &sea, i in gc.seas {
		sea_state := &gs.sea_states[i]
		load_territory_from_state(&sea.territory, &sea_state.territory_state)
		sea.idle_ships = sea_state.idle_ships
		sea.active_ships = sea_state.active_ships
		sea.team_units = {}
		for player in gc.players {
			for ship in sea.idle_ships[player.index] {
				sea.team_units[player.team.index] += ship
			}
			for plane in sea.idle_planes[player.index] {
				sea.team_units[player.team.index] += plane
			}
		}
	}
	count_sea_unit_totals(gc)
	load_open_canals(gc)
	debug_checks(gc)
}

load_territory_from_state :: proc(territory: ^Territory, ts: ^Territory_State) {
	territory.combat_status = ts.combat_status
	//territory.builds_left = ts.builds_left
	territory.skipped_moves = ts.skipped_moves
	territory.skipped_buys = ts.skipped_buys
	territory.active_planes = ts.active_planes
	territory.idle_planes = ts.idle_planes
}

save_territory_to_state :: proc(ts: ^Territory_State, territory: ^Territory) {
	ts.combat_status = territory.combat_status
	//ts.builds_left = territory.builds_left
	ts.skipped_moves = territory.skipped_moves
	ts.skipped_buys = territory.skipped_buys
	ts.active_planes = territory.active_planes
	ts.idle_planes = territory.idle_planes
}

count_sea_unit_totals :: proc(gc: ^Game_Cache) {
	for &sea in gc.seas {
		sea.enemy_fighters_total = 0
		sea.enemy_submarines_total = 0
		sea.enemy_destroyer_total = 0
		sea.enemy_blockade_total = 0
		for enemy in sa.slice(&gc.cur_player.team.enemy_players) {
			sea.enemy_fighters_total += sea.idle_planes[enemy.index][Idle_Plane.FIGHTER]
			sea.enemy_submarines_total += sea.idle_ships[enemy.index][Idle_Ship.SUB]
			sea.enemy_destroyer_total += sea.idle_ships[enemy.index][Idle_Ship.DESTROYER]
			sea.enemy_blockade_total +=
				sea.idle_ships[enemy.index][Idle_Ship.CARRIER] +
				sea.idle_ships[enemy.index][Idle_Ship.CRUISER] +
				sea.idle_ships[enemy.index][Idle_Ship.BATTLESHIP] +
				sea.idle_ships[enemy.index][Idle_Ship.BS_DAMAGED]
		}
		sea.enemy_blockade_total += sea.enemy_destroyer_total
		sea.allied_carriers = 0
		for ally in sa.slice(&gc.cur_player.team.players) {
			sea.allied_carriers += sea.idle_ships[ally.index][Idle_Ship.CARRIER]
		}
	}
}
load_open_canals :: proc(gc: ^Game_Cache) {
	gc.canals_open = {}
	for canal, canal_idx in Canal_Lands {
		if canal[0].owner.team == gc.cur_player.team && canal[1].owner.team == gc.cur_player.team {
			gc.canals_open += {Canal_ID(canal_idx)}
		}
	}
}
