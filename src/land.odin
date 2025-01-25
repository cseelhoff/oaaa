package oaaa

import sa "core:container/small_array"
import "core:mem"
import "core:slice"

SA_Adjacent_L2S :: sa.Small_Array(MAX_LAND_TO_SEA_CONNECTIONS, Sea_ID)

Land_Data :: struct {
	land:  Land_ID,
	owner: Player_ID,
	value: u8,
}

to_land :: proc{air_to_land, action_to_land}
is_land :: proc{is_air_land, is_action_land}

action_to_land :: #force_inline proc(act: Action_ID) -> Land_ID {
	return Land_ID(act)
}

air_to_land :: #force_inline proc(air : Air_ID) -> Land_ID {
	assert(int(air) < len(Land_ID))
	return Land_ID(air)
}

is_air_land :: #force_inline proc(air: Air_ID) -> bool {
	return int(air) < len(Land_ID)
}

is_action_land :: #force_inline proc(action: Action_ID) -> bool {
	return int(action) < len(Land_ID)
}

Active_Armies :: [Active_Army]u8


L2S_2_Moves_Away :: struct {
	sea:       Sea_ID,
	mid_lands: Mid_Lands,
}

Land_ID :: distinct enum u8 {
	Washington,
	London,
	Berlin,
	Moscow,
	Tokyo,
}

//  PACIFIC | USA | ATLANTIC | ENG | BALTIC | GER | RUS | JAP | PAC
LANDS_DATA := [?]Land_Data {
	{land = .Washington, owner = .USA, value = 10},
	{land = .London, owner = .Eng, value = 8},
	{land = .Berlin, owner = .Ger, value = 10},
	{land = .Moscow, owner = .Rus, value = 8},
	{land = .Tokyo, owner = .Jap, value = 8},
}
LAND_CONNECTIONS := [?][2]Land_ID{{.Berlin, .Moscow}}

// get_land_idx_from_string :: proc(land_name: string) -> (land_idx: int, ok: bool) {
// 	for land, land_idx in LANDS_DATA {
// 		if strings.compare(land.name, land_name) == 0 {
// 			return land_idx, true
// 		}
// 	}
// 	fmt.eprintln("Error: Land not found: %s\n", land_name)
// 	return 0, false
// }

initialize_l2l_2away_via_land :: proc() {
	// Floyd-Warshall algorithm
	// Initialize distances array to Infinity
	distances: [len(Land_ID)][len(Land_ID)]u8
	INFINITY :: 127
	mem.set(&distances, INFINITY, size_of(distances))
	for land in Land_ID {
		// Ensure that the distance from a land to itself is 0
		distances[land][land] = 0
		// Set initial distances based on adjacent lands
		for adjacent_land in sa.slice(&mm.l2l_1away_via_land[land]) {
			distances[land][adjacent_land] = 1
		}
	}
	for mid_idx in Land_ID {
		for start_idx in Land_ID {
			for end_idx in Land_ID {
				new_dist := distances[start_idx][mid_idx] + distances[mid_idx][end_idx]
				if new_dist < distances[start_idx][end_idx] {
					distances[start_idx][end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the l2l_2away_via_land array
	// for land in Land_ID {
	// 	adjacent_lands := sa.slice(&mm.l2l_1away_via_land[land])
	// 	for distance, dest_land_idx in distances[land] {
	// 		if distance == 2 {
	// 			dest := Land_2_Moves_Away {
	// 				land = &lands[dest_land_idx],
	// 			}
	// 			for dest_adjacent_land in sa.slice(&dest.land.adjacent_lands) {
	// 				_ = slice.linear_search(adjacent_lands, dest_adjacent_land) or_continue
	// 				sa.push(&dest.mid_lands, dest_adjacent_land)
	// 			}
	// 			sa.push(&land.l2l_2away_via_land, dest)
	// 		}
	// 	}
	// }
}

initialize_canals :: proc() -> (ok: bool) {
	for canal_state in 0 ..< Canal_States {
		canals_open :Canals_Open = transmute(Canals_Open)u8(canal_state)
		for canal in canals_open {
			mm.s2s_1away_via_sea[canal_state][Canal_Seas[canal][0]] += {Canal_Seas[canal][1]}
			mm.s2s_1away_via_sea[canal_state][Canal_Seas[canal][1]] += {Canal_Seas[canal][0]}
		}
	}
	return true
}

conquer_land :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> (ok: bool) {
	old_owner := gc.owner[dst_land]
	if mm.capital[old_owner] == dst_land {
		gc.money[gc.cur_player] += gc.money[old_owner]
		gc.money[old_owner] = 0
	}
	gc.income[old_owner] -= mm.value[dst_land]
	new_owner := gc.cur_player
	if mm.team[gc.cur_player] == mm.team[mm.orig_owner[dst_land]] {
		new_owner = mm.original_owner[dst_land]
	}
	gc.owner[dst_land] = new_owner
	gc.income[new_owner] += mm.value[dst_land]
	gc.land_combat_status[dst_land] = .POST_COMBAT
	if gc.factory_prod[dst_land] == 0 {
		return true
	}
	sa.push(&gc.factory_locations[new_owner], dst_land)
	index, found := slice.linear_search(sa.slice(&gc.factory_locations[old_owner]), dst_land)
	assert(found, "factory conquered, but not found in owned factory locations")
	sa.unordered_remove(&gc.factory_locations[old_owner], index)
	return true
}
