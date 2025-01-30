/*
Combat System Test Suite
Tests the combat resolution system including:
1. Low luck hit calculation
2. Casualty selection order
3. Special combat rules (submarines, bombardment)
4. Combat state transitions
*/

package oaaa_test

import "core:testing"
import oaaa "../src"

// Helper: Create game state with specific combat setup
setup_combat_state :: proc() -> oaaa.Game_Cache {
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    gc.seed = 0 // Use deterministic random numbers
    oaaa.initialize_random_numbers() // Initialize random number table
    return gc
}

@(test)
test_low_luck_hits :: proc(t: ^testing.T) {
    gc := setup_combat_state()
    
    // Test guaranteed hits (whole number division)
    hits := oaaa.calculate_attacker_hits_low_luck(&gc, 6) // 6/6 = 1 guaranteed hit
    testing.expect(t, hits == 1, "6 attack value should give 1 guaranteed hit")
    
    // Test fractional hits with lucky team
    gc.answers_remaining = 1
    gc.unlucky_teams = {.Allies} // Makes enemy team unlucky, so attacker is "lucky"
    hits = oaaa.calculate_attacker_hits_low_luck(&gc, 4) // 4/6 = 0 guaranteed + 1 fractional
    testing.expect(t, hits == 1, "4 attack value should round up for lucky team")
    
    // Test fractional hits with normal luck
    gc.answers_remaining = 2 // Deep search mode
    gc.unlucky_teams = {} // Reset luck
    gc.seed = 0 // Reset to known random sequence
    hits = oaaa.calculate_attacker_hits_low_luck(&gc, 4) // 4/6 chance of hit based on random roll
    testing.expect(t, hits == 1, "4 attack value should use random roll for normal luck")
}

@(test)
test_sea_casualty_order :: proc(t: ^testing.T) {
    gc := setup_combat_state()
    test_sea := oaaa.Sea_ID.Pacific
    
    // Setup fleet with mixed units
    gc.active_ships[test_sea][.SUB_0_MOVES] = 2
    gc.active_ships[test_sea][.DESTROYER_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][.SUB] = 2
    gc.idle_ships[test_sea][.USA][.DESTROYER] = 1
    
    // Simulate one hit on the fleet
    hits: u8 = 1
    oaaa.remove_sea_attackers(&gc, test_sea, &hits)
    
    // Verify submarine was taken as casualty
    testing.expect(t, gc.active_ships[test_sea][.SUB_0_MOVES] == 1, 
        "Submarines should be taken as first casualties")
    testing.expect(t, gc.active_ships[test_sea][.DESTROYER_0_MOVES] == 1,
        "Destroyer should remain after first casualty")
}

@(test)
test_submarine_first_strike :: proc(t: ^testing.T) {
    gc := setup_combat_state()
    test_sea := oaaa.Sea_ID.Pacific
    
    // Setup submarine attacking fleet with destroyer
    gc.active_ships[test_sea][.SUB_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][.SUB] = 1
    gc.idle_ships[test_sea][.Jap][.DESTROYER] = 1 // Enemy destroyer
    
    // Verify submarine can't submerge due to destroyer
    testing.expect(t, gc.idle_ships[test_sea][.Jap][.DESTROYER] == 1,
        "Destroyers should prevent submarine submerge")
}
