package oaaa

import "core:fmt"
import "core:os"
import "core:strconv"

is_human := [Player_ID]bool {
	.Rus = false,
	.Ger = false,
	.Eng = false,
	.Jap = false,
	.USA = false,
}

main :: proc() {
 start()
}

start :: proc() {
	fmt.println("Starting CAAA")
	iterations := 100_000_000_000
	// if len(os.args) >= 2 {
	// 	iterations, _ = strconv.parse_int(os.args[1])
	// }

	fmt.println("Running ", iterations, " iterations")
	initialize_random_numbers()
	game_state: Game_State
	game_cache: Game_Cache
	game_cache.answers_remaining = 65000
	game_cache.seed = 2	

	ok := initialize_map_constants(&game_cache)
	if !ok {
		fmt.eprintln("Error initializing map constants")
		return
	}
	
	load_path:string
	if len(os.args) >= 2 {
		load_path = os.args[1]
		is_human = {
			.Rus = true,
			.Ger = true,
			.Eng = true,
			.Jap = true,
			.USA = true,
		}		
		load_game_data(&game_state, load_path)
		load_cache_from_state(&game_cache, &game_state)
		get_possible_actions(&game_cache)
		for {
			play_full_turn(&game_cache)
		}
		// return
	} else {
		// return
	}
	load_default_game_state(&game_state)
	// get_canonical_form(&game_state, 0)
	//save_json(game_state, "game_state.json")
	//load_game_data(&game_state, "game_state.json")

	load_cache_from_state(&game_cache, &game_state)

	// for (game_cache.answers_remaining > 0) {
	// 	ok = play_full_turn(&game_cache)
	// 	if !ok {
	// 		fmt.eprintln("Error playing full turn")
	// 		fmt.println(game_cache.answers_remaining)
	// 		fmt.println(game_cache.step_id)
	// 		return
	// 	}
	// }
	// fmt.println(game_cache.answers_remaining)
	// fmt.println(game_cache.step_id)

	game_state = game_cache.state

	// print_game_state(&game_cache)
	// for {
	// 	play_full_turn(&game_cache)
	// }

	root :^MCTSNode= mcts_search(&game_state, iterations)
	best_action := select_best_action(root)
	// print_mcts_tree(root, 0, nil, 0)
	fmt.println("Best action: ", best_action)
	delete_mcts(root)
	// save_mcts(root)
}