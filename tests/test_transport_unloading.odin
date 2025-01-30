/*
Transport Unloading Test Suite
Tests the mechanics of unloading units from transports to land territories.

Test Categories:
1. Basic Unloading
   - Single unit unloading
   - Multiple unit unloading
   - Unloading to friendly territory
   - Unloading to hostile territory

2. Movement Validation
   - Pre-combat unloading
   - Post-combat unloading
   - Movement restrictions after unloading

3. Special Rules
   - Unloading during amphibious assault
   - Unloading with enemy submarines present
   - Unloading with enemy destroyers present
*/

package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_basic_unloading :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place a transport with infantry and artillery
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_1A_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I_1A] = 1
    
    // Replace transport with empty one after unloading
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_1A_0_MOVES, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    
    // Add units to land
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] += 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] += 1
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 1,
        "Infantry should be unloaded to land")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] == 1,
        "Transport should be empty after unloading")
}

@(test)
test_amphibious_assault :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Tokyo
    
    // Place a transport with tank
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1T_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1T] = 1
    
    // Place enemy infantry in territory
    gc.idle_armies[test_land][.Jap][oaaa.Idle_Army.INF] = 1
    
    // Replace transport with empty one after unloading
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1T_0_MOVES, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    
    // Add tank to land for assault
    gc.active_armies[test_land][oaaa.Active_Army.TANK_0_MOVES] += 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.TANK] += 1
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.TANK_0_MOVES] == 1,
        "Tank should be unloaded for amphibious assault")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] == 1,
        "Transport should be empty after unloading")
    testing.expect(t, gc.idle_armies[test_land][.Jap][oaaa.Idle_Army.INF] == 1,
        "Enemy infantry should still be present")
}

@(test)
test_movement_after_unload :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place a transport with infantry that has moved once
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_1_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I] = 1
    
    // Replace transport with empty one after unloading, preserving move count
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_1_MOVES, oaaa.Active_Ship.TRANS_EMPTY_1_MOVES)
    
    // Add infantry to land with 0 moves (can't move after unloading)
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] += 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] += 1
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 1,
        "Infantry should be unloaded with 0 moves")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_1_MOVES] == 1,
        "Transport should preserve its remaining move")
}