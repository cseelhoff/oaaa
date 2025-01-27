package oaaa
import sa "core:container/small_array"

MAX_SEA_TO_LAND_CONNECTIONS :: 6
MAX_SEA_TO_SEA_CONNECTIONS :: 7
Canal_States :: 1 << len(Canal_ID)
SA_Adjacent_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, Sea_ID)
Canal_Paths :: [Canal_States]Sea_Distances
Seas_2_Moves_Away :: sa.Small_Array(len(Sea_ID), Sea_2_Moves_Away)

to_sea :: proc {
	air_to_sea,
	action_to_sea,
}

air_to_sea :: #force_inline proc(air: Air_ID) -> Sea_ID {
	assert(int(air) >= len(Land_ID))
	return Sea_ID(int(air) - len(Land_ID))
}

action_to_sea :: #force_inline proc(action: Action_ID) -> Sea_ID {
	assert(int(action) >= len(Land_ID) && int(action) < len(Air_ID))
	return Sea_ID(int(action) - len(Land_ID))
}

Canal :: struct {
	lands: [2]Land_ID,
	seas:  [2]Sea_ID,
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

// SEAS_DATA := [?]string{"Pacific", "Atlantic", "Baltic"}
SEA_CONNECTIONS :: [?][2]Sea_ID{{.Pacific, .Atlantic}, {.Atlantic, .Baltic}}
CANALS := [?]Canal{{lands = {.Moscow, .Moscow}, seas = {.Pacific, .Baltic}}}

get_sea_id :: #force_inline proc(air: Air_ID) -> Sea_ID {
	assert(int(air) >= len(Land_ID), "Invalid air index")
	return Sea_ID(int(air) - len(Land_ID))
}

initialize_sea_connections :: proc() {
	INFINITY :: 127
	for canal_state in 0 ..< Canal_States {
		// Floyd-Warshall algorithm
		// Initialize distances array to Infinity
		
		for sea in Sea_ID {
			for dst_sea in Sea_ID {
				mm.sea_distances[canal_state][sea][dst_sea] = INFINITY
			}
			// Ensure that the distance from a sea to itself is 0
			mm.sea_distances[canal_state][sea][sea] = 0
		}
		for connection in SEA_CONNECTIONS {
			mm.s2s_1away_via_sea[canal_state][connection[0]] += {connection[1]}
			mm.s2s_1away_via_sea[canal_state][connection[1]] += {connection[0]}
			mm.sea_distances[canal_state][connection[0]][connection[1]] = 1
			mm.sea_distances[canal_state][connection[1]][connection[0]] = 1	
		}
		canals_open:= transmute(Canals_Open)u8(canal_state)
		for canal in canals_open {
			mm.s2s_1away_via_sea[canal_state][CANALS[canal].seas[0]] += {CANALS[canal].seas[1]}
			mm.s2s_1away_via_sea[canal_state][CANALS[canal].seas[1]] += {CANALS[canal].seas[0]}
			mm.sea_distances[canal_state][CANALS[canal].seas[0]][CANALS[canal].seas[1]] = 1
			mm.sea_distances[canal_state][CANALS[canal].seas[1]][CANALS[canal].seas[0]] = 1
		}
		// Floyd-Warshall algorithm
		for mid_idx in Sea_ID {
			for start_idx in Sea_ID {
				for end_idx in Sea_ID {
					new_dist := mm.sea_distances[canal_state][start_idx][mid_idx] + mm.sea_distances[canal_state][mid_idx][end_idx]
					if new_dist < mm.sea_distances[canal_state][start_idx][end_idx] {
						mm.sea_distances[canal_state][start_idx][end_idx] = new_dist
					}
				}
			}
		}
		// Initialize the seas_2_moves_away array
		for src_sea in Sea_ID {
			adjacent_seas := mm.s2s_1away_via_sea[canal_state][src_sea]
			for distance, dst_sea in mm.sea_distances[canal_state][src_sea] {
				if distance == 2 {
					mm.s2s_2away_via_sea[canal_state][src_sea] += {dst_sea}
					for mid_sea in (adjacent_seas & mm.s2s_1away_via_sea[canal_state][dst_sea]) {
						sa.push(&mm.s2s_2away_via_midseas[canal_state][src_sea][dst_sea], mid_sea)
					}
				}
			}
		}
	}
}
