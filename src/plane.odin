package oaaa

MAX_PLANE_MOVES :: 6

Roster_Plane :: enum {
	Fighter,
	Bomber,
}

roster_plane_names := [Roster_Plane]string {
	Roster_Plane.Fighter = "Fighter",
	Roster_Plane.Bomber  = "Bomber",
}

COST_ROSTER_PLANE := [Roster_Plane]u8 {
	Roster_Plane.Fighter = 10,
	Roster_Plane.Bomber  = 12,
}

FIGHTER_ATTACK_VALUE :: 3
BOMBER_ATTACK_VALUE :: 4

FIGHTER_DEFENSE_VALUE :: 4
BOMBER_DEFENSE_VALUE :: 1

Active_Plane :: enum {
	Fighter_Unmoved, // distinct from 4_moves, for when ships placed under fighter
	Fighter_4_Moves,
	Fighter_3_Moves,
	Fighter_2_Moves,
	Fighter_1_Moves,
	Fighter_0_Moves,
	Bomber_Unmoved,
	Bomber_5_Moves,
	Bomber_4_Moves,
	Bomber_3_Moves,
	Bomber_2_Moves,
	Bomber_1_Moves,
	Bomber_0_Moves,
}

active_plane_to_roster := [Active_Plane]Roster_Plane {
	.Fighter_Unmoved = .Fighter,
	.Fighter_4_Moves = .Fighter,
	.Fighter_3_Moves = .Fighter,
	.Fighter_2_Moves = .Fighter,
	.Fighter_1_Moves = .Fighter,
	.Fighter_0_Moves = .Fighter,
	.Bomber_Unmoved  = .Bomber,
	.Bomber_5_Moves  = .Bomber,
	.Bomber_4_Moves  = .Bomber,
	.Bomber_3_Moves  = .Bomber,
	.Bomber_2_Moves  = .Bomber,
	.Bomber_1_Moves  = .Bomber,
	.Bomber_0_Moves  = .Bomber,
}

active_plane_names := [Active_Plane]string {
	.Fighter_Unmoved = "Fighter_Unmoved",
	.Fighter_4_Moves = "Fighter_4_Moves",
	.Fighter_3_Moves = "Fighter_3_Moves",
	.Fighter_2_Moves = "Fighter_2_Moves",
	.Fighter_1_Moves = "Fighter_1_Moves",
	.Fighter_0_Moves = "Fighter_0_Moves",
	.Bomber_Unmoved  = "Bomber_Unmoved",
	.Bomber_5_Moves  = "Bomber_5_Moves",
	.Bomber_4_Moves  = "Bomber_4_Moves",
	.Bomber_3_Moves  = "Bomber_3_Moves",
	.Bomber_2_Moves  = "Bomber_2_Moves",
	.Bomber_1_Moves  = "Bomber_1_Moves",
	.Bomber_0_Moves  = "Bomber_0_Moves",
}

plane_after_moves := [Active_Plane]Active_Plane {
	.Fighter_Unmoved = .Fighter_0_Moves,
	.Fighter_4_Moves = .Fighter_0_Moves,
	.Fighter_3_Moves = .Fighter_0_Moves,
	.Fighter_2_Moves = .Fighter_0_Moves,
	.Fighter_1_Moves = .Fighter_0_Moves,
	.Fighter_0_Moves = .Fighter_0_Moves,
	.Bomber_Unmoved  = .Bomber_0_Moves,
	.Bomber_5_Moves  = .Bomber_0_Moves,
	.Bomber_4_Moves  = .Bomber_0_Moves,
	.Bomber_3_Moves  = .Bomber_0_Moves,
	.Bomber_2_Moves  = .Bomber_0_Moves,
	.Bomber_1_Moves  = .Bomber_0_Moves,
	.Bomber_0_Moves  = .Bomber_0_Moves,
}

unmoved_planes := [?]Active_Plane{.Fighter_Unmoved, .Bomber_Unmoved}
