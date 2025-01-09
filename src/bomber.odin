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

bomber_enemy_checks :: proc(
	gc: ^Game_Cache,
	src_air: ^Territory,
	dst_air: ^Territory,
) -> Active_Plane {
	if !dst_air.can_bomber_land_here {
		dst_air.combat_status = .PRE_COMBAT
		return Bomber_After_Moves[src_air.air_distances[dst_air.territory_index]]
	}
	return .BOMBER_0_MOVES
}

bomber_can_land_here :: proc(territory: ^Territory) {
	territory.can_bomber_land_here = true
	for air in sa.slice(&territory.adjacent_airs) {
		air.can_bomber_land_in_1_move = true
	}
	for air in sa.slice(&territory.airs_2_moves_away) {
		air.can_bomber_land_in_2_moves = true
	}
}

refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
	// initialize all to false
	if gc.is_bomber_cache_current do return
	for territory in gc.territories {
		territory.can_bomber_land_here = false
		territory.can_bomber_land_in_1_move = false
		territory.can_bomber_land_in_2_moves = false
	}
	// check if any bombers have full moves remaining
	for &land in gc.lands {
		// is allied owned and not recently conquered?
		//Since bombers happen first, we can assume that the land is not recently conquered
		if gc.cur_player.team == land.owner.team { 	//&& land.combat_status == .NO_COMBAT {
			bomber_can_land_here(&land)
		}
	}
	gc.is_bomber_cache_current = true
}
add_valid_bomber_moves :: proc(gc: ^Game_Cache, src_air: ^Territory) {
	for dst_air in sa.slice(&src_air.adjacent_airs) {
		add_meaningful_bomber_move(gc, src_air, dst_air)
	}
	for dst_air in sa.slice(&src_air.airs_2_moves_away) {
		add_meaningful_bomber_move(gc, src_air, dst_air)
	}
	for dst_air in sa.slice(&src_air.airs_3_moves_away) {
		add_meaningful_bomber_move(gc, src_air, dst_air)
	}
	for dst_air in sa.slice(&src_air.airs_4_moves_away) {
		if dst_air.can_bomber_land_in_2_moves {
			add_meaningful_bomber_move(gc, src_air, dst_air)
		}
	}
	for dst_air in sa.slice(&src_air.airs_5_moves_away) {
		if dst_air.can_bomber_land_in_1_move {
			add_meaningful_bomber_move(gc, src_air, dst_air)
		}
	}
	for dst_air in sa.slice(&src_air.airs_6_moves_away) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
}

add_meaningful_bomber_move :: proc(gc: ^Game_Cache, src_air: ^Territory, dst_air: ^Territory) {
	terr_idx := dst_air.territory_index
	if dst_air.can_bomber_land_here ||
	   dst_air.team_units[gc.cur_player.team.enemy_team.index] != 0 ||
	   is_land(dst_air) && gc.lands[terr_idx].factory_dmg < gc.lands[terr_idx].factory_prod * 2 {
		add_move_if_not_skipped(gc, src_air, dst_air)
	}
}

land_bomber_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Bombers {
		land_bomber_airs(gc, plane) or_return
	}
	return true
}

land_bomber_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
	gc.clear_needed = false
	for &src_air in gc.territories {
		land_bomber_air(gc, src_air, plane) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

land_bomber_air :: proc(gc: ^Game_Cache, src_air: ^Territory, plane: Active_Plane) -> (ok: bool) {
	if src_air.active_planes[plane] == 0 do return true
	refresh_can_bomber_land_here(gc)
	gc.valid_actions.len = 0
	add_valid_bomber_landing(gc, src_air, plane)
	for src_air.active_planes[plane] > 0 {
		land_next_bomber_in_air(gc, src_air, plane) or_return
	}
	return true
}

import "core:fmt"

add_valid_bomber_landing :: proc(gc: ^Game_Cache, src_air: ^Territory, plane: Active_Plane) {
	for dst_air in sa.slice(&src_air.adjacent_airs) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .BOMBER_1_MOVES do return
	for dst_air in sa.slice(&src_air.airs_2_moves_away) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .BOMBER_2_MOVES do return
	for dst_air in sa.slice(&src_air.airs_3_moves_away) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .BOMBER_3_MOVES do return
	for dst_air in sa.slice(&src_air.airs_4_moves_away) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .BOMBER_4_MOVES do return
	for dst_air in sa.slice(&src_air.airs_5_moves_away) {
		if dst_air.can_bomber_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
}

land_next_bomber_in_air :: proc(
	gc: ^Game_Cache,
	src_air: ^Territory,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	dst_air_idx := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
	dst_air := gc.territories[dst_air_idx]
	move_single_plane(dst_air, Plane_After_Moves[plane], gc.cur_player, plane, src_air)
	return true
}
