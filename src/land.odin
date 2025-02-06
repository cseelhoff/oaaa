package oaaa

import sa "core:container/small_array"
import "core:slice"

SA_Adjacent_L2S :: sa.Small_Array(MAX_LAND_TO_SEA_CONNECTIONS, Sea_ID)

Land_Data :: struct {
	land:       Land_ID,
	orig_owner: Player_ID,
	value:      u8,
}

to_land :: proc {
	air_to_land,
	action_to_land,
}
is_land :: proc {
	is_air_land,
	is_action_land,
}

action_to_land :: #force_inline proc(action: Action_ID) -> Land_ID {
	return Land_ID(int(action) % len(Air_ID))
}

to_land_count :: #force_inline proc(action: Action_ID) -> (Land_ID, u8) {
	return Land_ID(int(action) % len(Air_ID)), (64 >> u8(int(action) / len(Air_ID)))
}

air_to_land :: #force_inline proc(air: Air_ID) -> Land_ID {
	assert(int(air) < len(Land_ID))
	return Land_ID(air)
}

is_air_land :: #force_inline proc(air: Air_ID) -> bool {
	return int(air) < len(Land_ID)
}

is_action_land :: #force_inline proc(action: Action_ID) -> bool {
	return (int(action) % len(Air_ID)) < len(Land_ID)
}

Active_Armies :: [Active_Army]u8


L2S_2_Moves_Away :: struct {
	sea:       Sea_ID,
	mid_lands: Mid_Lands,
}

initialize_land_connections :: proc() {
	// Floyd-Warshall algorithm
	// Initialize distances array to Infinity
	INFINITY :: 127
	for land in Land_ID {
		for dst_land in Land_ID {
			mm.land_distances[land][dst_land] = INFINITY
		}
		// Ensure that the distance from a land to itself is 0
		mm.land_distances[land][land] = 0
	}
	for connection in LAND_CONNECTIONS {
		sa.push(&mm.l2l_1away_via_land[connection[0]],connection[1])
		sa.push(&mm.l2l_1away_via_land[connection[1]],connection[0])
		mm.l2l_1away_via_land_bitset[connection[0]] += {connection[1]}
		mm.l2l_1away_via_land_bitset[connection[1]] += {connection[0]}
		mm.land_distances[connection[0]][connection[1]] = 1
		mm.land_distances[connection[1]][connection[0]] = 1
	}
	for mid_idx in Land_ID {
		for start_idx in Land_ID {
			for end_idx in Land_ID {
				new_dist := mm.land_distances[start_idx][mid_idx] + mm.land_distances[mid_idx][end_idx]
				if new_dist < mm.land_distances[start_idx][end_idx] {
					mm.land_distances[start_idx][end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the l2l_2away_via_land array
	for src_land in Land_ID {
		adjacent_lands := sa.slice(&mm.l2l_1away_via_land[src_land])
		for distance, dst_land in mm.land_distances[src_land] {
			if distance == 2 {
				for adjacent_land in sa.slice(&mm.l2l_1away_via_land[dst_land]) {
					_ = slice.linear_search(adjacent_lands, adjacent_land) or_continue
					mm.l2l_2away_via_midland_bitset[src_land][dst_land] += {adjacent_land}
				}
				mm.l2l_2away_via_land_bitset[src_land] += {dst_land}
			}
		}
	}
}

transfer_land_ownership :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> (ok: bool) {
	old_owner := gc.owner[dst_land]
	if mm.capital[old_owner] == dst_land {
		gc.money[gc.cur_player] += gc.money[old_owner]
		gc.money[old_owner] = 0
	}
	gc.income[old_owner] -= mm.value[dst_land]
	new_owner := gc.cur_player
	if mm.team[gc.cur_player] == mm.team[mm.orig_owner[dst_land]] {
		new_owner = mm.orig_owner[dst_land]
	}
	gc.owner[dst_land] = new_owner
	gc.income[new_owner] += mm.value[dst_land]
	gc.land_combat_started += {dst_land}
	gc.more_land_combat_needed -= {dst_land}
	if gc.factory_prod[dst_land] == 0 {
		return true
	}
	sa.push(&gc.factory_locations[new_owner], dst_land)
	index, found := slice.linear_search(sa.slice(&gc.factory_locations[old_owner]), dst_land)
	assert(found, "factory conquered, but not found in owned factory locations")
	sa.unordered_remove(&gc.factory_locations[old_owner], index)
	return true
}
