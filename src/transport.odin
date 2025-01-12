package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"

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

Transport_Load_Unit := [len(Idle_Army)][len(Active_Ship)]Active_Ship {
	Idle_Army.INF = {
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
	Idle_Army.ARTY = {
		Active_Ship.TRANS_1I_2_MOVES = .TRANS_1I_1A_2_MOVES,
		Active_Ship.TRANS_EMPTY_2_MOVES = .TRANS_1A_2_MOVES,
		Active_Ship.TRANS_1I_1_MOVES = .TRANS_1I_1A_1_MOVES,
		Active_Ship.TRANS_EMPTY_1_MOVES = .TRANS_1A_1_MOVES,
		Active_Ship.TRANS_1I_0_MOVES = .TRANS_1I_1A_0_MOVES,
		Active_Ship.TRANS_EMPTY_0_MOVES = .TRANS_1A_0_MOVES,
	},
	Idle_Army.TANK = {
		Active_Ship.TRANS_1I_2_MOVES = .TRANS_1I_1T_2_MOVES,
		Active_Ship.TRANS_EMPTY_2_MOVES = .TRANS_1T_2_MOVES,
		Active_Ship.TRANS_1I_1_MOVES = .TRANS_1I_1T_1_MOVES,
		Active_Ship.TRANS_EMPTY_1_MOVES = .TRANS_1T_1_MOVES,
		Active_Ship.TRANS_1I_0_MOVES = .TRANS_1I_1T_0_MOVES,
		Active_Ship.TRANS_EMPTY_0_MOVES = .TRANS_1T_0_MOVES,
	},
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
	gc.clear_needed = false
	for &src_sea in gc.seas {
		stage_trans_sea(gc, &src_sea, ship) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

stage_trans_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	reset_valid_moves(gc, src_sea)
	add_valid_transport_moves(gc, src_sea, 2)
	for gc.active_ships[src_sea][ship] > 0 {
		stage_next_ship_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

stage_next_ship_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, Active_Ship_Names[ship], src_sea) or_return
	dst_sea_idx := get_sea_id(dst_air_idx)
	// sea_distance := src_sea.canal_paths[gc.canal_state].sea_distance[dst_sea_idx]
	sea_distance := src_sea.canal_paths[transmute(u8)gc.canals_open].sea_distance[dst_sea_idx]
	dst_sea := &gc.seas[dst_sea_idx]
	if skip_ship(src_sea, dst_sea, ship) do return true
	if dst_sea.combat_status == .PRE_COMBAT {
		// only allow staging to sea with enemy blockade if other unit started combat
		sea_distance = 2
	}
	ship_after_staged := Ship_After_Staged[ship][sea_distance]
	move_single_ship(dst_sea, ship_after_staged, gc.cur_player, ship, src_sea)
	return true
}

skip_empty_transports :: proc(gc: ^Game_Cache) {
	for &src_sea in gc.seas {
		gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_0_MOVES] +=
			gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_1_MOVES] +
			gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_2_MOVES]
		gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_1_MOVES] = 0
		gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_2_MOVES] = 0
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
	gc.clear_needed = false
	for &src_sea in gc.seas {
		move_trans_sea(gc, &src_sea, ship) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_trans_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	reset_valid_moves(gc, src_sea)
	add_valid_transport_moves(gc, src_sea, Ships_Moves[ship])
	for gc.active_ships[src_sea][ship] > 0 {
		move_next_trans_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

move_next_trans_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, Active_Ship_Names[ship], src_sea) or_return
	dst_sea := get_sea(gc, dst_air_idx)
	if skip_ship(src_sea, dst_sea, ship) do return true
	move_single_ship(dst_sea, Ships_Moved[ship], gc.cur_player, ship, src_sea)
	return true
}

add_valid_transport_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID, max_distance: int) {
	// for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	for dst_sea in sa.slice(&src_sea.canal_paths[transmute(u8)gc.canals_open].adjacent_seas) {
		if src_sea.skipped_moves[dst_sea.territory_index] ||
		   dst_sea.team_units[gc.cur_player.team.enemy_team.index] > 0 &&
			   dst_sea.combat_status != .PRE_COMBAT { 	// transport needs escort
			continue
		}
		sa.push(&gc.valid_actions, u8(dst_sea.territory_index))
	}
	if max_distance == 1 do return
	// for &dst_sea_2_away in sa.slice(&src_sea.canal_paths[gc.canal_state].seas_2_moves_away) {
	for &dst_sea_2_away in sa.slice(
		&src_sea.canal_paths[transmute(u8)gc.canals_open].seas_2_moves_away,
	) {
		if (src_sea.skipped_moves[dst_sea_2_away.sea.territory_index] ||
			   dst_sea_2_away.sea.team_units[gc.cur_player.team.enemy_team.index] > 0 &&
				   dst_sea_2_away.sea.combat_status != .PRE_COMBAT) { 	// transport needs escort
			continue
		}
		for mid_sea in sa.slice(&dst_sea_2_away.mid_seas) {
			if (!mid_sea.sea_path_blocked) {
				sa.push(&gc.valid_actions, u8(dst_sea_2_away.sea.territory_index))
				break
			}
		}
	}
}

add_valid_unload_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	for dst_land in sa.slice(&src_sea.adjacent_lands) {
		sa.push(&gc.valid_actions, u8(dst_land.territory_index))
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

Skipped_Transports := [?]Active_Ship {
	Active_Ship.TRANS_1I_0_MOVES    = .TRANS_1I_UNLOADED,
	Active_Ship.TRANS_1A_0_MOVES    = .TRANS_1A_UNLOADED,
	Active_Ship.TRANS_1T_0_MOVES    = .TRANS_1T_UNLOADED,
	Active_Ship.TRANS_2I_0_MOVES    = .TRANS_2I_UNLOADED,
	Active_Ship.TRANS_1I_1A_0_MOVES = .TRANS_1I_1A_UNLOADED,
	Active_Ship.TRANS_1I_1T_0_MOVES = .TRANS_1I_1T_UNLOADED,
}

unload_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Transports_With_Cargo {
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			reset_valid_moves(gc, &src_sea)
			add_valid_unload_moves(gc, &src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				dst_air_idx := get_move_input(gc, Active_Ship_Names[ship], &src_sea) or_return
				if dst_air_idx == src_sea.territory_index {
					gc.active_ships[src_sea][Skipped_Transports[ship]] += gc.active_ships[src_sea][ship]
					gc.active_ships[src_sea][ship] = 0
					continue
				}
				dst_land := get_land(gc, dst_air_idx)
				unload_unit_to_land(gc, dst_land, ship)
				replace_ship(gc, &src_sea, ship, Transport_Unloaded[ship])
			}
		}
		if gc.clear_needed do clear_move_history(gc)
	}
	return true
}

Transport_Unload_Unit_1 := [?]Active_Army {
	Active_Ship.TRANS_1I_0_MOVES    = .INF_0_MOVES,
	Active_Ship.TRANS_1A_0_MOVES    = .ARTY_0_MOVES,
	Active_Ship.TRANS_1T_0_MOVES    = .TANK_0_MOVES,
	Active_Ship.TRANS_2I_0_MOVES    = .INF_0_MOVES,
	Active_Ship.TRANS_1I_1A_0_MOVES = .INF_0_MOVES,
	Active_Ship.TRANS_1I_1T_0_MOVES = .INF_0_MOVES,
}

Transport_Unloaded := [?]Active_Ship {
	Active_Ship.TRANS_1I_0_MOVES    = .TRANS_EMPTY_0_MOVES,
	Active_Ship.TRANS_1A_0_MOVES    = .TRANS_EMPTY_0_MOVES,
	Active_Ship.TRANS_1T_0_MOVES    = .TRANS_EMPTY_0_MOVES,
	Active_Ship.TRANS_2I_0_MOVES    = .TRANS_1I_0_MOVES,
	Active_Ship.TRANS_1I_1A_0_MOVES = .TRANS_1A_0_MOVES,
	Active_Ship.TRANS_1I_1T_0_MOVES = .TRANS_1T_0_MOVES,
}

unload_unit_to_land :: proc(gc: ^Game_Cache, dst_land: Land_ID, ship: Active_Ship) {
	army := Transport_Unload_Unit_1[ship]
	gc.active_armies[dst_land][army] += 1
	gc.idle_armies[dst_land][gc.cur_player.index][Active_Army_To_Idle[army]] += 1
	gc.team_units[dst_land][gc.cur_player.team.index] += 1
	dst_land.max_bombards += 1
	if !flag_for_enemy_combat(dst_land, gc.cur_player.team.enemy_team.index)
	{
		check_for_conquer(gc, dst_land)
	}
}

replace_ship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship, new_ship: Active_Ship) {
	src_sea.idle_ships[gc.cur_player.index][Active_Ship_To_Idle[new_ship]] += 1
	gc.active_ships[src_sea][new_ship] += 1
	src_sea.idle_ships[gc.cur_player.index][Active_Ship_To_Idle[ship]] -= 1
	gc.active_ships[src_sea][ship] -= 1
}
