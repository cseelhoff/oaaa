package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_transport_unload_and_conquer :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place a transport with infantry in the sea
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_0_MOVES] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I] = 1
    
    // Unload infantry to land
    oaaa.unload_unit_to_land(&gc, test_land, oaaa.Active_Ship.TRANS_1I_0_MOVES)
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_0_MOVES, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    
    // Verify unit was unloaded
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_0_MOVES] == 1,
        "Infantry should be unloaded to land")
    testing.expect(t, gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] == 1,
        "Infantry should be added to idle armies")
    testing.expect(t, gc.team_land_units[test_land][.Allies] == 1,
        "Team land units should be incremented")
    
    // Verify transport state
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_1I_0_MOVES] == 0,
        "Old transport state should be removed")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] == 1,
        "New empty transport state should be added")
    testing.expect(t, gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_EMPTY] == 1,
        "Idle ship should be updated to empty")
    testing.expect(t, gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I] == 0,
        "Old idle ship state should be removed")
}

@(test)
test_transport_load_and_stage :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    test_land := oaaa.Land_ID.Washington
    
    // Place an empty transport and infantry
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_UNMOVED] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_EMPTY] = 1
    gc.active_armies[test_land][oaaa.Active_Army.INF_UNMOVED] = 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] = 1
    gc.team_land_units[test_land][.Allies] = 1
    
    // Load infantry onto transport
    loaded_ship := oaaa.Active_Ship.TRANS_1I_UNMOVED
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_EMPTY_UNMOVED, loaded_ship)
    
    // Update land units
    gc.active_armies[test_land][oaaa.Active_Army.INF_UNMOVED] -= 1
    gc.idle_armies[test_land][.USA][oaaa.Idle_Army.INF] -= 1
    gc.team_land_units[test_land][.Allies] -= 1
    
    // Verify transport state
    testing.expect(t, gc.active_ships[test_sea][loaded_ship] == 1,
        "Transport should be in loaded state")
    testing.expect(t, gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I] == 1,
        "Idle ship should be updated to loaded state")
    
    // Verify land state
    testing.expect(t, gc.active_armies[test_land][oaaa.Active_Army.INF_UNMOVED] == 0,
        "Infantry should be removed from land")
    testing.expect(t, gc.team_land_units[test_land][.Allies] == 0,
        "Team land units should be decremented")
}

@(test)
test_skip_empty_transports :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    test_sea := oaaa.Sea_ID.Pacific
    
    // Place transports with different move counts
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] = 1
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_1_MOVES] = 2
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_2_MOVES] = 3
    
    // Skip empty transports
    oaaa.skip_empty_transports(&gc)
    
    // Verify all transports were moved to 0 moves
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_0_MOVES] == 6,
        "All empty transports should be moved to 0 moves")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_1_MOVES] == 0,
        "No transports should have 1 move")
    testing.expect(t, gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_2_MOVES] == 0,
        "No transports should have 2 moves")
}

@(test)
test_transport_loading :: proc(t: ^testing.T) {
    // Test loading infantry onto different transport states
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_EMPTY_2_MOVES] == oaaa.Active_Ship.TRANS_1I_2_MOVES,
        "Loading infantry onto empty transport with 2 moves failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1T_2_MOVES] == oaaa.Active_Ship.TRANS_1I_1T_2_MOVES,
        "Loading infantry onto transport with tank and 2 moves failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1A_2_MOVES] == oaaa.Active_Ship.TRANS_1I_1A_2_MOVES,
        "Loading infantry onto transport with artillery and 2 moves failed")
        
    // Test loading artillery
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_EMPTY_2_MOVES] == oaaa.Active_Ship.TRANS_1A_2_MOVES,
        "Loading artillery onto empty transport with 2 moves failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1I_2_MOVES] == oaaa.Active_Ship.TRANS_1I_1A_2_MOVES,
        "Loading artillery onto transport with infantry and 2 moves failed")
        
    // Test loading tank
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_EMPTY_2_MOVES] == oaaa.Active_Ship.TRANS_1T_2_MOVES,
        "Loading tank onto empty transport with 2 moves failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_1I_2_MOVES] == oaaa.Active_Ship.TRANS_1I_1T_2_MOVES,
        "Loading tank onto transport with infantry and 2 moves failed")
}

@(test)
test_transport_staging :: proc(t: ^testing.T) {
    // Test staging empty transport
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_EMPTY_UNMOVED][0] == oaaa.Active_Ship.TRANS_EMPTY_2_MOVES,
        "Staging empty transport with 0 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_EMPTY_UNMOVED][1] == oaaa.Active_Ship.TRANS_EMPTY_1_MOVES,
        "Staging empty transport with 1 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_EMPTY_UNMOVED][2] == oaaa.Active_Ship.TRANS_EMPTY_0_MOVES,
        "Staging empty transport with 2 distance failed")
        
    // Test staging transport with infantry
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1I_UNMOVED][0] == oaaa.Active_Ship.TRANS_1I_2_MOVES,
        "Staging transport with infantry at 0 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1I_UNMOVED][1] == oaaa.Active_Ship.TRANS_1I_1_MOVES,
        "Staging transport with infantry at 1 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1I_UNMOVED][2] == oaaa.Active_Ship.TRANS_1I_0_MOVES,
        "Staging transport with infantry at 2 distance failed")
        
    // Test staging transport with artillery
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1A_UNMOVED][0] == oaaa.Active_Ship.TRANS_1A_2_MOVES,
        "Staging transport with artillery at 0 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1A_UNMOVED][1] == oaaa.Active_Ship.TRANS_1A_1_MOVES,
        "Staging transport with artillery at 1 distance failed")
    testing.expect(t,
        oaaa.Ship_After_Staged[oaaa.Active_Ship.TRANS_1A_UNMOVED][2] == oaaa.Active_Ship.TRANS_1A_0_MOVES,
        "Staging transport with artillery at 2 distance failed")
}

@(test)
test_transport_space :: proc(t: ^testing.T) {
    // Test transport space for small armies
    small_ships := oaaa.Idle_Ship_Space[oaaa.Army_Sizes.SMALL]
    
    // Check if ship types exist in the slice
    contains_ship :: proc(ships: []oaaa.Idle_Ship, ship: oaaa.Idle_Ship) -> bool {
        for s in ships {
            if s == ship do return true
        }
        return false
    }
    
    testing.expect(t, 
        contains_ship(small_ships, oaaa.Idle_Ship.TRANS_EMPTY),
        "Small armies should be able to use empty transports")
    testing.expect(t, 
        contains_ship(small_ships, oaaa.Idle_Ship.TRANS_1I),
        "Small armies should be able to use transports with infantry")
    testing.expect(t, 
        contains_ship(small_ships, oaaa.Idle_Ship.TRANS_1A),
        "Small armies should be able to use transports with artillery")
    testing.expect(t, 
        contains_ship(small_ships, oaaa.Idle_Ship.TRANS_1T),
        "Small armies should be able to use transports with tanks")
        
    // Test transport space for large armies
    large_ships := oaaa.Idle_Ship_Space[oaaa.Army_Sizes.LARGE]
    testing.expect(t, 
        contains_ship(large_ships, oaaa.Idle_Ship.TRANS_EMPTY),
        "Large armies should be able to use empty transports")
    testing.expect(t, 
        contains_ship(large_ships, oaaa.Idle_Ship.TRANS_1I),
        "Large armies should be able to use transports with infantry")
    testing.expect(t, 
        !contains_ship(large_ships, oaaa.Idle_Ship.TRANS_1A),
        "Large armies should not be able to use transports with artillery")
    testing.expect(t, 
        !contains_ship(large_ships, oaaa.Idle_Ship.TRANS_1T),
        "Large armies should not be able to use transports with tanks")
}

@(test)
test_transport_unloading :: proc(t: ^testing.T) {
    // Test unloading single units
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_1I_0_MOVES] == oaaa.Active_Ship.TRANS_EMPTY_0_MOVES,
        "Unloading infantry from transport with only infantry should leave empty transport")
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_1A_0_MOVES] == oaaa.Active_Ship.TRANS_EMPTY_0_MOVES,
        "Unloading artillery from transport with only artillery should leave empty transport")
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_1T_0_MOVES] == oaaa.Active_Ship.TRANS_EMPTY_0_MOVES,
        "Unloading tank from transport with only tank should leave empty transport")
        
    // Test unloading from transports with multiple units
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_2I_0_MOVES] == oaaa.Active_Ship.TRANS_1I_0_MOVES,
        "Unloading infantry from transport with two infantry should leave one infantry")
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_1I_1A_0_MOVES] == oaaa.Active_Ship.TRANS_1A_0_MOVES,
        "Unloading infantry from transport with infantry and artillery should leave artillery")
    testing.expect(t,
        oaaa.Transport_Unloaded[oaaa.Active_Ship.TRANS_1I_1T_0_MOVES] == oaaa.Active_Ship.TRANS_1T_0_MOVES,
        "Unloading infantry from transport with infantry and tank should leave tank")
}

@(test)
test_transport_loading_unmoved :: proc(t: ^testing.T) {
    // Test loading onto unmoved transports
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_EMPTY_UNMOVED] == oaaa.Active_Ship.TRANS_1I_UNMOVED,
        "Loading infantry onto unmoved empty transport failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_EMPTY_UNMOVED] == oaaa.Active_Ship.TRANS_1A_UNMOVED,
        "Loading artillery onto unmoved empty transport failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_EMPTY_UNMOVED] == oaaa.Active_Ship.TRANS_1T_UNMOVED,
        "Loading tank onto unmoved empty transport failed")
        
    // Test loading onto transports with one unit
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1I_UNMOVED] == oaaa.Active_Ship.TRANS_2I_2_MOVES,
        "Loading infantry onto transport with infantry unmoved failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1I_UNMOVED] == oaaa.Active_Ship.TRANS_1I_UNMOVED,
        "Loading artillery onto transport with infantry unmoved failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_1I_UNMOVED] == oaaa.Active_Ship.TRANS_1I_1T_2_MOVES,
        "Loading tank onto transport with infantry unmoved failed")
}

@(test)
test_transport_loading_unloaded :: proc(t: ^testing.T) {
    // Test that loading onto unloaded transports maintains unloaded state
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.TRANS_1I_UNLOADED] == oaaa.Active_Ship.TRANS_2I_UNLOADED,
        "Loading infantry onto unloaded transport with infantry failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.TRANS_1I_UNLOADED] == oaaa.Active_Ship.TRANS_1I_1A_UNLOADED,
        "Loading artillery onto unloaded transport with infantry failed")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.TRANS_1I_UNLOADED] == oaaa.Active_Ship.TRANS_1I_1T_UNLOADED,
        "Loading tank onto unloaded transport with infantry failed")
}

@(test)
test_transport_loading_invalid :: proc(t: ^testing.T) {
    // Test that loading onto non-transport ships returns the same state
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.INF][oaaa.Active_Ship.SUB_UNMOVED] == oaaa.Active_Ship.SUB_UNMOVED,
        "Loading onto submarine should not change state")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.ARTY][oaaa.Active_Ship.CARRIER_UNMOVED] == oaaa.Active_Ship.CARRIER_UNMOVED,
        "Loading onto carrier should not change state")
    testing.expect(t, 
        oaaa.Transport_Load_Unit[oaaa.Idle_Army.TANK][oaaa.Active_Ship.BATTLESHIP_UNMOVED] == oaaa.Active_Ship.BATTLESHIP_UNMOVED,
        "Loading onto battleship should not change state")
}

@(test)
test_transport_multiple_units :: proc(t: ^testing.T) {
    // Create game cache with initial state
    gc := oaaa.Game_Cache{}
    gc.cur_player = .USA
    test_sea := oaaa.Sea_ID.Pacific
    src_land := oaaa.Land_ID.Washington
    dst_land := oaaa.Land_ID.London
    
    // Place an empty transport and units in source land
    gc.active_ships[test_sea][oaaa.Active_Ship.TRANS_EMPTY_UNMOVED] = 1
    gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_EMPTY] = 1
    
    // Place infantry and artillery in source land
    gc.active_armies[src_land][oaaa.Active_Army.INF_UNMOVED] = 1
    gc.active_armies[src_land][oaaa.Active_Army.ARTY_UNMOVED] = 1
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.INF] = 1
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.ARTY] = 1
    gc.team_land_units[src_land][.Allies] = 2
    
    // First load infantry
    loaded_ship := oaaa.Active_Ship.TRANS_1I_UNMOVED
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_EMPTY_UNMOVED, loaded_ship)
    
    // Update source land after loading infantry
    gc.active_armies[src_land][oaaa.Active_Army.INF_UNMOVED] -= 1
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.INF] -= 1
    gc.team_land_units[src_land][.Allies] -= 1
    
    // Then load artillery
    loaded_ship = oaaa.Active_Ship.TRANS_1I_1A_UNMOVED
    oaaa.replace_ship(&gc, test_sea, oaaa.Active_Ship.TRANS_1I_UNMOVED, loaded_ship)
    
    // Update source land after loading artillery
    gc.active_armies[src_land][oaaa.Active_Army.ARTY_UNMOVED] -= 1
    gc.idle_armies[src_land][.USA][oaaa.Idle_Army.ARTY] -= 1
    gc.team_land_units[src_land][.Allies] -= 1
    
    // Verify source land state
    testing.expect(t, gc.team_land_units[src_land][.Allies] == 0,
        "Source land should have no units")
    testing.expect(t, gc.active_armies[src_land][oaaa.Active_Army.INF_UNMOVED] == 0,
        "Source land should have no infantry")
    testing.expect(t, gc.active_armies[src_land][oaaa.Active_Army.ARTY_UNMOVED] == 0,
        "Source land should have no artillery")
    
    // Verify transport state after loading both units
    testing.expect(t, gc.active_ships[test_sea][loaded_ship] == 1,
        "Transport should be in loaded state with both units")
    testing.expect(t, gc.idle_ships[test_sea][.USA][oaaa.Idle_Ship.TRANS_1I_1A] == 1,
        "Idle ship should reflect both loaded units")
    
    // Now unload units to destination
    oaaa.unload_unit_to_land(&gc, dst_land, loaded_ship)
    oaaa.replace_ship(&gc, test_sea, loaded_ship, oaaa.Active_Ship.TRANS_EMPTY_0_MOVES)
    
    // Verify destination land state
    testing.expect(t, gc.active_armies[dst_land][oaaa.Active_Army.INF_0_MOVES] == 1,
        "Infantry should be unloaded to destination")
    testing.expect(t, gc.active_armies[dst_land][oaaa.Active_Army.ARTY_0_MOVES] == 1,
        "Artillery should be unloaded to destination")
    testing.expect(t, gc.idle_armies[dst_land][.USA][oaaa.Idle_Army.INF] == 1,
        "Infantry should be added to idle armies in destination")
    testing.expect(t, gc.idle_armies[dst_land][.USA][oaaa.Idle_Army.ARTY] == 1,
        "Artillery should be added to idle armies in destination")
    testing.expect(t, gc.team_land_units[dst_land][.Allies] == 2,
        "Destination should have two allied units")
}
