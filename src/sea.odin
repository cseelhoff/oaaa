package oaaa

MAX_SEA_TO_LAND_CONNECTIONS :: 6
MAX_SEA_TO_SEA_CONNECTIONS :: 7
Canal_States :: 1 << len(Canal_ID)
Adjacent_S2S :: [dynamic; MAX_SEA_TO_SEA_CONNECTIONS]Sea_ID
Canal_Paths :: [Canal_States]Sea_Distances
Seas_2_Moves_Away :: [dynamic; len(Sea_ID)]Sea_2_Moves_Away

to_sea :: proc {
	region_to_sea,
	action_to_sea,
}

region_to_sea :: #force_inline proc(region: Region_ID) -> Sea_ID {
	assert(int(region) >= len(Land_ID))
	return Sea_ID(int(region) - len(Land_ID))
}

action_to_sea :: #force_inline proc(action: Action_ID) -> Sea_ID {
	mod_sea := int(action) % len(Region_ID)
	assert(int(mod_sea) >= len(Land_ID))
	return Sea_ID(int(mod_sea) - len(Land_ID))
}

to_sea_count :: #force_inline proc(action: Action_ID) -> (Sea_ID, u8) {
	mod_sea := int(action) % len(Region_ID)
	assert(int(mod_sea) >= len(Land_ID))
	return Sea_ID(int(mod_sea) - len(Land_ID)), 32 >> (uint(action) / len(Region_ID))
}

Canal :: struct {
	lands: [2]Land_ID,
	seas:  [2]Sea_ID,
}

Sea_Distances :: struct {
	sea_distance:      [Sea_ID]u8,
	seas_2_moves_away: Seas_2_Moves_Away,
	adjacent_seas:     Adjacent_S2S,
}

Sea_2_Moves_Away :: struct {
	sea:      Sea_ID,
	mid_seas: [dynamic; MAX_PATHS_TO_SEA]Sea_ID,
}

Coastal_Connection :: struct {
	land: Land_ID,
	sea:  Sea_ID,
}

initialize_sea_connections :: proc() {
	INFINITY :: 127
	for canal_state in 0 ..< Canal_States {
		// Floyd-Warshall algorithm
		// Initialize distances array to Infinity
		
		for sea in Sea_ID {
			for dst_sea in Sea_ID {
				mm.sea_distance[canal_state][sea][dst_sea] = INFINITY
			}
			// Ensure that the distance from a sea to itself is 0
			mm.sea_distance[canal_state][sea][sea] = 0
		}
		for connection in SEA_CONNECTIONS {
			mm.seas_within_1_move[canal_state][connection[0]] += {connection[1]}
			mm.seas_within_1_move[canal_state][connection[1]] += {connection[0]}
			mm.sea_distance[canal_state][connection[0]][connection[1]] = 1
			mm.sea_distance[canal_state][connection[1]][connection[0]] = 1	
		}
		canals_open:= transmute(Canals_Open)u8(canal_state)
		for canal in canals_open {
			mm.seas_within_1_move[canal_state][CANALS[canal].seas[0]] += {CANALS[canal].seas[1]}
			mm.seas_within_1_move[canal_state][CANALS[canal].seas[1]] += {CANALS[canal].seas[0]}
			mm.sea_distance[canal_state][CANALS[canal].seas[0]][CANALS[canal].seas[1]] = 1
			mm.sea_distance[canal_state][CANALS[canal].seas[1]][CANALS[canal].seas[0]] = 1
		}
		// Floyd-Warshall algorithm
		for mid_idx in Sea_ID {
			for start_idx in Sea_ID {
				for end_idx in Sea_ID {
					new_dist := mm.sea_distance[canal_state][start_idx][mid_idx] + mm.sea_distance[canal_state][mid_idx][end_idx]
					if new_dist < mm.sea_distance[canal_state][start_idx][end_idx] {
						mm.sea_distance[canal_state][start_idx][end_idx] = new_dist
					}
				}
			}
		}
		// Initialize the seas_2_moves_away array
		for src_sea in Sea_ID {
			adjacent_seas := mm.seas_within_1_move[canal_state][src_sea]
			for distance, dst_sea in mm.sea_distance[canal_state][src_sea] {
				if distance == 2 {
					mm.seas_within_2_moves[canal_state][src_sea] += {dst_sea}
					for mid_sea in (adjacent_seas & mm.seas_within_1_move[canal_state][dst_sea]) {
						append(&mm.seas_between[canal_state][src_sea][dst_sea], mid_sea)
					}
				}
			}
		}
	}
}
