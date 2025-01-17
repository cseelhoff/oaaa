package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

Idle_Army :: enum {
	INF,
	ARTY,
	TANK,
	AAGUN,
}

COST_IDLE_ARMY := [?]u8 {
	Idle_Army.INF   = Cost_Buy[Buy_Action.BUY_INF],
	Idle_Army.ARTY  = Cost_Buy[Buy_Action.BUY_ARTY],
	Idle_Army.TANK  = Cost_Buy[Buy_Action.BUY_TANK],
	Idle_Army.AAGUN = Cost_Buy[Buy_Action.BUY_AAGUN],
}

Idle_Army_Names := [?]string {
	Idle_Army.INF   = "INF",
	Idle_Army.ARTY  = "ARTY",
	Idle_Army.TANK  = "TANK",
	Idle_Army.AAGUN = "AAGUN",
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
	Active_Army.INF_UNMOVED   = "INF_UNMOVED",
	Active_Army.INF_0_MOVES   = "INF_0_MOVES",
	Active_Army.ARTY_UNMOVED  = "ARTY_UNMOVED",
	Active_Army.ARTY_0_MOVES  = "ARTY_0_MOVES",
	Active_Army.TANK_UNMOVED  = "TANK_UNMOVED",
	Active_Army.TANK_1_MOVES  = "TANK_1_MOVES",
	Active_Army.TANK_0_MOVES  = "TANK_0_MOVES",
	Active_Army.AAGUN_UNMOVED = "AAGUN_UNMOVED",
	Active_Army.AAGUN_0_MOVES = "AAGUN_0_MOVES",
}

Active_Army_To_Idle := [Active_Army]Idle_Army {
	Active_Army.INF_UNMOVED   = .INF,
	Active_Army.INF_0_MOVES   = .INF,
	Active_Army.ARTY_UNMOVED  = .ARTY,
	Active_Army.ARTY_0_MOVES  = .ARTY,
	Active_Army.TANK_UNMOVED  = .TANK,
	Active_Army.TANK_1_MOVES  = .TANK,
	Active_Army.TANK_0_MOVES  = .TANK,
	Active_Army.AAGUN_UNMOVED = .AAGUN,
	Active_Army.AAGUN_0_MOVES = .AAGUN,
}

Armies_Moved := [Active_Army]Active_Army {
	Active_Army.INF_UNMOVED   = .INF_0_MOVES,
	Active_Army.INF_0_MOVES   = .INF_0_MOVES,
	Active_Army.ARTY_UNMOVED  = .ARTY_0_MOVES,
	Active_Army.ARTY_0_MOVES  = .ARTY_0_MOVES,
	Active_Army.TANK_UNMOVED  = .TANK_0_MOVES,
	Active_Army.TANK_1_MOVES  = .TANK_1_MOVES,
	Active_Army.TANK_0_MOVES  = .TANK_0_MOVES,
	Active_Army.AAGUN_UNMOVED = .AAGUN_0_MOVES,
	Active_Army.AAGUN_0_MOVES = .AAGUN_0_MOVES,
}

Unmoved_Armies := [?]Active_Army {
	Active_Army.INF_UNMOVED,
	Active_Army.ARTY_UNMOVED,
	Active_Army.TANK_UNMOVED,
	Active_Army.TANK_1_MOVES,
	//Active_Army.AAGUN_UNMOVED, //Moved in later engine version
}

Army_Sizes :: distinct enum u8 {
	SMALL,
	LARGE,
}

Army_Size := [Active_Army]Army_Sizes {
	Active_Army.INF_UNMOVED   = .SMALL,
	Active_Army.INF_0_MOVES   = .SMALL,
	Active_Army.ARTY_UNMOVED  = .LARGE,
	Active_Army.ARTY_0_MOVES  = .LARGE,
	Active_Army.TANK_UNMOVED  = .LARGE,
	Active_Army.TANK_1_MOVES  = .LARGE,
	Active_Army.TANK_0_MOVES  = .LARGE,
	Active_Army.AAGUN_UNMOVED = .LARGE,
	Active_Army.AAGUN_0_MOVES = .LARGE,
}

move_armies :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for army in Unmoved_Armies {
		move_army_lands(gc, army) or_return
	}
	return true
}

move_army_lands :: proc(gc: ^Game_Cache, army: Active_Army) -> (ok: bool) {
	gc.clear_needed = false
	for src_land in Land_ID {
		move_army_land(gc, army, src_land) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_army_land :: proc(gc: ^Game_Cache, army: Active_Army, src_land: Land_ID) -> (ok: bool) {
	if gc.active_armies[src_land][army] == 0 do return true
	reset_valid_land_moves(gc, src_land)
	add_valid_army_moves(gc, src_land, army)
	for gc.active_armies[src_land][army] > 0 {
		move_next_army_in_land(gc, army, src_land) or_return
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
	dst_air := get_move_input(gc, Active_Army_Names[army], l2aid(src_land)) or_return
	if check_load_transport(gc, army, src_land, dst_air) do return true
	if skip_army(gc, src_land, a2lid(dst_air), army) do return true
	army_after_move := blitz_checks(gc, a2lid(dst_air), army, src_land)
	move_single_army_land(gc, a2lid(dst_air), army_after_move, gc.cur_player, src_land, army)
	return true
}

blitz_checks :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	army: Active_Army,
	src_land: Land_ID,
) -> Active_Army {
	if !flag_for_land_enemy_combat(gc, dst_land, mm.enemy_team[gc.cur_player]) &&
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
	if is_boat_available(gc, src_land, dst_sea, army) {
		if s2aid(dst_sea) not_in gc.skipped_a2a[l2aid(src_land)] {
			push_sea_action(gc, dst_sea)
		}
	}
}

are_midlands_blocked :: proc(gc: ^Game_Cache, mid_lands: ^Mid_Lands, enemy_team: Team_ID) -> bool {
	for mid_land in sa.slice(mid_lands) {
		if gc.team_land_units[mid_land][enemy_team] == 0 do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	for dst_land in sa.slice(&mm.adj_l2l[src_land]) {
		if l2aid(dst_land) in gc.skipped_a2a[l2aid(src_land)] do continue
		push_land_action(gc, dst_land)
	}
	for dst_sea in sa.slice(&mm.adj_l2s[src_land]) {
		add_if_boat_available(gc, src_land, dst_sea, army)
	}
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	enemy_team := mm.enemy_team[gc.cur_player]
	for &dst_land_2_away in sa.slice(&mm.lands_2_moves_away[src_land]) {
		if l2aid(dst_land_2_away.land) in gc.skipped_a2a[l2aid(src_land)] ||
		   are_midlands_blocked(gc, &dst_land_2_away.mid_lands, enemy_team) {
			continue
		}
		push_land_action(gc, dst_land_2_away.land)
	}
	// check for moving from land to sea (two moves away)
	for &dst_sea_2_away in sa.slice(&mm.adj_l2s_2_away[src_land]) {
		if s2aid(dst_sea_2_away.sea) in gc.skipped_a2a[l2aid(src_land)] ||
		   are_midlands_blocked(gc, &dst_sea_2_away.mid_lands, enemy_team) {
			continue
		}
		add_if_boat_available(gc, src_land, dst_sea_2_away.sea, army)
	}
}

add_valid_army_moves :: proc(gc: ^Game_Cache, src_land: Land_ID, army: Active_Army) {
	add_valid_army_moves_1(gc, src_land, army)
	if army != .TANK_UNMOVED do return
	add_valid_army_moves_2(gc, src_land, army)
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
	gc.valid_actions -= {a2act(dst_air)}
	return true
}

load_available_transport :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	player: Player_ID,
) {
	active_ship_spaces := Active_Ship_Space[Army_Size[army]]
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
