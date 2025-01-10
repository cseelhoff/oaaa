package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"

MAX_SEA_TO_LAND_CONNECTIONS :: 6
MAX_SEA_TO_SEA_CONNECTIONS :: 7
SEAS_COUNT :: len(SEAS_DATA)
Seas :: [SEAS_COUNT]Sea
CANALS_COUNT :: len(CANALS)
//CANALS_COUNT :: 2
CANAL_STATES :: 1 << CANALS_COUNT
MAX_PATHS_TO_SEA :: 2
SA_Adjacent_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, ^Sea)
Canal_Paths :: [CANAL_STATES]Sea_Distances
Seas_2_Moves_Away :: sa.Small_Array(SEAS_COUNT, Sea_2_Moves_Away)

Sea :: struct {
	using territory:        Territory,
	idle_ships:             [PLAYERS_COUNT]Idle_Sea_For_Player,
	active_ships:           [len(Active_Ship)]u8,
	canal_paths:            Canal_Paths,
	sea_index:              Sea_ID,
	enemy_destroyer_total:  u8,
	enemy_submarines_total: u8,
	enemy_blockade_total:   u8,
	allied_carriers:        u8,
	enemy_fighters_total:   u8,
	sea_path_blocked:       bool,
	sub_path_blocked:       bool,
}

Canal :: struct {
	lands: [2]string,
	seas:  [2]string,
}

Sea_Distances :: struct {
	sea_distance:      [SEAS_COUNT]u8,
	seas_2_moves_away: Seas_2_Moves_Away,
	adjacent_seas:     SA_Adjacent_S2S,
}

Sea_2_Moves_Away :: struct {
	sea:      ^Sea,
	mid_seas: sa.Small_Array(MAX_PATHS_TO_SEA, ^Sea),
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
Canal_Lands: [CANALS_COUNT][2]^Land

get_sea_id :: proc(air_idx: Air_ID) -> Sea_ID {
	assert(int(air_idx) >= LANDS_COUNT, "Invalid air index")
	return Sea_ID(int(air_idx) - LANDS_COUNT)
}

get_sea :: proc(gc: ^Game_Cache, air_idx: Air_ID) -> ^Sea {
	assert(int(air_idx) >= LANDS_COUNT, "Invalid air index")
	return &gc.seas[int(air_idx) - LANDS_COUNT]
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
initialize_sea_connections :: proc(seas: ^Seas) -> (ok: bool) {
	for sea_name, sea_idx in SEAS_DATA {
		seas[sea_idx].name = sea_name
	}
	for connection in SEA_CONNECTIONS {
		sea1_idx := get_sea_idx_from_string(connection[0]) or_return
		sea2_idx := get_sea_idx_from_string(connection[1]) or_return
		for &canal_path, canal_path_idx in seas[sea1_idx].canal_paths {
			sa.append(&canal_path.adjacent_seas, &seas[sea2_idx])
		}
		for &canal_path, canal_path_idx in seas[sea2_idx].canal_paths {
			sa.append(&canal_path.adjacent_seas, &seas[sea1_idx])
		}
	}
	// for canal, canal_idx in CANALS {
	// if canal_idx not_in canals_open do continue
	// if (canal_path_idx & (1 << uint(canal_idx))) == 0 {
	// 	continue
	// }
	for canal_path_idx in 0 ..< CANAL_STATES {
		canals_open := transmute(CANALS_OPEN)u8(canal_path_idx)
		for canal_idx in canals_open {
			canal := CANALS[canal_idx]
			sea1_idx := get_sea_idx_from_string(canal.seas[0]) or_return
			sea2_idx := get_sea_idx_from_string(canal.seas[1]) or_return
			sa.append(&seas[sea1_idx].canal_paths[canal_path_idx].adjacent_seas, &seas[sea2_idx])
			sa.append(&seas[sea2_idx].canal_paths[canal_path_idx].adjacent_seas, &seas[sea1_idx])
		}
	}
	return true
}

initialize_seas_2_moves_away :: proc(seas: ^Seas) {
	for canal_state in 0 ..< CANAL_STATES {
		// Floyd-Warshall algorithm
		// Initialize distances array to Infinity
		distances: [SEAS_COUNT][SEAS_COUNT]u8
		INFINITY :: 127
		mem.set(&distances, INFINITY, size_of(distances))
		for &sea, sea_idx in seas {
			// Ensure that the distance from a sea to itself is 0
			distances[sea_idx][sea_idx] = 0
			// Set initial distances based on adjacent seas
			for adjacent_sea in sa.slice(&sea.canal_paths[canal_state].adjacent_seas) {
				distances[sea_idx][adjacent_sea.sea_index] = 1
			}
		}
		for mid_idx in 0 ..< SEAS_COUNT {
			for start_idx in 0 ..< SEAS_COUNT {
				for end_idx in 0 ..< SEAS_COUNT {
					new_dist := distances[start_idx][mid_idx] + distances[mid_idx][end_idx]
					if new_dist < distances[start_idx][end_idx] {
						distances[start_idx][end_idx] = new_dist
					}
				}
			}
		}
		// Initialize the seas_2_moves_away array
		for &sea, sea_idx in seas {
			src_canal_path := &sea.canal_paths[canal_state]
			adjacent_seas := sa.slice(&src_canal_path.adjacent_seas)
			for distance, dest_sea_idx in distances[sea_idx] {
				src_canal_path.sea_distance[dest_sea_idx] = distance
				dest_sea := &seas[dest_sea_idx]
				if distance == 2 {
					dest := Sea_2_Moves_Away {
						sea = dest_sea,
					}
					dest_adj_seas := sa.slice(&dest_sea.canal_paths[canal_state].adjacent_seas)
					for dest_adj_sea in sa.slice(
						&dest_sea.canal_paths[canal_state].adjacent_seas,
					) {
						_ = slice.linear_search(adjacent_seas, dest_adj_sea) or_continue
						sa.push(&dest.mid_seas, dest_adj_sea)
					}
					sa.push(&sea.canal_paths[canal_state].seas_2_moves_away, dest)
				}
			}
		}
	}
}
