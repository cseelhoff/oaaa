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
	smallest_allowable_action: [Air_ID]Action_ID,
	// skipped_buys:            [Air_ID]Purchase_Bitset,
	owner:                   [Land_ID]Player_ID,
	money:                   [Player_ID]u8,
	max_bombards:            [Land_ID]u8,
	factory_dmg:             [Land_ID]u8,
	factory_prod:            [Land_ID]u8,
	builds_left:             [Land_ID]u8,
	seed:                    u16,
  current_territory:       Air_ID,
  current_Active_Unit:     Active_Unit,
	more_land_combat_needed: Land_Bitset,
	more_sea_combat_needed:  Sea_Bitset,
	land_combat_started:     Land_Bitset,
	sea_combat_started:      Sea_Bitset,
	cur_player:              Player_ID,
}

load_default_game_state :: proc(gs: ^Game_State) -> (ok: bool) {
	for &money, idx in gs.money {
		money = starting_money[idx]
	}
	for land in factory_locations {
		gs.factory_prod[land] = mm.value[land]
	}
	for land in Land_ID {
		gs.owner[land] = mm.orig_owner[land]
		for player in Player_ID {
			for army in Idle_Army {
				gs.idle_armies[land][player][army] = 0
			}
			for plane in Idle_Plane {
				gs.idle_land_planes[land][player][plane] = 0
			}
		}
		if gs.owner[land] == gs.cur_player {
			gs.builds_left[land] = gs.factory_prod[land]
		}
	}
	for sea in Sea_ID {
		for player in Player_ID {
			for plane in Idle_Plane {
				gs.idle_sea_planes[sea][player][plane] = 0
			}
			for ship in Idle_Ship {
				gs.idle_ships[sea][player][ship] = 0
			}
		}
	}
	return true
}
