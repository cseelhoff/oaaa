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

get_factory_buy :: proc(gc: ^Game_Cache) -> (action: Action_ID, ok: bool) {
	action = gc.valid_actions.data[0]
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return action, false
		if mm.is_human[gc.cur_player] {
			print_game_state(gc)
			fmt.println("Buying Factory For: ")
			for valid_move in sa.slice(&gc.valid_actions) {
				if valid_move >= Action_ID {
					fmt.print(int(valid_move), "=Skip", ", ")
				} else {
					fmt.print(int(valid_move), act2air(valid_move), ", ")
				}
			}
			action = get_user_input(gc)
		} else {
			action = get_ai_input(gc)
		}
	}
	update_factory_history(gc, action)
	return action, true
}

update_factory_history :: proc(gc: ^Game_Cache, action: u8) {
	for {
		assert(gc.valid_actions.len > 0)
		valid_action := gc.valid_actions.data[gc.valid_actions.len - 1]
		if (valid_action == action) do return
		Air_ID[valid_action].skipped_moves[valid_action] = true
		gc.valid_actions.len -= 1
	}
}

update_buy_history :: proc(gc: ^Game_Cache, src_air: Air_ID, action: Buy_Action) {
	for {
		assert(gc.valid_actions.len > 0)
		valid_action_idx := gc.valid_actions.data[gc.valid_actions.len - 1]
		if (action_idx_to_buy(valid_action_idx) == action) do return
		src_air.skipped_buys[action_idx_to_buy(valid_action_idx)] = true
		gc.clear_needed = true
		gc.valid_actions.len -= 1
	}
}

buy_to_action_idx :: proc(action: Buy_Action) -> Action_ID {
	return Action_ID(u8(action) + TERRITORIES_COUNT)
}

action_idx_to_buy :: proc(action: u8) -> Buy_Action {
	return Buy_Action(action - TERRITORIES_COUNT)
}

add_buy_if_not_skipped :: proc(gc: ^Game_Cache, src_air: Air_ID, action: Buy_Action) {
	if !src_air.skipped_buys[u8(action)] {
		sa.push(&gc.valid_actions, buy_to_action_idx(action))
	}
}

buy_sea_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for dst_sea in sa.slice(&land.adjacent_seas) {
		for (gc.builds_left[land] > 0 && !dst_sea.skipped_buys[Buy_Action.SKIP_BUY]) {
			repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
			gc.valid_actions.len = 1
			if gc.cur_player.money >= Cost_Buy[Buy_Action.BUY_FIGHTER] + repair_cost &&
			   dst_sea.can_fighter_land_here {
				add_buy_if_not_skipped(gc, dst_sea, Buy_Action.BUY_FIGHTER)
			}
			for buy_ship in Valid_Sea_Buys {
				if gc.cur_player.money < Cost_Buy[buy_ship] + repair_cost do continue
				add_buy_if_not_skipped(gc, dst_sea, buy_ship)
			}
			action := get_buy_input(gc, dst_sea) or_return
			if action == .SKIP_BUY {
				dst_sea.skipped_buys[Buy_Action.SKIP_BUY] = true
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
			gc.cur_player.money -= (Cost_Buy[action] + repair_cost)
			// fmt.println(gc.cur_player.money)
			if action == .BUY_FIGHTER {
				dst_sea.active_planes[Active_Plane.FIGHTER_0_MOVES] += 1
				dst_sea.idle_planes[gc.cur_player.index][Idle_Plane.FIGHTER] += 1
				dst_sea.can_fighter_land_here = is_carrier_available(gc, dst_sea)
			} else {
				ship := Buy_Active_Ship[action]
				dst_sea.active_ships[ship] += 1
				dst_sea.idle_ships[gc.cur_player.index][Active_Ship_To_Idle[ship]] += 1
				if ship == .CARRIER_0_MOVES do dst_sea.can_fighter_land_here = true
			}
			dst_sea.team_units[gc.cur_player.team.index] += 1
		}
	}
	return true
}

clear_buy_history :: proc(gc: ^Game_Cache, land: Land_ID) {
	for sea in sa.slice(&land.adjacent_seas) {
		mem.zero_slice(sea.skipped_buys[:])
	}
	gc.clear_needed = false
}

buy_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for (gc.builds_left[land] > 0) {
		repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
		gc.valid_actions.len = 1
		for buy_plane in Valid_Air_Buys {
			if gc.cur_player.money < Cost_Buy[buy_plane] + repair_cost do continue
			add_buy_if_not_skipped(gc, land, buy_plane)
		}
		for buy_army in Valid_Land_Buys {
			if gc.cur_player.money < Cost_Buy[buy_army] + repair_cost do continue
			add_buy_if_not_skipped(gc, land, buy_army)
		}
		action := get_buy_input(gc, land) or_return
		if action == .SKIP_BUY {
			gc.builds_left[land] = 0
			break
		}
		gc.builds_left[land] -= 1
		gc.factory_dmg[land] -= repair_cost
		gc.cur_player.money -= Cost_Buy[action] + repair_cost
		if action == .BUY_FIGHTER || action == .BUY_BOMBER {
			plane := Buy_Active_Plane[action]
			land.active_planes[plane] += 1
			land.idle_planes[gc.cur_player.index][Active_Plane_To_Idle[plane]] += 1
		} else {
			army := Buy_Active_Army[action]
			land.active_armies[army] += 1
			land.idle_armies[gc.cur_player.index][Active_Army_To_Idle[army]] += 1
		}
		land.team_units[gc.cur_player.team.index] += 1
	}
	return true
}

buy_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.valid_actions.data[0] = buy_to_action_idx(.SKIP_BUY)
	for land in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.builds_left[land] == 0 do continue
		if gc.clear_needed do clear_buy_history(gc, land)
		buy_sea_units(gc, land) or_return
		buy_land_units(gc, land) or_return
	}
	return true
}
