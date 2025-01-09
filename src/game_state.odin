package oaaa

Idle_Plane_For_Player :: [len(Idle_Plane)]int
Idle_Army_For_Player :: [len(Idle_Army)]int
Idle_Sea_For_Player :: [len(Idle_Ship)]int

Game_State :: struct {
	cur_player:  int,
	seed:        int,
	money:       [PLAYERS_COUNT]int,
	land_states: [LANDS_COUNT]Land_State,
	sea_states:  [SEAS_COUNT]Sea_State,
}

Territory_State :: struct {
	idle_planes:   [PLAYERS_COUNT]Idle_Plane_For_Player,
	active_planes: [len(Active_Plane)]int,
	skipped_moves: [TERRITORIES_COUNT]bool,
	skipped_buys:  Skipped_Buys,
	combat_status: Combat_Status,
	builds_left:   int,
}

Land_State :: struct {
	using territory_state: Territory_State,
	idle_armies:           [PLAYERS_COUNT]Idle_Army_For_Player,
	active_armies:         [len(Active_Army)]int,
	owner:                 int,
	factory_dmg:           int,
	factory_prod:          int,
	max_bombards:          int,
}

Sea_State :: struct {
	using territory_state: Territory_State,
	idle_ships:            [PLAYERS_COUNT]Idle_Sea_For_Player,
	active_ships:          [len(Active_Ship)]int,
}

Combat_Status :: enum {
	NO_COMBAT,
	MID_COMBAT,
	PRE_COMBAT,
	POST_COMBAT,
}

load_default_game_state :: proc(gs: ^Game_State) -> (ok: bool) {
	for &money in gs.money {
		money = 20
	}
	factory_locations :: [?]Land_ID{.Washington, .London, .Berlin, .Moscow, .Tokyo}
	for land in factory_locations {
		gs.land_states[land].factory_prod = LANDS_DATA[land].value
	}
	for &land, land_idx in gs.land_states {
		land.owner = get_player_idx_from_string(LANDS_DATA[land_idx].owner) or_return
		land.idle_armies[land.owner][Idle_Army.INF] = 3
		if land.owner == gs.cur_player {
			land.builds_left = land.factory_prod
			land.active_armies[Active_Army.INF_UNMOVED] = 3
		}
	}
	return true
}
