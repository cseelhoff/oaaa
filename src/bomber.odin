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

bomber_enemy_checks :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) -> Active_Plane {
	if is_land(dst_air) && a2lid(dst_air) in gc.can_bomber_land_here {
		return .BOMBER_0_MOVES
	}
	gc.land_combat_status[a2lid(dst_air)] = .PRE_COMBAT
	return Bomber_After_Moves[mm.air_distances[src_air][dst_air]]
}
refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
	gc.can_bomber_land_here = gc.friendly_owner & gc.land_no_combat
	gc.can_bomber_land_in_1_moves = {}
	gc.can_bomber_land_in_2_moves = {}
	for dst_land in gc.can_bomber_land_here {
		gc.can_bomber_land_in_1_moves += mm.adj_l2a[dst_land]
		gc.can_bomber_land_in_2_moves += mm.air_l2a_2away[dst_land]
	}
	gc.is_bomber_cache_current = true
}
unmoved_bomber_can_move_here :: #force_inline proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
) -> (
	air_bitset: Air_Bitset,
) {
	air_bitset =
		(~gc.skipped_a2a[l2aid(src_land)] &
			(l2a_bitset(mm.l2l_within_6_air_moves[src_land] & gc.can_bomber_land_here) |
					((gc.air_has_enemies | l2a_bitset(gc.has_bombable_factory)) &
							(mm.l2a_within_3_moves[src_land] |
									(mm.l2a_within_4_air_moves[src_land] &
											gc.can_bomber_land_in_2_moves) |
									(mm.l2a_within_5_air_moves[src_land] &
											gc.can_bomber_land_in_1_moves)))))
	return air_bitset
}

// add_valid_attacking_bomber_moves :: proc(gc: ^Game_Cache, src_land: Land_ID) {
// 	valid_air_moves_bitset :=
// 		~gc.skipped_l2a_moves[src_land] &
// 	 	l2a_bitset(mm.l2l_within_6_air_moves[src_land]) &
// 		(gc.air_has_enemies | l2a_bitset(gc.has_bombable_factory) | l2a_bitset(gc.can_bomber_land_here))
// }

add_valid_landing_bomber_moves :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	valid_air_moves_bitset: Air_Bitset,
) {
	#partial switch plane {
	case .BOMBER_5_MOVES:
		valid_air_moves_bitset = 
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here &
			mm.a2l_within_5_air_moves[src_air],
		)
	case .BOMBER_4_MOVES:
		valid_air_moves_bitset = 
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here &
			mm.a2l_within_4_air_moves[src_air],
		)
	case .BOMBER_3_MOVES:
		valid_air_moves_bitset = 
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here &
			mm.a2l_within_3_air_moves[src_air],
		)
	case .BOMBER_2_MOVES:
		valid_air_moves_bitset = 
			~gc.skipped_a2a[src_air] &
			l2a_bitset(gc.can_bomber_land_here &
			mm.a2l_within_2_air_moves[src_air],
		)
	case .BOMBER_1_MOVES:
		valid_air_moves_bitset = 
			~gc.skipped_a2a[src_air] & l2a_bitset(gc.can_bomber_land_here & mm.adj_a2l[src_air],
		)
	}
	return valid_air_moves_bitset
}

land_bomber_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Bombers {
		land_bomber_airs(gc, plane) or_return
	}
	return true
}

land_bomber_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
	gc.clear_needed = false
	for src_air in Air_ID {
		land_bomber_air(gc, src_air, plane) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

land_bomber_air :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> (ok: bool) {
	if gc.active_planes[src_air][plane] == 0 do return true
	refresh_can_bomber_land_here(gc)
	gc.valid_actions = {}
	add_valid_landing_bomber_moves(gc, src_air, plane)
	for gc.active_planes[src_air][plane] > 0 {
		land_next_bomber_in_air(gc, src_air, plane) or_return
	}
	return true
}

land_next_bomber_in_air :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	dst_air := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
	move_single_plane(gc, dst_air, Plane_After_Moves[plane], gc.cur_player, plane, src_air)
	return true
}
