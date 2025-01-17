package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"

// get_move_input :: proc(
// 	gc: ^Game_Cache,
// 	unit_name: string,
// 	src_air: Air_ID,
// ) -> (
// 	dst_air_idx: int,
// ) {
// 	if (PLAYER_DATA[gc.cur_player.index].is_human) {
// 		fmt.print("Moving ", unit_name, " From ", src_air.name, " Valid Moves: ")
// 		for valid_move in sa.slice(&gc.valid_actions) {
// 			fmt.print(Air_ID[valid_move].name, ", ")
// 		}
// 		return get_user_input(gc)
// 	}
// 	return get_ai_input(gc)
// }

print_retreat_prompt :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	print_game_state(gc)
	fmt.print(mm.color[gc.cur_player])
	fmt.println("Retreat From ", mm.air_name[src_air], " Valid Moves: ")
	for valid_move in sa.slice(&gc.valid_actions) {
		fmt.print(int(valid_move), valid_move, ", ")
	}
	fmt.println(DEF_COLOR)
}


get_retreat_input :: proc(gc: ^Game_Cache, src_air: Air_ID) -> (dst_air: Air_ID, ok: bool) {
	debug_checks(gc)
	dst_air = act2air(gc.valid_actions.data[0])
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return dst_air, false
		if gc.cur_player in mm.is_human {
			print_retreat_prompt(gc, src_air)
			dst_air = act2air(get_user_input(gc))
		} else {
			if ACTUALLY_PRINT do print_retreat_prompt(gc, src_air)
			dst_air = act2air(get_ai_input(gc))
			if ACTUALLY_PRINT {
				fmt.println("AI Action:", dst_air)
			}
		}
	}
	return dst_air, true
}

print_move_prompt :: proc(gc: ^Game_Cache, unit_name: string, src_air: Air_ID) {
	print_game_state(gc)
	fmt.print(mm.color[gc.cur_player])
	fmt.println("Moving ", unit_name, " From ", src_air, " Valid Moves: ")
	for valid_move in gc.valid_actions {
		fmt.print(int(valid_move), valid_move, ", ")
	}
	fmt.println(DEF_COLOR)
}

get_move_input :: proc(
	gc: ^Game_Cache,
	unit_name: string,
	src_air: Air_ID,
) -> (
	dst_air: Air_ID,
	ok: bool,
) {
	debug_checks(gc)
	if card(gc.valid_actions) > 1 {
		if gc.answers_remaining == 0 do return Air_ID(0), false
		if is_human[gc.cur_player] {
			print_move_prompt(gc, unit_name, l2aid(src_air))
			dst_air = act2air(get_user_input(gc))
		} else {
			if ACTUALLY_PRINT do print_move_prompt(gc, unit_name, l2aid(src_air))
			dst_air = act2air(get_ai_input(gc))
			if ACTUALLY_PRINT {
				fmt.println("AI Action:", dst_air)
			}
		}
	}
	update_move_history(gc, src_air, dst_air)
	return dst_air, true
}

get_user_input :: proc(gc: ^Game_Cache) -> (action: Action_ID) {
	buffer: [10]byte
	fmt.print("Enter a number between 0 and 255: ")
	n, err := os.read(os.stdin, buffer[:])
	fmt.println()
	if err != 0 {
		return
	}
	input_str := string(buffer[:n])
	int_input := int2act(strconv.atoi(input_str))
	assert(int_input in gc.valid_actions)
	return int_input
}

get_ai_input :: proc(gc: ^Game_Cache) -> Action_ID {
	gc.answers_remaining -= 1
	if !gc.use_selected_action {
		//fmt.eprintln("Invalid input ", gc.selected_action)
		gc.seed = (gc.seed + 1) % RANDOM_MAX
		rand_idx := RANDOM_NUMBERS[gc.seed] % card(gc.valid_actions)
		for action_idx in gc.valid_actions {
			if rand_idx == 0 {
				return action_idx
			}
			rand_idx -= 1
		}
		//return gc.valid_actions.data[RANDOM_NUMBERS[gc.seed] % gc.valid_actions.len]
	}
	assert (gc.selected_action in gc.valid_actions)
	// _, found := slice.linear_search(sa.slice(&gc.valid_actions), gc.selected_action)
	// if !found {
	// 	fmt.eprintln("Invalid input ", gc.selected_action)
	// 	gc.seed = (gc.seed + 1) % RANDOM_MAX
	// 	return gc.valid_actions.data[RANDOM_NUMBERS[gc.seed] % gc.valid_actions.len]
	// }
	return gc.selected_action
}

print_buy_prompt :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	print_game_state(gc)
	fmt.print(PLAYER_DATA[gc.cur_player.index].color)
	fmt.println("Buy At", src_air.name)
	for buy_action_idx in sa.slice(&gc.valid_actions) {
		fmt.print(buy_action_idx, Buy_Names[action_idx_to_buy(buy_action_idx)], ", ")
	}
	fmt.println(DEF_COLOR)
}

get_buy_input :: proc(gc: ^Game_Cache, src_air: Air_ID) -> (action: Buy_Action, ok: bool) {
	debug_checks(gc)
	action = action_idx_to_buy(gc.valid_actions.data[0])
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return .SKIP_BUY, false
		if PLAYER_DATA[gc.cur_player.index].is_human {
			print_buy_prompt(gc, src_air)
			action = action_idx_to_buy(get_user_input(gc))
		} else {
			if ACTUALLY_PRINT do print_buy_prompt(gc, src_air)
			action = action_idx_to_buy(get_ai_input(gc))
			if ACTUALLY_PRINT {
				fmt.println("AI Action:", action)
			}
		}
	}
	update_buy_history(gc, src_air, action)
	return action, true
}

print_game_state :: proc(gc: ^Game_Cache) {
	color := PLAYER_DATA[gc.cur_player].color
	fmt.println(color, "--------------------")
	fmt.println("Current Player: ", PLAYER_DATA[gc.cur_player].name)
	fmt.println("Money: ", gc.money[gc.cur_player], DEF_COLOR, "\n")
	for air in Air_ID {
		if int(air) < len(Land_ID) {
			land := a2lid(air)
			fmt.print(mm.color[gc.owner[land]])
			fmt.println(
				mm.air_name[air],
				gc.combat_status[air],
				"builds:",
				gc.builds_left[land],
				gc.factory_dmg[land],
				"/",
				gc.factory_prod[land],
				"bombards:",
				gc.max_bombards[land],
			)
			fmt.print(PLAYER_DATA[gc.cur_player].color)
			for army, army_idx in gc.active_armies[land] {
				if army > 0 {
					fmt.println(Active_Army_Names[army_idx], ":", army)
				}
			}
			for plane, plane_idx in gc.active_planes[air] {
				if plane > 0 {
					fmt.println(Active_Plane_Names[plane_idx], ":", plane)
				}
			}
			for &player in gc.players {
				// if &player == gc.cur_player do continue
				fmt.print(mm.color[player])
				for army, army_idx in gc.idle_armies[land][player] {
					if army > 0 {
						fmt.println(Idle_Army_Names[army_idx], ":", army)
					}
				}
				for plane, plane_idx in gc.idle_planes[air][player] {
					if plane > 0 {
						fmt.println(Idle_Plane_Names[plane_idx], ":", plane)
					}
				}
			}
		} else {
			sea := get_sea(gc, territory.territory_index)
			fmt.println(territory.name)
			fmt.print(PLAYER_DATA[gc.cur_player.index].color)
			for ship, ship_idx in sea.active_ships {
				if ship > 0 {
					fmt.println(Active_Ship_Names[ship_idx], ":", ship)
				}
			}
			for plane, plane_idx in sea.active_planes {
				if plane > 0 {
					fmt.println(Active_Plane_Names[plane_idx], ":", plane)
				}
			}
			for &player in gc.players {
				// if &player == gc.cur_player do continue
				fmt.print(PLAYER_DATA[player.index].color)
				for ship, ship_idx in sea.idle_ships[player.index] {
					if ship > 0 {
						fmt.println(Idle_Ship_Names[ship_idx], ":", ship)
					}
				}
				for plane, plane_idx in sea.idle_planes[player.index] {
					if plane > 0 {
						fmt.println(Idle_Plane_Names[plane_idx], ":", plane)
					}
				}
			}
		}
		fmt.println(DEF_COLOR)
	}
}
