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
		for sea in Sea_ID {
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
	move_unmoved_fighters(gc) or_return // move before carriers for more options
	debug_checks(gc)
	move_unmoved_bombers(gc) or_return
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
	land_remaining_fighters(gc) or_return
	debug_checks(gc)
	land_remaining_bombers(gc) or_return
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

// add_move_if_not_skipped :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
// 	if dst_air not_in gc.skipped_a2a[src_air] {
// 		gc.valid_actions += {a2act(dst_air)}
// 	}
// }

update_move_history :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
	// get a list of newly skipped valid_actions
	for valid_action in gc.valid_actions {
		// assert(card(gc.valid_actions) > 0)
		// valid_action := gc.valid_actions.data[gc.valid_actions.len - 1]
		if valid_action == a2act(src_air) do continue
		if valid_action == a2act(dst_air) do break
		gc.skipped_a2a[src_air] += {act2air(valid_action)}
		gc.clear_needed = true
	}
	gc.valid_actions -= transmute(Actions_Bitset)u32(transmute(u16)gc.skipped_a2a[src_air])
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
		gc.skipped_a2a[air] = {}
	}
	gc.clear_needed = false
}

reset_valid_land_moves :: proc(gc: ^Game_Cache, land: Land_ID) { 
	gc.valid_actions = {l2act(land)}
}

buy_factory :: proc(gc: ^Game_Cache) -> (ok: bool) {
	if gc.money[gc.cur_player] < FACTORY_COST do return true
	gc.valid_actions = {.Skip_Action}
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player ||
		   gc.factory_prod[land] > 0 ||
		   gc.land_combat_status[land] != .NO_COMBAT ||
		   l2aid(land) in gc.skipped_a2a[l2aid(land)] {
			continue
		}
		gc.valid_actions += {l2act(land)}
	}
	for gc.money[gc.cur_player] < FACTORY_COST {
		factory_land_action := get_factory_buy(gc) or_return
		if factory_land_action == .Skip_Action do return true
		gc.money[gc.cur_player] -= FACTORY_COST
		factory_land := act2land(factory_land_action)
		gc.factory_prod[factory_land] = mm.value[factory_land]
		sa.push(&gc.factory_locations[gc.cur_player], factory_land)
	}
	return true
}

reset_units_fully :: proc(gc: ^Game_Cache) {
	for sea in Sea_ID {
		gc.active_ships[sea][.BATTLESHIP_0_MOVES] += gc.active_ships[sea][.BS_DAMAGED_0_MOVES]
		gc.active_ships[sea][.BS_DAMAGED_0_MOVES] = 0
		gc.active_ships[sea][.BATTLESHIP_BOMBARDED] += gc.active_ships[sea][.BS_DAMAGED_BOMBARDED]
		gc.active_ships[sea][.BS_DAMAGED_BOMBARDED] = 0
		gc.idle_ships[sea][gc.cur_player][.BATTLESHIP] +=
			gc.idle_ships[sea][gc.cur_player][.BS_DAMAGED]
		gc.idle_ships[sea][gc.cur_player][.BS_DAMAGED] = 0
	}
}

collect_money :: proc(gc: ^Game_Cache) {
	if gc.owner[mm.capital[gc.cur_player]] == gc.cur_player {
		gc.money[gc.cur_player] += gc.income[gc.cur_player]
	}
}

rotate_turns :: proc(gc: ^Game_Cache) {
	gc.cur_player = Player_ID((u8(gc.cur_player) + 1) % PLAYERS_COUNT)
	gc.clear_needed = false
	gc.is_bomber_cache_current = false
	gc.is_fighter_cache_current = false
	for land in Land_ID {
		if gc.owner[land] == gc.cur_player {
			gc.builds_left[land] = gc.factory_prod[land]
		}
		gc.land_combat_status[land] = .NO_COMBAT
		gc.max_bombards[land] = 0
		gc.skipped_a2a[l2aid(land)] = {}
		gc.skipped_buys[l2aid(land)] = {}
		gc.active_armies[land] = {}
		idle_armies := &gc.idle_armies[land][gc.cur_player]
		gc.active_armies[land][.INF_UNMOVED] = idle_armies[.INF]
		gc.active_armies[land][.ARTY_UNMOVED] = idle_armies[.ARTY]
		gc.active_armies[land][.TANK_UNMOVED] = idle_armies[.TANK]
		gc.active_armies[land][.AAGUN_UNMOVED] = idle_armies[.AAGUN]
		gc.active_land_planes[land] = {}
		idle_planes := &gc.idle_land_planes[land][gc.cur_player]
		gc.active_land_planes[land][.FIGHTER_UNMOVED] = idle_planes[.FIGHTER]
		gc.active_land_planes[land][.BOMBER_UNMOVED] = idle_planes[.BOMBER]
	}

	for sea in Sea_ID {
		gc.sea_combat_status[sea] = .NO_COMBAT
		gc.skipped_a2a[s2aid(sea)] = {}
		gc.skipped_buys[s2aid(sea)] = {}
		gc.active_ships[sea] = {}
		idle_ships := &gc.idle_ships[sea][gc.cur_player]
		gc.active_ships[sea][.TRANS_EMPTY_UNMOVED] = idle_ships[.TRANS_EMPTY]
		gc.active_ships[sea][.TRANS_1I_UNMOVED] = idle_ships[.TRANS_1I]
		gc.active_ships[sea][.TRANS_1A_UNMOVED] = idle_ships[.TRANS_1A]
		gc.active_ships[sea][.TRANS_1T_UNMOVED] = idle_ships[.TRANS_1T]
		gc.active_ships[sea][.TRANS_2I_2_MOVES] = idle_ships[.TRANS_2I]
		gc.active_ships[sea][.TRANS_1I_1A_2_MOVES] = idle_ships[.TRANS_1I_1A]
		gc.active_ships[sea][.TRANS_1I_1T_2_MOVES] = idle_ships[.TRANS_1I_1T]
		gc.active_ships[sea][.SUB_UNMOVED] = idle_ships[.SUB]
		gc.active_ships[sea][.DESTROYER_UNMOVED] = idle_ships[.DESTROYER]
		gc.active_ships[sea][.CARRIER_UNMOVED] = idle_ships[.CARRIER]
		gc.active_ships[sea][.CRUISER_UNMOVED] = idle_ships[.CRUISER]
		gc.active_ships[sea][.BATTLESHIP_UNMOVED] = idle_ships[.BATTLESHIP]
		gc.active_ships[sea][.BS_DAMAGED_UNMOVED] = idle_ships[.BS_DAMAGED]
		gc.active_sea_planes[sea] = {}
		idle_planes := &gc.idle_sea_planes[sea][gc.cur_player]
		gc.active_sea_planes[sea][.FIGHTER_UNMOVED] = idle_planes[.FIGHTER]
		gc.active_sea_planes[sea][.BOMBER_UNMOVED] = idle_planes[.BOMBER]
	}
	count_sea_unit_totals(gc)
	load_open_canals(gc)
	// refresh_landable_planes(gc)
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
	for ally in sa.slice(&mm.allies[gs.cur_player]) {
		allied_score += int(gs.money[ally])
	}
	for enemy in sa.slice(&mm.enemies[gs.cur_player]) {
		enemy_score += int(gs.money[enemy])
	}
	for player in Player_ID {
		mil_cost := 0
		for land in Land_ID {
			for army in Idle_Army {
				mil_cost += int(gs.idle_armies[land][player][army]) * int(COST_IDLE_ARMY[army])
			}
			for plane in Idle_Plane {
				mil_cost += int(gs.idle_land_planes[land][player][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		for sea in Sea_ID {
			for ship in Idle_Ship {
				mil_cost += int(gs.idle_ships[sea][player][ship]) * int(COST_IDLE_SHIP[ship])
			}
			for plane in Idle_Plane {
				mil_cost += int(gs.idle_sea_planes[sea][player][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		if mm.team[player] == mm.team[gs.cur_player] {
			allied_score += mil_cost
		} else {
			enemy_score += mil_cost
		}
	}
	score: f64 = f64(allied_score) / f64(enemy_score + allied_score)
	// ??? if starting_player >= PLAYERS_COUNT do return 1 - score
	return score
}

evaluate_cache :: #force_inline proc(gc: ^Game_Cache) -> f64 {
	return evaluate_state(&gc.state)
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
	if mm.team[gc.cur_player] == .Axis {
		score = 1 - score
	}
	return score
}

get_possible_actions :: proc(gs: ^Game_State) -> Actions_Bitset {
	// Return the list of possible actions from the given state
	gc: Game_Cache
	// set unlucky teams
	ok := initialize_map_constants(&gc)
	load_cache_from_state(&gc, gs)
	gc.unlucky_teams = {mm.team[gc.cur_player]}
	gc.answers_remaining = 0
	gc.seed = 0
	debug_checks(&gc)
	for {
		play_full_turn(&gc) or_break
	}
	return gc.valid_actions
}

apply_action :: proc(gs: ^Game_State, action: Action_ID) {
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
