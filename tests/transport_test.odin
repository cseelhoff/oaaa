package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_skip_empty_transports :: proc(t: ^testing.T) {
    // Create a minimal game cache with just the fields we need
    gc := oaaa.Game_Cache{}
    
    // Set up test scenario: empty transports in different seas with different move counts
    test_sea := oaaa.Sea_ID.Pacific
    
    // Initial state: transports with different move counts
    gc.active_ships[test_sea][.TRANS_EMPTY_0_MOVES] = 1
    gc.active_ships[test_sea][.TRANS_EMPTY_1_MOVES] = 2
    gc.active_ships[test_sea][.TRANS_EMPTY_2_MOVES] = 3
    
    // Run the function
    oaaa.skip_empty_transports(&gc)
    
    // Verify results
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_0_MOVES] == 6, 
        "Expected 6 transports with 0 moves (1 + 2 + 3)")
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_1_MOVES] == 0, 
        "Expected 0 transports with 1 move")
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_2_MOVES] == 0, 
        "Expected 0 transports with 2 moves")
    
    // Test multiple seas
    another_sea := oaaa.Sea_ID.Atlantic
    gc.active_ships[another_sea][.TRANS_EMPTY_0_MOVES] = 2
    gc.active_ships[another_sea][.TRANS_EMPTY_1_MOVES] = 1
    gc.active_ships[another_sea][.TRANS_EMPTY_2_MOVES] = 1
    
    oaaa.skip_empty_transports(&gc)
    
    testing.expect(t, gc.active_ships[another_sea][.TRANS_EMPTY_0_MOVES] == 4,
        "Expected 4 transports with 0 moves in second sea (2 + 1 + 1)")
    testing.expect(t, gc.active_ships[another_sea][.TRANS_EMPTY_1_MOVES] == 0,
        "Expected 0 transports with 1 move in second sea")
    testing.expect(t, gc.active_ships[another_sea][.TRANS_EMPTY_2_MOVES] == 0,
        "Expected 0 transports with 2 moves in second sea")
    
    // Original sea should remain unchanged from first test
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_0_MOVES] == 6,
        "First sea should remain unchanged")
}
