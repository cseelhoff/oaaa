package oaaa

import "core:fmt"

MAX_PLANE_MOVES :: 6

Idle_Plane :: enum {
	FIGHTER,
	BOMBER,
}

Idle_Plane_Names := [Idle_Plane]string {
	Idle_Plane.FIGHTER = "FIGHTER",
	Idle_Plane.BOMBER  = "BOMBER",
}

COST_IDLE_PLANE := [Idle_Plane]u8 {
	Idle_Plane.FIGHTER = Cost_Buy[.BUY_FIGHTER],
	Idle_Plane.BOMBER  = Cost_Buy[.BUY_BOMBER],
}

FIGHTER_ATTACK :: 3
BOMBER_ATTACK :: 4

FIGHTER_DEFENSE :: 4
BOMBER_DEFENSE :: 1

Active_Plane :: enum {
	FIGHTER_UNMOVED, // distinct from 4_moves, for when ships placed under fighter
	FIGHTER_4_MOVES,
	FIGHTER_3_MOVES,
	FIGHTER_2_MOVES,
	FIGHTER_1_MOVES,
	FIGHTER_0_MOVES,
	BOMBER_UNMOVED,
	BOMBER_5_MOVES,
	BOMBER_4_MOVES,
	BOMBER_3_MOVES,
	BOMBER_2_MOVES,
	BOMBER_1_MOVES,
	BOMBER_0_MOVES,
}

Active_Plane_To_Idle := [Active_Plane]Idle_Plane {
	.FIGHTER_UNMOVED = .FIGHTER,
	.FIGHTER_4_MOVES = .FIGHTER,
	.FIGHTER_3_MOVES = .FIGHTER,
	.FIGHTER_2_MOVES = .FIGHTER,
	.FIGHTER_1_MOVES = .FIGHTER,
	.FIGHTER_0_MOVES = .FIGHTER,
	.BOMBER_UNMOVED  = .BOMBER,
	.BOMBER_5_MOVES  = .BOMBER,
	.BOMBER_4_MOVES  = .BOMBER,
	.BOMBER_3_MOVES  = .BOMBER,
	.BOMBER_2_MOVES  = .BOMBER,
	.BOMBER_1_MOVES  = .BOMBER,
	.BOMBER_0_MOVES  = .BOMBER,
}

Active_Plane_Names := [Active_Plane]string {
	.FIGHTER_UNMOVED = "FIGHTER_UNMOVED",
	.FIGHTER_4_MOVES = "FIGHTER_4_MOVES",
	.FIGHTER_3_MOVES = "FIGHTER_3_MOVES",
	.FIGHTER_2_MOVES = "FIGHTER_2_MOVES",
	.FIGHTER_1_MOVES = "FIGHTER_1_MOVES",
	.FIGHTER_0_MOVES = "FIGHTER_0_MOVES",
	.BOMBER_UNMOVED  = "BOMBER_UNMOVED",
	.BOMBER_5_MOVES  = "BOMBER_5_MOVES",
	.BOMBER_4_MOVES  = "BOMBER_4_MOVES",
	.BOMBER_3_MOVES  = "BOMBER_3_MOVES",
	.BOMBER_2_MOVES  = "BOMBER_2_MOVES",
	.BOMBER_1_MOVES  = "BOMBER_1_MOVES",
	.BOMBER_0_MOVES  = "BOMBER_0_MOVES",
}

Plane_After_Moves := [Active_Plane]Active_Plane {
	.FIGHTER_UNMOVED = .FIGHTER_0_MOVES,
	.FIGHTER_4_MOVES = .FIGHTER_0_MOVES,
	.FIGHTER_3_MOVES = .FIGHTER_0_MOVES,
	.FIGHTER_2_MOVES = .FIGHTER_0_MOVES,
	.FIGHTER_1_MOVES = .FIGHTER_0_MOVES,
	.FIGHTER_0_MOVES = .FIGHTER_0_MOVES,
	.BOMBER_UNMOVED  = .BOMBER_0_MOVES,
	.BOMBER_5_MOVES  = .BOMBER_0_MOVES,
	.BOMBER_4_MOVES  = .BOMBER_0_MOVES,
	.BOMBER_3_MOVES  = .BOMBER_0_MOVES,
	.BOMBER_2_MOVES  = .BOMBER_0_MOVES,
	.BOMBER_1_MOVES  = .BOMBER_0_MOVES,
	.BOMBER_0_MOVES  = .BOMBER_0_MOVES,
}

Unmoved_Planes := [?]Active_Plane{.FIGHTER_UNMOVED, .BOMBER_UNMOVED}

move_unmoved_planes :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unmoved_Planes {
		move_plane_airs(gc, plane) or_return
	}
	return true
}

move_plane_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
	gc.clear_needed = false
	for src_air in Air_ID {
		move_plane_air(gc, src_air, plane) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

move_plane_air :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> (ok: bool) {
	if gc.active_planes[src_air][plane] == 0 do return true
	refresh_plane_can_land_here(gc, plane)
	gc.valid_actions = {a2act(src_air)}
	add_valid_plane_moves(gc, src_air, plane)
	for gc.active_planes[src_air][plane] > 0 {
		move_next_plane_in_air(gc, src_air, plane) or_return
	}
	return true
}

move_next_plane_in_air :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	dst_air := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
	if skip_plane(src_air, act2air(dst_air), plane, gc.cur_player.team.enemy_team.index) do return true
	plane_after_move := plane_enemy_checks(gc, src_air, act2air(dst_air), plane)
	move_single_plane(gc, act2air(dst_air), plane_after_move, gc.cur_player, plane, src_air)
	return true
}

skip_plane :: proc(
	src_air: Air_ID,
	dst_air: Air_ID,
	plane: Active_Plane,
	enemy_idx: Team_ID,
) -> (
	ok: bool,
) {
	if src_air != dst_air || dst_air.team_units[enemy_idx] > 0 do return false
	gc.active_planes[src_air][Plane_After_Moves[plane]] += gc.active_planes[src_air][plane]
	gc.active_planes[src_air][plane] = 0
	return true
}

move_single_plane :: proc(
	gc: ^Game_Cache,
	dst_air: Air_ID,
	dst_unit: Active_Plane,
	player: Player_ID,
	src_unit: Active_Plane,
	src_air: Air_ID,
) {
	gc.active_planes[dst_air][dst_unit] += 1
	gc.idle_planes[dst_air][player][Active_Plane_To_Idle[dst_unit]] += 1
	gc.team_units[dst_air][mm.team[player]] += 1
	gc.active_planes[src_air][src_unit] -= 1
	gc.idle_planes[src_air][player][Active_Plane_To_Idle[src_unit]] -= 1
	gc.team_units[src_air][mm.team[player]] -= 1
}

plane_enemy_checks :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	dst_air: Air_ID,
	plane: Active_Plane,
) -> Active_Plane {
	if plane == Active_Plane.FIGHTER_UNMOVED {
		return fighter_enemy_checks(gc, src_air, dst_air)
	}
}

add_valid_plane_moves :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
	if plane == Active_Plane.FIGHTER_UNMOVED {
		add_valid_fighter_moves(gc, src_air)
	} else {
		add_valid_bomber_moves(gc, src_air)
	}
}

refresh_plane_can_land_here :: proc(gc: ^Game_Cache, plane: Active_Plane) {
	if plane == Active_Plane.FIGHTER_UNMOVED {
		refresh_can_fighter_land_here(gc)
	} else {
		refresh_can_bomber_land_here(gc)
	}
}

crash_unlandable_fighters :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> bool {
	if gc.valid_actions.len > 0 do return false
	planes_count := gc.active_planes[src_air][plane]
	src_air.team_units[gc.cur_player.team.index] -= planes_count
	src_air.idle_planes[gc.cur_player.index][Active_Plane_To_Idle[plane]] -= planes_count
	gc.active_planes[src_air][plane] = 0
	return true
}
