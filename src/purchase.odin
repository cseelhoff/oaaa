#+feature global-context
package oaaa
import "core:fmt"
import "core:slice"

Buy_Action :: enum {
	Skip_Buy,
	Buy_Infantry,
	Buy_Artillery,
	Buy_Tank,
	Buy_AAGun,
	Buy_Fighter,
	Buy_Bomber,
	Buy_Transport,
	Buy_Submarine,
	Buy_Destroyer,
	Buy_Carrier,
	Buy_Cruiser,
	Buy_Battleship,
}

valid_sea_buys := [?]Action_ID {
	.Buy_Transport_Action,
	.Buy_Submarine_Action,
	.Buy_Destroyer_Action,
	.Buy_Carrier_Action,
	.Buy_Cruiser_Action,
	.Buy_Battleship_Action,
}

valid_air_buys := [?]Action_ID{.Buy_Fighter_Action, .Buy_Bomber_Action}

valid_land_buys := [?]Action_ID{.Buy_Infantry_Action, .Buy_Artillery_Action, .Buy_Tank_Action, .Buy_AAGun_Action}

buy_active_ship: [Action_ID]Active_Ship

@(init)
init_buy_active_ship :: proc() {
	buy_active_ship[.Buy_Transport_Action] = .Transport_Empty_0_Moves
	buy_active_ship[.Buy_Submarine_Action] = .Submarine_0_Moves
	buy_active_ship[.Buy_Destroyer_Action] = .Destroyer_0_Moves
	buy_active_ship[.Buy_Carrier_Action] = .Carrier_0_Moves
	buy_active_ship[.Buy_Cruiser_Action] = .Cruiser_0_Moves
	buy_active_ship[.Buy_Battleship_Action] = .Battleship_0_Moves
}

buy_active_plane: [Action_ID]Active_Plane

@(init)
init_buy_active_plane :: proc() {
	buy_active_plane[.Buy_Fighter_Action] = .Fighter_0_Moves
	buy_active_plane[.Buy_Bomber_Action] = .Bomber_0_Moves
}

buy_active_army: [Action_ID]Active_Army

@(init)
init_buy_active_army :: proc() {
	buy_active_army[.Buy_Infantry_Action] = .Infantry_0_Moves
	buy_active_army[.Buy_Artillery_Action] = .Artillery_0_Moves
	buy_active_army[.Buy_Tank_Action] = .Tank_0_Moves
	buy_active_army[.Buy_AAGun_Action] = .AAGun_0_Moves
}

cost_buy : [Action_ID]u8

@(init)
init_cost_buy :: proc() {
	cost_buy[.Skip_Action] = 0
	cost_buy[.Buy_Infantry_Action] = 3
	cost_buy[.Buy_Artillery_Action] = 4
	cost_buy[.Buy_Tank_Action] = 6
	cost_buy[.Buy_AAGun_Action] = 5
	cost_buy[.Buy_Fighter_Action] = 10
	cost_buy[.Buy_Bomber_Action] = 12
	cost_buy[.Buy_Transport_Action] = 7
	cost_buy[.Buy_Submarine_Action] = 6
	cost_buy[.Buy_Destroyer_Action] = 8
	cost_buy[.Buy_Carrier_Action] = 14
	cost_buy[.Buy_Cruiser_Action] = 12
	cost_buy[.Buy_Battleship_Action] = 20
}

FACTORY_COST :: 15

// Buy_Names := [Buy_Action]string {
// 	.Skip_Buy       = "Skip_Buy",
// 	.Buy_Infantry        = "Buy_Infantry",
// 	.Buy_Artillery       = "Buy_Artillery",
// 	.Buy_Tank       = "Buy_Tank",
// 	.Buy_AAGun      = "Buy_AAGun",
// 	.Buy_Fighter    = "Buy_Fighter",
// 	.Buy_Bomber     = "Buy_Bomber",
// 	.Buy_Transport      = "Buy_Transport",
// 	.Buy_Submarine        = "Buy_Submarine",
// 	.Buy_Destroyer  = "Buy_Destroyer",
// 	.Buy_Carrier    = "Buy_Carrier",
// 	.Buy_Cruiser    = "Buy_Cruiser",
// 	.Buy_Battleship = "Buy_Battleship",
// }

// print_factory_prompt :: proc(gc: ^Game_Cache) {
// 	print_game_state(gc)
// 	fmt.print(mm.color[gc.acting_nation])
// 	fmt.println("Buying Factory For Land: ")
// 	for valid_action in gc.valid_actions {
// 		if valid_action == .Skip_Action {
// 			fmt.print(int(valid_action), "=Skip", ", ")
// 		} else {
// 			fmt.print(int(valid_action), to_region(valid_action), ", ")
// 		}

// 	}
// 	fmt.println(DEF_COLOR)
// }

// get_factory_buy :: proc(gc: ^Game_Cache) -> (action: Action_ID, ok: bool) {
// 	// action = .Skip_Action
// 	if card(gc.valid_actions) > 1 {
// 		if gc.answers_remaining == 0 do return .Skip_Action, false
// 		if is_human[gc.acting_nation] {
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

// update_buy_history :: proc(gc: ^Game_Cache, src_region: Region_ID, action: Buy_Action) {
// 	for valid_action in gc.valid_actions {
// 		// assert(gc.valid_actions.len > 0)
// 		// valid_action_idx := gc.valid_actions.data[gc.valid_actions.len - 1]
// 		if valid_action == .Skip_Action do continue
// 		if valid_action == buy_to_action_idx(action) do break
// 		gc.skipped_buys[src_region] += {to_buy_action(valid_action)}
// 		gc.clear_history_needed = true
// 	}
// 	gc.valid_actions -= transmute(Action_Bitset)u32(transmute(u16)gc.skipped_buys[src_region])
// }

buy_sea_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for dst_sea in mm.coastal_seas[land] {
		for (gc.builds_left[land] > 0 &&
			    gc.smallest_allowable_action[to_region(dst_sea)] != .Skip_Action) {
			repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
			reset_valid_actions(gc)
			if gc.treasury[gc.acting_nation] >= cost_buy[.Buy_Fighter_Action] + repair_cost {
				get_regions(gc.can_fighter_land_here, &region_positions)
				_, found := slice.linear_search(region_positions[:], to_region(dst_sea))
				if found {
					add_valid_action(gc, .Buy_Fighter_Action)
				}
			}
			for buy_ship in valid_sea_buys {
				if gc.treasury[gc.acting_nation] < cost_buy[buy_ship] + repair_cost do continue
				add_valid_action(gc, buy_ship)
			}
			gc.current_territory = to_region(dst_sea)
			action := get_action_input(gc) or_return
			if action == .Skip_Action {
				gc.smallest_allowable_action[to_region(dst_sea)] = .Skip_Action
				break
			}
			gc.builds_left[land] -= 1
			gc.factory_dmg[land] -= repair_cost
			// buy_cost := cost_buy[action]
			// fmt.printf(
			// 	"Buying %s for %d. Repair cost: %d  Starting treasury: %d  Ending treasury:",
			// 	Buy_Names[action],
			// 	buy_cost,
			// 	repair_cost,
			// 	gc.acting_nation.treasury,
			// )
			gc.treasury[gc.acting_nation] -= (cost_buy[action] + repair_cost)
			// fmt.println(gc.acting_nation.treasury)
			if action == .Buy_Fighter_Action {
				gc.active_sea_planes[dst_sea][.Fighter_0_Moves] += 1
				add_ally_fighters_to_sea(gc, dst_sea, gc.acting_nation, 1)
			} else {
				ship := buy_active_ship[action]
				gc.active_ships[dst_sea][ship] += 1
				gc.roster_ships[dst_sea][gc.acting_nation][active_ship_to_roster[ship]] += 1
				if ship == .Carrier_0_Moves {
					gc.friendly_carriers_total[dst_sea] += 1
					if gc.friendly_carriers_total[dst_sea] * 2 > gc.friendly_fighters_total[dst_sea] {
						gc.has_carrier_space += {dst_sea}
						gc.is_fighter_cache_current = false
					}
				}
				gc.team_sea_units[dst_sea][mm.team[gc.acting_nation]] += 1
			}
		}
	}
	return true
}

// clear_buy_history :: proc(gc: ^Game_Cache, land: Land_ID) {
// 	for sea in mm.coastal_seas[land] {
// 		gc.skipped_buys[to_region(sea)] = {}
// 		// mem.zero_slice(sea.skipped_buys[:])
// 	}
// 	gc.clear_history_needed = false
// }

buy_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> (ok: bool) {
	for (gc.builds_left[land] > 0) {
		repair_cost := u8(max(0, 1 + int(gc.factory_dmg[land]) - int(gc.builds_left[land])))
		reset_valid_actions(gc)
		for buy_plane in valid_air_buys {
			if gc.treasury[gc.acting_nation] < cost_buy[buy_plane] + repair_cost do continue
			add_valid_action(gc, buy_plane)
		}
		for buy_army in valid_land_buys {
			if gc.treasury[gc.acting_nation] < cost_buy[buy_army] + repair_cost do continue
			add_valid_action(gc, buy_army)
		}
		gc.current_territory = to_region(land)
		gc.current_active_unit = .Factory
		action := get_action_input(gc) or_return
		if action == .Skip_Action {
			gc.builds_left[land] = 0
			break
		}
		gc.builds_left[land] -= 1
		gc.factory_dmg[land] -= repair_cost
		gc.treasury[gc.acting_nation] -= cost_buy[action] + repair_cost
		if action == .Buy_Fighter_Action || action == .Buy_Bomber_Action {
			plane := buy_active_plane[action]
			gc.active_land_planes[land][plane] += 1
			gc.roster_land_planes[land][gc.acting_nation][active_plane_to_roster[plane]] += 1
		} else {
			army := buy_active_army[action]
			gc.active_armies[land][army] += 1
			gc.roster_armies[land][gc.acting_nation][active_army_to_roster[army]] += 1
		}
		gc.team_land_units[land][mm.team[gc.acting_nation]] += 1
	}
	return true
}

buy_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	reset_valid_actions(gc)
	for land in gc.factory_locations[gc.acting_nation] {
		if gc.builds_left[land] == 0 do continue
		if gc.clear_history_needed do clear_move_history(gc)
		buy_sea_units(gc, land) or_return
		buy_land_units(gc, land) or_return
	}
	return true
}
