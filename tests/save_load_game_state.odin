package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_save_load_game_state :: proc(t: ^testing.T) {
    // Save initial state
    initial_state := oaaa.Game_State{}
    oaaa.load_default_game_state(&initial_state)
    oaaa.save_json(initial_state, "test_save.json")
    
    // Load state
    loaded_state := oaaa.Game_State{}
    oaaa.load_game_data(&loaded_state, "test_save.json")
    
    // Verify integrity
    testing.expect(t, loaded_state.money[.USA] == 20, 
        "USA money should remain 20 after save/load")
    testing.expect(t, loaded_state.cur_player == .USA, 
        "Current player should be USA after save/load")
}