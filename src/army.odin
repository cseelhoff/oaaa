package oaaa

import sa "core:container/small_array"
import "core:fmt"

Idle_Army :: enum {
	INF,
	ARTY,
	TANK,
	AAGUN,
}

COST_IDLE_ARMY := [Idle_Army]u8 {
	.INF   = Cost_Buy[.BUY_INF],
	.ARTY  = Cost_Buy[.BUY_ARTY],
	.TANK  = Cost_Buy[.BUY_TANK],
	.AAGUN = Cost_Buy[.BUY_AAGUN],
}

Idle_Army_Names := [Idle_Army]string {
	.INF   = "INF",
	.ARTY  = "ARTY",
	.TANK  = "TANK",
	.AAGUN = "AAGUN",
}

INFANTRY_ATTACK :: 1
ARTILLERY_ATTACK :: 2
TANK_ATTACK :: 3

INFANTRY_DEFENSE :: 2
ARTILLERY_DEFENSE :: 2
TANK_DEFENSE :: 3

Active_Army :: enum {
	INF_UNMOVED,
	INF_0_MOVES,
	ARTY_UNMOVED,
	ARTY_0_MOVES,
	TANK_UNMOVED,
	TANK_1_MOVES,
	TANK_0_MOVES,
	AAGUN_UNMOVED,
	AAGUN_0_MOVES,
}

Active_Army_Names := [Active_Army]string {
	.INF_UNMOVED   = "INF_UNMOVED",
	.INF_0_MOVES   = "INF_0_MOVES",
	.ARTY_UNMOVED  = "ARTY_UNMOVED",
	.ARTY_0_MOVES  = "ARTY_0_MOVES",
	.TANK_UNMOVED  = "TANK_UNMOVED",
	.TANK_1_MOVES  = "TANK_1_MOVES",
	.TANK_0_MOVES  = "TANK_0_MOVES",
	.AAGUN_UNMOVED = "AAGUN_UNMOVED",
	.AAGUN_0_MOVES = "AAGUN_0_MOVES",
}

Active_Army_To_Idle := [Active_Army]Idle_Army {
	.INF_UNMOVED   = .INF,
	.INF_0_MOVES   = .INF,
	.ARTY_UNMOVED  = .ARTY,
	.ARTY_0_MOVES  = .ARTY,
	.TANK_UNMOVED  = .TANK,
	.TANK_1_MOVES  = .TANK,
	.TANK_0_MOVES  = .TANK,
	.AAGUN_UNMOVED = .AAGUN,
	.AAGUN_0_MOVES = .AAGUN,
}

Armies_Moved := [Active_Army]Active_Army {
	.INF_UNMOVED   = .INF_0_MOVES,
	.INF_0_MOVES   = .INF_0_MOVES,
	.ARTY_UNMOVED  = .ARTY_0_MOVES,
	.ARTY_0_MOVES  = .ARTY_0_MOVES,
	.TANK_UNMOVED  = .TANK_0_MOVES,
	.TANK_1_MOVES  = .TANK_0_MOVES,
	.TANK_0_MOVES  = .TANK_0_MOVES,
	.AAGUN_UNMOVED = .AAGUN_0_MOVES,
	.AAGUN_0_MOVES = .AAGUN_0_MOVES,
}

Unmoved_Armies := [?]Active_Army {
	.INF_UNMOVED,
	.ARTY_UNMOVED,
	.TANK_UNMOVED,
	.TANK_1_MOVES,
	//Active_Army.AAGUN_UNMOVED, //Moved in later engine version
}

Army_Sizes :: distinct enum u8 {
	SMALL,
	LARGE,
}

Army_Size := [Active_Army]Army_Sizes {
	.INF_UNMOVED   = .SMALL,
	.INF_0_MOVES   = .SMALL,
	.ARTY_UNMOVED  = .LARGE,
	.ARTY_0_MOVES  = .LARGE,
	.TANK_UNMOVED  = .LARGE,
	.TANK_1_MOVES  = .LARGE,
	.TANK_0_MOVES  = .LARGE,
	.AAGUN_UNMOVED = .LARGE,
	.AAGUN_0_MOVES = .LARGE,
}

move_armies :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for army in Unmoved_Armies {
		gc.clear_history_needed = false
		for src_land in Land_ID {
			if gc.active_armies[src_land][army] == 0 do continue
			gc.valid_actions = {to_action(src_land)}
			add_valid_army_moves_1(gc, src_land, army)
			if army == .TANK_UNMOVED do add_valid_army_moves_2(gc, src_land, army)
			for gc.active_armies[src_land][army] > 0 {
				move_next_army_in_land(gc, army, src_land) or_return
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

move_next_army_in_land :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
) -> (
	ok: bool,
) {
	dst_air := get_move_input(gc, Active_Army_Names[army], to_air(src_land)) or_return
	if check_load_transport(gc, army, src_land, dst_air) do return true
	if skip_army(gc, src_land, to_land(dst_air), army) do return true
	army_after_move := blitz_checks(gc, to_land(dst_air), army, src_land)
	move_single_army_land(gc, to_land(dst_air), army_after_move, gc.cur_player, src_land, army)
	return true
}

blitz_checks :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	army: Active_Army,
	src_land: Land_ID,
) -> Active_Army {
	if !flag_for_land_enemy_combat(gc, dst_land) &&
	   check_for_conquer(gc, dst_land) &&
	   army == .TANK_UNMOVED &&
	   mm.land_distances[src_land][dst_land] == 1 &&
	   gc.factory_prod[dst_land] == 0 {
		return .TANK_1_MOVES //blitz!
	}
	return Armies_Moved[army]
}

move_single_army_land :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	dst_unit: Active_Army,
	player: Player_ID,
	src_land: Land_ID,
	src_unit: Active_Army,
) {
	gc.active_armies[dst_land][dst_unit] += 1
	gc.idle_armies[dst_land][player][Active_Army_To_Idle[dst_unit]] += 1
	gc.team_land_units[dst_land][mm.team[player]] += 1
	gc.active_armies[src_land][src_unit] -= 1
	gc.idle_armies[src_land][player][Active_Army_To_Idle[src_unit]] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
}

is_boat_available :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	army: Active_Army,
) -> bool {
	idle_ships := &gc.idle_ships[dst_sea][gc.cur_player]
	for transport in Idle_Ship_Space[Army_Size[army]] {
		if idle_ships[transport] > 0 {
			return true
		}
	}
	return false
}

add_if_boat_available :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	army: Active_Army,
) {
	if to_air(dst_sea) not_in gc.skipped_a2a[to_air(src_land)] {
		if is_boat_available(gc, src_land, dst_sea, army) {
			gc.valid_actions += {to_action(dst_sea)}
		}
	}
}

are_midlands_blocked :: proc(gc: ^Game_Cache, mid_lands: ^Mid_Lands) -> bool {
	for mid_land in sa.slice(mid_lands) {
		if gc.team_land_units[mid_land][mm.enemy_team[gc.cur_player]] == 0 do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
		if to_air(dst_land) in gc.skipped_a2a[to_air(src_land)] do continue
		gc.valid_actions += {to_action(dst_land)}
	}
	for dst_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		add_if_boat_available(gc, src_land, dst_sea, army)
	}
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	for &dst_land_2_away in sa.slice(&mm.l2l_2away_via_land[src_land]) {
		if to_air(dst_land_2_away.land) in gc.skipped_a2a[to_air(src_land)] ||
		   are_midlands_blocked(gc, &dst_land_2_away.mid_lands) {
			continue
		}
		gc.valid_actions += {to_action(dst_land_2_away.land)}
	}
	// check for moving from land to sea (two moves away)
	for &dst_sea_2_away in sa.slice(&mm.l2s_2away_via_land[src_land]) {
		if to_air(dst_sea_2_away.sea) in gc.skipped_a2a[to_air(src_land)] ||
		   are_midlands_blocked(gc, &dst_sea_2_away.mid_lands) {
			continue
		}
		add_if_boat_available(gc, src_land, dst_sea_2_away.sea, army)
	}
}

skip_army :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_land: Land_ID,
	army: Active_Army,
) -> (
	ok: bool,
) {
	if src_land != dst_land do return false
	gc.active_armies[src_land][Armies_Moved[army]] += gc.active_armies[src_land][army]
	gc.active_armies[src_land][army] = 0
	return true
}

check_load_transport :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
	dst_air: Air_ID,
) -> (
	ok: bool,
) {
	if int(dst_air) < len(Land_ID) do return false
	load_available_transport(gc, army, src_land, get_sea_id(dst_air), gc.cur_player)
	if is_boat_available(gc, src_land, get_sea_id(dst_air), army) do return true
	gc.valid_actions -= {to_action(dst_air)}
	return true
}

load_available_transport :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	player: Player_ID,
) {
	// active_ship_spaces := Active_Ship_Space[Army_Size[army]]
	for transport in Active_Ship_Space[Army_Size[army]] {
		if gc.active_ships[dst_sea][transport] > 0 {
			load_specific_transport(gc, src_land, dst_sea, transport, army, player)
			return
		}
	}
	fmt.eprintln("Error: No large transport available to load")
}

load_specific_transport :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	ship: Active_Ship,
	army: Active_Army,
	player: Player_ID,
) {
	idle_army := Active_Army_To_Idle[army]
	new_ship := Transport_Load_Unit[idle_army][ship]
	gc.active_ships[dst_sea][new_ship] += 1
	gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[new_ship]] += 1
	gc.active_armies[src_land][army] -= 1
	gc.idle_armies[src_land][player][idle_army] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	gc.active_ships[dst_sea][ship] -= 1
	gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[ship]] -= 1
}
