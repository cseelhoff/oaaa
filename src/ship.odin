#+feature global-context
package oaaa

import sa "core:container/small_array"
import "core:fmt"

Idle_Ship :: enum {
	TRANS_EMPTY,
	TRANS_1I,
	TRANS_1A,
	TRANS_1T,
	TRANS_2I,
	TRANS_1I_1A,
	TRANS_1I_1T,
	SUB,
	DESTROYER,
	CARRIER,
	CRUISER,
	BATTLESHIP,
	BS_DAMAGED,
}

COST_IDLE_SHIP := [Idle_Ship]u8 {
	.TRANS_EMPTY = 7,
	.TRANS_1I    = 7 + 3,
	.TRANS_1A    = 7 + 4,
	.TRANS_1T    = 7 + 6,
	.TRANS_2I    = 7 + 3 + 3,
	.TRANS_1I_1A = 7 + 3 + 4,
	.TRANS_1I_1T = 7 + 3 + 6,
	.SUB         = 6,
	.DESTROYER   = 8,
	.CARRIER     = 14,
	.CRUISER     = 12,
	.BATTLESHIP  = 20,
	.BS_DAMAGED  = 20,
}

DESTROYER_ATTACK :: 2
CARRIER_ATTACK :: 1
CRUISER_ATTACK :: 3
BATTLESHIP_ATTACK :: 4

Active_Ship_Attack: [Active_Ship]int

@(init)
init_Active_Ship_Attack :: proc() {
	Active_Ship_Attack[.BATTLESHIP_0_MOVES] = BATTLESHIP_ATTACK
	Active_Ship_Attack[.BS_DAMAGED_0_MOVES] = BATTLESHIP_ATTACK
	Active_Ship_Attack[.CRUISER_0_MOVES] = CRUISER_ATTACK
}

Ship_After_Bombard: [Active_Ship]Active_Ship

@(init)
init_Ship_After_Bombard :: proc() {
	Ship_After_Bombard[.BATTLESHIP_0_MOVES] = .BATTLESHIP_BOMBARDED
	Ship_After_Bombard[.BS_DAMAGED_0_MOVES] = .BS_DAMAGED_BOMBARDED
	Ship_After_Bombard[.CRUISER_0_MOVES] = .CRUISER_BOMBARDED
}

DESTROYER_DEFENSE :: 2
CARRIER_DEFENSE :: 2
CRUISER_DEFENSE :: 3
BATTLESHIP_DEFENSE :: 4

Active_Ship :: enum {
	TRANS_EMPTY_UNMOVED,
	TRANS_EMPTY_2_MOVES,
	TRANS_EMPTY_1_MOVES,
	TRANS_EMPTY_0_MOVES,
	TRANS_1I_UNMOVED,
	TRANS_1I_2_MOVES,
	TRANS_1I_1_MOVES,
	TRANS_1I_0_MOVES,
	TRANS_1I_UNLOADED,
	TRANS_1A_UNMOVED,
	TRANS_1A_2_MOVES,
	TRANS_1A_1_MOVES,
	TRANS_1A_0_MOVES,
	TRANS_1A_UNLOADED,
	TRANS_1T_UNMOVED,
	TRANS_1T_2_MOVES,
	TRANS_1T_1_MOVES,
	TRANS_1T_0_MOVES,
	TRANS_1T_UNLOADED,
	TRANS_2I_2_MOVES,
	TRANS_2I_1_MOVES,
	TRANS_2I_0_MOVES,
	TRANS_2I_UNLOADED,
	TRANS_1I_1A_2_MOVES,
	TRANS_1I_1A_1_MOVES,
	TRANS_1I_1A_0_MOVES,
	TRANS_1I_1A_UNLOADED,
	TRANS_1I_1T_2_MOVES,
	TRANS_1I_1T_1_MOVES,
	TRANS_1I_1T_0_MOVES,
	TRANS_1I_1T_UNLOADED,
	SUB_2_MOVES,
	SUB_0_MOVES,
	DESTROYER_2_MOVES,
	DESTROYER_0_MOVES,
	CARRIER_2_MOVES,
	CARRIER_0_MOVES,
	CRUISER_2_MOVES,
	CRUISER_0_MOVES,
	CRUISER_BOMBARDED,
	BATTLESHIP_2_MOVES,
	BATTLESHIP_0_MOVES,
	BATTLESHIP_BOMBARDED,
	BS_DAMAGED_2_MOVES,
	BS_DAMAGED_0_MOVES,
	BS_DAMAGED_BOMBARDED,
}
Bombard_Ships := []Active_Ship{.BATTLESHIP_0_MOVES, .BS_DAMAGED_0_MOVES, .CRUISER_0_MOVES} //Battleships first, since they have higher attack damage

Active_Ship_To_Idle := [Active_Ship]Idle_Ship {
	.TRANS_EMPTY_UNMOVED  = .TRANS_EMPTY,
	.TRANS_EMPTY_2_MOVES  = .TRANS_EMPTY,
	.TRANS_EMPTY_1_MOVES  = .TRANS_EMPTY,
	.TRANS_EMPTY_0_MOVES  = .TRANS_EMPTY,
	.TRANS_1I_UNMOVED     = .TRANS_1I,
	.TRANS_1I_2_MOVES     = .TRANS_1I,
	.TRANS_1I_1_MOVES     = .TRANS_1I,
	.TRANS_1I_0_MOVES     = .TRANS_1I,
	.TRANS_1I_UNLOADED    = .TRANS_1I,
	.TRANS_1A_UNMOVED     = .TRANS_1A,
	.TRANS_1A_2_MOVES     = .TRANS_1A,
	.TRANS_1A_1_MOVES     = .TRANS_1A,
	.TRANS_1A_0_MOVES     = .TRANS_1A,
	.TRANS_1A_UNLOADED    = .TRANS_1A,
	.TRANS_1T_UNMOVED     = .TRANS_1T,
	.TRANS_1T_2_MOVES     = .TRANS_1T,
	.TRANS_1T_1_MOVES     = .TRANS_1T,
	.TRANS_1T_0_MOVES     = .TRANS_1T,
	.TRANS_1T_UNLOADED    = .TRANS_1T,
	.TRANS_2I_2_MOVES     = .TRANS_2I,
	.TRANS_2I_1_MOVES     = .TRANS_2I,
	.TRANS_2I_0_MOVES     = .TRANS_2I,
	.TRANS_2I_UNLOADED    = .TRANS_2I,
	.TRANS_1I_1A_2_MOVES  = .TRANS_1I_1A,
	.TRANS_1I_1A_1_MOVES  = .TRANS_1I_1A,
	.TRANS_1I_1A_0_MOVES  = .TRANS_1I_1A,
	.TRANS_1I_1A_UNLOADED = .TRANS_1I_1A,
	.TRANS_1I_1T_2_MOVES  = .TRANS_1I_1T,
	.TRANS_1I_1T_1_MOVES  = .TRANS_1I_1T,
	.TRANS_1I_1T_0_MOVES  = .TRANS_1I_1T,
	.TRANS_1I_1T_UNLOADED = .TRANS_1I_1T,
	.SUB_2_MOVES          = .SUB,
	.SUB_0_MOVES          = .SUB,
	.DESTROYER_2_MOVES    = .DESTROYER,
	.DESTROYER_0_MOVES    = .DESTROYER,
	.CARRIER_2_MOVES      = .CARRIER,
	.CARRIER_0_MOVES      = .CARRIER,
	.CRUISER_2_MOVES      = .CRUISER,
	.CRUISER_0_MOVES      = .CRUISER,
	.CRUISER_BOMBARDED    = .CRUISER,
	.BATTLESHIP_2_MOVES   = .BATTLESHIP,
	.BATTLESHIP_0_MOVES   = .BATTLESHIP,
	.BATTLESHIP_BOMBARDED = .BATTLESHIP,
	.BS_DAMAGED_2_MOVES   = .BS_DAMAGED,
	.BS_DAMAGED_0_MOVES   = .BS_DAMAGED,
	.BS_DAMAGED_BOMBARDED = .BS_DAMAGED,
}

Unmoved_Blockade_Ships := [?]Active_Ship {
	.SUB_2_MOVES,
	.DESTROYER_2_MOVES,
	.CARRIER_2_MOVES,
	.CRUISER_2_MOVES,
	.BATTLESHIP_2_MOVES,
	.BS_DAMAGED_2_MOVES,
}

Ships_Moved: [Active_Ship]Active_Ship

@(init)
init_Ships_Moved :: proc() {
	Ships_Moved[.TRANS_EMPTY_UNMOVED] = .TRANS_EMPTY_2_MOVES
	Ships_Moved[.TRANS_1I_UNMOVED] = .TRANS_1I_2_MOVES
	Ships_Moved[.TRANS_1I_2_MOVES] = .TRANS_1I_0_MOVES
	Ships_Moved[.TRANS_1I_1_MOVES] = .TRANS_1I_0_MOVES
	Ships_Moved[.TRANS_1A_UNMOVED] = .TRANS_1A_2_MOVES
	Ships_Moved[.TRANS_1A_2_MOVES] = .TRANS_1A_0_MOVES
	Ships_Moved[.TRANS_1A_1_MOVES] = .TRANS_1A_0_MOVES
	Ships_Moved[.TRANS_1T_UNMOVED] = .TRANS_1T_2_MOVES
	Ships_Moved[.TRANS_1T_2_MOVES] = .TRANS_1T_0_MOVES
	Ships_Moved[.TRANS_1T_1_MOVES] = .TRANS_1T_0_MOVES
	Ships_Moved[.TRANS_2I_2_MOVES] = .TRANS_2I_0_MOVES
	Ships_Moved[.TRANS_2I_1_MOVES] = .TRANS_2I_0_MOVES
	Ships_Moved[.TRANS_1I_1A_2_MOVES] = .TRANS_1I_1A_0_MOVES
	Ships_Moved[.TRANS_1I_1A_1_MOVES] = .TRANS_1I_1A_0_MOVES
	Ships_Moved[.TRANS_1I_1T_2_MOVES] = .TRANS_1I_1T_0_MOVES
	Ships_Moved[.TRANS_1I_1T_1_MOVES] = .TRANS_1I_1T_0_MOVES
	Ships_Moved[.SUB_2_MOVES] = .SUB_0_MOVES
	Ships_Moved[.DESTROYER_2_MOVES] = .DESTROYER_0_MOVES
	Ships_Moved[.CARRIER_2_MOVES] = .CARRIER_0_MOVES
	Ships_Moved[.CRUISER_2_MOVES] = .CRUISER_0_MOVES
	Ships_Moved[.BATTLESHIP_2_MOVES] = .BATTLESHIP_0_MOVES
	Ships_Moved[.BS_DAMAGED_2_MOVES] = .BS_DAMAGED_0_MOVES
}

Ships_Moves: [Active_Ship]int

@(init)
init_Ships_Moves :: proc() {
	Ships_Moves[.TRANS_1I_1_MOVES] = 1
	Ships_Moves[.TRANS_1A_1_MOVES] = 1
	Ships_Moves[.TRANS_1T_1_MOVES] = 1
	Ships_Moves[.TRANS_2I_1_MOVES] = 1
	Ships_Moves[.TRANS_1I_1A_1_MOVES] = 1
	Ships_Moves[.TRANS_1I_1T_1_MOVES] = 1
	Ships_Moves[.TRANS_1I_2_MOVES] = 2
	Ships_Moves[.TRANS_1A_2_MOVES] = 2
	Ships_Moves[.TRANS_1T_2_MOVES] = 2
	Ships_Moves[.TRANS_2I_2_MOVES] = 2
	Ships_Moves[.TRANS_1I_1A_2_MOVES] = 2
	Ships_Moves[.TRANS_1I_1T_2_MOVES] = 2
}

Retreatable_Ships := [?]Active_Ship {
	.TRANS_EMPTY_0_MOVES,
	.TRANS_1I_0_MOVES,
	.TRANS_1A_0_MOVES,
	.TRANS_1T_0_MOVES,
	.TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES,
	.SUB_0_MOVES,
	.DESTROYER_0_MOVES,
	.CARRIER_0_MOVES,
	.CRUISER_BOMBARDED,
	.BATTLESHIP_BOMBARDED,
	.BS_DAMAGED_BOMBARDED,
}

Ships_After_Retreat: [Active_Ship]Active_Ship

@(init)
init_Ships_After_Retreat :: proc() {
	Ships_After_Retreat[.TRANS_EMPTY_0_MOVES] = .TRANS_EMPTY_0_MOVES
	Ships_After_Retreat[.TRANS_1I_0_MOVES] = .TRANS_1I_UNLOADED
	Ships_After_Retreat[.TRANS_1A_0_MOVES] = .TRANS_1A_UNLOADED
	Ships_After_Retreat[.TRANS_1T_0_MOVES] = .TRANS_1T_UNLOADED
	Ships_After_Retreat[.TRANS_1I_1A_0_MOVES] = .TRANS_1I_1A_UNLOADED
	Ships_After_Retreat[.TRANS_1I_1T_0_MOVES] = .TRANS_1I_1T_UNLOADED
	Ships_After_Retreat[.SUB_0_MOVES] = .SUB_0_MOVES
	Ships_After_Retreat[.DESTROYER_0_MOVES] = .DESTROYER_0_MOVES
	Ships_After_Retreat[.CARRIER_0_MOVES] = .CARRIER_0_MOVES
	Ships_After_Retreat[.CRUISER_BOMBARDED] = .CRUISER_BOMBARDED
	Ships_After_Retreat[.BATTLESHIP_BOMBARDED] = .BATTLESHIP_BOMBARDED
	Ships_After_Retreat[.BS_DAMAGED_BOMBARDED] = .BS_DAMAGED_BOMBARDED
}

move_combat_ships :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Unmoved_Blockade_Ships {
		gc.current_active_unit = to_unit(ship)
		gc.clear_history_needed = false
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			gc.current_territory = to_air(src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_ship_moves(gc)
					dst_action := get_action_input(gc) or_return
				if skip_ship(gc, dst_action) do continue
				dst_sea := to_sea(dst_action)
				mark_sea_for_combat_resolution(gc, dst_sea)
				move_single_ship(gc, Ships_Moved[ship], dst_action)
				if ship == .CARRIER_2_MOVES {
					gc.allied_carriers_total[dst_sea] += 1
					gc.allied_carriers_total[src_sea] -= 1
					carry_allied_fighters(gc, src_sea, dst_sea)
					// todo - not sure if next few lines are needed. But maybe since carriers are moved
					if gc.allied_carriers_total[dst_sea] * 2 > gc.allied_fighters_total[dst_sea] {
						gc.has_carrier_space += {dst_sea}
						gc.is_fighter_cache_current = false
					}
					if gc.allied_carriers_total[src_sea] * 2 <= gc.allied_fighters_total[src_sea] {
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
	gc.active_ships[src_sea][Ships_Moved[ship]] += gc.active_ships[src_sea][ship]
	gc.active_ships[src_sea][ship] = 0
	return true
}

add_valid_ship_moves :: proc(gc: ^Game_Cache) {
	// for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	src_sea := to_sea(gc.current_territory)
	ship := to_ship(gc.current_active_unit)
	add_seas_to_valid_actions(gc, mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea], gc.active_ships[src_sea][ship])
	// for &dst_sea_2_away in sa.slice(&src_sea.canal_paths[gc.canal_state].seas_2_moves_away) {
	for dst_sea_2_away in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		for mid_sea in sa.slice(
			&mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][src_sea][dst_sea_2_away],
		) {
			if gc.enemy_destroyer_total[mid_sea] > 0 do continue
			if ship != .SUB_2_MOVES && gc.enemy_blockade_total[mid_sea] > 0 do continue
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
	gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[dst_unit]] += unit_count
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += unit_count
	gc.active_ships[src_sea][src_unit] -= unit_count
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[src_unit]] -= unit_count
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= unit_count
}
