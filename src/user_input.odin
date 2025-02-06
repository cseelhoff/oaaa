package oaaa
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:slice"

get_action_input:: proc(gc: ^Game_Cache) -> (action: Action_ID, ok: bool) {
	debug_checks(gc)
	load_dyn_arr_actions(gc)
	assert(len(gc.dyn_arr_valid_actions) > 0)
	action = gc.dyn_arr_valid_actions[0]
	if len(gc.dyn_arr_valid_actions) > 1 {
		if gc.answers_remaining == 0 do return action, false
		if is_human[gc.cur_player] {
			print_move_prompt_2(gc)
			action = get_user_input(gc)
		} else {
			if ACTUALLY_PRINT do print_move_prompt_2(gc)
			action = get_ai_input(gc)
			if ACTUALLY_PRINT {
				fmt.println("--->AI Action:", action)
			}
		}
	}
	update_move_history_2(gc, action)
	return action, true
}

print_move_prompt_2 :: proc(gc: ^Game_Cache) {
	print_game_state(gc)
	fmt.print(mm.color[gc.cur_player])
	fmt.println("Moving ", gc.current_active_unit, " From ", gc.current_territory, " Valid Moves: ")
	for valid_move in gc.dyn_arr_valid_actions {
		fmt.print(int(valid_move), valid_move, ", ")
	}
	fmt.println(DEF_COLOR)
}

get_user_input :: proc(gc: ^Game_Cache) -> (action: Action_ID) {
	buffer: [10]byte
	fmt.print("Enter a number between 0 and 1024: ")
	n, err := os.read(os.stdin, buffer[:])
	fmt.println()
	if err != os.General_Error.None {
		return
	}
	input_str := string(buffer[:n])
	int_input := to_action(strconv.atoi(input_str))
	// assert in input in valid_actions
	return int_input
}

get_ai_input :: proc(gc: ^Game_Cache) -> Action_ID {
	gc.answers_remaining -= 1
	if !gc.use_selected_action {
		//fmt.eprintln("Invalid input ", gc.selected_action)
		gc.seed = (gc.seed + 1) % RANDOM_MAX
		// rand_idx := RANDOM_NUMBERS[gc.seed] % len(gc.dyn_arr_valid_actions)
		// for action_idx in gc.dyn_arr_valid_actions {
		// 	if rand_idx == 0 {
		// 		return action_idx
		// 	}
		// 	rand_idx -= 1
		// }
		return gc.dyn_arr_valid_actions[RANDOM_NUMBERS[gc.seed] % u16(len(gc.dyn_arr_valid_actions))] // gc.dyn_arr_valid_actions[rand_idx] // gc.dyn_arr_valid_actions[RANDOM_NUMBERS[gc.seed] % gc.dyn_arr_valid_actions.len]
	}
	// assert(gc.selected_action in gc.valid_actions)
	_, found := slice.linear_search(gc.dyn_arr_valid_actions[:], gc.selected_action)
	if !found {
		print_game_state(gc)
		for action_idx in gc.valid_actions {
			fmt.print(action_idx, ", ")
		}
		fmt.println()
		fmt.eprintln("Invalid input ", gc.selected_action)
		save_json(gc)
	}
	// assert(gc.selected_action in gc.valid_actions)

	return gc.selected_action
}

print_buy_prompt :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	print_game_state(gc)
	fmt.print(mm.color[gc.cur_player])
	fmt.println("Buy At", src_air)
	for buy_action_idx in gc.valid_actions {
		fmt.print(int(buy_action_idx), buy_action_idx, ", ")
	}
	fmt.println(DEF_COLOR)
}

// get_buy_input :: proc(gc: ^Game_Cache, src_air: Air_ID) -> (action: Buy_Action, ok: bool) {
// 	debug_checks(gc)
// 	// action = action_idx_to_buy(gc.valid_actions)
// 	// assert(card(gc.valid_actions) > 0)
// 	for valid_action in gc.valid_actions {
// 		action = to_buy_action(valid_action)
// 		break
// 	}
// 	if card(gc.valid_actions) > 1 {
// 		if gc.answers_remaining == 0 do return .SKIP_BUY, false
// 		if is_human[gc.cur_player] {
// 			print_buy_prompt(gc, src_air)
// 			action = to_buy_action(get_user_input(gc))
// 		} else {
// 			if ACTUALLY_PRINT do print_buy_prompt(gc, src_air)
// 			action = to_buy_action(get_ai_input(gc))
// 			if ACTUALLY_PRINT {
// 				fmt.println("--->AI Action:", action)
// 			}
// 		}
// 	}
// 	update_buy_history(gc, src_air, action)
// 	return action, true
// }

print_game_state :: proc(gc: ^Game_Cache) {
	color := mm.color[gc.cur_player]
	fmt.println(color, "--------------------")
	fmt.println("Current Player: ", gc.cur_player)
	fmt.println("Money: ", gc.money[gc.cur_player], DEF_COLOR, "\n")
	for land in Land_ID {
		fmt.print(mm.color[gc.owner[land]])
		fmt.print(land)
		if land in gc.more_land_combat_needed do fmt.print(" more-combat")
		if land in gc.land_combat_started do fmt.print(" combat-started")
		if gc.builds_left[land] > 0 do fmt.print(" builds:", gc.builds_left[land])
		if gc.factory_dmg[land] > 0 do fmt.print(" factory-dmg:", gc.factory_dmg[land])
		if gc.factory_prod[land] > 0 do fmt.print(" factory-prod:", gc.factory_prod[land])
		if gc.max_bombards[land] > 0 do fmt.print(" bombards:", gc.max_bombards[land])
		fmt.println()
		fmt.print(mm.color[gc.cur_player])
		for army in Active_Army {
			if gc.active_armies[land][army] > 0 {
				fmt.println(fmt.tprint(army), ":", gc.active_armies[land][army])
			}
		}
		for plane in Active_Plane {
			if gc.active_land_planes[land][plane] > 0 {
				fmt.println(fmt.tprint(plane), ":", gc.active_land_planes[land][plane])
			}
		}
		for player in Player_ID {
			if player == gc.cur_player do continue
			fmt.print(mm.color[player])
			for army in Idle_Army {
				if gc.idle_armies[land][player][army] > 0 {
					fmt.println(Idle_Army_Names[army], ":", gc.idle_armies[land][player][army])
				}
			}
			for plane in Idle_Plane {
				if gc.idle_land_planes[land][player][plane] > 0 {
					fmt.println(
						Idle_Plane_Names[plane],
						":",
						gc.idle_land_planes[land][player][plane],
					)
				}
			}
		}
		fmt.println()
	}
	for sea in Sea_ID {
		if gc.team_sea_units[sea][.Allies] == 0 && gc.team_sea_units[sea][.Axis] == 0 {
			continue
		}
		fmt.print(DEF_COLOR)
		fmt.print(sea)
		if sea in gc.more_sea_combat_needed do fmt.print(" more-combat")
		if sea in gc.sea_combat_started do fmt.print(" combat-started")
		fmt.println()
		fmt.print(mm.color[gc.cur_player])
		for ship in Active_Ship {
			if gc.active_ships[sea][ship] > 0 {
				fmt.println(fmt.tprint(ship), ":", gc.active_ships[sea][ship])
			}
		}
		for plane in Active_Plane {
			if gc.active_sea_planes[sea][plane] > 0 {
				fmt.println(fmt.tprint(plane), ":", gc.active_sea_planes[sea][plane])
			}
		}
		for player in Player_ID {
			if player == gc.cur_player do continue
			fmt.print(mm.color[player])
			for ship in Idle_Ship {
				if gc.idle_ships[sea][player][ship] > 0 {
					fmt.println(ship, ":", gc.idle_ships[sea][player][ship])
				}
			}
			if gc.idle_sea_planes[sea][player][.FIGHTER] > 0 {
				fmt.println(
					Idle_Plane_Names[.FIGHTER],
					":",
					gc.idle_sea_planes[sea][player][.FIGHTER],
				)
			}
		}
		fmt.println()
	}
	fmt.println(DEF_COLOR)
}

game_state_to_string :: proc(gc: ^Game_Cache) -> string {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	color := mm.color[gc.cur_player]
	strings.write_string(&sb, color)
	strings.write_string(&sb, "--------------------\n")
	fmt.sbprintf(&sb, "Current Player: %v\n", gc.cur_player)
	fmt.sbprintf(&sb, "Money: %v%v\n\n", gc.money[gc.cur_player], DEF_COLOR)

	for land in Land_ID {
		strings.write_string(&sb, mm.color[gc.owner[land]])
		strings.write_string(&sb, fmt.tprint(land))
		if land in gc.more_land_combat_needed do strings.write_string(&sb, " more-combat")
		if land in gc.land_combat_started do strings.write_string(&sb, " combat-started")
		if gc.builds_left[land] > 0 do fmt.sbprintf(&sb, " builds:%v", gc.builds_left[land])
		if gc.factory_dmg[land] > 0 do fmt.sbprintf(&sb, " factory-dmg:%v", gc.factory_dmg[land])
		if gc.factory_prod[land] > 0 do fmt.sbprintf(&sb, " factory-prod:%v", gc.factory_prod[land])
		if gc.max_bombards[land] > 0 do fmt.sbprintf(&sb, " bombards:%v", gc.max_bombards[land])
		strings.write_string(&sb, "\n")

		strings.write_string(&sb, mm.color[gc.cur_player])
		for army in Active_Army {
			if gc.active_armies[land][army] > 0 {
				fmt.sbprintf(&sb, "%v: %v\n", fmt.tprint(army), gc.active_armies[land][army])
			}
		}
		for plane in Active_Plane {
			if gc.active_land_planes[land][plane] > 0 {
				fmt.sbprintf(&sb, "%v: %v\n", fmt.tprint(plane), gc.active_land_planes[land][plane])
			}
		}
		for player in Player_ID {
			if player == gc.cur_player do continue
			strings.write_string(&sb, mm.color[player])
			for army in Idle_Army {
				if gc.idle_armies[land][player][army] > 0 {
					fmt.sbprintf(&sb, "%v: %v\n", Idle_Army_Names[army], gc.idle_armies[land][player][army])
				}
			}
			for plane in Idle_Plane {
				if gc.idle_land_planes[land][player][plane] > 0 {
					fmt.sbprintf(&sb, "%v: %v\n", Idle_Plane_Names[plane], gc.idle_land_planes[land][player][plane])
				}
			}
		}
		strings.write_string(&sb, "\n")
	}

	for sea in Sea_ID {
		strings.write_string(&sb, DEF_COLOR)
		strings.write_string(&sb, fmt.tprint(sea))
		if sea in gc.more_sea_combat_needed do strings.write_string(&sb, " more-combat")
		if sea in gc.sea_combat_started do strings.write_string(&sb, " combat-started")
		strings.write_string(&sb, "\n")

		strings.write_string(&sb, mm.color[gc.cur_player])
		for ship in Active_Ship {
			if gc.active_ships[sea][ship] > 0 {
				fmt.sbprintf(&sb, "%v: %v\n", fmt.tprint(ship), gc.active_ships[sea][ship])
			}
		}
		for plane in Active_Plane {
			if gc.active_sea_planes[sea][plane] > 0 {
				fmt.sbprintf(&sb, "%v: %v\n", fmt.tprint(plane), gc.active_sea_planes[sea][plane])
			}
		}
		for player in Player_ID {
			if player == gc.cur_player do continue
			strings.write_string(&sb, mm.color[player])
			for ship in Idle_Ship {
				if gc.idle_ships[sea][player][ship] > 0 {
					fmt.sbprintf(&sb, "%v: %v\n", ship, gc.idle_ships[sea][player][ship])
				}
			}
			if gc.idle_sea_planes[sea][player][.FIGHTER] > 0 {
				fmt.sbprintf(&sb, "%v: %v\n", Idle_Plane_Names[.FIGHTER], gc.idle_sea_planes[sea][player][.FIGHTER])
			}
		}
		strings.write_string(&sb, "\n")
	}
	strings.write_string(&sb, DEF_COLOR)

	return strings.to_string(sb)
}
