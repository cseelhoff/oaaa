package oaaa

import "core:slice"

Adjacent_L2S :: [dynamic; MAX_LAND_TO_SEA_CONNECTIONS]Sea_ID

Land_Data :: struct {
	land:       Land_ID,
	orig_owner: Nation_ID,
	value:      u8,
}

to_land :: proc {
	region_to_land,
	action_to_land,
}
is_land :: proc {
	region_is_land,
	is_action_land,
}

action_to_land :: #force_inline proc(action: Action_ID) -> Land_ID {
	return Land_ID(int(action) % len(Region_ID))
}

to_land_count :: #force_inline proc(action: Action_ID) -> (Land_ID, u8) {
	return Land_ID(int(action) % len(Region_ID)), 32 >> (uint(action) / len(Region_ID))
}

region_to_land :: #force_inline proc(region: Region_ID) -> Land_ID {
	assert(int(region) < len(Land_ID))
	return Land_ID(region)
}

region_is_land :: #force_inline proc(region: Region_ID) -> bool {
	return int(region) < len(Land_ID)
}

is_action_land :: #force_inline proc(action: Action_ID) -> bool {
	return (int(action) % len(Region_ID)) < len(Land_ID)
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
			mm.land_distance[land][dst_land] = INFINITY
		}
		// Ensure that the distance from a land to itself is 0
		mm.land_distance[land][land] = 0
	}
	for connection in LAND_CONNECTIONS {
		append(&mm.lands_within_1_move[connection[0]],connection[1])
		append(&mm.lands_within_1_move[connection[1]],connection[0])
		mm.lands_within_1_move_bitset[connection[0]] += {connection[1]}
		mm.lands_within_1_move_bitset[connection[1]] += {connection[0]}
		mm.land_distance[connection[0]][connection[1]] = 1
		mm.land_distance[connection[1]][connection[0]] = 1
	}
	for mid_idx in Land_ID {
		for start_idx in Land_ID {
			for end_idx in Land_ID {
				new_dist := mm.land_distance[start_idx][mid_idx] + mm.land_distance[mid_idx][end_idx]
				if new_dist < mm.land_distance[start_idx][end_idx] {
					mm.land_distance[start_idx][end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the l2l_2away_via_land array
	for src_land in Land_ID {
		adjacent_lands := mm.lands_within_1_move[src_land][:]
		for distance, dst_land in mm.land_distance[src_land] {
			if distance == 2 {
				for adjacent_land in mm.lands_within_1_move[dst_land] {
					_ = slice.linear_search(adjacent_lands, adjacent_land) or_continue
					mm.lands_between[src_land][dst_land] += {adjacent_land}
				}
				mm.lands_within_2_moves[src_land] += {dst_land}
			}
		}
	}
}

transfer_land_ownership :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> (ok: bool) {
	old_owner := gc.owner[dst_land]
	if mm.capital[old_owner] == dst_land {
		gc.treasury[gc.acting_nation] += gc.treasury[old_owner]
		gc.treasury[old_owner] = 0
	}
	gc.income[old_owner] -= mm.value[dst_land]
	new_owner := gc.acting_nation
	if mm.team[gc.acting_nation] == mm.team[mm.original_owner[dst_land]] {
		new_owner = mm.original_owner[dst_land]
	}
	gc.owner[dst_land] = new_owner
	gc.income[new_owner] += mm.value[dst_land]
	gc.land_battle_started += {dst_land}
	gc.more_land_battles_needed -= {dst_land}
	if gc.factory_prod[dst_land] == 0 {
		return true
	}
	append(&gc.factory_locations[new_owner], dst_land)
	index, found := slice.linear_search(gc.factory_locations[old_owner][:], dst_land)
	assert(found, "factory conquered, but not found in owned factory locations")
	unordered_remove(&gc.factory_locations[old_owner], index)
	return true
}
