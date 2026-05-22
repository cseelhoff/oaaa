#+feature global-context
package oaaa

import "core:fmt"

Roster_Ship :: enum {
	Transport_Empty,
	Transport_Infantry,
	Transport_Artillery,
	Transport_Tank,
	Transport_Infantry_Infantry,
	Transport_Infantry_Artillery,
	Transport_Infantry_Tank,
	Submarine,
	Destroyer,
	Carrier,
	Cruiser,
	Battleship,
	Battleship_Damaged,
}

COST_ROSTER_SHIP := [Roster_Ship]u8 {
	.Transport_Empty = 7,
	.Transport_Infantry    = 7 + 3,
	.Transport_Artillery    = 7 + 4,
	.Transport_Tank    = 7 + 6,
	.Transport_Infantry_Infantry    = 7 + 3 + 3,
	.Transport_Infantry_Artillery = 7 + 3 + 4,
	.Transport_Infantry_Tank = 7 + 3 + 6,
	.Submarine         = 6,
	.Destroyer   = 8,
	.Carrier     = 14,
	.Cruiser     = 12,
	.Battleship  = 20,
	.Battleship_Damaged  = 20,
}

DESTROYER_ATTACK_VALUE :: 2
CARRIER_ATTACK_VALUE :: 1
CRUISER_ATTACK_VALUE :: 3
BATTLESHIP_ATTACK_VALUE :: 4

active_ship_attack: [Active_Ship]int

@(init)
init_active_ship_attack :: proc() {
	active_ship_attack[.Battleship_0_Moves] = BATTLESHIP_ATTACK_VALUE
	active_ship_attack[.Battleship_Damaged_0_Moves] = BATTLESHIP_ATTACK_VALUE
	active_ship_attack[.Cruiser_0_Moves] = CRUISER_ATTACK_VALUE
}

ship_after_bombardment: [Active_Ship]Active_Ship

@(init)
init_ship_after_bombardment :: proc() {
	ship_after_bombardment[.Battleship_0_Moves] = .Battleship_Bombarded
	ship_after_bombardment[.Battleship_Damaged_0_Moves] = .Battleship_Damaged_Bombarded
	ship_after_bombardment[.Cruiser_0_Moves] = .Cruiser_Bombarded
}

DESTROYER_DEFENSE_VALUE :: 2
CARRIER_DEFENSE_VALUE :: 2
CRUISER_DEFENSE_VALUE :: 3
BATTLESHIP_DEFENSE_VALUE :: 4

Active_Ship :: enum {
	Transport_Empty_Unmoved,
	Transport_Empty_2_Moves,
	Transport_Empty_1_Moves,
	Transport_Empty_0_Moves,
	Transport_Infantry_Unmoved,
	Transport_Infantry_2_Moves,
	Transport_Infantry_1_Moves,
	Transport_Infantry_0_Moves,
	Transport_Infantry_Unloaded,
	Transport_Artillery_Unmoved,
	Transport_Artillery_2_Moves,
	Transport_Artillery_1_Moves,
	Transport_Artillery_0_Moves,
	Transport_Artillery_Unloaded,
	Transport_Tank_Unmoved,
	Transport_Tank_2_Moves,
	Transport_Tank_1_Moves,
	Transport_Tank_0_Moves,
	Transport_Tank_Unloaded,
	Transport_Infantry_Infantry_2_Moves,
	Transport_Infantry_Infantry_1_Moves,
	Transport_Infantry_Infantry_0_Moves,
	Transport_Infantry_Infantry_Unloaded,
	Transport_Infantry_Artillery_2_Moves,
	Transport_Infantry_Artillery_1_Moves,
	Transport_Infantry_Artillery_0_Moves,
	Transport_Infantry_Artillery_Unloaded,
	Transport_Infantry_Tank_2_Moves,
	Transport_Infantry_Tank_1_Moves,
	Transport_Infantry_Tank_0_Moves,
	Transport_Infantry_Tank_Unloaded,
	Submarine_2_Moves,
	Submarine_0_Moves,
	Destroyer_2_Moves,
	Destroyer_0_Moves,
	Carrier_2_Moves,
	Carrier_0_Moves,
	Cruiser_2_Moves,
	Cruiser_0_Moves,
	Cruiser_Bombarded,
	Battleship_2_Moves,
	Battleship_0_Moves,
	Battleship_Bombarded,
	Battleship_Damaged_2_Moves,
	Battleship_Damaged_0_Moves,
	Battleship_Damaged_Bombarded,
}
bombardment_ships := []Active_Ship{.Battleship_0_Moves, .Battleship_Damaged_0_Moves, .Cruiser_0_Moves} //Battleships first, since they have higher attack damage

active_ship_to_roster := [Active_Ship]Roster_Ship {
	.Transport_Empty_Unmoved  = .Transport_Empty,
	.Transport_Empty_2_Moves  = .Transport_Empty,
	.Transport_Empty_1_Moves  = .Transport_Empty,
	.Transport_Empty_0_Moves  = .Transport_Empty,
	.Transport_Infantry_Unmoved     = .Transport_Infantry,
	.Transport_Infantry_2_Moves     = .Transport_Infantry,
	.Transport_Infantry_1_Moves     = .Transport_Infantry,
	.Transport_Infantry_0_Moves     = .Transport_Infantry,
	.Transport_Infantry_Unloaded    = .Transport_Infantry,
	.Transport_Artillery_Unmoved     = .Transport_Artillery,
	.Transport_Artillery_2_Moves     = .Transport_Artillery,
	.Transport_Artillery_1_Moves     = .Transport_Artillery,
	.Transport_Artillery_0_Moves     = .Transport_Artillery,
	.Transport_Artillery_Unloaded    = .Transport_Artillery,
	.Transport_Tank_Unmoved     = .Transport_Tank,
	.Transport_Tank_2_Moves     = .Transport_Tank,
	.Transport_Tank_1_Moves     = .Transport_Tank,
	.Transport_Tank_0_Moves     = .Transport_Tank,
	.Transport_Tank_Unloaded    = .Transport_Tank,
	.Transport_Infantry_Infantry_2_Moves     = .Transport_Infantry_Infantry,
	.Transport_Infantry_Infantry_1_Moves     = .Transport_Infantry_Infantry,
	.Transport_Infantry_Infantry_0_Moves     = .Transport_Infantry_Infantry,
	.Transport_Infantry_Infantry_Unloaded    = .Transport_Infantry_Infantry,
	.Transport_Infantry_Artillery_2_Moves  = .Transport_Infantry_Artillery,
	.Transport_Infantry_Artillery_1_Moves  = .Transport_Infantry_Artillery,
	.Transport_Infantry_Artillery_0_Moves  = .Transport_Infantry_Artillery,
	.Transport_Infantry_Artillery_Unloaded = .Transport_Infantry_Artillery,
	.Transport_Infantry_Tank_2_Moves  = .Transport_Infantry_Tank,
	.Transport_Infantry_Tank_1_Moves  = .Transport_Infantry_Tank,
	.Transport_Infantry_Tank_0_Moves  = .Transport_Infantry_Tank,
	.Transport_Infantry_Tank_Unloaded = .Transport_Infantry_Tank,
	.Submarine_2_Moves          = .Submarine,
	.Submarine_0_Moves          = .Submarine,
	.Destroyer_2_Moves    = .Destroyer,
	.Destroyer_0_Moves    = .Destroyer,
	.Carrier_2_Moves      = .Carrier,
	.Carrier_0_Moves      = .Carrier,
	.Cruiser_2_Moves      = .Cruiser,
	.Cruiser_0_Moves      = .Cruiser,
	.Cruiser_Bombarded    = .Cruiser,
	.Battleship_2_Moves   = .Battleship,
	.Battleship_0_Moves   = .Battleship,
	.Battleship_Bombarded = .Battleship,
	.Battleship_Damaged_2_Moves   = .Battleship_Damaged,
	.Battleship_Damaged_0_Moves   = .Battleship_Damaged,
	.Battleship_Damaged_Bombarded = .Battleship_Damaged,
}

unmoved_blockade_ships := [?]Active_Ship {
	.Submarine_2_Moves,
	.Destroyer_2_Moves,
	.Carrier_2_Moves,
	.Cruiser_2_Moves,
	.Battleship_2_Moves,
	.Battleship_Damaged_2_Moves,
}

ships_moved: [Active_Ship]Active_Ship

@(init)
init_ships_moved :: proc() {
	ships_moved[.Transport_Empty_Unmoved] = .Transport_Empty_2_Moves
	ships_moved[.Transport_Infantry_Unmoved] = .Transport_Infantry_2_Moves
	ships_moved[.Transport_Infantry_2_Moves] = .Transport_Infantry_0_Moves
	ships_moved[.Transport_Infantry_1_Moves] = .Transport_Infantry_0_Moves
	ships_moved[.Transport_Artillery_Unmoved] = .Transport_Artillery_2_Moves
	ships_moved[.Transport_Artillery_2_Moves] = .Transport_Artillery_0_Moves
	ships_moved[.Transport_Artillery_1_Moves] = .Transport_Artillery_0_Moves
	ships_moved[.Transport_Tank_Unmoved] = .Transport_Tank_2_Moves
	ships_moved[.Transport_Tank_2_Moves] = .Transport_Tank_0_Moves
	ships_moved[.Transport_Tank_1_Moves] = .Transport_Tank_0_Moves
	ships_moved[.Transport_Infantry_Infantry_2_Moves] = .Transport_Infantry_Infantry_0_Moves
	ships_moved[.Transport_Infantry_Infantry_1_Moves] = .Transport_Infantry_Infantry_0_Moves
	ships_moved[.Transport_Infantry_Artillery_2_Moves] = .Transport_Infantry_Artillery_0_Moves
	ships_moved[.Transport_Infantry_Artillery_1_Moves] = .Transport_Infantry_Artillery_0_Moves
	ships_moved[.Transport_Infantry_Tank_2_Moves] = .Transport_Infantry_Tank_0_Moves
	ships_moved[.Transport_Infantry_Tank_1_Moves] = .Transport_Infantry_Tank_0_Moves
	ships_moved[.Submarine_2_Moves] = .Submarine_0_Moves
	ships_moved[.Destroyer_2_Moves] = .Destroyer_0_Moves
	ships_moved[.Carrier_2_Moves] = .Carrier_0_Moves
	ships_moved[.Cruiser_2_Moves] = .Cruiser_0_Moves
	ships_moved[.Battleship_2_Moves] = .Battleship_0_Moves
	ships_moved[.Battleship_Damaged_2_Moves] = .Battleship_Damaged_0_Moves
}

ships_moves: [Active_Ship]int

@(init)
init_ships_moves :: proc() {
	ships_moves[.Transport_Infantry_1_Moves] = 1
	ships_moves[.Transport_Artillery_1_Moves] = 1
	ships_moves[.Transport_Tank_1_Moves] = 1
	ships_moves[.Transport_Infantry_Infantry_1_Moves] = 1
	ships_moves[.Transport_Infantry_Artillery_1_Moves] = 1
	ships_moves[.Transport_Infantry_Tank_1_Moves] = 1
	ships_moves[.Transport_Infantry_2_Moves] = 2
	ships_moves[.Transport_Artillery_2_Moves] = 2
	ships_moves[.Transport_Tank_2_Moves] = 2
	ships_moves[.Transport_Infantry_Infantry_2_Moves] = 2
	ships_moves[.Transport_Infantry_Artillery_2_Moves] = 2
	ships_moves[.Transport_Infantry_Tank_2_Moves] = 2
}

retreatable_ships := [?]Active_Ship {
	.Transport_Empty_0_Moves,
	.Transport_Infantry_0_Moves,
	.Transport_Artillery_0_Moves,
	.Transport_Tank_0_Moves,
	.Transport_Infantry_Artillery_0_Moves,
	.Transport_Infantry_Tank_0_Moves,
	.Submarine_0_Moves,
	.Destroyer_0_Moves,
	.Carrier_0_Moves,
	.Cruiser_Bombarded,
	.Battleship_Bombarded,
	.Battleship_Damaged_Bombarded,
}

ships_after_retreat: [Active_Ship]Active_Ship

@(init)
init_ships_after_retreat :: proc() {
	ships_after_retreat[.Transport_Empty_0_Moves] = .Transport_Empty_0_Moves
	ships_after_retreat[.Transport_Infantry_0_Moves] = .Transport_Infantry_Unloaded
	ships_after_retreat[.Transport_Artillery_0_Moves] = .Transport_Artillery_Unloaded
	ships_after_retreat[.Transport_Tank_0_Moves] = .Transport_Tank_Unloaded
	ships_after_retreat[.Transport_Infantry_Artillery_0_Moves] = .Transport_Infantry_Artillery_Unloaded
	ships_after_retreat[.Transport_Infantry_Tank_0_Moves] = .Transport_Infantry_Tank_Unloaded
	ships_after_retreat[.Submarine_0_Moves] = .Submarine_0_Moves
	ships_after_retreat[.Destroyer_0_Moves] = .Destroyer_0_Moves
	ships_after_retreat[.Carrier_0_Moves] = .Carrier_0_Moves
	ships_after_retreat[.Cruiser_Bombarded] = .Cruiser_Bombarded
	ships_after_retreat[.Battleship_Bombarded] = .Battleship_Bombarded
	ships_after_retreat[.Battleship_Damaged_Bombarded] = .Battleship_Damaged_Bombarded
}

move_combat_ships :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in unmoved_blockade_ships {
		gc.current_active_unit = to_unit(ship)
		gc.clear_history_needed = false
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			gc.current_territory = to_region(src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_ship_moves(gc)
					dst_action := get_action_input(gc) or_return
				if skip_ship(gc, dst_action) do continue
				dst_sea := to_sea(dst_action)
				mark_sea_for_combat_resolution(gc, dst_sea)
				move_single_ship(gc, ships_moved[ship], dst_action)
				if ship == .Carrier_2_Moves {
					gc.friendly_carriers_total[dst_sea] += 1
					gc.friendly_carriers_total[src_sea] -= 1
					carry_friendly_fighters(gc, src_sea, dst_sea)
					// todo - not sure if next few lines are needed. But maybe since carriers are moved
					if gc.friendly_carriers_total[dst_sea] * 2 > gc.friendly_fighters_total[dst_sea] {
						gc.has_carrier_space += {dst_sea}
						gc.is_fighter_cache_current = false
					}
					if gc.friendly_carriers_total[src_sea] * 2 <= gc.friendly_fighters_total[src_sea] {
						gc.has_carrier_space -= {src_sea}
						gc.is_fighter_cache_current = false
					}
				}
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

skip_ship :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> bool {
	if dst_action != .Skip_Action do return false
	src_sea := to_sea(gc.current_territory)
	ship := to_ship(gc.current_active_unit)
	gc.active_ships[src_sea][ships_moved[ship]] += gc.active_ships[src_sea][ship]
	gc.active_ships[src_sea][ship] = 0
	return true
}

add_valid_ship_moves :: proc(gc: ^Game_Cache) {
	// for dst_sea in src_sea.canal_paths[gc.canal_state].adjacent_seas {
	src_sea := to_sea(gc.current_territory)
	ship := to_ship(gc.current_active_unit)
	add_seas_to_valid_actions(gc, mm.seas_within_1_move[transmute(u8)gc.canals_open][src_sea], gc.active_ships[src_sea][ship])
	// for &dst_sea_2_away in src_sea.canal_paths[gc.canal_state].seas_2_moves_away {
	for dst_sea_2_away in mm.seas_within_2_moves[transmute(u8)gc.canals_open][src_sea] {
		for mid_sea in mm.seas_between[transmute(u8)gc.canals_open][src_sea][dst_sea_2_away] {
			if gc.enemy_destroyers_total[mid_sea] > 0 do continue
			if ship != .Submarine_2_Moves && gc.enemy_blockade_total[mid_sea] > 0 do continue
			add_sea_to_valid_actions(gc, dst_sea_2_away, gc.active_ships[src_sea][ship])
			break
		}
	}
}

move_single_ship :: proc(
	gc: ^Game_Cache,
	dst_unit: Active_Ship,
	dst_action: Action_ID,
) {
	src_sea := to_sea(gc.current_territory)
	src_unit := to_ship(gc.current_active_unit)
	dst_sea, unit_count := to_sea_count(dst_action)
	unit_count = min(unit_count, gc.active_ships[src_sea][src_unit])
	gc.active_ships[dst_sea][dst_unit] += unit_count
	gc.roster_ships[dst_sea][gc.acting_nation][active_ship_to_roster[dst_unit]] += unit_count
	gc.team_sea_units[dst_sea][mm.team[gc.acting_nation]] += unit_count
	gc.active_ships[src_sea][src_unit] -= unit_count
	gc.roster_ships[src_sea][gc.acting_nation][active_ship_to_roster[src_unit]] -= unit_count
	gc.team_sea_units[src_sea][mm.team[gc.acting_nation]] -= unit_count
}
