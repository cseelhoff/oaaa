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
UNLUCKY_TEAMS :: bit_set[Team_ID;u8]
Territory_Bitset :: bit_set[Air_ID;u8]
SA_Valid_Actions :: sa.Small_Array(len(Action_ID), Action_ID)

Game_Cache :: struct {
	//state:             Game_State,
	// seas:                       Seas,
	// lands:                    Lands,
	active_armies:              [Land_ID][Active_Army]u8,
	active_ships:               [Sea_ID][Active_Ship]u8,
	active_planes:              [Air_ID][Active_Plane]u8,
	idle_armies:                [Land_ID][Player_ID][Idle_Army]u8,
	idle_planes:                [Air_ID][Player_ID][Idle_Plane]u8,
	idle_ships:                 [Sea_ID][Player_ID][Idle_Ship]u8,
	skipped_moves:              [Air_ID]Territory_Bitset,
	team_units:                 [Air_ID][Team_ID]u8,
	combat_status:              [Air_ID]Combat_Status,
	can_bomber_land_here:       Territory_Bitset,
	can_bomber_land_in_1_move:  Territory_Bitset,
	can_bomber_land_in_2_moves: Territory_Bitset,
	can_fighter_land_here:      Territory_Bitset,
	factory_locations:          [Player_ID]SA_Land,
	valid_actions:              SA_Valid_Actions,
	income:                     [Player_ID]u8,
	enemy_blockade_total:       [Sea_ID]u8,
	enemy_fighters_total:       [Sea_ID]u8,
	enemy_submarines_total:     [Sea_ID]u8,
	enemy_destroyer_total:      [Sea_ID]u8,
	max_bombards:               [Land_ID]u8,
	// territories:                Territory_Pointers,
	players:                    Players,
	money:                      [Player_ID]u8,
	owner:                      [Land_ID]Player_ID,
	factory_dmg:                [Land_ID]u8,
	factory_prod:               [Land_ID]u8,
	//teams:                    Teams,
	cur_player:                 Player_ID,
	seed:                       u16,
	//canal_state:              int, //array of bools / bit_set is probably best
	// step_id:                  int,
	answers_remaining:          u16,
	max_loops:                  u16,
	canals_open:                Canals_Open, //[CANALS_COUNT]bool,
	unlucky_teams:              UNLUCKY_TEAMS,
	selected_action:            u8,
	// user_input:               int,
	// actually_print:           bool,
	is_bomber_cache_current:    bool,
	is_fighter_cache_current:   bool,
	clear_needed:               bool,
	use_selected_action:        bool,
	builds_left:                [Land_ID]u8,
}

save_cache_to_state :: proc(gc: ^Game_Cache, gs: ^Game_State) {
	gs.seed = gc.seed
	gs.cur_player = u8(gc.cur_player.index)
	for &player, i in gc.players {
		gs.money[i] = player.money
	}
	for &land, i in gc.lands {
		land_state := &gs.land_states[i]
		land_state.owner = u8(land.owner.index)
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

load_territory_from_state :: proc(territory: Air_ID, ts: Air_ID) {
	territory.combat_status = ts.combat_status
	//territory.builds_left = ts.builds_left
	territory.skipped_moves = ts.skipped_moves
	territory.skipped_buys = ts.skipped_buys
	territory.active_planes = ts.active_planes
	territory.idle_planes = ts.idle_planes
}

save_territory_to_state :: proc(ts: Air_ID, territory: Air_ID) {
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
