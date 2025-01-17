package oaaa

import sa "core:container/small_array"

Game_State :: struct {
	active_armies:      [Land_ID][Active_Army]u8,
	active_ships:       [Sea_ID][Active_Ship]u8,
	active_land_planes: [Land_ID][Active_Plane]u8,
	active_sea_planes:  [Sea_ID][Active_Plane]u8,
	idle_armies:        [Land_ID][Player_ID][Idle_Army]u8,
	idle_land_planes:   [Land_ID][Player_ID][Idle_Plane]u8,
	idle_sea_planes:    [Sea_ID][Player_ID][Idle_Plane]u8,
	idle_ships:         [Sea_ID][Player_ID][Idle_Ship]u8,
	skipped_a2a:        [Air_ID]Air_Bitset,
	skipped_buys:       [Land_ID]Purchase_Bitset,
	land_combat_status: [Land_ID]Combat_Status,
	sea_combat_status:  [Sea_ID]Combat_Status,
	owner:              [Land_ID]Player_ID,
	income:             [Player_ID]u8,
	money:              [Player_ID]u8,
	max_bombards:       [Land_ID]u8,
	factory_dmg:        [Land_ID]u8,
	factory_prod:       [Land_ID]u8,
	builds_left:        [Land_ID]u8,
	seed:               u16,
	cur_player:         Player_ID,
}


Combat_Status :: enum u8 {
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
			gc.builds_left[land] = land.factory_prod
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
