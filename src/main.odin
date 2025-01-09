package oaaa

import "core:fmt"
import "core:os"
import "core:strconv"

main :: proc() {
	fmt.println("Starting CAAA")
	iterations := 1_000
	if len(os.args) >= 2 {
		iterations, _ = strconv.parse_int(os.args[1])
	}
	fmt.println("Running ", iterations, " iterations")
	initialize_random_numbers()
	game_cache: Game_Cache
	ok := initialize_map_constants(&game_cache)
	if !ok {
		fmt.eprintln("Error initializing map constants")
		return
	}
	game_state: Game_State
	load_default_game_state(&game_state)
	//save_json(game_state, "game_state.json")
	//load_game_data(&game_state, "game_state.json")
	load_cache_from_state(&game_cache, &game_state)
	game_cache.answers_remaining = 100000
	game_cache.seed = 2	

	// PLAYER_DATA[0].is_human = true
	// PLAYER_DATA[1].is_human = true
	// PLAYER_DATA[2].is_human = true
	// PLAYER_DATA[3].is_human = true
	// PLAYER_DATA[4].is_human = true
	
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

	save_cache_to_state(&game_cache, &game_state)

	root :^MCTSNode= mcts_search(&game_state, iterations)
	best_action := select_best_action(root)
	print_mcts(root)
	fmt.println("Best action: ", best_action)
}
