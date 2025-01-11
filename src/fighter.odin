package oaaa
import sa "core:container/small_array"
import "core:mem"
import "core:slice"

Fighter_After_Moves := [?]Active_Plane {
	.FIGHTER_4_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_1_MOVES,
	.FIGHTER_0_MOVES,
}

Unlanded_Fighters := [?]Active_Plane {
	.FIGHTER_1_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_4_MOVES,
}

FIGHTER_MAX_MOVES :: 4

fighter_enemy_checks :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	dst_air: Air_ID,
) -> Active_Plane {
	if flag_for_enemy_combat(dst_air, gc.cur_player.team.enemy_team.index) {
		return Fighter_After_Moves[src_air.air_distances[dst_air.territory_index]]
	}
	return .FIGHTER_0_MOVES
}

fighter_can_land_here :: proc(territory: Air_ID) {
	territory.can_fighter_land_here = true
	for air in sa.slice(&territory.adjacent_airs) {
		air.can_fighter_land_in_1_move = true
	}
}

refresh_can_fighter_land_here :: proc(gc: ^Game_Cache) {
	if gc.is_fighter_cache_current do return
	// initialize all to false
	for territory in gc.territories {
		territory.can_fighter_land_here = false
		territory.can_fighter_land_in_1_move = false
	}
	for &land in gc.lands {
		// is allied owned and not recently conquered?
		if gc.cur_player.team == land.owner.team && land.combat_status == .NO_COMBAT {
			fighter_can_land_here(&land.territory)
		}
		// check for possiblity to build carrier under fighter
		if (land.owner == gc.cur_player && land.factory_prod > 0) {
			for &sea in sa.slice(&land.adjacent_seas) {
				fighter_can_land_here(&sea.territory)
			}
		}
	}
	for &sea in gc.seas {
		if sea.allied_carriers > 0 {
			fighter_can_land_here(&sea.territory)
		}
		// if player owns a carrier, then landing area is 2 spaces away
		if sea.active_ships[Active_Ship.CARRIER_UNMOVED] > 0 {
			// for adj_sea in sa.slice(&sea.canal_paths[gc.canal_state].adjacent_seas) {
			for adj_sea in sa.slice(&sea.canal_paths[transmute(u8)gc.canals_open].adjacent_seas) {
				fighter_can_land_here(adj_sea)
			}
			// for sea_2_moves_away in sa.slice(&sea.canal_paths[gc.canal_state].seas_2_moves_away) {
			for sea_2_moves_away in sa.slice(
				&sea.canal_paths[transmute(u8)gc.canals_open].seas_2_moves_away,
			) {
				fighter_can_land_here(sea_2_moves_away.sea)
			}
		}
	}
	gc.is_fighter_cache_current = true
}

add_valid_fighter_moves :: proc(gc: ^Game_Cache, src_air: Air_ID) {
	for dst_air in sa.slice(&src_air.adjacent_airs) {
		add_meaningful_fighter_move(gc, src_air, dst_air)
	}
	for dst_air in sa.slice(&src_air.airs_2_moves_away) {
		add_meaningful_fighter_move(gc, src_air, dst_air)
	}
	for dst_air in sa.slice(&src_air.airs_3_moves_away) {
		if dst_air.can_fighter_land_in_1_move {
			add_meaningful_fighter_move(gc, src_air, dst_air)
		}
	}
	for dst_air in sa.slice(&src_air.airs_4_moves_away) {
		if dst_air.can_fighter_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
}

add_meaningful_fighter_move :: proc(gc: ^Game_Cache, src_air: Air_ID, dst_air: Air_ID) {
	if dst_air.can_fighter_land_here ||
	   dst_air.team_units[gc.cur_player.team.enemy_team.index] != 0 {
		add_move_if_not_skipped(gc, src_air, dst_air)
	}
}

land_fighter_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for plane in Unlanded_Fighters {
		land_fighter_airs(gc, plane) or_return
	}
	return true
}

land_fighter_airs :: proc(gc: ^Game_Cache, plane: Active_Plane) -> (ok: bool) {
		gc.clear_needed = false
	for &src_air in gc.territories {
		land_fighter_air(gc, src_air, plane) or_return
	}
	if gc.clear_needed do clear_move_history(gc)
	return true
}

land_fighter_air :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) -> (ok: bool) {
	if src_air.active_planes[plane] == 0 do return true
	refresh_can_fighter_land_here(gc)
	gc.valid_actions.len = 0
	add_valid_fighter_landing(gc, src_air, plane)
	for src_air.active_planes[plane] > 0 {
		land_next_fighter_in_air(gc, src_air, plane) or_return
	}
	return true
}

add_valid_fighter_landing :: proc(gc: ^Game_Cache, src_air: Air_ID, plane: Active_Plane) {
	for dst_air in sa.slice(&src_air.adjacent_airs) {
		if dst_air.can_fighter_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .FIGHTER_1_MOVES do return
	for dst_air in sa.slice(&src_air.airs_2_moves_away) {
		if dst_air.can_fighter_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .FIGHTER_2_MOVES do return
	for dst_air in sa.slice(&src_air.airs_3_moves_away) {
		if dst_air.can_fighter_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
	if plane == .FIGHTER_3_MOVES do return
	for dst_air in sa.slice(&src_air.airs_4_moves_away) {
		if dst_air.can_fighter_land_here {
			add_move_if_not_skipped(gc, src_air, dst_air)
		}
	}
}

land_next_fighter_in_air :: proc(
	gc: ^Game_Cache,
	src_air: Air_ID,
	plane: Active_Plane,
) -> (
	ok: bool,
) {
	if crash_unlandable_fighters(gc, src_air, plane) do return true
	dst_air_idx := get_move_input(gc, Active_Plane_Names[plane], src_air) or_return
	dst_air := gc.territories[dst_air_idx]
	move_single_plane(dst_air, Plane_After_Moves[plane], gc.cur_player, plane, src_air)
	if carrier_now_empty(gc, dst_air_idx) {
		valid_move_index := slice.linear_search(
			sa.slice(&gc.valid_actions),
			u8(dst_air_idx),
		) or_return
		sa.unordered_remove(&gc.valid_actions, valid_move_index)
	}
	return true
}
