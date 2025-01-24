package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"

MAX_SEA_TO_LAND_CONNECTIONS :: 6
MAX_SEA_TO_SEA_CONNECTIONS :: 7
SEAS_COUNT :: len(SEAS_DATA)
// Seas :: [Sea_ID]Sea
Canals_Count :: len(Canal_ID)
//CANALS_COUNT :: 2
Canal_States :: 1 << Canals_Count
SA_Adjacent_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, Sea_ID)
Canal_Paths :: [Canal_States]Sea_Distances
Seas_2_Moves_Away :: sa.Small_Array(SEAS_COUNT, Sea_2_Moves_Away)


air_to_sea :: #force_inline proc(air : Air_ID) -> Sea_ID {
	assert(int(air) >= len(Land_ID))
	return Sea_ID(int(air) - len(Land_ID))
}
action_to_sea :: #force_inline proc(action: Action_ID) -> Sea_ID {
	assert(int(action) >= len(Land_ID) && int(action) < len(Air_ID))
	return Sea_ID(int(action) - len(Land_ID))
}
to_sea :: proc{air_to_sea, action_to_sea}

Canal :: struct {
	lands: [2]string,
	seas:  [2]string,
}

Sea_Distances :: struct {
	sea_distance:      [Sea_ID]u8,
	seas_2_moves_away: Seas_2_Moves_Away,
	adjacent_seas:     SA_Adjacent_S2S,
}

Sea_2_Moves_Away :: struct {
	sea:      Sea_ID,
	mid_seas: sa.Small_Array(MAX_PATHS_TO_SEA, Sea_ID),
}

Sea_ID :: enum {
	Pacific,
	Atlantic,
	Baltic,
}

Canal_ID :: enum {
	Pacific_Baltic,
}

SEAS_DATA := [?]string{"Pacific", "Atlantic", "Baltic"}
SEA_CONNECTIONS :: [?][2]string{{"Pacific", "Atlantic"}, {"Atlantic", "Baltic"}}
CANALS := [?]Canal{{lands = {"Moscow", "Moscow"}, seas = {"Pacific", "Baltic"}}}
Canal_Lands:= [Canals_Count][2]Land_ID{{.Moscow, .Moscow}}
Canal_Seas:= [Canals_Count][2]Sea_ID{{.Pacific, .Pacific}}

get_sea_id :: #force_inline proc(air: Air_ID) -> Sea_ID {
	assert(int(air) >= len(Land_ID), "Invalid air index")
	return Sea_ID(int(air) - len(Land_ID))
}

get_sea_idx_from_string :: proc(sea_name: string) -> (sea_idx: int, ok: bool) {
	for sea_string, sea_idx in SEAS_DATA {
		if strings.compare(sea_string, sea_name) == 0 {
			return sea_idx, true
		}
	}
	fmt.eprintln("Error: Sea not found: %s\n", sea_name)
	return 0, false
}
initialize_sea_connections :: proc() -> (ok: bool) {
	// for sea_name, sea_idx in SEAS_DATA {
	// 	seas[sea_idx].name = sea_name
	// }
	// for connection in SEA_CONNECTIONS {
	// 	sea1_idx := get_sea_idx_from_string(connection[0]) or_return
	// 	sea2_idx := get_sea_idx_from_string(connection[1]) or_return
	// 	for &canal_path, canal_path_idx in seas[sea1_idx].canal_paths {
	// 		sa.append(&canal_path.adjacent_seas, &seas[sea2_idx])
	// 	}
	// 	for &canal_path, canal_path_idx in seas[sea2_idx].canal_paths {
	// 		sa.append(&canal_path.adjacent_seas, &seas[sea1_idx])
	// 	}
	// }
	// // for canal, canal_idx in CANALS {
	// // if canal_idx not_in canals_open do continue
	// // if (canal_path_idx & (1 << uint(canal_idx))) == 0 {
	// // 	continue
	// // }
	// for canal_path_idx in 0 ..< Canal_States {
	// 	canals_open := transmute(Canals_Open)u8(canal_path_idx)
	// 	for canal_idx in canals_open {
	// 		canal := CANALS[canal_idx]
	// 		sea1_idx := get_sea_idx_from_string(canal.seas[0]) or_return
	// 		sea2_idx := get_sea_idx_from_string(canal.seas[1]) or_return
	// 		sa.append(&seas[sea1_idx].canal_paths[canal_path_idx].adjacent_seas, &seas[sea2_idx])
	// 		sa.append(&seas[sea2_idx].canal_paths[canal_path_idx].adjacent_seas, &seas[sea1_idx])
	// 	}
	// }
	return true
}

initialize_seas_2_moves_away :: proc() {
	// for canal_state in 0 ..< Canal_States {
	// 	// Floyd-Warshall algorithm
	// 	// Initialize distances array to Infinity
	// 	distances: [SEAS_COUNT][SEAS_COUNT]u8
	// 	INFINITY :: 127
	// 	mem.set(&distances, INFINITY, size_of(distances))
	// 	for &sea, sea_idx in seas {
	// 		// Ensure that the distance from a sea to itself is 0
	// 		distances[sea_idx][sea_idx] = 0
	// 		// Set initial distances based on adjacent seas
	// 		for adjacent_sea in sa.slice(&sea.canal_paths[canal_state].adjacent_seas) {
	// 			distances[sea_idx][adjacent_sea.sea_index] = 1
	// 		}
	// 	}
	// 	for mid_idx in 0 ..< SEAS_COUNT {
	// 		for start_idx in 0 ..< SEAS_COUNT {
	// 			for end_idx in 0 ..< SEAS_COUNT {
	// 				new_dist := distances[start_idx][mid_idx] + distances[mid_idx][end_idx]
	// 				if new_dist < distances[start_idx][end_idx] {
	// 					distances[start_idx][end_idx] = new_dist
	// 				}
	// 			}
	// 		}
	// 	}
	// 	// Initialize the seas_2_moves_away array
	// 	for &sea, sea_idx in seas {
	// 		src_canal_path := &sea.canal_paths[canal_state]
	// 		adjacent_seas := sa.slice(&src_canal_path.adjacent_seas)
	// 		for distance, dest_sea_idx in distances[sea_idx] {
	// 			src_canal_path.sea_distance[dest_sea_idx] = distance
	// 			dest_sea := &seas[dest_sea_idx]
	// 			if distance == 2 {
	// 				dest := Sea_2_Moves_Away {
	// 					sea = dest_sea,
	// 				}
	// 				dest_adj_seas := sa.slice(&dest_sea.canal_paths[canal_state].adjacent_seas)
	// 				for dest_adj_sea in sa.slice(
	// 					&dest_sea.canal_paths[canal_state].adjacent_seas,
	// 				) {
	// 					_ = slice.linear_search(adjacent_seas, dest_adj_sea) or_continue
	// 					sa.push(&dest.mid_seas, dest_adj_sea)
	// 				}
	// 				sa.push(&sea.canal_paths[canal_state].seas_2_moves_away, dest)
	// 			}
	// 		}
	// 	}
	// }
}
