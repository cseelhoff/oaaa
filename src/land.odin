package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"

SA_Adjacent_L2S :: sa.Small_Array(MAX_LAND_TO_SEA_CONNECTIONS, Sea_ID)

a2lid :: #force_inline proc(air : Air_ID) -> Land_ID {
	assert(int(air) < len(Land_ID))
	return Land_ID(air)
}

Land_Data :: struct {
	name:  string,
	owner: string,
	value: u8,
}

Idle_Armies :: [PLAYERS_COUNT]Idle_Army_For_Player
Active_Armies :: [len(Active_Army)]u8
// Land :: struct {
// 	using territory:    Territory,
// 	idle_armies:        Idle_Armies,
// 	active_armies:      Active_Armies,
// 	lands_2_moves_away: sa.Small_Array(len(Land_ID), Land_2_Moves_Away),
// 	seas_2_moves_away:  sa.Small_Array(len(Sea_ID), L2S_2_Moves_Away),
// 	adjacent_seas:      SA_Adjacent_L2S,
// 	original_owner:     ^Player,
// 	land_distances:     [len(Land_ID)]u8,
// 	// owner:              Player_ID,
// 	land_index:         Land_ID,
// 	value:              u8,
// 	factory_dmg:        u8,
// 	factory_prod:       u8,
// 	max_bombards:       u8,
// 	builds_left:        u8,
// }

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
	{name = "Washington", owner = "USA", value = 10},
	{name = "London", owner = "Eng", value = 8},
	{name = "Berlin", owner = "Ger", value = 10},
	{name = "Moscow", owner = "Rus", value = 8},
	{name = "Tokyo", owner = "Jap", value = 8},
}
LAND_CONNECTIONS := [?][2]string{{"Berlin", "Moscow"}}

get_land_idx_from_string :: proc(land_name: string) -> (land_idx: int, ok: bool) {
	for land, land_idx in LANDS_DATA {
		if strings.compare(land.name, land_name) == 0 {
			return land_idx, true
		}
	}
	fmt.eprintln("Error: Land not found: %s\n", land_name)
	return 0, false
}

initialize_lands_2_moves_away :: proc() {
	// Floyd-Warshall algorithm
	// Initialize distances array to Infinity
	distances: [LANDS_COUNT][LANDS_COUNT]u8
	INFINITY :: 127
	mem.set(&distances, INFINITY, size_of(distances))
	for &land, land_idx in lands {
		// Ensure that the distance from a land to itself is 0
		distances[land_idx][land_idx] = 0
		// Set initial distances based on adjacent lands
		for adjacent_land in sa.slice(&land.adjacent_lands) {
			distances[land_idx][adjacent_land.land_index] = 1
		}
	}
	for mid_idx in 0 ..< LANDS_COUNT {
		for start_idx in 0 ..< LANDS_COUNT {
			for end_idx in 0 ..< LANDS_COUNT {
				new_dist := distances[start_idx][mid_idx] + distances[mid_idx][end_idx]
				if new_dist < distances[start_idx][end_idx] {
					distances[start_idx][end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the lands_2_moves_away array
	for &land, land_idx in lands {
		adjacent_lands := sa.slice(&land.adjacent_lands)
		for distance, dest_land_idx in distances[land_idx] {
			if distance == 2 {
				dest := Land_2_Moves_Away {
					land = &lands[dest_land_idx],
				}
				for dest_adjacent_land in sa.slice(&dest.land.adjacent_lands) {
					_ = slice.linear_search(adjacent_lands, dest_adjacent_land) or_continue
					sa.push(&dest.mid_lands, dest_adjacent_land)
				}
				sa.push(&land.lands_2_moves_away, dest)
			}
		}
	}
}

initialize_canals :: proc() -> (ok: bool) {
	// convert canal_state to a bitmask and loop through CANALS for those
	// enabled for example if canal_state is 0, do not process any items in
	// CANALS, if canal_state is 1, process the first item in CANALS, if
	// canal_state is 2, process the second item in CANALS, if canal_state is
	// 3, process the first and second items in CANALS, etc.
	// for canal_state in 0 ..< CANAL_STATES {
	// 	adjacent_seas := canal[canal_state].adjacent_seas
	// 	sea_distances := canal[canal_state].sea_distances
	// 	for canal, canal_idx in CANALS {
	// 		sea1 := canal.sea1
	// 		sea2 := canal.sea2
	// 		if (canal_state & (1 << uint(canal_idx))) == 0 {
	// 			continue
	// 		}
	// 		append(&seas[sea1], adjacent_seas, sea2)
	// 		seas[sea1], sea_distances[sea2] = 1
	// 		append(&seas[sea2], adjacent_seas, sea1)
	// 		seas[sea2], sea_distances[sea1] = 1
	// 	}
	// }	
	for canal, canal_idx in CANALS {
		land1_idx := get_land_idx_from_string(canal.lands[0]) or_return
		land2_idx := get_land_idx_from_string(canal.lands[1]) or_return
		Canal_Lands[canal_idx] = {&lands[land1_idx], &lands[land2_idx]}
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
	gc.combat_status[l2aid(dst_land)] = .POST_COMBAT
	if gc.factory_prod[dst_land] == 0 {
		return true
	}
	sa.push(&gc.factory_locations[new_owner], dst_land)
	index, found := slice.linear_search(sa.slice(&gc.factory_locations[old_owner]), dst_land)
	assert(found, "factory conquered, but not found in owned factory locations")
	sa.unordered_remove(&gc.factory_locations[old_owner], index)
	return true
}
