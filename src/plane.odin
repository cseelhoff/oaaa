package oaaa

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

move_single_plane :: proc(
	gc: ^Game_Cache,
	dst_air: Air_ID,
	dst_unit: Active_Plane,
	player: Player_ID,
	src_unit: Active_Plane,
	src_air: Air_ID,
) {
	if is_land(dst_air) {
		gc.active_land_planes[to_land(dst_air)][dst_unit] += 1
		gc.idle_land_planes[to_land(dst_air)][player][Active_Plane_To_Idle[dst_unit]] += 1
		gc.team_land_units[to_land(dst_air)][mm.team[player]] += 1
	} else {
		dst_sea := to_sea(dst_air)
		gc.active_sea_planes[dst_sea][dst_unit] += 1
		gc.idle_sea_planes[dst_sea][player][Active_Plane_To_Idle[dst_unit]] += 1
		gc.team_sea_units[dst_sea][mm.team[player]] += 1
	}
	if is_land(src_air) {
		gc.active_land_planes[to_land(src_air)][src_unit] -= 1
		gc.idle_land_planes[to_land(src_air)][player][Active_Plane_To_Idle[src_unit]] -= 1
		gc.team_land_units[to_land(src_air)][mm.team[player]] -= 1
	} else {
		src_sea := to_sea(src_air)
		gc.active_sea_planes[src_sea][src_unit] -= 1
		gc.idle_sea_planes[src_sea][player][Active_Plane_To_Idle[src_unit]] -= 1
		gc.team_sea_units[src_sea][mm.team[player]] -= 1
	}
}

refresh_plane_can_land_here :: proc(gc: ^Game_Cache, plane: Active_Plane) {
	if plane == Active_Plane.FIGHTER_UNMOVED {
		refresh_can_fighter_land_here(gc)
	} else {
		refresh_can_bomber_land_here(gc)
	}
}
