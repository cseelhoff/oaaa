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
	Idle_Plane.FIGHTER = 10,
	Idle_Plane.BOMBER  = 12,
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
