package oaaa

Game_State :: struct {
    /*
    AI NOTE: Unit State Tracking System
    
    The game uses two parallel unit tracking systems:
    
    1. Idle Units (All Players):
       - Tracks units for ALL players
       - Used for:
         * Combat calculations (need all units)
         * Territory control (need unit counts)
         * Movement validation (checking threats)
       - Indexed by [location][player][unit_type]
       
    2. Active Units (Current Player Only):
       - Only tracks current player's units
       - Used for:
         * Movement tracking (which units moved)
         * Combat state (which units fought)
         * Special abilities (bombardment used)
       - Saves memory by not tracking inactive players
       - Indexed by [location][unit_state]
    
    Active_Army_To_Idle mapping:
    - Converts between the two systems
    - Example: .INF_0_MOVES -> .INF
    - Needed when:
      * Converting moved units back to idle
      * Updating both systems after combat
    */
    /*
    AI NOTE: Monte Carlo Search Optimization Fields
    Several fields help optimize the Monte Carlo search by tracking
    player decisions to avoid re-exploring rejected paths:
    
    rejected_moves_from:
    - Maps source airspace to set of rejected destination airspaces
    - When player chooses not to move to a destination, it's recorded here
    - Prevents re-offering moves player already rejected
    - Helps search converge faster by pruning duplicate paths
    
    skipped_buys:
    - Similar concept but for purchase decisions
    - Records which purchase options were rejected at each location
    */
    active_armies:           [Land_ID][Active_Army]u8,
    active_ships:            [Sea_ID][Active_Ship]u8,
    active_land_planes:      [Land_ID][Active_Plane]u8,
    active_sea_planes:       [Sea_ID][Active_Plane]u8,
    idle_armies:             [Land_ID][Player_ID][Idle_Army]u8,
    idle_land_planes:        [Land_ID][Player_ID][Idle_Plane]u8,
    idle_sea_planes:         [Sea_ID][Player_ID][Idle_Plane]u8,
    idle_ships:              [Sea_ID][Player_ID][Idle_Ship]u8,
    rejected_moves_from:     [Air_ID]Air_Bitset,
    skipped_buys:            [Air_ID]Purchase_Bitset,
    owner:                   [Land_ID]Player_ID,
    money:                   [Player_ID]u8,
    max_bombards:            [Land_ID]u8,
    factory_dmg:             [Land_ID]u8,
    factory_prod:            [Land_ID]u8,
    builds_left:             [Land_ID]u8,
    seed:                    u16,
    more_land_combat_needed: Land_Bitset,
    more_sea_combat_needed:  Sea_Bitset,
    land_combat_started:     Land_Bitset,
    sea_combat_started:      Sea_Bitset,
    cur_player:              Player_ID,
}

load_default_game_state :: proc(gs: ^Game_State) -> (ok: bool) {
	// for &money in gs.money {
	// 	money = 20
	// }
  gs.money[.Rus] = 10
  gs.money[.Ger] = 20
  gs.money[.Eng] = 6
  gs.money[.Jap] = 20
  gs.money[.USA] = 6

	factory_locations :: [?]Land_ID{.Washington, .London, .Berlin, .Moscow, .Tokyo}
	for land in factory_locations {
		gs.factory_prod[land] = mm.value[land]
	}
	for land in Land_ID {
		gs.owner[land] = mm.orig_owner[land]
		gs.idle_armies[land][gs.owner[land]][.INF] = 0
		if gs.owner[land] == gs.cur_player {
			gs.builds_left[land] = gs.factory_prod[land]
			gs.active_armies[land][.INF_1_MOVES] = 0
		}
	}
	// gs.land_states[Land_ID.Moscow].active_armies[Active_Army.TANK_2_MOVES] = 2
	// gs.land_states[Land_ID.Moscow].idle_armies[Player_ID.Rus][Idle_Army.TANK] = 2
	// gs.land_states[Land_ID.Moscow].active_planes[Active_Plane.FIGHTER_UNMOVED] = 1
	// gs.land_states[Land_ID.Moscow].idle_planes[Player_ID.Rus][Idle_Plane.FIGHTER] = 1
	// gs.land_states[Land_ID.Moscow].active_planes[Active_Plane.BOMBER_UNMOVED] = 1
	// gs.land_states[Land_ID.Moscow].idle_planes[Player_ID.Rus][Idle_Plane.BOMBER] = 1
	// gs.sea_states[Sea_ID.Pacific].idle_ships[Player_ID.Eng][Idle_Ship.TRANS_1I_1T] = 3
	return true
}
