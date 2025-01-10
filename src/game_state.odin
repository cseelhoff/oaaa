package oaaa

Idle_Plane_For_Player :: [len(Idle_Plane)]u8
Idle_Army_For_Player :: [len(Idle_Army)]u8
Idle_Sea_For_Player :: [len(Idle_Ship)]u8

Game_State :: struct {
	land_states: [LANDS_COUNT]Land_State,
	sea_states:  [SEAS_COUNT]Sea_State,
	money:       [PLAYERS_COUNT]u8,
	seed:        u16,
	cur_player:  u8,
}

Territory_State :: struct {
	idle_planes:   [PLAYERS_COUNT]Idle_Plane_For_Player,
	active_planes: [len(Active_Plane)]u8,
	skipped_moves: [TERRITORIES_COUNT]bool,
	skipped_buys:  Skipped_Buys,
	combat_status: Combat_Status,
	builds_left:   u8,
}

Land_State :: struct {
	using territory_state: Territory_State,
	idle_armies:           [PLAYERS_COUNT]Idle_Army_For_Player,
	active_armies:         [len(Active_Army)]u8,
	owner:                 u8,
	factory_dmg:           u8,
	factory_prod:          u8,
	max_bombards:          u8,
}

Sea_State :: struct {
	using territory_state: Territory_State,
	idle_ships:            [PLAYERS_COUNT]Idle_Sea_For_Player,
	active_ships:          [len(Active_Ship)]u8,
}

Combat_Status :: enum u8{
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
		land.idle_armies[land.owner][Idle_Army.INF] = 0
		if land.owner == gs.cur_player {
			land.builds_left = land.factory_prod
			land.active_armies[Active_Army.INF_UNMOVED] = 0
		}
	}
	// gs.land_states[Land_ID.Moscow].active_armies[Active_Army.TANK_UNMOVED] = 2
	// gs.land_states[Land_ID.Moscow].idle_armies[Player_ID.Rus][Idle_Army.TANK] = 2
	// gs.land_states[Land_ID.Moscow].active_planes[Active_Plane.FIGHTER_UNMOVED] = 1
	// gs.land_states[Land_ID.Moscow].idle_planes[Player_ID.Rus][Idle_Plane.FIGHTER] = 1
	// gs.land_states[Land_ID.Moscow].active_planes[Active_Plane.BOMBER_UNMOVED] = 1
	// gs.land_states[Land_ID.Moscow].idle_planes[Player_ID.Rus][Idle_Plane.BOMBER] = 1
	// gs.sea_states[Sea_ID.Pacific].idle_ships[Player_ID.Eng][Idle_Ship.TRANS_1I_1T] = 3
	return true
}
