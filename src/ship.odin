package oaaa

import sa "core:container/small_array"

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

Idle_Ship_Names := [?]string {
	Idle_Ship.TRANS_EMPTY = "TRANS_EMPTY",
	Idle_Ship.TRANS_1I    = "TRANS_1I",
	Idle_Ship.TRANS_1A    = "TRANS_1A",
	Idle_Ship.TRANS_1T    = "TRANS_1T",
	Idle_Ship.TRANS_2I    = "TRANS_2I",
	Idle_Ship.TRANS_1I_1A = "TRANS_1I_1A",
	Idle_Ship.TRANS_1I_1T = "TRANS_1I_1T",
	Idle_Ship.SUB         = "SUB",
	Idle_Ship.DESTROYER   = "DESTROYER",
	Idle_Ship.CARRIER     = "CARRIER",
	Idle_Ship.CRUISER     = "CRUISER",
	Idle_Ship.BATTLESHIP  = "BATTLESHIP",
	Idle_Ship.BS_DAMAGED  = "BS_DAMAGED",
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
	SUB_UNMOVED,
	SUB_0_MOVES,
	DESTROYER_UNMOVED,
	DESTROYER_0_MOVES,
	CARRIER_UNMOVED,
	CARRIER_0_MOVES,
	CRUISER_UNMOVED,
	CRUISER_0_MOVES,
	CRUISER_BOMBARDED,
	BATTLESHIP_UNMOVED,
	BATTLESHIP_0_MOVES,
	BATTLESHIP_BOMBARDED,
	BS_DAMAGED_UNMOVED,
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
Bombard_Ships := []Active_Ship{.BATTLESHIP_0_MOVES, .BS_DAMAGED_0_MOVES, .CRUISER_0_MOVES}


Active_Ship_Names := [?]string {
	Active_Ship.TRANS_EMPTY_UNMOVED  = "TRANS_EMPTY_UNMOVED",
	Active_Ship.TRANS_EMPTY_2_MOVES  = "TRANS_EMPTY_2_MOVES",
	Active_Ship.TRANS_EMPTY_1_MOVES  = "TRANS_EMPTY_1_MOVES",
	Active_Ship.TRANS_EMPTY_0_MOVES  = "TRANS_EMPTY_0_MOVES",
	Active_Ship.TRANS_1I_UNMOVED     = "TRANS_1I_UNMOVED",
	Active_Ship.TRANS_1I_2_MOVES     = "TRANS_1I_2_MOVES",
	Active_Ship.TRANS_1I_1_MOVES     = "TRANS_1I_1_MOVES",
	Active_Ship.TRANS_1I_0_MOVES     = "TRANS_1I_0_MOVES",
	Active_Ship.TRANS_1I_UNLOADED    = "TRANS_1I_UNLOADED",
	Active_Ship.TRANS_1A_UNMOVED     = "TRANS_1A_UNMOVED",
	Active_Ship.TRANS_1A_2_MOVES     = "TRANS_1A_2_MOVES",
	Active_Ship.TRANS_1A_1_MOVES     = "TRANS_1A_1_MOVES",
	Active_Ship.TRANS_1A_0_MOVES     = "TRANS_1A_0_MOVES",
	Active_Ship.TRANS_1A_UNLOADED    = "TRANS_1A_UNLOADED",
	Active_Ship.TRANS_1T_UNMOVED     = "TRANS_1T_UNMOVED",
	Active_Ship.TRANS_1T_2_MOVES     = "TRANS_1T_2_MOVES",
	Active_Ship.TRANS_1T_1_MOVES     = "TRANS_1T_1_MOVES",
	Active_Ship.TRANS_1T_0_MOVES     = "TRANS_1T_0_MOVES",
	Active_Ship.TRANS_1T_UNLOADED    = "TRANS_1T_UNLOADED",
	Active_Ship.TRANS_2I_2_MOVES     = "TRANS_2I_2_MOVES",
	Active_Ship.TRANS_2I_1_MOVES     = "TRANS_2I_1_MOVES",
	Active_Ship.TRANS_2I_0_MOVES     = "TRANS_2I_0_MOVES",
	Active_Ship.TRANS_2I_UNLOADED    = "TRANS_2I_UNLOADED",
	Active_Ship.TRANS_1I_1A_2_MOVES  = "TRANS_1I_1A_2_MOVES",
	Active_Ship.TRANS_1I_1A_1_MOVES  = "TRANS_1I_1A_1_MOVES",
	Active_Ship.TRANS_1I_1A_0_MOVES  = "TRANS_1I_1A_0_MOVES",
	Active_Ship.TRANS_1I_1A_UNLOADED = "TRANS_1I_1A_UNLOADED",
	Active_Ship.TRANS_1I_1T_2_MOVES  = "TRANS_1I_1T_2_MOVES",
	Active_Ship.TRANS_1I_1T_1_MOVES  = "TRANS_1I_1T_1_MOVES",
	Active_Ship.TRANS_1I_1T_0_MOVES  = "TRANS_1I_1T_0_MOVES",
	Active_Ship.TRANS_1I_1T_UNLOADED = "TRANS_1I_1T_UNLOADED",
	Active_Ship.SUB_UNMOVED          = "SUB_UNMOVED",
	Active_Ship.SUB_0_MOVES          = "SUB_0_MOVES",
	Active_Ship.DESTROYER_UNMOVED    = "DESTROYER_UNMOVED",
	Active_Ship.DESTROYER_0_MOVES    = "DESTROYER_0_MOVES",
	Active_Ship.CARRIER_UNMOVED      = "CARRIER_UNMOVED",
	Active_Ship.CARRIER_0_MOVES      = "CARRIERS_0_MOVES",
	Active_Ship.CRUISER_UNMOVED      = "CRUISER_UNMOVED",
	Active_Ship.CRUISER_0_MOVES      = "CRUISER_0_MOVES",
	Active_Ship.CRUISER_BOMBARDED    = "CRUISER_BOMBARDED",
	Active_Ship.BATTLESHIP_UNMOVED   = "BATTLESHIP_UNMOVED",
	Active_Ship.BATTLESHIP_0_MOVES   = "BATTLESHIP_0_MOVES",
	Active_Ship.BATTLESHIP_BOMBARDED = "BATTLESHIP_BOMBARDED",
	Active_Ship.BS_DAMAGED_UNMOVED   = "BS_DAMAGED_UNMOVED",
	Active_Ship.BS_DAMAGED_0_MOVES   = "BS_DAMAGED_0_MOVES",
	Active_Ship.BS_DAMAGED_BOMBARDED = "BS_DAMAGED_BOMBARDED",
}

Active_Ship_To_Idle := [?]Idle_Ship {
	Active_Ship.TRANS_EMPTY_UNMOVED  = .TRANS_EMPTY,
	Active_Ship.TRANS_EMPTY_2_MOVES  = .TRANS_EMPTY,
	Active_Ship.TRANS_EMPTY_1_MOVES  = .TRANS_EMPTY,
	Active_Ship.TRANS_EMPTY_0_MOVES  = .TRANS_EMPTY,
	Active_Ship.TRANS_1I_UNMOVED     = .TRANS_1I,
	Active_Ship.TRANS_1I_2_MOVES     = .TRANS_1I,
	Active_Ship.TRANS_1I_1_MOVES     = .TRANS_1I,
	Active_Ship.TRANS_1I_0_MOVES     = .TRANS_1I,
	Active_Ship.TRANS_1I_UNLOADED    = .TRANS_1I,
	Active_Ship.TRANS_1A_UNMOVED     = .TRANS_1A,
	Active_Ship.TRANS_1A_2_MOVES     = .TRANS_1A,
	Active_Ship.TRANS_1A_1_MOVES     = .TRANS_1A,
	Active_Ship.TRANS_1A_0_MOVES     = .TRANS_1A,
	Active_Ship.TRANS_1A_UNLOADED    = .TRANS_1A,
	Active_Ship.TRANS_1T_UNMOVED     = .TRANS_1T,
	Active_Ship.TRANS_1T_2_MOVES     = .TRANS_1T,
	Active_Ship.TRANS_1T_1_MOVES     = .TRANS_1T,
	Active_Ship.TRANS_1T_0_MOVES     = .TRANS_1T,
	Active_Ship.TRANS_1T_UNLOADED    = .TRANS_1T,
	Active_Ship.TRANS_2I_2_MOVES     = .TRANS_2I,
	Active_Ship.TRANS_2I_1_MOVES     = .TRANS_2I,
	Active_Ship.TRANS_2I_0_MOVES     = .TRANS_2I,
	Active_Ship.TRANS_2I_UNLOADED    = .TRANS_2I,
	Active_Ship.TRANS_1I_1A_2_MOVES  = .TRANS_1I_1A,
	Active_Ship.TRANS_1I_1A_1_MOVES  = .TRANS_1I_1A,
	Active_Ship.TRANS_1I_1A_0_MOVES  = .TRANS_1I_1A,
	Active_Ship.TRANS_1I_1A_UNLOADED = .TRANS_1I_1A,
	Active_Ship.TRANS_1I_1T_2_MOVES  = .TRANS_1I_1T,
	Active_Ship.TRANS_1I_1T_1_MOVES  = .TRANS_1I_1T,
	Active_Ship.TRANS_1I_1T_0_MOVES  = .TRANS_1I_1T,
	Active_Ship.TRANS_1I_1T_UNLOADED = .TRANS_1I_1T,
	Active_Ship.SUB_UNMOVED          = .SUB,
	Active_Ship.SUB_0_MOVES          = .SUB,
	Active_Ship.DESTROYER_UNMOVED    = .DESTROYER,
	Active_Ship.DESTROYER_0_MOVES    = .DESTROYER,
	Active_Ship.CARRIER_UNMOVED      = .CARRIER,
	Active_Ship.CARRIER_0_MOVES      = .CARRIER,
	Active_Ship.CRUISER_UNMOVED      = .CRUISER,
	Active_Ship.CRUISER_0_MOVES      = .CRUISER,
	Active_Ship.CRUISER_BOMBARDED    = .CRUISER,
	Active_Ship.BATTLESHIP_UNMOVED   = .BATTLESHIP,
	Active_Ship.BATTLESHIP_0_MOVES   = .BATTLESHIP,
	Active_Ship.BATTLESHIP_BOMBARDED = .BATTLESHIP,
	Active_Ship.BS_DAMAGED_UNMOVED   = .BS_DAMAGED,
	Active_Ship.BS_DAMAGED_0_MOVES   = .BS_DAMAGED,
	Active_Ship.BS_DAMAGED_BOMBARDED = .BS_DAMAGED,
}

Unmoved_Blockade_Ships := [?]Active_Ship {
	.SUB_UNMOVED,
	.DESTROYER_UNMOVED,
	.CARRIER_UNMOVED,
	.CRUISER_UNMOVED,
	.BATTLESHIP_UNMOVED,
	.BS_DAMAGED_UNMOVED,
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
	Active_Ship.SUB_UNMOVED         = .SUB_0_MOVES,
	Active_Ship.DESTROYER_UNMOVED   = .DESTROYER_0_MOVES,
	Active_Ship.CARRIER_UNMOVED     = .CARRIER_0_MOVES,
	Active_Ship.CRUISER_UNMOVED     = .CRUISER_0_MOVES,
	Active_Ship.BATTLESHIP_UNMOVED  = .BATTLESHIP_0_MOVES,
	Active_Ship.BS_DAMAGED_UNMOVED  = .BS_DAMAGED_0_MOVES,
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
		gc.clear_needed = false
	for &src_sea in gc.seas {
		move_ship_sea(gc, &src_sea, ship) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_ship_sea :: proc(gc: ^Game_Cache, src_sea: ^Sea, ship: Active_Ship) -> (ok: bool) {
	if src_sea.active_ships[ship] == 0 do return true
	reset_valid_moves(gc, src_sea)
	add_valid_ship_moves(gc, src_sea, ship)
	for src_sea.active_ships[ship] > 0 {
		move_next_ship_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

move_next_ship_in_sea :: proc(gc: ^Game_Cache, src_sea: ^Sea, ship: Active_Ship) -> (ok: bool) {
		dst_air_idx := get_move_input(gc, Active_Ship_Names[ship], src_sea) or_return
	flag_for_enemy_combat(gc.territories[dst_air_idx], gc.cur_player.team.enemy_team.index)
		dst_sea := get_sea(gc, dst_air_idx)
	if skip_ship(src_sea, dst_sea, ship) do return true
		move_single_ship(dst_sea, Ships_Moved[ship], gc.cur_player, ship, src_sea)
		if ship == Active_Ship.CARRIER_UNMOVED {
		carry_allied_fighters(gc, src_sea, dst_sea)
		gc.is_fighter_cache_current = false
	}
		return true
}

skip_ship :: proc(src_sea: ^Sea, dst_sea: ^Sea, ship: Active_Ship) -> bool {
	if src_sea != dst_sea do return false
	src_sea.active_ships[Ships_Moved[ship]] += src_sea.active_ships[ship]
	src_sea.active_ships[ship] = 0
	return true
}

add_valid_ship_moves :: proc(gc: ^Game_Cache, src_sea: ^Sea, ship: Active_Ship) {
	// for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	for dst_sea in sa.slice(&src_sea.canal_paths[transmute(u8)gc.canals_open].adjacent_seas) {
		if src_sea.skipped_moves[dst_sea.territory_index] {
			continue
		}
		sa.push(&gc.valid_actions, u8(dst_sea.territory_index))
	}
	// for &dst_sea_2_away in sa.slice(&src_sea.canal_paths[gc.canal_state].seas_2_moves_away) {
	for &dst_sea_2_away in sa.slice(
		&src_sea.canal_paths[transmute(u8)gc.canals_open].seas_2_moves_away,
	) {
		if src_sea.skipped_moves[dst_sea_2_away.sea.territory_index] {
			continue
		}
		for mid_sea in sa.slice(&dst_sea_2_away.mid_seas) {
			if mid_sea.enemy_destroyer_total > 0 do continue
			if ship != Active_Ship.SUB_UNMOVED && mid_sea.sea_path_blocked do continue
			sa.push(&gc.valid_actions, u8(dst_sea_2_away.sea.territory_index))
			break
		}
	}
}

move_single_ship :: proc(
	dst_sea: ^Sea,
	dst_unit: Active_Ship,
	player: ^Player,
	src_unit: Active_Ship,
	src_sea: ^Sea,
) {
	dst_sea.active_ships[dst_unit] += 1
	dst_sea.idle_ships[player.index][Active_Ship_To_Idle[dst_unit]] += 1
	dst_sea.team_units[player.team.index] += 1
	src_sea.active_ships[src_unit] -= 1
	src_sea.idle_ships[player.index][Active_Ship_To_Idle[dst_unit]] -= 1
	src_sea.team_units[player.team.index] -= 1
}
