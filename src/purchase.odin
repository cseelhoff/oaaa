package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

Buy_Action :: enum {
	SKIP_BUY,
	BUY_INF,
	BUY_ARTY,
	BUY_TANK,
	BUY_AAGUN,
	BUY_FIGHTER,
	BUY_BOMBER,
	BUY_TRANS,
	BUY_SUB,
	BUY_DESTROYER,
	BUY_CARRIER,
	BUY_CRUISER,
	BUY_BATTLESHIP,
}

Valid_Sea_Buys := [?]Action_ID {
	.BUY_TRANS_ACTION,
	.BUY_SUB_ACTION,
	.BUY_DESTROYER_ACTION,
	.BUY_CARRIER_ACTION,
	.BUY_CRUISER_ACTION,
	.BUY_BATTLESHIP_ACTION,
}

Valid_Air_Buys := [?]Action_ID{.BUY_FIGHTER_ACTION, .BUY_BOMBER_ACTION}

Valid_Land_Buys := [?]Action_ID{.BUY_INF_ACTION, .BUY_ARTY_ACTION, .BUY_TANK_ACTION, .BUY_AAGUN_ACTION}

Buy_Active_Ship: [Action_ID]Active_Ship

@(init)
init_buy_active_ship :: proc() {
	Buy_Active_Ship[.BUY_TRANS_ACTION] = .TRANS_EMPTY_0_MOVES
	Buy_Active_Ship[.BUY_SUB_ACTION] = .SUB_0_MOVES
	Buy_Active_Ship[.BUY_DESTROYER_ACTION] = .DESTROYER_0_MOVES
	Buy_Active_Ship[.BUY_CARRIER_ACTION] = .CARRIER_0_MOVES
	Buy_Active_Ship[.BUY_CRUISER_ACTION] = .CRUISER_0_MOVES
	Buy_Active_Ship[.BUY_BATTLESHIP_ACTION] = .BATTLESHIP_0_MOVES
}

Buy_Active_Plane: [Action_ID]Active_Plane

@(init)
init_buy_active_plane :: proc() {
	Buy_Active_Plane[.BUY_FIGHTER_ACTION] = .FIGHTER_0_MOVES
	Buy_Active_Plane[.BUY_BOMBER_ACTION] = .BOMBER_0_MOVES
}

Buy_Active_Army: [Action_ID]Active_Army

@(init)
init_buy_active_army :: proc() {
	Buy_Active_Army[.BUY_INF_ACTION] = .INF_0_MOVES
	Buy_Active_Army[.BUY_ARTY_ACTION] = .ARTY_0_MOVES
	Buy_Active_Army[.BUY_TANK_ACTION] = .TANK_0_MOVES
	Buy_Active_Army[.BUY_AAGUN_ACTION] = .AAGUN_0_MOVES
}

Cost_Buy : [Action_ID]u8

@(init)
init_cost_buy :: proc() {
	Cost_Buy[.Skip_Action] = 0
	Cost_Buy[.BUY_INF_ACTION] = 3
	Cost_Buy[.BUY_ARTY_ACTION] = 4
	Cost_Buy[.BUY_TANK_ACTION] = 6
	Cost_Buy[.BUY_AAGUN_ACTION] = 5
	Cost_Buy[.BUY_FIGHTER_ACTION] = 10
	Cost_Buy[.BUY_BOMBER_ACTION] = 12
	Cost_Buy[.BUY_TRANS_ACTION] = 7
	Cost_Buy[.BUY_SUB_ACTION] = 6
	Cost_Buy[.BUY_DESTROYER_ACTION] = 8
	Cost_Buy[.BUY_CARRIER_ACTION] = 14
	Cost_Buy[.BUY_CRUISER_ACTION] = 12
	Cost_Buy[.BUY_BATTLESHIP_ACTION] = 20
}

FACTORY_COST :: 15

// Buy_Names := [Buy_Action]string {
// 	.SKIP_BUY       = "SKIP_BUY",
// 	.BUY_INF        = "BUY_INF",
// 	.BUY_ARTY       = "BUY_ARTY",
// 	.BUY_TANK       = "BUY_TANK",
// 	.BUY_AAGUN      = "BUY_AAGUN",
// 	.BUY_FIGHTER    = "BUY_FIGHTER",
// 	.BUY_BOMBER     = "BUY_BOMBER",
// 	.BUY_TRANS      = "BUY_TRANS",
// 	.BUY_SUB        = "BUY_SUB",
// 	.BUY_DESTROYER  = "BUY_DESTROYER",
// 	.BUY_CARRIER    = "BUY_CARRIER",
// 	.BUY_CRUISER    = "BUY_CRUISER",
// 	.BUY_BATTLESHIP = "BUY_BATTLESHIP",
// }

// print_factory_prompt :: proc(gc: ^Game_Cache) {
// 	print_game_state(gc)
// 	fmt.print(mm.color[gc.cur_player])
// 	fmt.println("Buying Factory For Land: ")
// 	for valid_action in gc.valid_actions {
// 		if valid_action == .Skip_Action {
// 			fmt.print(int(valid_action), "=Skip", ", ")
// 		} else {
// 			fmt.print(int(valid_action), to_air(valid_action), ", ")
// 		}

// 	}
// 	fmt.println(DEF_COLOR)
// }

// get_factory_buy :: proc(gc: ^Game_Cache) -> (action: Action_ID, ok: bool) {
// 	// action = .Skip_Action
// 	if card(gc.valid_actions) > 1 {
// 		if gc.answers_remaining == 0 do return .Skip_Action, false
// 		if is_human[gc.cur_player] {
// 			print_game_state(gc)
// 			print_factory_prompt(gc)
// 			action = get_user_input(gc)
// 		} else {
// 			if ACTUALLY_PRINT do print_factory_prompt(gc)
// 			action = get_ai_input(gc)
// 			if ACTUALLY_PRINT {
// 				fmt.println("AI buy factory Action:", action)
// 			}
// 		}
// 	}
// 	update_move_history_2(gc, action)
// 	return action, true
// }

// update_buy_history :: proc(gc: ^Game_Cache, src_air: Air_ID, action: Buy_Action) {
// 	for valid_action in gc.valid_actions {
// 		// assert(gc.valid_actions.len > 0)
// 		// valid_action_idx := gc.valid_actions.data[gc.valid_actions.len - 1]
// 		if valid_action == .Skip_Action do continue
// 		if valid_action == buy_to_action_idx(action) do break
// 		gc.skipped_buys[src_air] += {to_buy_action(valid_action)}
// 		gc.clear_history_needed = true
// 	}
// 	gc.valid_actions -= transmute(Action_Bitset)u32(transmute(u16)gc.skipped_buys[src_air])
// }

buy_sea_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for dst_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
		for (gc.builds_left[land] > 0 &&
			    gc.smallest_allowable_action[to_air(dst_sea)] != .Skip_Action) {
			repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
			reset_valid_actions(gc)
			if gc.money[gc.cur_player] >= Cost_Buy[.BUY_FIGHTER_ACTION] + repair_cost {
				get_airs(gc.can_fighter_land_here, &air_positions)
				_, found := slice.linear_search(air_positions[:], to_air(dst_sea))
				if found {
					add_valid_action(gc, .BUY_FIGHTER_ACTION)
				}
			}
			for buy_ship in Valid_Sea_Buys {
				if gc.money[gc.cur_player] < Cost_Buy[buy_ship] + repair_cost do continue
				add_valid_action(gc, buy_ship)
			}
			gc.current_territory = to_air(dst_sea)
			action := get_action_input(gc) or_return
			if action == .Skip_Action {
				gc.smallest_allowable_action[to_air(dst_sea)] = .Skip_Action
				break
			}
			gc.builds_left[land] -= 1
			gc.factory_dmg[land] -= repair_cost
			// buy_cost := Cost_Buy[action]
			// fmt.printf(
			// 	"Buying %s for %d. Repair cost: %d  Starting money: %d  Ending money:",
			// 	Buy_Names[action],
			// 	buy_cost,
			// 	repair_cost,
			// 	gc.cur_player.money,
			// )
			gc.money[gc.cur_player] -= (Cost_Buy[action] + repair_cost)
			// fmt.println(gc.cur_player.money)
			if action == .BUY_FIGHTER_ACTION {
				gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
				add_ally_fighters_to_sea(gc, dst_sea, gc.cur_player, 1)
			} else {
				ship := Buy_Active_Ship[action]
				gc.active_ships[dst_sea][ship] += 1
				gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[ship]] += 1
				if ship == .CARRIER_0_MOVES {
					gc.allied_carriers_total[dst_sea] += 1
					if gc.allied_carriers_total[dst_sea] * 2 > gc.allied_fighters_total[dst_sea] {
						gc.has_carrier_space += {dst_sea}
						gc.is_fighter_cache_current = false
					}
				}
				gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
			}
		}
	}
	return true
}

// clear_buy_history :: proc(gc: ^Game_Cache, land: Land_ID) {
// 	for sea in sa.slice(&mm.l2s_1away_via_land[land]) {
// 		gc.skipped_buys[to_air(sea)] = {}
// 		// mem.zero_slice(sea.skipped_buys[:])
// 	}
// 	gc.clear_history_needed = false
// }

buy_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for (gc.builds_left[land] > 0) {
		repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
		reset_valid_actions(gc)
		for buy_plane in Valid_Air_Buys {
			if gc.money[gc.cur_player] < Cost_Buy[buy_plane] + repair_cost do continue
			add_valid_action(gc, buy_plane)
		}
		for buy_army in Valid_Land_Buys {
			if gc.money[gc.cur_player] < Cost_Buy[buy_army] + repair_cost do continue
			add_valid_action(gc, buy_army)
		}
		gc.current_territory = to_air(land)
		gc.current_active_unit = .FACTORY
		action := get_action_input(gc) or_return
		if action == .Skip_Action {
			gc.builds_left[land] = 0
			break
		}
		gc.builds_left[land] -= 1
		gc.factory_dmg[land] -= repair_cost
		gc.money[gc.cur_player] -= Cost_Buy[action] + repair_cost
		if action == .BUY_FIGHTER_ACTION || action == .BUY_BOMBER_ACTION {
			plane := Buy_Active_Plane[action]
			gc.active_land_planes[land][plane] += 1
			gc.idle_land_planes[land][gc.cur_player][Active_Plane_To_Idle[plane]] += 1
		} else {
			army := Buy_Active_Army[action]
			gc.active_armies[land][army] += 1
			gc.idle_armies[land][gc.cur_player][Active_Army_To_Idle[army]] += 1
		}
		gc.team_land_units[land][mm.team[gc.cur_player]] += 1
	}
	return true
}

buy_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	reset_valid_actions(gc)
	for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.builds_left[land] == 0 do continue
		if gc.clear_history_needed do clear_move_history(gc)
		buy_sea_units(gc, land) or_return
		buy_land_units(gc, land) or_return
	}
	return true
}
