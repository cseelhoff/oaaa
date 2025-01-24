package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"


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

Valid_Sea_Buys := [?]Buy_Action {
	.BUY_TRANS,
	.BUY_SUB,
	.BUY_DESTROYER,
	.BUY_CARRIER,
	.BUY_CRUISER,
	.BUY_BATTLESHIP,
}

Valid_Air_Buys := [?]Buy_Action{.BUY_FIGHTER, .BUY_BOMBER}

Valid_Land_Buys := [?]Buy_Action{.BUY_INF, .BUY_ARTY, .BUY_TANK, .BUY_AAGUN}

Buy_Active_Ship := [?]Active_Ship {
	Buy_Action.BUY_TRANS      = .TRANS_EMPTY_0_MOVES,
	Buy_Action.BUY_SUB        = .SUB_0_MOVES,
	Buy_Action.BUY_DESTROYER  = .DESTROYER_0_MOVES,
	Buy_Action.BUY_CARRIER    = .CARRIER_0_MOVES,
	Buy_Action.BUY_CRUISER    = .CRUISER_0_MOVES,
	Buy_Action.BUY_BATTLESHIP = .BATTLESHIP_0_MOVES,
}

Buy_Active_Plane := [?]Active_Plane {
	Buy_Action.BUY_FIGHTER = .FIGHTER_0_MOVES,
	Buy_Action.BUY_BOMBER  = .BOMBER_0_MOVES,
}

Buy_Active_Army := [?]Active_Army {
	Buy_Action.BUY_INF   = .INF_0_MOVES,
	Buy_Action.BUY_ARTY  = .ARTY_0_MOVES,
	Buy_Action.BUY_TANK  = .TANK_0_MOVES,
	Buy_Action.BUY_AAGUN = .AAGUN_0_MOVES,
}

Cost_Buy := [Buy_Action]u8 {
	.SKIP_BUY       = 0,
	.BUY_INF        = 3,
	.BUY_ARTY       = 4,
	.BUY_TANK       = 6,
	.BUY_AAGUN      = 5,
	.BUY_FIGHTER    = 10,
	.BUY_BOMBER     = 12,
	.BUY_TRANS      = 7,
	.BUY_SUB        = 6,
	.BUY_DESTROYER  = 8,
	.BUY_CARRIER    = 14,
	.BUY_CRUISER    = 12,
	.BUY_BATTLESHIP = 20,
}

FACTORY_COST :: 15

Buy_Names := [Buy_Action]string {
	.SKIP_BUY       = "SKIP_BUY",
	.BUY_INF        = "BUY_INF",
	.BUY_ARTY       = "BUY_ARTY",
	.BUY_TANK       = "BUY_TANK",
	.BUY_AAGUN      = "BUY_AAGUN",
	.BUY_FIGHTER    = "BUY_FIGHTER",
	.BUY_BOMBER     = "BUY_BOMBER",
	.BUY_TRANS      = "BUY_TRANS",
	.BUY_SUB        = "BUY_SUB",
	.BUY_DESTROYER  = "BUY_DESTROYER",
	.BUY_CARRIER    = "BUY_CARRIER",
	.BUY_CRUISER    = "BUY_CRUISER",
	.BUY_BATTLESHIP = "BUY_BATTLESHIP",
}

print_factory_prompt :: proc(gc: ^Game_Cache) {
	print_game_state(gc)
	fmt.print(mm.color[gc.cur_player])
	fmt.println("Buying Factory For Land: ")
	for valid_action in gc.valid_actions {
		if valid_action == .Skip_Action {
			fmt.print(int(valid_action), "=Skip", ", ")
		} else {
			fmt.print(int(valid_action), to_air(valid_action), ", ")
		}

	}
	fmt.println(DEF_COLOR)
}

get_factory_buy :: proc(gc: ^Game_Cache) -> (action: Action_ID, ok: bool) {
	// action = .Skip_Action
	if card(gc.valid_actions) > 1 {
		if gc.answers_remaining == 0 do return .Skip_Action, false
		if is_human[gc.cur_player] {
			print_game_state(gc)
			print_factory_prompt(gc)
			action = get_user_input(gc)
		} else {
			if ACTUALLY_PRINT do print_factory_prompt(gc)
			action = get_ai_input(gc)
			if ACTUALLY_PRINT {
				fmt.println("AI buy factory Action:", action)
			}
		}
	}
	update_factory_history(gc, action)
	return action, true
}

update_factory_history :: proc(gc: ^Game_Cache, action: Action_ID) {
	actions_to_remove:Action_Bitset={}
	for valid_action in gc.valid_actions {
		// assert(card(gc.valid_actions) > 0)
		// valid_action := gc.valid_actions.data[gc.valid_actions.len - 1]
		if (valid_action == action) do break
		gc.skipped_a2a[to_air(valid_action)] += {to_air(valid_action)}
		actions_to_remove += {valid_action}
		// Air_ID[valid_action].skipped_moves[valid_action] = true
		// gc.valid_actions.len -= 1
	}
	gc.valid_actions -= actions_to_remove
}

update_buy_history :: proc(gc: ^Game_Cache, src_air: Air_ID, action: Buy_Action) {
	for valid_action in gc.valid_actions {
		// assert(gc.valid_actions.len > 0)
		// valid_action_idx := gc.valid_actions.data[gc.valid_actions.len - 1]
		if valid_action == .Skip_Action do continue
		if valid_action == buy_to_action_idx(action) do break
		gc.skipped_buys[src_air] += {to_buy_action(valid_action)}
		gc.clear_needed = true
	}
	gc.valid_actions -= transmute(Action_Bitset)u32(transmute(u16)gc.skipped_buys[src_air])
}

buy_to_action_idx :: proc(action: Buy_Action) -> Action_ID {
	return Action_ID(u8(action) + len(Air_ID))
}

to_buy_action :: proc(action: Action_ID) -> Buy_Action {
	return Buy_Action(u8(action) - len(Air_ID))
}

add_buy_if_not_skipped :: proc(gc: ^Game_Cache, src_air: Air_ID, action: Buy_Action) {
	if action not_in gc.skipped_buys[src_air] {
		gc.valid_actions += {buy_to_action_idx(action)}
	}
}

buy_sea_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for dst_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
		for (gc.builds_left[land] > 0 && .SKIP_BUY not_in gc.skipped_buys[to_air(dst_sea)]) {
			repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
			gc.valid_actions = {.Skip_Action}
			if gc.money[gc.cur_player] >= Cost_Buy[.BUY_FIGHTER] + repair_cost &&
				to_air(dst_sea) in gc.can_fighter_land_here {
				add_buy_if_not_skipped(gc, to_air(dst_sea), .BUY_FIGHTER)
			}
			for buy_ship in Valid_Sea_Buys {
				if gc.money[gc.cur_player] < Cost_Buy[buy_ship] + repair_cost do continue
				add_buy_if_not_skipped(gc, to_air(dst_sea), buy_ship)
			}
			action := get_buy_input(gc, to_air(dst_sea)) or_return
			if action == .SKIP_BUY {
				gc.skipped_buys[to_air(dst_sea)]+= {.SKIP_BUY}
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
			if action == .BUY_FIGHTER {
				gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
				gc.idle_sea_planes[dst_sea][gc.cur_player][.FIGHTER] += 1
				if is_carrier_available(gc, dst_sea) {
					gc.can_fighter_land_here += {to_air(dst_sea)}
				} else {
					gc.can_fighter_land_here -= {to_air(dst_sea)}
				}
			} else {
				ship := Buy_Active_Ship[action]
				gc.active_ships[dst_sea][ship] += 1
				gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[ship]] += 1
				if ship == .CARRIER_0_MOVES do gc.can_fighter_land_here += {to_air(dst_sea)}
			}
			gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
		}
	}
	return true
}

clear_buy_history :: proc(gc: ^Game_Cache, land: Land_ID) {
	for sea in sa.slice(&mm.l2s_1away_via_land[land]) {
		gc.skipped_buys[to_air(sea)] = {}
		// mem.zero_slice(sea.skipped_buys[:])
	}
	gc.clear_needed = false
}

buy_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for (gc.builds_left[land] > 0) {
		repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
		gc.valid_actions = {.Skip_Action}
		for buy_plane in Valid_Air_Buys {
			if gc.money[gc.cur_player] < Cost_Buy[buy_plane] + repair_cost do continue
			add_buy_if_not_skipped(gc, to_air(land), buy_plane)
		}
		for buy_army in Valid_Land_Buys {
			if gc.money[gc.cur_player] < Cost_Buy[buy_army] + repair_cost do continue
			add_buy_if_not_skipped(gc, to_air(land), buy_army)
		}
		action := get_buy_input(gc, to_air(land)) or_return
		if action == .SKIP_BUY {
			gc.builds_left[land] = 0
			break
		}
		gc.builds_left[land] -= 1
		gc.factory_dmg[land] -= repair_cost
		gc.money[gc.cur_player] -= Cost_Buy[action] + repair_cost
		if action == .BUY_FIGHTER || action == .BUY_BOMBER {
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
	gc.valid_actions = {.Skip_Action}
	for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.builds_left[land] == 0 do continue
		if gc.clear_needed do clear_buy_history(gc, land)
		buy_sea_units(gc, land) or_return
		buy_land_units(gc, land) or_return
	}
	return true
}
