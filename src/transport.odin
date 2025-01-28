package oaaa
import sa "core:container/small_array"
import "core:fmt"

MAX_TRANSPORT_MOVES :: 2

Transports_With_Moves := [?]Active_Ship {
	.TRANS_1I_1_MOVES,
	.TRANS_1A_1_MOVES,
	.TRANS_1T_1_MOVES,
	.TRANS_2I_1_MOVES,
	.TRANS_1I_1A_1_MOVES,
	.TRANS_1I_1T_1_MOVES,
	.TRANS_1I_2_MOVES,
	.TRANS_1A_2_MOVES,
	.TRANS_1T_2_MOVES,
	.TRANS_2I_2_MOVES,
	.TRANS_1I_1A_2_MOVES,
	.TRANS_1I_1T_2_MOVES,
}

Idle_Transports := [?]Idle_Ship {
	.TRANS_EMPTY,
	.TRANS_1I,
	.TRANS_1A,
	.TRANS_1T,
	.TRANS_1I_1A,
	.TRANS_1I_1T,
}

Transports_Needing_Staging := [?]Active_Ship {
	.TRANS_EMPTY_UNMOVED,
	.TRANS_1I_UNMOVED,
	.TRANS_1A_UNMOVED,
	.TRANS_1T_UNMOVED,
}

Ship_After_Staged := [?][MAX_TRANSPORT_MOVES + 1]Active_Ship {
	Active_Ship.TRANS_EMPTY_UNMOVED = {
		0 = .TRANS_EMPTY_2_MOVES,
		1 = .TRANS_EMPTY_1_MOVES,
		2 = .TRANS_EMPTY_0_MOVES,
	},
	Active_Ship.TRANS_1I_UNMOVED = {
		0 = .TRANS_1I_2_MOVES,
		1 = .TRANS_1I_1_MOVES,
		2 = .TRANS_1I_0_MOVES,
	},
	Active_Ship.TRANS_1A_UNMOVED = {
		0 = .TRANS_1A_2_MOVES,
		1 = .TRANS_1A_1_MOVES,
		2 = .TRANS_1A_0_MOVES,
	},
	Active_Ship.TRANS_1T_UNMOVED = {
		0 = .TRANS_1T_2_MOVES,
		1 = .TRANS_1T_1_MOVES,
		2 = .TRANS_1T_0_MOVES,
	},
}

Transport_Load_Unit := [Idle_Army][len(Active_Ship)]Active_Ship {
	.INF = {
		Active_Ship.TRANS_1T_2_MOVES = .TRANS_1I_1T_2_MOVES,
		Active_Ship.TRANS_1A_2_MOVES = .TRANS_1I_1A_2_MOVES,
		Active_Ship.TRANS_1I_2_MOVES = .TRANS_2I_2_MOVES,
		Active_Ship.TRANS_EMPTY_2_MOVES = .TRANS_1I_2_MOVES,
		Active_Ship.TRANS_1T_1_MOVES = .TRANS_1I_1T_1_MOVES,
		Active_Ship.TRANS_1A_1_MOVES = .TRANS_1I_1A_1_MOVES,
		Active_Ship.TRANS_1I_1_MOVES = .TRANS_2I_1_MOVES,
		Active_Ship.TRANS_EMPTY_1_MOVES = .TRANS_1I_1_MOVES,
		Active_Ship.TRANS_1T_0_MOVES = .TRANS_1I_1T_0_MOVES,
		Active_Ship.TRANS_1A_0_MOVES = .TRANS_1I_1A_0_MOVES,
		Active_Ship.TRANS_1I_0_MOVES = .TRANS_2I_0_MOVES,
		Active_Ship.TRANS_EMPTY_0_MOVES = .TRANS_1I_0_MOVES,
	},
	.ARTY = {
		Active_Ship.TRANS_1I_2_MOVES = .TRANS_1I_1A_2_MOVES,
		Active_Ship.TRANS_EMPTY_2_MOVES = .TRANS_1A_2_MOVES,
		Active_Ship.TRANS_1I_1_MOVES = .TRANS_1I_1A_1_MOVES,
		Active_Ship.TRANS_EMPTY_1_MOVES = .TRANS_1A_1_MOVES,
		Active_Ship.TRANS_1I_0_MOVES = .TRANS_1I_1A_0_MOVES,
		Active_Ship.TRANS_EMPTY_0_MOVES = .TRANS_1A_0_MOVES,
	},
	.TANK = {
		Active_Ship.TRANS_1I_2_MOVES = .TRANS_1I_1T_2_MOVES,
		Active_Ship.TRANS_EMPTY_2_MOVES = .TRANS_1T_2_MOVES,
		Active_Ship.TRANS_1I_1_MOVES = .TRANS_1I_1T_1_MOVES,
		Active_Ship.TRANS_EMPTY_1_MOVES = .TRANS_1T_1_MOVES,
		Active_Ship.TRANS_1I_0_MOVES = .TRANS_1I_1T_0_MOVES,
		Active_Ship.TRANS_EMPTY_0_MOVES = .TRANS_1T_0_MOVES,
	},
	.AAGUN = {},
}

Idle_Ship_Space := [?][]Idle_Ship {
	Army_Sizes.SMALL = {.TRANS_EMPTY, .TRANS_1I, .TRANS_1A, .TRANS_1T},
	Army_Sizes.LARGE = {.TRANS_EMPTY, .TRANS_1I},
}

Active_Ship_Space := [?][]Active_Ship {
	Army_Sizes.SMALL = {.TRANS_1T_2_MOVES, .TRANS_1A_2_MOVES, .TRANS_1T_1_MOVES, .TRANS_1A_1_MOVES, .TRANS_1T_0_MOVES, .TRANS_1A_0_MOVES, .TRANS_1I_2_MOVES, .TRANS_EMPTY_2_MOVES, .TRANS_1I_1_MOVES, .TRANS_EMPTY_1_MOVES, .TRANS_1I_0_MOVES, .TRANS_EMPTY_0_MOVES},
	Army_Sizes.LARGE = {.TRANS_1I_2_MOVES, .TRANS_EMPTY_2_MOVES, .TRANS_1I_1_MOVES, .TRANS_EMPTY_1_MOVES, .TRANS_1I_0_MOVES, .TRANS_EMPTY_0_MOVES},
}

stage_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Transports_Needing_Staging {
		stage_trans_seas(gc, ship) or_return
	}
	return true
}

stage_trans_seas :: proc(gc: ^Game_Cache, ship: Active_Ship) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_sea in Sea_ID {
		stage_trans_sea(gc, src_sea, ship) or_return
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}

stage_trans_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	gc.valid_actions = {to_action(src_sea)}
	add_valid_transport_moves(gc, src_sea, 2)
	for gc.active_ships[src_sea][ship] > 0 {
		stage_next_ship_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

stage_next_ship_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, fmt.tprint(ship), to_air(src_sea)) or_return
	dst_sea := get_sea_id(dst_air_idx)
	// sea_distance := src_sea.canal_paths[gc.canal_state].sea_distance[dst_sea_idx]
	sea_distance := mm.sea_distances[transmute(u8)gc.canals_open][src_sea][dst_sea]
	if skip_ship(gc, src_sea, dst_sea, ship) do return true
	if dst_sea in gc.more_sea_combat_needed {
		// only allow staging to sea with enemy blockade if other unit started combat
		sea_distance = 2
	}
	ship_after_staged := Ship_After_Staged[ship][sea_distance]
	move_single_ship(gc, dst_sea, ship_after_staged, ship, src_sea)
	return true
}

skip_empty_transports :: proc(gc: ^Game_Cache) {
	for src_sea in Sea_ID {
		gc.active_ships[src_sea][.TRANS_EMPTY_0_MOVES] +=
			gc.active_ships[src_sea][.TRANS_EMPTY_1_MOVES] +
			gc.active_ships[src_sea][.TRANS_EMPTY_2_MOVES]
		gc.active_ships[src_sea][.TRANS_EMPTY_1_MOVES] = 0
		gc.active_ships[src_sea][.TRANS_EMPTY_2_MOVES] = 0
	}
}

move_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	skip_empty_transports(gc)
	for ship in Transports_With_Moves {
		move_trans_seas(gc, ship) or_return
	}
	return true
}

move_trans_seas :: proc(gc: ^Game_Cache, ship: Active_Ship) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_sea in Sea_ID {
		move_trans_sea(gc, src_sea, ship) or_return
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}

move_trans_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	gc.valid_actions = {to_action(src_sea)}
	add_valid_transport_moves(gc, src_sea, Ships_Moves[ship])
	for gc.active_ships[src_sea][ship] > 0 {
		move_next_trans_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

move_next_trans_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, fmt.tprint(ship), to_air(src_sea)) or_return
	dst_sea := to_sea(dst_air_idx)
	if skip_ship(gc, src_sea, dst_sea, ship) do return true
	move_single_ship(gc, dst_sea, Ships_Moved[ship], ship, src_sea)
	return true
}

add_valid_transport_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID, max_distance: int) {
	// for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if to_air(dst_sea) in gc.skipped_a2a[to_air(src_sea)] ||
		   gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 &&
			 dst_sea not_in gc.sea_combat_started { 	// transport needs escort
			continue
		}
		gc.valid_actions += {to_action(dst_sea)}
	}
	if max_distance == 1 do return
	// for &dst_sea_2_away in sa.slice(&src_sea.canal_paths[gc.canal_state].seas_2_moves_away) {
	mid_seas := &mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][src_sea]
	for dst_sea_2_away in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if to_air(dst_sea_2_away) in gc.skipped_a2a[to_air(src_sea)] ||
		   gc.team_sea_units[dst_sea_2_away][mm.enemy_team[gc.cur_player]] > 0 &&
			   dst_sea_2_away not_in gc.more_sea_combat_needed { 	// transport needs escort
			continue
		}
		for mid_sea in sa.slice(&mid_seas[dst_sea_2_away]) {
			if (gc.enemy_blockade_total[mid_sea] == 0) {
				gc.valid_actions += {to_action(dst_sea_2_away)}
				break
			}
		}
	}
}

add_valid_unload_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	for dst_land in sa.slice(&mm.s2l_1away_via_sea[src_sea]) {
		gc.valid_actions += {to_action(dst_land)}
	}
}

Transports_With_Cargo := [?]Active_Ship {
	.TRANS_1I_0_MOVES,
	.TRANS_1A_0_MOVES,
	.TRANS_1T_0_MOVES,
	.TRANS_2I_0_MOVES,
	.TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES,
}

Skipped_Transports := [Active_Ship]Active_Ship {
	.TRANS_EMPTY_UNMOVED  = .TRANS_EMPTY_UNMOVED,
	.TRANS_EMPTY_2_MOVES  = .TRANS_EMPTY_2_MOVES,
	.TRANS_EMPTY_1_MOVES  = .TRANS_EMPTY_1_MOVES,
	.TRANS_EMPTY_0_MOVES  = .TRANS_EMPTY_0_MOVES,
	.TRANS_1I_UNMOVED     = .TRANS_1I_UNMOVED,
	.TRANS_1I_2_MOVES     = .TRANS_1I_2_MOVES,
	.TRANS_1I_1_MOVES     = .TRANS_1I_1_MOVES,
	.TRANS_1I_UNLOADED    = .TRANS_1I_UNLOADED,
	.TRANS_1A_UNMOVED     = .TRANS_1A_UNMOVED,
	.TRANS_1A_2_MOVES     = .TRANS_1A_2_MOVES,
	.TRANS_1A_1_MOVES     = .TRANS_1A_1_MOVES,
	.TRANS_1A_UNLOADED    = .TRANS_1A_UNLOADED,
	.TRANS_1T_UNMOVED     = .TRANS_1T_UNMOVED,
	.TRANS_1T_2_MOVES     = .TRANS_1T_2_MOVES,
	.TRANS_1T_1_MOVES     = .TRANS_1T_1_MOVES,
	.TRANS_1T_UNLOADED    = .TRANS_1T_UNLOADED,
	.TRANS_2I_2_MOVES     = .TRANS_2I_2_MOVES,
	.TRANS_2I_1_MOVES     = .TRANS_2I_1_MOVES,
	.TRANS_2I_UNLOADED    = .TRANS_2I_UNLOADED,
	.TRANS_1I_1A_2_MOVES  = .TRANS_1I_1A_2_MOVES,
	.TRANS_1I_1A_1_MOVES  = .TRANS_1I_1A_1_MOVES,
	.TRANS_1I_1A_UNLOADED = .TRANS_1I_1A_UNLOADED,
	.TRANS_1I_1T_2_MOVES  = .TRANS_1I_1T_2_MOVES,
	.TRANS_1I_1T_1_MOVES  = .TRANS_1I_1T_1_MOVES,
	.TRANS_1I_1T_UNLOADED = .TRANS_1I_1T_UNLOADED,
	.SUB_UNMOVED          = .SUB_UNMOVED,
	.SUB_0_MOVES          = .SUB_0_MOVES,
	.DESTROYER_UNMOVED    = .DESTROYER_UNMOVED,
	.DESTROYER_0_MOVES    = .DESTROYER_0_MOVES,
	.CARRIER_UNMOVED      = .CARRIER_UNMOVED,
	.CARRIER_0_MOVES      = .CARRIER_0_MOVES,
	.CRUISER_UNMOVED      = .CRUISER_UNMOVED,
	.CRUISER_0_MOVES      = .CRUISER_0_MOVES,
	.CRUISER_BOMBARDED    = .CRUISER_BOMBARDED,
	.BATTLESHIP_UNMOVED   = .BATTLESHIP_UNMOVED,
	.BATTLESHIP_0_MOVES   = .BATTLESHIP_0_MOVES,
	.BATTLESHIP_BOMBARDED = .BATTLESHIP_BOMBARDED,
	.BS_DAMAGED_UNMOVED   = .BS_DAMAGED_UNMOVED,
	.BS_DAMAGED_0_MOVES   = .BS_DAMAGED_0_MOVES,
	.BS_DAMAGED_BOMBARDED = .BS_DAMAGED_BOMBARDED,
	.TRANS_1I_0_MOVES     = .TRANS_1I_UNLOADED,
	.TRANS_1A_0_MOVES     = .TRANS_1A_UNLOADED,
	.TRANS_1T_0_MOVES     = .TRANS_1T_UNLOADED,
	.TRANS_2I_0_MOVES     = .TRANS_2I_UNLOADED,
	.TRANS_1I_1A_0_MOVES  = .TRANS_1I_1A_UNLOADED,
	.TRANS_1I_1T_0_MOVES  = .TRANS_1I_1T_UNLOADED,
}

unload_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Transports_With_Cargo {
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			gc.valid_actions = {to_action(src_sea)}
			add_valid_unload_moves(gc, src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				dst_air := get_move_input(gc, fmt.tprint(ship), to_air(src_sea)) or_return
				if dst_air == to_air(src_sea) {
					gc.active_ships[src_sea][Skipped_Transports[ship]] +=
						gc.active_ships[src_sea][ship]
					gc.active_ships[src_sea][ship] = 0
					continue
				}
				unload_unit_to_land(gc, to_land(dst_air), ship)
				replace_ship(gc, src_sea, ship, Transport_Unloaded[ship])
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

Transport_Unload_Unit_1 := [Active_Ship]Active_Army {
	.TRANS_EMPTY_UNMOVED  = .INF_0_MOVES,
	.TRANS_EMPTY_2_MOVES  = .INF_0_MOVES,
	.TRANS_EMPTY_1_MOVES  = .INF_0_MOVES,
	.TRANS_EMPTY_0_MOVES  = .INF_0_MOVES,
	.TRANS_1I_UNMOVED     = .INF_0_MOVES,
	.TRANS_1I_2_MOVES     = .INF_0_MOVES,
	.TRANS_1I_1_MOVES     = .INF_0_MOVES,
	.TRANS_1I_UNLOADED    = .INF_0_MOVES,
	.TRANS_1A_UNMOVED     = .INF_0_MOVES,
	.TRANS_1A_2_MOVES     = .INF_0_MOVES,
	.TRANS_1A_1_MOVES     = .INF_0_MOVES,
	.TRANS_1A_UNLOADED    = .INF_0_MOVES,
	.TRANS_1T_UNMOVED     = .INF_0_MOVES,
	.TRANS_1T_2_MOVES     = .INF_0_MOVES,
	.TRANS_1T_1_MOVES     = .INF_0_MOVES,
	.TRANS_1T_UNLOADED    = .INF_0_MOVES,
	.TRANS_2I_2_MOVES     = .INF_0_MOVES,
	.TRANS_2I_1_MOVES     = .INF_0_MOVES,
	.TRANS_2I_UNLOADED    = .INF_0_MOVES,
	.TRANS_1I_1A_2_MOVES  = .INF_0_MOVES,
	.TRANS_1I_1A_1_MOVES  = .INF_0_MOVES,
	.TRANS_1I_1A_UNLOADED = .INF_0_MOVES,
	.TRANS_1I_1T_2_MOVES  = .INF_0_MOVES,
	.TRANS_1I_1T_1_MOVES  = .INF_0_MOVES,
	.TRANS_1I_1T_UNLOADED = .INF_0_MOVES,
	.SUB_UNMOVED          = .INF_0_MOVES,
	.SUB_0_MOVES          = .INF_0_MOVES,
	.DESTROYER_UNMOVED    = .INF_0_MOVES,
	.DESTROYER_0_MOVES    = .INF_0_MOVES,
	.CARRIER_UNMOVED      = .INF_0_MOVES,
	.CARRIER_0_MOVES      = .INF_0_MOVES,
	.CRUISER_UNMOVED      = .INF_0_MOVES,
	.CRUISER_0_MOVES      = .INF_0_MOVES,
	.CRUISER_BOMBARDED    = .INF_0_MOVES,
	.BATTLESHIP_UNMOVED   = .INF_0_MOVES,
	.BATTLESHIP_0_MOVES   = .INF_0_MOVES,
	.BATTLESHIP_BOMBARDED = .INF_0_MOVES,
	.BS_DAMAGED_UNMOVED   = .INF_0_MOVES,
	.BS_DAMAGED_0_MOVES   = .INF_0_MOVES,
	.BS_DAMAGED_BOMBARDED = .INF_0_MOVES,
	.TRANS_1I_0_MOVES     = .INF_0_MOVES,
	.TRANS_1A_0_MOVES     = .ARTY_0_MOVES,
	.TRANS_1T_0_MOVES     = .TANK_0_MOVES,
	.TRANS_2I_0_MOVES     = .INF_0_MOVES,
	.TRANS_1I_1A_0_MOVES  = .INF_0_MOVES,
	.TRANS_1I_1T_0_MOVES  = .INF_0_MOVES,
}

Transport_Unloaded := [Active_Ship]Active_Ship {
	.TRANS_1I_0_MOVES     = .TRANS_EMPTY_0_MOVES,
	.TRANS_1A_0_MOVES     = .TRANS_EMPTY_0_MOVES,
	.TRANS_1T_0_MOVES     = .TRANS_EMPTY_0_MOVES,
	.TRANS_2I_0_MOVES     = .TRANS_1I_0_MOVES,
	.TRANS_1I_1A_0_MOVES  = .TRANS_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES  = .TRANS_1T_0_MOVES,
	.TRANS_EMPTY_UNMOVED  = .TRANS_EMPTY_0_MOVES,
	.TRANS_EMPTY_2_MOVES  = .TRANS_EMPTY_0_MOVES,
	.TRANS_EMPTY_1_MOVES  = .TRANS_EMPTY_0_MOVES,
	.TRANS_EMPTY_0_MOVES  = .TRANS_EMPTY_0_MOVES,
	.TRANS_1I_UNMOVED     = .TRANS_1I_0_MOVES,
	.TRANS_1I_2_MOVES     = .TRANS_1I_0_MOVES,
	.TRANS_1I_1_MOVES     = .TRANS_1I_0_MOVES,
	.TRANS_1I_UNLOADED    = .TRANS_1I_0_MOVES,
	.TRANS_1A_UNMOVED     = .TRANS_1A_0_MOVES,
	.TRANS_1A_2_MOVES     = .TRANS_1A_0_MOVES,
	.TRANS_1A_1_MOVES     = .TRANS_1A_0_MOVES,
	.TRANS_1A_UNLOADED    = .TRANS_1A_0_MOVES,
	.TRANS_1T_UNMOVED     = .TRANS_1T_0_MOVES,
	.TRANS_1T_2_MOVES     = .TRANS_1T_0_MOVES,
	.TRANS_1T_1_MOVES     = .TRANS_1T_0_MOVES,
	.TRANS_1T_UNLOADED    = .TRANS_1T_0_MOVES,
	.TRANS_2I_2_MOVES     = .TRANS_2I_0_MOVES,
	.TRANS_2I_1_MOVES     = .TRANS_2I_0_MOVES,
	.TRANS_2I_UNLOADED    = .TRANS_2I_0_MOVES,
	.TRANS_1I_1A_2_MOVES  = .TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1A_1_MOVES  = .TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1A_UNLOADED = .TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_2_MOVES  = .TRANS_1I_1T_0_MOVES,
	.TRANS_1I_1T_1_MOVES  = .TRANS_1I_1T_0_MOVES,
	.TRANS_1I_1T_UNLOADED = .TRANS_1I_1T_0_MOVES,
	.SUB_UNMOVED          = .TRANS_EMPTY_0_MOVES,
	.SUB_0_MOVES          = .TRANS_EMPTY_0_MOVES,
	.DESTROYER_UNMOVED    = .TRANS_EMPTY_0_MOVES,
	.DESTROYER_0_MOVES    = .TRANS_EMPTY_0_MOVES,
	.CARRIER_UNMOVED      = .TRANS_EMPTY_0_MOVES,
	.CARRIER_0_MOVES      = .TRANS_EMPTY_0_MOVES,
	.CRUISER_UNMOVED      = .TRANS_EMPTY_0_MOVES,
	.CRUISER_0_MOVES      = .TRANS_EMPTY_0_MOVES,
	.CRUISER_BOMBARDED    = .TRANS_EMPTY_0_MOVES,
	.BATTLESHIP_UNMOVED   = .TRANS_EMPTY_0_MOVES,
	.BATTLESHIP_0_MOVES   = .TRANS_EMPTY_0_MOVES,
	.BATTLESHIP_BOMBARDED = .TRANS_EMPTY_0_MOVES,
	.BS_DAMAGED_UNMOVED   = .TRANS_EMPTY_0_MOVES,
	.BS_DAMAGED_0_MOVES   = .TRANS_EMPTY_0_MOVES,
	.BS_DAMAGED_BOMBARDED = .TRANS_EMPTY_0_MOVES,
}

unload_unit_to_land :: proc(gc: ^Game_Cache, dst_land: Land_ID, ship: Active_Ship) {
	army := Transport_Unload_Unit_1[ship]
	gc.active_armies[dst_land][army] += 1
	gc.idle_armies[dst_land][gc.cur_player][Active_Army_To_Idle[army]] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.max_bombards[dst_land] += 1
	if !flag_for_land_enemy_combat(gc, dst_land) {
		check_for_conquer(gc, dst_land)
	}
}

replace_ship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship, new_ship: Active_Ship) {
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[new_ship]] += 1
	gc.active_ships[src_sea][new_ship] += 1
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[ship]] -= 1
	gc.active_ships[src_sea][ship] -= 1
}
