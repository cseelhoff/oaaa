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
    gc.unlucky_teams = {.AXIS} // Makes attacker "lucky"
    hits = oaaa.calculate_attacker_hits_low_luck(&gc, 4) // 4/6 = 0 guaranteed + 1 fractional
    testing.expect(t, hits == 1, "4 attack value should round up for lucky team")
    
    // Test fractional hits with normal luck
    gc.answers_remaining = 2 // Normal luck mode
    gc.seed = 0 // Reset to known random sequence
    hits = oaaa.calculate_attacker_hits_low_luck(&gc, 4)
    testing.expect(t, hits == 0, "4 attack value should use random roll for normal luck")
}

@(test)
test_sea_casualty_order :: proc(t: ^testing.T) {
    gc := setup_combat_state()
    test_sea := oaaa.Sea_ID.Pacific
    
    // Setup fleet with mixed units
    gc.active_ships[test_sea][.SUB_UNMOVED] = 2
    gc.active_ships[test_sea][.DESTROYER_UNMOVED] = 1
    gc.active_ships[test_sea][.BATTLESHIP_UNMOVED] = 1
    gc.active_ships[test_sea][.TRANS_EMPTY_UNMOVED] = 1
    
    // Apply 2 hits
    hits: u8 = 2
    oaaa.remove_sea_attackers(&gc, test_sea, &hits)
    
    // Verify casualty order:
    // 1. Should take submarines first (weakest combat ships)
    testing.expect(t, gc.active_ships[test_sea][.SUB_UNMOVED] == 0, 
        "Submarines should be taken as first casualties")
    
    // 2. Should preserve stronger ships
    testing.expect(t, gc.active_ships[test_sea][.BATTLESHIP_UNMOVED] == 1, 
        "Battleship should be preserved")
    testing.expect(t, gc.active_ships[test_sea][.TRANS_EMPTY_UNMOVED] == 1, 
        "Transport should be preserved")
}

@(test)
test_submarine_first_strike :: proc(t: ^testing.T) {
    gc := setup_combat_state()
    test_sea := oaaa.Sea_ID.Pacific
    
    // Setup submarine attack without destroyer defense
    gc.active_ships[test_sea][.SUB_UNMOVED] = 1
    gc.idle_ships[test_sea][.USA][.SUB] = 1
    
    // Enemy fleet without destroyers
    gc.active_ships[test_sea][.BATTLESHIP_UNMOVED] = 1
    gc.idle_ships[test_sea][.GERMANY][.BATTLESHIP] = 1
    
    // Resolve submarine first strike
    oaaa.resolve_submarine_first_strike(&gc, test_sea)
    
    // Verify submarine got its attack before regular combat
    testing.expect(t, gc.active_ships[test_sea][.BATTLESHIP_UNMOVED] == 0, 
        "Battleship should be hit by submarine first strike")
    
    // Setup same scenario but with destroyer present
    other_sea := oaaa.Sea_ID.Atlantic
    gc.active_ships[other_sea][.SUB_UNMOVED] = 1
    gc.idle_ships[other_sea][.USA][.SUB] = 1
    gc.active_ships[other_sea][.BATTLESHIP_UNMOVED] = 1
    gc.idle_ships[other_sea][.GERMANY][.BATTLESHIP] = 1
    gc.active_ships[other_sea][.DESTROYER_UNMOVED] = 1
    gc.idle_ships[other_sea][.GERMANY][.DESTROYER] = 1
    
    // Resolve submarine first strike
    oaaa.resolve_submarine_first_strike(&gc, other_sea)
    
    // Verify destroyer prevented first strike
    testing.expect(t, gc.active_ships[other_sea][.BATTLESHIP_UNMOVED] == 1, 
        "Destroyer should prevent submarine first strike")
}
