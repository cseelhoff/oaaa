package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_ai_prefer_strong_unit_purchases :: proc(t: ^testing.T) {
    // Setup a game state where the AI has money to buy units
    game_state := oaaa.Game_State{}
    game_state.money[.USA] = 20
    game_state.builds_left = {}
    game_state.cur_player = .USA
    
    // Create a Game_Cache and run MCTS
    gc := oaaa.Game_Cache{}
    oaaa.load_cache_from_state(&gc, &game_state)
    root := oaaa.mcts_search(&gc, &game_state, 100)
    
    // Check if the AI prefers purchasing tanks (higher cost/impact units)
    best_action := oaaa.select_best_action(root)
    testing.expect(t, best_action == .Tank_Action, "AI did not prioritize purchasing tanks")
}