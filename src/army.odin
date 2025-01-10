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

Active_Army_Names := [?]string {
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

Active_Army_To_Idle := [?]Idle_Army {
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

Armies_Moved := [?]Active_Army {
	Active_Army.INF_UNMOVED   = .INF_0_MOVES,
	Active_Army.ARTY_UNMOVED  = .ARTY_0_MOVES,
	Active_Army.TANK_UNMOVED  = .TANK_0_MOVES,
	Active_Army.AAGUN_UNMOVED = .AAGUN_0_MOVES,
}

Unmoved_Armies := [?]Active_Army {
	Active_Army.INF_UNMOVED,
	Active_Army.ARTY_UNMOVED,
	Active_Army.TANK_UNMOVED,
	Active_Army.TANK_1_MOVES,
	//Active_Army.AAGUN_UNMOVED, //Moved in later phase
}

Army_Sizes :: enum {
	SMALL,
	LARGE,
}

Army_Size := [?]Army_Sizes {
	Active_Army.INF_UNMOVED  = .SMALL,
	Active_Army.ARTY_UNMOVED = .LARGE,
	Active_Army.TANK_UNMOVED = .LARGE,
	Active_Army.TANK_1_MOVES = .LARGE,
	//Active_Army.AAGUN_UNMOVED = .LARGE, //AAGUN Transports not implemented
}

move_armies :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for army in Unmoved_Armies {
		move_army_lands(gc, army) or_return
	}
	return true
}

move_army_lands :: proc(gc: ^Game_Cache, army: Active_Army) -> (ok: bool) {
	gc.clear_needed = false
	for &src_land in gc.lands {
		move_army_land(gc, army, &src_land) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_army_land :: proc(gc: ^Game_Cache, army: Active_Army, src_land: ^Land) -> (ok: bool) {
	if src_land.active_armies[army] == 0 do return true
	reset_valid_moves(gc, src_land)
	add_valid_army_moves(gc, src_land, army)
	for src_land.active_armies[army] > 0 {
		move_next_army_in_land(gc, army, src_land) or_return
	}
	return true
}

move_next_army_in_land :: proc(gc: ^Game_Cache, army: Active_Army, src_land: ^Land) -> (ok: bool) {
	dst_air_idx := get_move_input(gc, Active_Army_Names[army], src_land) or_return
	if check_load_transport(gc, army, src_land, dst_air_idx) do return true
	dst_land := &gc.lands[dst_air_idx]
	if skip_army(src_land, dst_land, army) do return true
	army_after_move := blitz_checks(gc, dst_air_idx, dst_land, army, src_land)
	move_single_army(dst_land, army_after_move, gc.cur_player, army, src_land)
	return true
}

blitz_checks :: proc(
	gc: ^Game_Cache,
	dst_air_idx: Air_ID,
	dst_land: ^Land,
	army: Active_Army,
	src_land: ^Land,
) -> Active_Army {
	if !flag_for_enemy_combat(gc.territories[dst_air_idx], gc.cur_player.team.enemy_team.index) &&
	   check_for_conquer(gc, dst_land) &&
	   army == .TANK_UNMOVED &&
	   src_land.land_distances[dst_air_idx] == 1 &&
	   dst_land.factory_prod == 0 {
		return .TANK_1_MOVES //blitz!
	}
	return Armies_Moved[army]
}

move_single_army :: proc(
	dst_land: ^Land,
	dst_unit: Active_Army,
	player: ^Player,
	src_unit: Active_Army,
	src_land: ^Land,
) {
	dst_land.active_armies[dst_unit] += 1
	dst_land.idle_armies[player.index][Active_Army_To_Idle[dst_unit]] += 1
	dst_land.team_units[player.team.index] += 1
	src_land.active_armies[src_unit] -= 1
	src_land.idle_armies[player.index][Active_Army_To_Idle[dst_unit]] -= 1
	src_land.team_units[player.team.index] -= 1
}

is_boat_available :: proc(
	gc: ^Game_Cache,
	src_land: ^Land,
	dst_sea: ^Sea,
	army: Active_Army,
) -> bool {
	idle_ships := &dst_sea.idle_ships[gc.cur_player.index]
	for transport in Idle_Ship_Space[Army_Size[army]] {
		if idle_ships[transport] > 0 {
			return true
		}
	}
	return false
}

add_if_boat_available :: proc(gc: ^Game_Cache, src_land: ^Land, dst_sea: ^Sea, army: Active_Army) {
	if is_boat_available(gc, src_land, dst_sea, army) {
		if !src_land.skipped_moves[dst_sea.territory_index] {
			sa.push(&gc.valid_actions, u8(dst_sea.territory_index))
		}
	}
}

are_midlands_blocked :: proc(mid_lands: ^Mid_Lands, enemy_team_idx: Team_ID) -> bool {
	for mid_land in sa.slice(mid_lands) {
		if mid_land.team_units[enemy_team_idx] == 0 do return false
	}
	return true
}

add_valid_army_moves_1 :: proc(gc: ^Game_Cache, src_land: ^Land, army: Active_Army) {
	for dst_land in sa.slice(&src_land.adjacent_lands) {
		if src_land.skipped_moves[dst_land.territory_index] do continue
		sa.push(&gc.valid_actions, u8(dst_land.territory_index))
	}
	for dst_sea in sa.slice(&src_land.adjacent_seas) {
		add_if_boat_available(gc, src_land, dst_sea, army)
	}
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache, src_land: ^Land, army: Active_Army) {
	enemy_team_idx := gc.cur_player.team.enemy_team.index
	for &dst_land_2_away in sa.slice(&src_land.lands_2_moves_away) {
		if src_land.skipped_moves[dst_land_2_away.land.territory_index] ||
		   are_midlands_blocked(&dst_land_2_away.mid_lands, enemy_team_idx) {
			continue
		}
		sa.push(&gc.valid_actions, u8(dst_land_2_away.land.territory_index))
	}
	// check for moving from land to sea (two moves away)
	for &dst_sea_2_away in sa.slice(&src_land.seas_2_moves_away) {
		if src_land.skipped_moves[dst_sea_2_away.sea.territory_index] ||
		   are_midlands_blocked(&dst_sea_2_away.mid_lands, enemy_team_idx) {
			continue
		}
		add_if_boat_available(gc, src_land, dst_sea_2_away.sea, army)
	}
}

add_valid_army_moves :: proc(gc: ^Game_Cache, src_land: ^Land, army: Active_Army) {
	add_valid_army_moves_1(gc, src_land, army)
	if army != .TANK_UNMOVED do return
	add_valid_army_moves_2(gc, src_land, army)
}

skip_army :: proc(src_land: ^Land, dst_land: ^Land, army: Active_Army) -> (ok: bool) {
	if src_land != dst_land do return false
	src_land.active_armies[Armies_Moved[army]] += src_land.active_armies[army]
	src_land.active_armies[army] = 0
	return true
}

check_load_transport :: proc(
	gc: ^Game_Cache,
	army: Active_Army,
	src_land: ^Land,
	dst_air_idx: Air_ID,
) -> (
	ok: bool,
) {
	if int(dst_air_idx) < LANDS_COUNT do return false
	dst_sea := get_sea(gc, dst_air_idx)
	load_available_transport(army, src_land, dst_sea, gc.cur_player)
	if is_boat_available(gc, src_land, dst_sea, army) do return true
	action_idx, found := slice.linear_search(sa.slice(&gc.valid_actions), u8(dst_air_idx))
	if !found {
		fmt.eprintln("Error: Previous action not found in list")
		return false
	}
	sa.unordered_remove(&gc.valid_actions, action_idx)
	return true
}

load_available_transport :: proc(
	army: Active_Army,
	src_land: ^Land,
	dst_sea: ^Sea,
	player: ^Player,
) {
	active_ship_spaces := Active_Ship_Space[Army_Size[army]]
	for transport in Active_Ship_Space[Army_Size[army]] {
		if dst_sea.active_ships[transport] > 0 {
			load_specific_transport(src_land, dst_sea, transport, army, player)
			return
		}
	}
	fmt.eprintln("Error: No large transport available to load")
}

load_specific_transport :: proc(
	src_land: ^Land,
	dst_sea: ^Sea,
	ship: Active_Ship,
	army: Active_Army,
	player: ^Player,
) {
	idle_army := Active_Army_To_Idle[army]
	new_ship := Transport_Load_Unit[idle_army][ship]
	dst_sea.active_ships[new_ship] += 1
	dst_sea.idle_ships[player.index][Active_Ship_To_Idle[new_ship]] += 1
	src_land.active_armies[army] -= 1
	src_land.idle_armies[player.index][idle_army] -= 1
	src_land.team_units[player.team.index] -= 1
	dst_sea.active_ships[ship] -= 1
	dst_sea.idle_ships[player.index][Active_Ship_To_Idle[ship]] -= 1
}
