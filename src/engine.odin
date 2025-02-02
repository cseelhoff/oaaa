package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:time"

GLOBAL_TICK := 0
ACTUALLY_PRINT := false
when ODIN_DEBUG && false {
	debug_checks :: proc(gc: ^Game_Cache) {
		GLOBAL_TICK += 1
		if GLOBAL_TICK >= 24495625300000 {
			fmt.println("Enable Print")
			print_game_state(gc)
			ACTUALLY_PRINT = true
		} //else do return
		for sea in Sea_ID {
			team_idles: [Team_ID]u8 = {
				.Allies = 0,
				.Axis   = 0,
			}
			for active_ship in Active_Ship {
				ship := gc.active_ships[sea][active_ship]
				if ship < 0 || ship > 200 {
					fmt.eprintln("Negative active ships")
				}
			}

			for player in Player_ID {
				for idle_ship in Idle_Ship {
					ship := gc.idle_ships[sea][player][idle_ship]
					if ship < 0 || ship > 200 {
						fmt.eprintln("Negative idle ships")
					}
					team_idles[mm.team[player]] += ship
				}
				for idle_plane in Idle_Plane {
					planes := gc.idle_sea_planes[sea][player][idle_plane]
					if planes < 0 || planes > 200 {
						fmt.eprintln("Negative idle planes")
					} else if planes > 0 &&
					   idle_plane == .BOMBER &&
					   mm.team[player] != mm.team[gc.cur_player] {
						fmt.eprintln("Enemy bombers at sea")
					}
					team_idles[mm.team[player]] += planes
				}
			}
			if gc.team_sea_units[sea][.Allies] != team_idles[.Allies] {
				fmt.eprintln("Unequal team 0 units")
			}
			if gc.team_sea_units[sea][.Axis] != team_idles[.Axis] {
				fmt.eprintln("Unequal team 1 units")
			}
			if gc.team_sea_units[sea][.Allies] < 0 {
				fmt.eprintln("Negative team units")
			}
			if gc.team_sea_units[sea][.Axis] < 0 {
				fmt.eprintln("Negative team units")
			}
		}
		for land in Land_ID {
			team_idles: [Team_ID]u8 = {
				.Allies = 0,
				.Axis   = 0,
			}
			for active_army in Active_Army {
				army := gc.active_armies[land][active_army]
				if army < 0 || army > 200 {
					fmt.eprintln("Negative active armies")
				}
			}
			for player in Player_ID {
				for idle_army in Idle_Army {
					army := gc.idle_armies[land][player][idle_army]
					if army < 0 || army > 200 {
						fmt.eprintln("Negative idle armies")
					}
					team_idles[mm.team[player]] += army
				}

				for idle_plane in Idle_Plane {
					plane := gc.idle_land_planes[land][player][idle_plane]
					if plane < 0 || plane > 200 {
						fmt.eprintln("Negative idle planes")
					}
					team_idles[mm.team[player]] += plane

					if player != gc.cur_player &&
					   plane > 0 &&
					   idle_plane == .BOMBER &&
					   mm.team[gc.owner[land]] != mm.team[player] {
						print_game_state(gc)
						fmt.eprintln("Enemy bombers at enemy land")
					}

					if team_idles[mm.team[player]] > 0 &&
					   mm.team[gc.owner[land]] == mm.team[gc.cur_player] &&
					   mm.team[player] != mm.team[gc.cur_player] {
						fmt.eprintln("Enemy units on land")
					}
				}
			}
			if gc.team_land_units[land][.Allies] != team_idles[.Allies] {
				fmt.eprintln("Unequal team 0 units")
			}
			if gc.team_land_units[land][.Axis] != team_idles[.Axis] {
				fmt.eprintln("Unequal team 1 units")
			}
			if gc.team_land_units[land][.Allies] < 0 {
				fmt.eprintln("Negative team units")
			}
			if gc.team_land_units[land][.Axis] < 0 {
				fmt.eprintln("Negative team units")
			}
		}
	}
} else {
	debug_checks :: proc(gc: ^Game_Cache) {}
}
play_full_turn :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// start := time.now()
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
	// end := time.now()
	// duration := time.duration_nanoseconds(time.diff(start, end))
	// fmt.println("Turn took ", duration, " nanoseconds")
	return true
}

update_move_history :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
	// get a list of newly skipped valid_actions
	for valid_action in gc.valid_actions {
		// assert(card(gc.valid_actions) > 0)
		// valid_action := gc.valid_actions.data[gc.valid_actions.len - 1]
		if valid_action == to_action(src_air) do continue
		if valid_action == to_action(dst_air) do break
		gc.rejected_moves_from[src_air] += {to_air(valid_action)}
		gc.clear_history_needed = true
	}
	gc.valid_actions -= transmute(Action_Bitset)u32(transmute(u16)gc.rejected_moves_from[src_air])
}

clear_move_history :: proc(gc: ^Game_Cache) {
	for air in Air_ID {
		gc.rejected_moves_from[air] = {}
	}
	gc.clear_history_needed = false
}

/*
Factory Building Process
1. Validation Phase:
   - Checks player's money and territory ownership
   - Verifies no existing production or combat
   - Builds list of valid locations
2. Purchase Phase:
   - Gets player's choice of location
   - Deducts cost and sets up production
   - Records factory in player's list
Returns true when:
- Player can't afford factory
- No valid build locations
- Player chooses to skip
- Purchase completed successfully
*/
buy_factory :: proc(gc: ^Game_Cache) -> (ok: bool) {
	if gc.money[gc.cur_player] < FACTORY_COST do return true
	gc.valid_actions = {.Skip_Action}
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player ||
		   gc.factory_prod[land] > 0 ||
		   land in (gc.more_land_combat_needed | gc.land_combat_started) ||
		   to_air(land) in gc.rejected_moves_from[to_air(land)] {
			continue
		}
		gc.valid_actions += {to_action(land)}
	}
	for gc.money[gc.cur_player] < FACTORY_COST {
		factory_land_action := get_factory_buy(gc) or_return
		if factory_land_action == .Skip_Action do return true
		gc.money[gc.cur_player] -= FACTORY_COST
		factory_land := to_land(factory_land_action)
		gc.factory_prod[factory_land] = mm.value[factory_land]
		sa.push(&gc.factory_locations[gc.cur_player], factory_land)
	}
	return true
}

// Repairs all damaged battleships at turn start
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
	gc.cur_player = Player_ID((u8(gc.cur_player) + 1) % len(Player_ID))
	gc.more_land_combat_needed = {}
	gc.land_combat_started = {}
	gc.more_sea_combat_needed = {}
	gc.sea_combat_started = {}
	gc.friendly_owner = {}
	for land in Land_ID {
		if gc.owner[land] == gc.cur_player {
			gc.builds_left[land] = gc.factory_prod[land]
		}
		if mm.team[gc.owner[land]] == mm.team[gc.cur_player] {
			gc.friendly_owner += {land}
		}
		gc.max_bombards[land] = 0
		gc.rejected_moves_from[to_air(land)] = {}
		gc.skipped_buys[to_air(land)] = {}
		gc.active_armies[land] = {}
		idle_armies := &gc.idle_armies[land][gc.cur_player]
		gc.active_armies[land][.INF_1_MOVES] = idle_armies[.INF]
		gc.active_armies[land][.ARTY_1_MOVES] = idle_armies[.ARTY]
		gc.active_armies[land][.TANK_2_MOVES] = idle_armies[.TANK]
		gc.active_armies[land][.AAGUN_1_MOVES] = idle_armies[.AAGUN]
		gc.active_land_planes[land] = {}
		idle_planes := &gc.idle_land_planes[land][gc.cur_player]
		gc.active_land_planes[land][.FIGHTER_UNMOVED] = idle_planes[.FIGHTER]
		gc.active_land_planes[land][.BOMBER_UNMOVED] = idle_planes[.BOMBER]
		if gc.team_land_units[land][mm.team[gc.cur_player]] > 0 {
			gc.has_enemy_units += {land}
		} else {
			gc.has_enemy_units -= {land}
		}
	}

	for sea in Sea_ID {
		gc.rejected_moves_from[to_air(sea)] = {}
		gc.skipped_buys[to_air(sea)] = {}
		gc.active_ships[sea] = {}
		idle_ships := &gc.idle_ships[sea][gc.cur_player]
		gc.active_ships[sea][.TRANS_EMPTY_UNMOVED] = idle_ships[.TRANS_EMPTY]
		gc.active_ships[sea][.TRANS_1I_UNMOVED] = idle_ships[.TRANS_1I]
		gc.active_ships[sea][.TRANS_1A_UNMOVED] = idle_ships[.TRANS_1A]
		gc.active_ships[sea][.TRANS_1T_UNMOVED] = idle_ships[.TRANS_1T]
		gc.active_ships[sea][.TRANS_2I_2_MOVES] = idle_ships[.TRANS_2I]
		gc.active_ships[sea][.TRANS_1I_1A_2_MOVES] = idle_ships[.TRANS_1I_1A]
		gc.active_ships[sea][.TRANS_1I_1T_2_MOVES] = idle_ships[.TRANS_1I_1T]
		gc.active_ships[sea][.SUB_2_MOVES] = idle_ships[.SUB]
		gc.active_ships[sea][.DESTROYER_2_MOVES] = idle_ships[.DESTROYER]
		gc.active_ships[sea][.CARRIER_2_MOVES] = idle_ships[.CARRIER]
		gc.active_ships[sea][.CRUISER_2_MOVES] = idle_ships[.CRUISER]
		gc.active_ships[sea][.BATTLESHIP_2_MOVES] = idle_ships[.BATTLESHIP]
		gc.active_ships[sea][.BS_DAMAGED_2_MOVES] = idle_ships[.BS_DAMAGED]
		gc.active_sea_planes[sea] = {}
		idle_planes := &gc.idle_sea_planes[sea][gc.cur_player]
		gc.active_sea_planes[sea][.FIGHTER_UNMOVED] = idle_planes[.FIGHTER]
		gc.active_sea_planes[sea][.BOMBER_UNMOVED] = idle_planes[.BOMBER]
	}
	resfresh_cache(gc)
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
				mil_cost +=
					int(gs.idle_land_planes[land][player][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		for sea in Sea_ID {
			for ship in Idle_Ship {
				mil_cost += int(gs.idle_ships[sea][player][ship]) * int(COST_IDLE_SHIP[ship])
			}
			for plane in Idle_Plane {
				mil_cost +=
					int(gs.idle_sea_planes[sea][player][plane]) * int(COST_IDLE_PLANE[plane])
			}
		}
		if mm.team[player] == mm.team[gs.cur_player] {
			allied_score += mil_cost
		} else {
			enemy_score += mil_cost
		}
	}
	score: f64 = f64(allied_score) / f64(enemy_score + allied_score)
	return score
}

evaluate_cache :: #force_inline proc(gc: ^Game_Cache) -> f64 {
	return evaluate_state(&gc.state)
}

gs_copy: Game_State

dump_gs :: proc() {
	save_json(gs_copy)
}

import "core:math/rand"
random_play_until_terminal :: proc(gs: ^Game_State) -> f64 {
	gs_copy := gs^
	gc: Game_Cache
	// ok := initialize_map_constants(gc)
	load_cache_from_state(&gc, gs)
	gc.answers_remaining = 65000
	gc.seed = u16(rand.int_max(RANDOM_MAX))
	//use_selected_action = false;
	score := evaluate_cache(&gc)
	max_loops := 400
	// clear_move_history();
	debug_checks(&gc)
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
		debug_checks(&gc)
		play_full_turn(&gc) or_break
		debug_checks(&gc)
		score = evaluate_cache(&gc)
	}
	score = evaluate_cache(&gc)
	if mm.team[gc.cur_player] == .Axis {
		score = 1 - score
	}
	return score
}

get_possible_actions :: proc(gs: ^Game_State) -> Action_Bitset {
	// Return the list of possible actions from the given state
	gc: Game_Cache
	// print_game_state(&gc)
	// set unlucky teams
	//initialize_map_constants(&gc)
	load_cache_from_state(&gc, gs)
	gc.unlucky_teams = {mm.team[gc.cur_player]}
	gc.answers_remaining = 0
	gc.seed = 0
	debug_checks(&gc)
	for {
		play_full_turn(&gc) or_break
	}
	if gc.cur_player == .USA && gc.active_land_planes[.London][.BOMBER_UNMOVED] == 2 {
		print_game_state(&gc)
		for action in gc.valid_actions {
			fmt.print(action, " ")
		}		
	}
	return gc.valid_actions
}

apply_action :: proc(gs: ^Game_State, action: Action_ID) {
	// Apply the action to the game state
	gc: Game_Cache
	//initialize_map_constants(&gc)
	load_cache_from_state(&gc, gs)
	gc.unlucky_teams = {mm.team[gc.cur_player]}
	gc.answers_remaining = 1
	gc.seed = 0
	gc.selected_action = action
	gc.use_selected_action = true
	//game_cache.clear_history_needed = false
	for {
		play_full_turn(&gc) or_break
	}
	gs^ = gc.state
}

// PYBIND11_MODULE(engine, handle) {
//   handle.doc() = "engine doc";
//   handle.def("random_play_until_terminal", &random_play_until_terminal);
// }
