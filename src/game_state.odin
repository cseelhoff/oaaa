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
    
    active_army_to_roster mapping:
    - Converts between the two systems
    - Example: .Infantry_0_Moves -> .Infantry
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
	active_armies:             [Land_ID][Active_Army]u8,
	active_ships:              [Sea_ID][Active_Ship]u8,
	active_land_planes:        [Land_ID][Active_Plane]u8,
	active_sea_planes:         [Sea_ID][Active_Plane]u8,
	roster_armies:               [Land_ID][Nation_ID][Roster_Army]u8,
	roster_land_planes:          [Land_ID][Nation_ID][Roster_Plane]u8,
	roster_sea_planes:           [Sea_ID][Nation_ID][Roster_Plane]u8,
	roster_ships:                [Sea_ID][Nation_ID][Roster_Ship]u8,
	smallest_allowable_action: [Region_ID]Action_ID,
	// skipped_buys:            [Region_ID]Purchase_Bitset,
	owner:                     [Land_ID]Nation_ID,
	treasury:                     [Nation_ID]u8,
	max_bombardment_dice:              [Land_ID]u8,
	factory_dmg:               [Land_ID]u8,
	factory_prod:              [Land_ID]u8,
	builds_left:               [Land_ID]u8,
	seed:                      u16,
	current_territory:         Region_ID,
	current_active_unit:       Active_Unit,
	more_land_battles_needed:   Land_Bitset,
	more_sea_battles_needed:    Sea_Bitset,
	land_battle_started:       Land_Bitset,
	sea_battle_started:        Sea_Bitset,
	acting_nation:                Nation_ID,
}

load_default_game_state :: proc(gs: ^Game_State) -> (ok: bool) {
	for &treasury, idx in gs.treasury {
		treasury = starting_money[idx]
	}
	for land in factory_locations {
		gs.factory_prod[land] = mm.value[land]
	}
	for land in Land_ID {
		gs.owner[land] = mm.original_owner[land]
		for player in Nation_ID {
			for army in Roster_Army {
				gs.roster_armies[land][player][army] = starting_armies[land][player][army]
				if player == gs.acting_nation {
					gs.active_armies[land][roster_army_to_active[army]] =
						starting_armies[land][player][army]
				}
			}
			for plane in Roster_Plane {
				gs.roster_land_planes[land][player][plane] =
					starting_land_planes[land][player][plane]
				if player == gs.acting_nation {
					gs.active_land_planes[land][roster_plane_to_active[plane]] =
						starting_land_planes[land][player][plane]
				}
			}
		}
		if gs.owner[land] == gs.acting_nation {
			gs.builds_left[land] = gs.factory_prod[land]
		}
	}
	for sea in Sea_ID {
		for player in Nation_ID {
			for plane in Roster_Plane {
				gs.roster_sea_planes[sea][player][plane] = starting_sea_planes[sea][player][plane]
				if player == gs.acting_nation {
					gs.active_sea_planes[sea][roster_plane_to_active[plane]] =
						starting_sea_planes[sea][player][plane]
				}
			}
			for ship in Roster_Ship {
				gs.roster_ships[sea][player][ship] = starting_ships[sea][player][ship]
				if player == gs.acting_nation {
					gs.active_ships[sea][roster_ship_to_active[ship]] = starting_ships[sea][player][ship]
				}
			}
		}
	}
	return true
}

roster_army_to_active: [Roster_Army]Active_Army = {
	.Infantry   = .Infantry_1_Moves,
	.Artillery  = .Artillery_1_Moves,
	.Tank  = .Tank_2_Moves,
	.AAGun = .AAGun_1_Moves,
}
roster_plane_to_active: [Roster_Plane]Active_Plane = {
	.Fighter = .Fighter_Unmoved,
	.Bomber  = .Bomber_Unmoved,
}
roster_ship_to_active: [Roster_Ship]Active_Ship = {
	.Transport_Empty = .Transport_Empty_Unmoved,
	.Transport_Infantry    = .Transport_Infantry_Unmoved,
	.Transport_Artillery    = .Transport_Artillery_Unmoved,
	.Transport_Tank    = .Transport_Tank_Unmoved,
	.Transport_Infantry_Infantry    = .Transport_Infantry_Infantry_2_Moves,
	.Transport_Infantry_Artillery = .Transport_Infantry_Artillery_2_Moves,
	.Transport_Infantry_Tank = .Transport_Infantry_Tank_2_Moves,
	.Submarine         = .Submarine_2_Moves,
	.Destroyer   = .Destroyer_2_Moves,
	.Carrier     = .Carrier_2_Moves,
	.Cruiser     = .Cruiser_2_Moves,
	.Battleship  = .Battleship_2_Moves,
	.Battleship_Damaged  = .Battleship_Damaged_2_Moves,
}
