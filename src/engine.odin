package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"

GLOBAL_TICK := 0
ACTUALLY_PRINT := false
when ODIN_DEBUG {
	debug_checks :: proc(gc: ^Game_Cache) {
		GLOBAL_TICK += 1
		// if GLOBAL_TICK >= 58968320 {
		// 	fmt.println("Enable Print")
		// 	//print_game_state(gc)
		// 	gc.actually_print = true
		// } else do return
		for sea in gc.seas {
			team_idles: [2]u8 = {0, 0}
			for ship, ship_idx in sea.active_ships {
				if ship < 0 {
					fmt.eprintln("Negative active ships")
				}
			}
			for player in gc.players {
				for ship, ship_idx in sea.idle_ships[player.index] {
					if ship < 0 {
						fmt.eprintln("Negative idle ships")
					}
					team_idles[player.team.index] += ship
				}
				for plane, plane_idx in sea.idle_planes[player.index] {
					if plane < 0 {
						fmt.eprintln("Negative idle planes")
					} else if plane > 0 && plane_idx == 1 && player.team != gc.cur_player.team {
						fmt.eprintln("Enemy bombers at sea")
					}
					team_idles[player.team.index] += plane
				}
			}
			if sea.team_units[0] != team_idles[0] {
				fmt.eprintln("Unequal team 0 units")
			}
			if sea.team_units[1] != team_idles[1] {
				fmt.eprintln("Unequal team 1 units")
			}
			if sea.team_units[0] < 0 {
				fmt.eprintln("Negative team units")
			}
			if sea.team_units[1] < 0 {
				fmt.eprintln("Negative team units")
			}
		}
		for land in gc.lands {
			team_idles: [2]u8 = {0, 0}
			for army, army_idx in land.active_armies {
				if army < 0 {
					fmt.eprintln("Negative active armies")
				}
			}
			for player in gc.players {
				for army, army_idx in land.idle_armies[player.index] {
					if army < 0 {
						fmt.eprintln("Negative idle armies")
					}
					team_idles[player.team.index] += army
				}
				for plane, plane_idx in land.idle_planes[player.index] {
					if plane < 0 {
						fmt.eprintln("Negative idle planes")
					}
					team_idles[player.team.index] += plane
				}
				if team_idles[player.team.index] > 0 &&
				   land.owner.team == gc.cur_player.team &&
				   player.team != gc.cur_player.team {
					fmt.eprintln("Enemy units on land")
				}
			}
			if land.team_units[0] != team_idles[0] {
				fmt.eprintln("Unequal team 0 units")
			}
			if land.team_units[1] != team_idles[1] {
				fmt.eprintln("Unequal team 1 units")
			}
			if land.team_units[0] < 0 {
				fmt.eprintln("Negative team units")
			}
			if land.team_units[1] < 0 {
				fmt.eprintln("Negative team units")
			}
		}
	}
} else {
	debug_checks :: proc(gc: ^Game_Cache) {}
}
play_full_turn :: proc(gc: ^Game_Cache) -> (ok: bool) {
	debug_checks(gc)
	move_unmoved_planes(gc) or_return // move before carriers for more options
	debug_checks(gc)
	move_combat_ships(gc) or_return
	debug_checks(gc)
	stage_transports(gc) or_return
	debug_checks(gc)
	move_armies(gc) or_return
	debug_checks(gc)
	move_transports(gc) or_return
	debug_checks(gc)
	resolve_sea_battles(gc) or_return
	debug_checks(gc)
	unload_transports(gc) or_return
	debug_checks(gc)
	resolve_land_battles(gc) or_return
	debug_checks(gc)
	move_aa_guns(gc) or_return
	debug_checks(gc)
	land_fighter_units(gc) or_return
	debug_checks(gc)
	land_bomber_units(gc) or_return
	debug_checks(gc)
	buy_units(gc) or_return
	debug_checks(gc)
	//crash_air_units(gc) or_return
	buy_factory(gc) or_return
	debug_checks(gc)
	reset_units_fully(gc)
	debug_checks(gc)
	collect_money(gc)
	debug_checks(gc)
	rotate_turns(gc)
	debug_checks(gc)
	return true
}

add_move_if_not_skipped :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
	if dst_air not_in gc.skipped_moves[src_air] {
		sa.push(&gc.valid_actions, u8(dst_air))
	}
}

update_move_history :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air_idx: Air_ID) {
	// get a list of newly skipped valid_actions
	for {
		assert(gc.valid_actions.len > 0)
		valid_action := gc.valid_actions.data[gc.valid_actions.len - 1]
		if u2aid(valid_action) == dst_air_idx do return
		gc.skipped_moves[src_air] += {src_air}
		gc.clear_needed = true
		//apply_skip(gc, src_air, gc.territories[valid_action])
		gc.valid_actions.len -= 1
	}
}

// apply_skip :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
// 	for skipped_move, src_air_idx in dst_air.skipped_moves {
// 		if skipped_move {
// 			src_air.skipped_moves[src_air_idx] = true
// 		}
// 	}
// }

clear_move_history :: proc(gc: ^Game_Cache) {
	for air in Air_ID {
		gc.skipped_moves[air] = {}
	}
	gc.clear_needed = false
}

reset_valid_moves :: proc(gc: ^Game_Cache, territory: Air_ID) { 	// -> (dst_air_idx: int) {
	gc.valid_actions.len = 1
	gc.valid_actions.data[0] = u8(territory)
}

buy_factory :: proc(gc: ^Game_Cache) -> (ok: bool) {
	if gc.money[gc.cur_player] < FACTORY_COST do return true
	gc.valid_actions.len = 1
	gc.valid_actions.data[0] = buy_to_action_idx(.SKIP_BUY)
	for land in gc.lands {
		if land.owner != gc.cur_player ||
		   land.factory_prod > 0 ||
		   land.combat_status != .NO_COMBAT ||
		   land.skipped_moves[land.territory_index] {
			continue
		}
		sa.push(&gc.valid_actions, u8(land.territory_index))
	}
	for gc.money[gc.cur_player] < FACTORY_COST {
		factory_land_idx := get_factory_buy(gc) or_return
		if factory_land_idx == buy_to_action_idx(.SKIP_BUY) do return true
		gc.money[gc.cur_player] -= FACTORY_COST
		factory_land := &gc.lands[factory_land_idx]
		factory_land.factory_prod = factory_land.value
		sa.push(&gc.cur_player.factory_locations, factory_land)
	}
	return true
}

reset_units_fully :: proc(gc: ^Game_Cache) {
	for &sea in gc.seas {
		sea.active_ships[Active_Ship.BATTLESHIP_0_MOVES] +=
			sea.active_ships[Active_Ship.BS_DAMAGED_0_MOVES]
		sea.active_ships[Active_Ship.BS_DAMAGED_0_MOVES] = 0
		sea.active_ships[Active_Ship.BATTLESHIP_BOMBARDED] +=
			sea.active_ships[Active_Ship.BS_DAMAGED_BOMBARDED]
		sea.active_ships[Active_Ship.BS_DAMAGED_BOMBARDED] = 0
		sea.idle_ships[gc.cur_player.index][Idle_Ship.BATTLESHIP] +=
			sea.idle_ships[gc.cur_player.index][Idle_Ship.BS_DAMAGED]
		sea.idle_ships[gc.cur_player.index][Idle_Ship.BS_DAMAGED] = 0
	}
}

collect_money :: proc(gc: ^Game_Cache) {
	if gc.owner[mm.capital[gc.cur_player]] == gc.cur_player {
		gc.money[gc.cur_player] += gc.cur_player.income_per_turn
	}
}

rotate_turns :: proc(gc: ^Game_Cache) {
	gc.cur_player = &gc.players[(int(gc.cur_player.index) + 1) % PLAYERS_COUNT]
	gc.clear_needed = false
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	for &land in gc.lands {
		if land.owner == gc.cur_player {
			land.builds_left = land.factory_prod
		}
		land.combat_status = .NO_COMBAT
		land.max_bombards = 0
		mem.zero_slice(land.skipped_moves[:])
		mem.zero_slice(land.skipped_buys[:])
		mem.zero_slice(land.active_armies[:])
		idle_armies := &land.idle_armies[gc.cur_player.index]
		land.active_armies[Active_Army.INF_UNMOVED] = idle_armies[Idle_Army.INF]
		land.active_armies[Active_Army.ARTY_UNMOVED] = idle_armies[Idle_Army.ARTY]
		land.active_armies[Active_Army.TANK_UNMOVED] = idle_armies[Idle_Army.TANK]
		land.active_armies[Active_Army.AAGUN_UNMOVED] = idle_armies[Idle_Army.AAGUN]
		mem.zero_slice(land.active_planes[:])
		idle_planes := &land.idle_planes[gc.cur_player.index]
		land.active_planes[Active_Plane.FIGHTER_UNMOVED] = idle_planes[Idle_Plane.FIGHTER]
		land.active_planes[Active_Plane.BOMBER_UNMOVED] = idle_planes[Idle_Plane.BOMBER]
	}

	for &sea in gc.seas {
		sea.combat_status = .NO_COMBAT
		mem.zero_slice(sea.skipped_moves[:])
		mem.zero_slice(sea.skipped_buys[:])
		mem.zero_slice(sea.active_ships[:])
		idle_ships := &sea.idle_ships[gc.cur_player.index]
		sea.active_ships[Active_Ship.TRANS_EMPTY_UNMOVED] = idle_ships[Idle_Ship.TRANS_EMPTY]
		sea.active_ships[Active_Ship.TRANS_1I_UNMOVED] = idle_ships[Idle_Ship.TRANS_1I]
		sea.active_ships[Active_Ship.TRANS_1A_UNMOVED] = idle_ships[Idle_Ship.TRANS_1A]
		sea.active_ships[Active_Ship.TRANS_1T_UNMOVED] = idle_ships[Idle_Ship.TRANS_1T]
		sea.active_ships[Active_Ship.TRANS_2I_2_MOVES] = idle_ships[Idle_Ship.TRANS_2I]
		sea.active_ships[Active_Ship.TRANS_1I_1A_2_MOVES] = idle_ships[Idle_Ship.TRANS_1I_1A]
		sea.active_ships[Active_Ship.TRANS_1I_1T_2_MOVES] = idle_ships[Idle_Ship.TRANS_1I_1T]
		sea.active_ships[Active_Ship.SUB_UNMOVED] = idle_ships[Idle_Ship.SUB]
		sea.active_ships[Active_Ship.DESTROYER_UNMOVED] = idle_ships[Idle_Ship.DESTROYER]
		sea.active_ships[Active_Ship.CARRIER_UNMOVED] = idle_ships[Idle_Ship.CARRIER]
		sea.active_ships[Active_Ship.CRUISER_UNMOVED] = idle_ships[Idle_Ship.CRUISER]
		sea.active_ships[Active_Ship.BATTLESHIP_UNMOVED] = idle_ships[Idle_Ship.BATTLESHIP]
		sea.active_ships[Active_Ship.BS_DAMAGED_UNMOVED] = idle_ships[Idle_Ship.BS_DAMAGED]
		mem.zero_slice(sea.active_planes[:])
		idle_planes := &sea.idle_planes[gc.cur_player.index]
		sea.active_planes[Active_Plane.FIGHTER_UNMOVED] = idle_planes[Idle_Plane.FIGHTER]
		sea.active_planes[Active_Plane.BOMBER_UNMOVED] = idle_planes[Idle_Plane.BOMBER]
	}
	count_sea_unit_totals(gc)
	load_open_canals(gc)
}

is_terminal_state :: proc(game_state: ^Game_State) -> bool {
	// Return true if the game is over
	score := evaluate_state(game_state)
	// return score > 0.99 || score < 0.01
	if score > 0.99 || score < 0.01 {
		return true
	}
	return false
}

evaluate_state :: proc(gs: ^Game_State) -> f64 {
	// Evaluate the game state and return a score
	allied_score := 1 // one helps prevent division by zero
	enemy_score := 1
	for player, player_idx in PLAYER_DATA {
		if player.team == PLAYER_DATA[gs.cur_player].team {
			allied_score += int(gs.money[player_idx])
		} else {
			enemy_score += int(gs.money[player_idx])
		}
	}
	for player, player_idx in PLAYER_DATA {
		mil_cost := 0
		for land in gs.land_states {
			for army in Idle_Army {
				mil_cost += int(land.idle_armies[player_idx][army]) * int(COST_IDLE_ARMY[army])
			}
			for plane in Idle_Plane {
				mil_cost += int(land.idle_planes[player_idx][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		for sea in gs.sea_states {
			for ship in Idle_Ship {
				mil_cost += int(sea.idle_ships[player_idx][ship]) * int(COST_IDLE_SHIP[ship])
			}
			for plane in Idle_Plane {
				mil_cost += int(sea.idle_planes[player_idx][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		if player.team == PLAYER_DATA[gs.cur_player].team {
			allied_score += mil_cost
		} else {
			enemy_score += mil_cost
		}
	}
	score: f64 = f64(allied_score) / f64(enemy_score + allied_score)
	// ??? if starting_player >= PLAYERS_COUNT do return 1 - score
	return score
}

evaluate_cache :: proc(gc: ^Game_Cache) -> f64 {
	// Evaluate the game cache and return a score
	allied_score := 1 // one helps prevent division by zero
	enemy_score := 1
	for player in gc.players {
		if player.team == gc.cur_player.team {
			allied_score += int(player.money)
		} else {
			enemy_score += int(player.money)
		}
	}
	for player in gc.players {
		mil_cost := 0
		for land in gc.lands {
			for army in Idle_Army {
				mil_cost += int(land.idle_armies[player.index][army]) * int(COST_IDLE_ARMY[army])
			}
			for plane in Idle_Plane {
				mil_cost +=
					int(land.idle_planes[player.index][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		for sea in gc.seas {
			for ship in Idle_Ship {
				mil_cost += int(sea.idle_ships[player.index][ship]) * int(COST_IDLE_SHIP[ship])
			}
			for plane in Idle_Plane {
				mil_cost += int(sea.idle_planes[player.index][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		if player.team == gc.cur_player.team {
			allied_score += mil_cost
		} else {
			enemy_score += mil_cost
		}
	}
	score: f64 = f64(allied_score) / f64(enemy_score + allied_score)
	// ??? if starting_player >= PLAYERS_COUNT do return 1 - score
	return score
}

import "core:math/rand"
random_play_until_terminal :: proc(gc: ^Game_Cache, gs: ^Game_State) -> f64 {
	// gc: Game_Cache
	// ok := initialize_map_constants(gc)
	load_cache_from_state(gc, gs)
	gc.answers_remaining = 65000
	gc.seed = u16(rand.int_max(RANDOM_MAX))
	//use_selected_action = false;
	score := evaluate_cache(gc)
	max_loops := 1000
	// clear_move_history();
	debug_checks(gc)
	for (score > 0.01 && score < 0.99 && max_loops > 0) {
		max_loops -= 1
		// printf("max_loops: %d\n", max_loops);
		//  if(max_loops == 2) {
		//    setPrintableStatus();
		//    printf("%s\n", printableGameStatus);
		//    printf("DEBUG: max_loops reached\n");
		//  }
		// if (max_loops % 100 == 0) {
		//   printf("max_loops: %d\n", max_loops);
		// }
		debug_checks(gc)
		play_full_turn(gc) or_break
		debug_checks(gc)
		score = evaluate_cache(gc)
	}
	score = evaluate_cache(gc)
	if int(gc.cur_player.index) % 2 == 1 {
		score = 1 - score
	}
	return score
}

get_possible_actions :: proc(gs: ^Game_State) -> SA_Valid_Actions {
	// Return the list of possible actions from the given state
	gc: Game_Cache
	// set unlucky teams
	ok := initialize_map_constants(&gc)
	load_cache_from_state(&gc, gs)
	gc.unlucky_teams = {gc.cur_player.team.index}
	gc.answers_remaining = 0
	gc.seed = 0
	debug_checks(&gc)
	for {
		play_full_turn(&gc) or_break
	}
	return gc.valid_actions
}

apply_action :: proc(gs: ^Game_State, action: u8) {
	// Apply the action to the game state
	gc: Game_Cache
	ok := initialize_map_constants(&gc)
	load_cache_from_state(&gc, gs)
	gc.answers_remaining = 1
	gc.seed = 0
	gc.selected_action = action
	gc.use_selected_action = true
	//game_cache.clear_needed = false
	for {
		play_full_turn(&gc) or_break
	}
	save_cache_to_state(&gc, gs)
}

// PYBIND11_MODULE(engine, handle) {
//   handle.doc() = "engine doc";
//   handle.def("random_play_until_terminal", &random_play_until_terminal);
// }
