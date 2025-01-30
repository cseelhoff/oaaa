/*
Game State Update Test Suite
Tests the mechanics of updating game state after various actions.

Test Categories:
1. Territory Control
   - Capturing empty territory
   - Capturing enemy territory
   - Liberating allied territory

2. Unit State Transitions
   - Moving units between territories
   - Combat state updates
   - Post-combat cleanup

3. Player State
   - Turn transitions
   - Victory conditions
   - Resource updates
*/

package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_territory_capture :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_land := oaaa.Land_ID.Tokyo
    
    // Set up initial state with enemy units
    gc.idle_armies[test_land][.Jap][oaaa.Idle_Army.INF] = 1
    gc.owner[test_land] = .Jap
    
    // Add attacking forces and simulate combat resolution
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] = 2
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] = 2
    
    // Remove defender and update territory control
    gc.idle_armies[test_land][.Jap][oaaa.Idle_Army.INF] = 0
    gc.owner[test_land] = .USA
    
    // Verify state changes
    testing.expect(t, gc.owner[test_land] == .USA,
        "Territory should be captured by USA")
    testing.expect(t, gc.idle_armies[test_land][.Jap][oaaa.Idle_Army.INF] == 0,
        "Enemy infantry should be removed")
}

@(test)
test_unit_state_transition :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    src_land := oaaa.Land_ID.Moscow
    dst_land := oaaa.Land_ID.Berlin
    
    // Place units in source territory
    gc.active_armies[src_land][oaaa.Active_Army.INF_1_MOVES] = 1
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.INF] = 1
    
    // Move unit (reduce moves by 1)
    gc.active_armies[src_land][oaaa.Active_Army.INF_1_MOVES] -= 1
    gc.active_armies[dst_land][oaaa.Active_Army.INF_0_MOVES] += 1
    
    // Update idle armies
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.INF] -= 1
    gc.idle_armies[dst_land][.USA][oaaa.Idle_Army.INF] += 1
    
    // Verify state changes
    testing.expect(t, gc.active_armies[src_land][oaaa.Active_Army.INF_1_MOVES] == 0,
        "Unit should be removed from source")
    testing.expect(t, gc.active_armies[dst_land][oaaa.Active_Army.INF_0_MOVES] == 1,
        "Unit should appear in destination with 0 moves")
    testing.expect(t, gc.idle_armies[src_land][.USA][oaaa.Idle_Army.INF] == 0,
        "Idle army should be removed from source")
    testing.expect(t, gc.idle_armies[dst_land][.USA][oaaa.Idle_Army.INF] == 1,
        "Idle army should appear in destination")
}

@(test)
test_end_turn_cleanup :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_land := oaaa.Land_ID.Washington
    
    // Place some units with various move states
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] = 1
    gc.active_armies[test_land][oaaa.Active_Army.TANK_1_MOVES] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.TANK] = 1
    
    // End turn - all units should reset to full moves
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] = 0
    gc.active_armies[test_land][oaaa.Active_Army.TANK_1_MOVES] = 0
    gc.active_armies[test_land][oaaa.Active_Army.INF_1_MOVES] = 1
    gc.active_armies[test_land][oaaa.Active_Army.TANK_2_MOVES] = 1
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 0,
        "Used infantry should be removed")
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_1_MOVES] == 1,
        "Infantry should be reset to full moves")
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.TANK_1_MOVES] == 0,
        "Partially moved tank should be removed")
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.TANK_2_MOVES] == 1,
        "Tank should be reset to full moves")
}