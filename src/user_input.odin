package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"

// get_move_input :: proc(
// 	gc: ^Game_Cache,
// 	unit_name: string,
// 	src_air: ^Territory,
// ) -> (
// 	dst_air_idx: int,
// ) {
// 	if (PLAYER_DATA[gc.cur_player.index].is_human) {
// 		fmt.print("Moving ", unit_name, " From ", src_air.name, " Valid Moves: ")
// 		for valid_move in sa.slice(&gc.valid_actions) {
// 			fmt.print(gc.territories[valid_move].name, ", ")
// 		}
// 		return get_user_input(gc)
// 	}
// 	return get_ai_input(gc)
// }

print_retreat_prompt :: proc(gc: ^Game_Cache, src_air: ^Territory) {
	print_game_state(gc)
	fmt.print(PLAYER_DATA[gc.cur_player.index].color)
	fmt.println("Retreat From ", src_air.name, " Valid Moves: ")
	for valid_move in sa.slice(&gc.valid_actions) {
		fmt.print(int(valid_move), gc.territories[valid_move].name, ", ")
	}
	fmt.println(DEF_COLOR)
}


get_retreat_input :: proc(
	gc: ^Game_Cache,
	src_air: ^Territory,
) -> (
	dst_air_idx: Air_ID,
	ok: bool,
) {
	// debug_checks(gc)
	dst_air_idx = Air_ID(gc.valid_actions.data[0])
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return dst_air_idx, false
		if PLAYER_DATA[gc.cur_player.index].is_human {
			print_retreat_prompt(gc, src_air)
			dst_air_idx = Air_ID(get_user_input(gc))
		} else {
			if gc.actually_print do print_retreat_prompt(gc, src_air)
			dst_air_idx = Air_ID(get_ai_input(gc))
			if gc.actually_print {
				fmt.println("AI Action:", dst_air_idx)
			}
		}
	}
	return dst_air_idx, true
}

print_move_prompt :: proc(gc: ^Game_Cache, unit_name: string, src_air: ^Territory) {
	print_game_state(gc)
	fmt.print(PLAYER_DATA[gc.cur_player.index].color)
	fmt.println("Moving ", unit_name, " From ", src_air.name, " Valid Moves: ")
	for valid_move in sa.slice(&gc.valid_actions) {
		fmt.print(int(valid_move), gc.territories[valid_move].name, ", ")
	}
	fmt.println(DEF_COLOR)
}

get_move_input :: proc(
	gc: ^Game_Cache,
	unit_name: string,
	src_air: ^Territory,
) -> (
	dst_air_idx: Air_ID,
	ok: bool,
) {
	// debug_checks(gc)
	dst_air_idx = Air_ID(gc.valid_actions.data[0])
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return dst_air_idx, false
		if PLAYER_DATA[gc.cur_player.index].is_human {
			print_move_prompt(gc, unit_name, src_air)
			dst_air_idx = Air_ID(get_user_input(gc))
		} else {
			if gc.actually_print do print_move_prompt(gc, unit_name, src_air)
			dst_air_idx = Air_ID(get_ai_input(gc))
			if gc.actually_print {
				fmt.println("AI Action:", dst_air_idx)
			}
		}
	}
	update_move_history(gc, src_air, dst_air_idx)
	return dst_air_idx, true
}

get_user_input :: proc(gc: ^Game_Cache) -> (user_input: int = 0) {
	buffer: [10]byte
	fmt.print("Enter a number between 0 and 255: ")
	n, err := os.read(os.stdin, buffer[:])
	fmt.println()
	if err != 0 {
		return
	}
	input_str := string(buffer[:n])
	int_input := strconv.atoi(input_str)
	_, found := slice.linear_search(sa.slice(&gc.valid_actions), int_input)
	if !found {
		fmt.eprintln("Invalid input ", int_input)
		return
	}
	return int_input
}

get_ai_input :: proc(gc: ^Game_Cache) -> (ai_input: int) {
	gc.answers_remaining -= 1
	if !gc.use_selected_action || gc.selected_action >= MAX_VALID_ACTIONS {
		//fmt.eprintln("Invalid input ", gc.selected_action)
		gc.seed = (gc.seed + 1) % RANDOM_MAX
		return gc.valid_actions.data[RANDOM_NUMBERS[gc.seed] % gc.valid_actions.len]
	}
	_, found := slice.linear_search(sa.slice(&gc.valid_actions), gc.selected_action)
	if !found {
		fmt.eprintln("Invalid input ", gc.selected_action)
		gc.seed = (gc.seed + 1) % RANDOM_MAX
		return gc.valid_actions.data[RANDOM_NUMBERS[gc.seed] % gc.valid_actions.len]
	}
	return gc.selected_action
}

print_buy_prompt :: proc(gc: ^Game_Cache, src_air: ^Territory) {
	print_game_state(gc)
	fmt.print(PLAYER_DATA[gc.cur_player.index].color)
	fmt.println("Buy At", src_air.name)
	for buy_action_idx in sa.slice(&gc.valid_actions) {
		fmt.print(buy_action_idx, Buy_Names[action_idx_to_buy(buy_action_idx)], ", ")
	}
	fmt.println(DEF_COLOR)
}

get_buy_input :: proc(gc: ^Game_Cache, src_air: ^Territory) -> (action: Buy_Action, ok: bool) {
	// debug_checks(gc)
	action = action_idx_to_buy(gc.valid_actions.data[0])
	if gc.valid_actions.len > 1 {
		if gc.answers_remaining == 0 do return .SKIP_BUY, false
		if PLAYER_DATA[gc.cur_player.index].is_human {
			print_buy_prompt(gc, src_air)
			action = action_idx_to_buy(get_user_input(gc))
		} else {
			if gc.actually_print do print_buy_prompt(gc, src_air)
			action = action_idx_to_buy(get_ai_input(gc))
			if gc.actually_print {
				fmt.println("AI Action:", action)
			}
		}
	}
	update_buy_history(gc, src_air, action)
	return action, true
}

print_game_state :: proc(gc: ^Game_Cache) {
	color := PLAYER_DATA[gc.cur_player.index].color
	fmt.println(color, "--------------------")
	fmt.println("Current Player: ", PLAYER_DATA[gc.cur_player.index].name)
	fmt.println("Money: ", gc.cur_player.money, DEF_COLOR, "\n")
	for territory in gc.territories {
		if int(territory.territory_index) < LANDS_COUNT {
			land := get_land(gc, territory.territory_index)
			fmt.print(PLAYER_DATA[land.owner.index].color)
			fmt.println(
				territory.name,
				"builds:",
				land.builds_left,
				land.combat_status,
				land.factory_dmg,
				"/",
				land.factory_prod,
				"bombards:",
				land.max_bombards,
			)
			fmt.print(PLAYER_DATA[gc.cur_player.index].color)
			for army, army_idx in land.active_armies {
				if army > 0 {
					fmt.println(Active_Army_Names[army_idx], ":", army)
				}
			}
			for plane, plane_idx in land.active_planes {
				if plane > 0 {
					fmt.println(Active_Plane_Names[plane_idx], ":", plane)
				}
			}
			for &player in gc.players {
				if &player == gc.cur_player do continue
				fmt.print(PLAYER_DATA[player.index].color)
				for army, army_idx in land.idle_armies[player.index] {
					if army > 0 {
						fmt.println(Idle_Army_Names[army_idx], ":", army)
					}
				}
				for plane, plane_idx in land.idle_planes[player.index] {
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
				if &player == gc.cur_player do continue
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
