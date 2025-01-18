package oaaa
import sa "core:container/small_array"
import "core:mem"
import "core:slice"

Bomber_After_Moves := [?]Active_Plane {
	.BOMBER_0_MOVES,
	.BOMBER_5_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_1_MOVES,
	.BOMBER_0_MOVES,
}

Unlanded_Bombers := [?]Active_Plane {
	.BOMBER_5_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_1_MOVES,
}

BOMBER_MAX_MOVES :: 6

move_unmoved_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
	gc.clear_needed = false
	for src_land in Land_ID {
		if gc.active_land_planes[src_land][.BOMBER_UNMOVED] == 0 do return true
		if ~gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		gc.valid_actions = {l2act(src_land)}
		add_valid_unmoved_bomber_moves(gc, src_land)
		for gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
			dst_air := get_move_input(gc, "BOMBER_UNMOVED", l2aid(src_land)) or_return
			if is_land(dst_air) {
				move_unmoved_bomber_to_land(gc, src_land, a2lid(dst_air))
			} else {
				move_unmoved_bomber_to_sea(gc, src_land, a2sid(dst_air))
			}
		}
	}
	return true
}

add_valid_unmoved_bomber_moves :: #force_inline proc(gc: ^Game_Cache, src_land: Land_ID) {
	gc.valid_actions += air2action_bitset(
		(~gc.skipped_a2a[l2aid(src_land)] &
			(mm.a2a_within_6_moves[l2aid(src_land)] & l2a_bitset(gc.can_bomber_land_here) |
					((gc.air_has_enemies | l2a_bitset(gc.has_bombable_factory)) &
							(mm.a2a_within_3_moves[l2aid(src_land)] |
									(mm.a2a_within_4_moves[l2aid(src_land)] &
											gc.can_bomber_land_in_2_moves) |
									(mm.a2a_within_5_moves[l2aid(src_land)] &
											gc.can_bomber_land_in_1_moves))))),
	)
}

move_unmoved_bomber_to_land :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) {
	if skip_bomber(gc, src_land, dst_land) do return
	if dst_land in gc.can_bomber_land_here {
		gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
	} else {
		gc.land_combat_status[dst_land] = .PRE_COMBAT
		gc.active_land_planes[dst_land][Bomber_After_Moves[mm.air_distances[l2aid(src_land)][l2aid(dst_land)]]] +=
		1
	}
	gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][.BOMBER_UNMOVED] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

skip_bomber :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) -> (ok: bool) {
	if src_land != dst_land do return false
	gc.active_land_planes[src_land][.BOMBER_0_MOVES] +=
		gc.active_land_planes[src_land][.BOMBER_UNMOVED]
	gc.active_land_planes[src_land][.BOMBER_UNMOVED] = 0
	return true
}

move_unmoved_bomber_to_sea :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	gc.sea_combat_status[dst_sea] = .PRE_COMBAT
	gc.idle_sea_planes[dst_sea][gc.cur_player][.BOMBER] += 1
	gc.team_sea_units[dst_sea][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][.BOMBER_UNMOVED] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
}

refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
	gc.can_bomber_land_here = gc.friendly_owner & gc.land_no_combat
	gc.can_bomber_land_in_1_moves = {}
	gc.can_bomber_land_in_2_moves = {}
	for dst_land in gc.can_bomber_land_here {
		gc.can_bomber_land_in_1_moves += mm.a2a_within_1_moves[l2aid(dst_land)]
		gc.can_bomber_land_in_2_moves += mm.a2a_within_2_moves[l2aid(dst_land)]
	}
	gc.is_bomber_cache_current = true
}
// add_valid_attacking_bomber_moves :: proc(gc: ^Game_Cache, src_land: Land_ID) {
// 	valid_air_moves_bitset :=
// 		~gc.skipped_l2a_moves[src_land] &
// 	 	l2a_bitset(mm.a2a_within_6_moves[src_land]) &
// 		(gc.air_has_enemies | l2a_bitset(gc.has_bombable_factory) | l2a_bitset(gc.can_bomber_land_here))
// }

land_remaining_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Bombers {
		gc.clear_needed = false
		for src_land in Land_ID {
			land_bomber_from_land(gc, src_land, plane) or_return
		}
		for src_sea in Sea_ID {
			land_bomber_from_sea(gc, src_sea, plane) or_return
		}
		if gc.clear_needed do clear_move_history(gc)
	}
	return true
}

land_bomber_from_land :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	if gc.active_land_planes[src_land][plane] == 0 do return true
	if ~gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_bomber_moves(gc, l2aid(src_land), plane)
	for gc.active_land_planes[src_land][plane] > 0 {
		dst_air := get_move_input(gc, Active_Plane_Names[plane], l2aid(src_land)) or_return
		move_bomber_from_land_to_land(gc, a2lid(dst_air), plane, src_land)
	}
	return true
}

move_bomber_from_land_to_land :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	plane: Active_Plane,
	src_land: Land_ID,
) {
	gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
	gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_land_planes[src_land][plane] -= 1
	gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
	gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
	return
}

land_bomber_from_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, plane: Active_Plane) -> (ok: bool) {
	if gc.active_sea_planes[src_sea][plane] == 0 do return true
	if ~gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_bomber_moves(gc, s2aid(src_sea), plane)
	for gc.active_sea_planes[src_sea][plane] > 0 {
		dst_air := get_move_input(gc, Active_Plane_Names[plane], s2aid(src_sea)) or_return
		move_bomber_from_sea_to_land(gc, a2lid(dst_air), plane, src_sea)
	}
	return true
}

move_bomber_from_sea_to_land :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	plane: Active_Plane,
	src_sea: Sea_ID,
) {
	gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
	gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.active_sea_planes[src_sea][plane] -= 1
	gc.idle_sea_planes[src_sea][gc.cur_player][.BOMBER] -= 1
	gc.team_sea_units[src_sea][mm.team[gc.cur_player]] -= 1
	return
}

add_valid_landing_bomber_moves :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	valid_air_moves_bitset: Air_Bitset,
) {
	#partial switch plane {
	case .BOMBER_1_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here) &
			mm.a2a_within_1_moves[src_air],
		)
	case .BOMBER_2_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here) &
			mm.a2a_within_2_moves[src_air],
		)
	case .BOMBER_3_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here) &
			mm.a2a_within_3_moves[src_air],
		)
	case .BOMBER_4_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here) &
			mm.a2a_within_4_moves[src_air],
		)
	case .BOMBER_5_MOVES:
		gc.valid_actions = air2action_bitset(
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here) &
			mm.a2a_within_5_moves[src_air],
		)
	}
	return valid_air_moves_bitset
}
