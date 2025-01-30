/*
Transport Loading Test Suite
Tests the transport loading/unloading mechanics for Axis & Allies.

Test Categories:
1. Basic Loading/Unloading
   - Single unit loading
   - Multiple unit loading
   - Unloading to friendly territory
   - Unloading to enemy territory

2. Movement Validation
   - Pre-staging movement
   - Post-loading movement
   - Post-unloading restrictions

3. Capacity Rules
   - Maximum capacity checks
   - Valid unit combinations
   - Invalid unit combinations

4. Game State Updates
   - Territory control changes
   - Unit count tracking
   - Movement state transitions
*/

package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_transport_loading :: proc(t: ^testing.T) {
    // Test loading infantry onto empty transport
    loaded_ship := oaaa.Trans_After_Loading[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1I_0_MOVES,
        "Loading infantry onto empty transport failed")

    // Test loading artillery onto empty transport
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1A_0_MOVES,
        "Loading artillery onto empty transport failed")

    // Test loading tank onto empty transport
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1T_0_MOVES,
        "Loading tank onto empty transport failed")

    // Test loading infantry onto transport with artillery
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1A_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1I_1A_0_MOVES,
        "Loading infantry onto transport with artillery failed")

    // Test loading artillery onto transport with infantry
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1I_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1I_1A_0_MOVES,
        "Loading artillery onto transport with infantry failed")

    // Test loading tank onto transport with infantry
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_1I_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1I_1T_0_MOVES,
        "Loading tank onto transport with infantry failed")

    // Test loading second infantry onto transport with one infantry
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1I_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_2I_0_MOVES,
        "Loading second infantry onto transport with infantry failed")

    // Test invalid combinations
    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_1A_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1A_0_MOVES,
        "Loading tank onto transport with artillery should fail")

    loaded_ship = oaaa.Trans_After_Loading[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1T_0_MOVES]
    testing.expect(t, loaded_ship == oaaa.Active_Ship.TRANS_1T_0_MOVES,
        "Loading artillery onto transport with tank should fail")
}

@(test)
test_transport_basic_loading :: proc(t: ^testing.T) {
    // Initialize game state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place empty transport in sea
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_EMPTY] = 1
    
    // Add infantry to land
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] = 1
    
    // Load infantry onto transport
    gc.valid_actions = {oaaa.to_action(test_sea)}
    gc.rejected_moves_from[oaaa.Air_ID.Pacific_Air] = {}
    oaaa.stage_next_ship_in_sea(&gc, test_sea, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 0,
        "Infantry should be removed from land")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_0_MOVES] == 1,
        "Transport should be loaded with infantry")
}

@(test)
test_transport_multiple_loading :: proc(t: ^testing.T) {
    // Initialize game state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place empty transport in sea
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_EMPTY] = 1
    
    // Add infantry and artillery to land
    gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] = 1
    gc.active_armies[test_land][oaaa.Active_Army.ARTY_0_MOVES] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.ARTY] = 1
    
    // Load both units onto transport
    gc.valid_actions = {oaaa.to_action(test_sea)}
    gc.rejected_moves_from[oaaa.Air_ID.Pacific_Air] = {}
    oaaa.stage_next_ship_in_sea(&gc, test_sea, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    oaaa.stage_next_ship_in_sea(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_0_MOVES)
    
    // Verify state changes
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 0,
        "Infantry should be removed from land")
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.ARTY_0_MOVES] == 0,
        "Artillery should be removed from land")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_1A_0_MOVES] == 1,
        "Transport should be loaded with both units")
}
