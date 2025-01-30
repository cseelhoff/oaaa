/*
Combat Casualty Order Test Suite
Tests the order in which units are taken as casualties during combat.

Test Categories:
1. Sea Combat Casualties
   - Attacker casualty order
   - Defender casualty order
   - Submarine special rules
   - Damaged battleship priority

2. Air Combat Casualties
   - Fighter order
   - Bomber order
   - Carrier-based vs land-based

3. Mixed Combat
   - Naval bombardment effects
   - Strategic bombing casualties
*/

package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_attacker_sea_casualty_order :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    
    // Set up test fleet with various ship types
    gc.active_ships[test_sea][oaaa.Active_Ship.SUB_0_MOVES] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.DESTROYER_0_MOVES] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.CARRIER_0_MOVES] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.CRUISER_BOMBARDED] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.BS_DAMAGED_BOMBARDED] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] = 1
    
    // Take 3 casualties - should remove in correct order
    hits := u8(3)
    oaaa.remove_sea_attackers(&gc, test_sea, &hits)
    
    // Verify casualties taken in correct order:
    // 1. Submarine and destroyer first (weakest combat ships)
    // 2. Carrier and used cruiser next (medium value)
    // 3. Leave transport and damaged battleship (preserve transport, take BB last)
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.SUB_0_MOVES] == 0,
        "Submarine should be taken as first casualty")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.DESTROYER_0_MOVES] == 0,
        "Destroyer should be taken as second casualty")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.CARRIER_0_MOVES] == 0,
        "Carrier should be taken as third casualty")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.CRUISER_BOMBARDED] == 1,
        "Used cruiser should remain")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.BS_DAMAGED_BOMBARDED] == 1,
        "Damaged battleship should remain")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] == 1,
        "Transport should remain")
}

@(test)
test_submarine_special_rules :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    
    // Set up test fleet with submarines and destroyers
    gc.active_ships[test_sea][oaaa.Active_Ship.SUB_0_MOVES] = 2
    gc.active_ships[test_sea][oaaa.Active_Ship.DESTROYER_0_MOVES] = 1
    gc.idle_ships[test_sea][.Ger][oaaa.Idle_Ship.DESTROYER] = 1
    
    // Take 1 casualty with enemy destroyer present
    hits := u8(1)
    oaaa.remove_sea_attackers(&gc, test_sea, &hits)
    
    // Verify submarine taken first even with destroyer present
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.SUB_0_MOVES] == 1,
        "One submarine should be taken as casualty")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.DESTROYER_0_MOVES] == 1,
        "Destroyer should remain")
}