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

COST_IDLE_SHIP := [?]u8 {
	Idle_Ship.TRANS_EMPTY = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_1I    = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_1A    = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_1T    = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_2I    = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_1I_1A = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.TRANS_1I_1T = Cost_Buy[Buy_Action.BUY_TRANS],
	Idle_Ship.SUB         = Cost_Buy[Buy_Action.BUY_SUB],
	Idle_Ship.DESTROYER   = Cost_Buy[Buy_Action.BUY_DESTROYER],
	Idle_Ship.CARRIER     = Cost_Buy[Buy_Action.BUY_CARRIER],
	Idle_Ship.CRUISER     = Cost_Buy[Buy_Action.BUY_CRUISER],
	Idle_Ship.BATTLESHIP  = Cost_Buy[Buy_Action.BUY_BATTLESHIP],
	Idle_Ship.BS_DAMAGED  = Cost_Buy[Buy_Action.BUY_BATTLESHIP],
}

DESTROYER_ATTACK :: 2
CARRIER_ATTACK :: 1
CRUISER_ATTACK :: 3
BATTLESHIP_ATTACK :: 4

Active_Ship_Attack := [?]int {
	Active_Ship.BATTLESHIP_0_MOVES = BATTLESHIP_ATTACK,
	Active_Ship.BS_DAMAGED_0_MOVES = BATTLESHIP_ATTACK,
	Active_Ship.CRUISER_0_MOVES    = CRUISER_ATTACK,
}

Ship_After_Bombard := [?]Active_Ship {
	Active_Ship.BATTLESHIP_0_MOVES = .BATTLESHIP_BOMBARDED,
	Active_Ship.BS_DAMAGED_0_MOVES = .BS_DAMAGED_BOMBARDED,
	Active_Ship.CRUISER_0_MOVES    = .CRUISER_BOMBARDED,
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

Attacker_Sea_Casualty_Order_1 := []Active_Ship{.SUB_0_MOVES, .DESTROYER_0_MOVES}

Air_Casualty_Order_Fighters := []Active_Plane {
	.FIGHTER_0_MOVES,
	.FIGHTER_1_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_4_MOVES,
}

Attacker_Sea_Casualty_Order_2 := []Active_Ship{.CARRIER_0_MOVES, .CRUISER_BOMBARDED}

Air_Casualty_Order_Bombers := []Active_Plane {
	.BOMBER_0_MOVES,
	.BOMBER_1_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_5_MOVES,
}
Attacker_Sea_Casualty_Order_3 := []Active_Ship{.BS_DAMAGED_BOMBARDED}

Attacker_Sea_Casualty_Order_4 := []Active_Ship {
	.TRANS_EMPTY_0_MOVES,
	.TRANS_1I_0_MOVES,
	.TRANS_1A_0_MOVES,
	.TRANS_1T_0_MOVES,
	.TRANS_2I_0_MOVES,
	.TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES,
}

Attacker_Land_Casualty_Order_1 := []Active_Army{.INF_0_MOVES, .ARTY_0_MOVES, .TANK_0_MOVES}

Defender_Sub_Casualty := []Idle_Ship{.SUB}

Defender_Sea_Casualty_Order_1 := []Idle_Ship{.DESTROYER, .CARRIER, .CRUISER}

Defender_Sea_Casualty_Order_2 := []Idle_Ship {
	.BS_DAMAGED,
	.TRANS_EMPTY,
	.TRANS_1I,
	.TRANS_1A,
	.TRANS_1T,
	.TRANS_2I,
	.TRANS_1I_1A,
	.TRANS_1I_1T,
}

Defender_Land_Casualty_Order_1 := []Idle_Army{.AAGUN}
Defender_Land_Casualty_Order_2 := []Idle_Army{.INF, .ARTY, .TANK}
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

Ships_Moved := [?]Active_Ship {
	Active_Ship.TRANS_EMPTY_UNMOVED = .TRANS_EMPTY_2_MOVES,
	Active_Ship.TRANS_1I_UNMOVED    = .TRANS_1I_2_MOVES,
	Active_Ship.TRANS_1I_2_MOVES    = .TRANS_1I_0_MOVES,
	Active_Ship.TRANS_1I_1_MOVES    = .TRANS_1I_0_MOVES,
	Active_Ship.TRANS_1A_UNMOVED    = .TRANS_1A_2_MOVES,
	Active_Ship.TRANS_1A_2_MOVES    = .TRANS_1A_0_MOVES,
	Active_Ship.TRANS_1A_1_MOVES    = .TRANS_1A_0_MOVES,
	Active_Ship.TRANS_1T_UNMOVED    = .TRANS_1T_2_MOVES,
	Active_Ship.TRANS_1T_2_MOVES    = .TRANS_1T_0_MOVES,
	Active_Ship.TRANS_1T_1_MOVES    = .TRANS_1T_0_MOVES,
	Active_Ship.TRANS_2I_2_MOVES    = .TRANS_2I_0_MOVES,
	Active_Ship.TRANS_2I_1_MOVES    = .TRANS_2I_0_MOVES,
	Active_Ship.TRANS_1I_1A_2_MOVES = .TRANS_1I_1A_0_MOVES,
	Active_Ship.TRANS_1I_1A_1_MOVES = .TRANS_1I_1A_0_MOVES,
	Active_Ship.TRANS_1I_1T_2_MOVES = .TRANS_1I_1T_0_MOVES,
	Active_Ship.TRANS_1I_1T_1_MOVES = .TRANS_1I_1T_0_MOVES,
	Active_Ship.SUB_2_MOVES         = .SUB_0_MOVES,
	Active_Ship.DESTROYER_2_MOVES   = .DESTROYER_0_MOVES,
	Active_Ship.CARRIER_2_MOVES     = .CARRIER_0_MOVES,
	Active_Ship.CRUISER_2_MOVES     = .CRUISER_0_MOVES,
	Active_Ship.BATTLESHIP_2_MOVES  = .BATTLESHIP_0_MOVES,
	Active_Ship.BS_DAMAGED_2_MOVES  = .BS_DAMAGED_0_MOVES,
}

Ships_Moves := [?]int {
	Active_Ship.TRANS_1I_1_MOVES    = 1,
	Active_Ship.TRANS_1A_1_MOVES    = 1,
	Active_Ship.TRANS_1T_1_MOVES    = 1,
	Active_Ship.TRANS_2I_1_MOVES    = 1,
	Active_Ship.TRANS_1I_1A_1_MOVES = 1,
	Active_Ship.TRANS_1I_1T_1_MOVES = 1,
	Active_Ship.TRANS_1I_2_MOVES    = 2,
	Active_Ship.TRANS_1A_2_MOVES    = 2,
	Active_Ship.TRANS_1T_2_MOVES    = 2,
	Active_Ship.TRANS_2I_2_MOVES    = 2,
	Active_Ship.TRANS_1I_1A_2_MOVES = 2,
	Active_Ship.TRANS_1I_1T_2_MOVES = 2,
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

Ships_After_Retreat := [?]Active_Ship {
	Active_Ship.TRANS_EMPTY_0_MOVES  = .TRANS_EMPTY_0_MOVES,
	Active_Ship.TRANS_1I_0_MOVES     = .TRANS_1I_UNLOADED,
	Active_Ship.TRANS_1A_0_MOVES     = .TRANS_1A_UNLOADED,
	Active_Ship.TRANS_1T_0_MOVES     = .TRANS_1T_UNLOADED,
	Active_Ship.TRANS_1I_1A_0_MOVES  = .TRANS_1I_1A_UNLOADED,
	Active_Ship.TRANS_1I_1T_0_MOVES  = .TRANS_1I_1T_UNLOADED,
	Active_Ship.SUB_0_MOVES          = .SUB_0_MOVES,
	Active_Ship.DESTROYER_0_MOVES    = .DESTROYER_0_MOVES,
	Active_Ship.CARRIER_0_MOVES      = .CARRIER_0_MOVES,
	Active_Ship.CRUISER_BOMBARDED    = .CRUISER_BOMBARDED,
	Active_Ship.BATTLESHIP_BOMBARDED = .BATTLESHIP_BOMBARDED,
	Active_Ship.BS_DAMAGED_BOMBARDED = .BS_DAMAGED_BOMBARDED,
}

move_combat_ships :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Unmoved_Blockade_Ships {
		move_ship_seas(gc, ship) or_return
	}
	return true
}

move_ship_seas :: proc(gc: ^Game_Cache, ship: Active_Ship) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_sea in Sea_ID {
		move_ship_sea(gc, src_sea, ship) or_return
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}

move_ship_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	gc.valid_actions = {to_action(src_sea)}
	add_valid_ship_moves(gc, src_sea, ship)
	for gc.active_ships[src_sea][ship] > 0 {
		move_next_ship_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

move_next_ship_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, fmt.tprint(ship), to_air(src_sea)) or_return
	dst_sea := to_sea(dst_air_idx)
	flag_for_sea_enemy_combat(gc, dst_sea)
	if skip_ship(gc, src_sea, dst_sea, ship) do return true
	move_single_ship(gc, dst_sea, Ships_Moved[ship], ship, src_sea)
	if ship == .CARRIER_2_MOVES {
		gc.allied_carriers_total[dst_sea] += 1
		gc.allied_carriers_total[src_sea] -= 1
		carry_allied_fighters(gc, src_sea, dst_sea)
		// todo - not sure if next few lines are needed. But maybe since carriers are moved
		if gc.allied_carriers_total[dst_sea] * 2 <= gc.allied_fighters_total[dst_sea] {
			gc.has_carrier_space += {dst_sea}
		} else {
			gc.has_carrier_space -= {dst_sea}
		}
		if gc.allied_carriers_total[src_sea] * 2 > gc.allied_fighters_total[src_sea] {
			gc.has_carrier_space += {src_sea}
		} else {
			gc.has_carrier_space -= {src_sea}
		}
		gc.is_fighter_cache_current = false
	}
	return true
}

skip_ship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID, ship: Active_Ship) -> bool {
	if src_sea != dst_sea do return false
	gc.active_ships[src_sea][Ships_Moved[ship]] += gc.active_ships[src_sea][ship]
	gc.active_ships[src_sea][ship] = 0
	return true
}

add_valid_ship_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) {
	// for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if to_air(dst_sea) in gc.skipped_a2a[to_air(src_sea)] {
			continue
		}
		gc.valid_actions += {to_action(dst_sea)}
	}
	// for &dst_sea_2_away in sa.slice(&src_sea.canal_paths[gc.canal_state].seas_2_moves_away) {
	for dst_sea_2_away in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if to_air(dst_sea_2_away) in gc.skipped_a2a[to_air(src_sea)] {
			continue
		}
		for mid_sea in sa.slice(&mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][src_sea][dst_sea_2_away]) {
			if gc.enemy_destroyer_total[mid_sea] > 0 do continue
			if ship != .SUB_2_MOVES && gc.enemy_blockade_total[mid_sea] > 0 do continue
			gc.valid_actions += {to_action(dst_sea_2_away)}
			break
		}
	}
}

move_single_ship :: proc(
	gc: ^Game_Cache,
	dst_sea: Sea_ID,
	dst_unit: Active_Ship,
	src_unit: Active_Ship,
	src_sea: Sea_ID,
) {
	gc.active_ships[dst_sea][dst_unit] += 1
	gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[dst_unit]] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_ships[src_sea][src_unit] -= 1
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[dst_unit]] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
}
