package oaaa
import sa "core:container/small_array"
import "core:mem"

// len(Air_ID) :: LANDS_COUNT + SEAS_COUNT
MAX_TERRITORY_TO_LAND_CONNECTIONS :: 6
// MAX_AIR_TO_AIR_CONNECTIONS :: 7
SA_Adjacent_Lands :: sa.Small_Array(MAX_TERRITORY_TO_LAND_CONNECTIONS, Land_ID)
SA_Adjacent_Airs :: sa.Small_Array(MAX_AIR_TO_AIR_CONNECTIONS, Air_ID)
Skipped_Buys :: [len(Buy_Action)]bool

Coastal_Connection_String :: struct {
	land: string,
	sea:  string,
}

Air_ID :: distinct enum u8 {
	Washington_Air,
	London_Air,
	Berlin_Air,
	Moscow_Air,
	Tokyo_Air,
	Pacific_Air,
	Atlantic_Air,
	Baltic_Air,
}

to_air :: proc{sea_to_air, land_to_air, action_to_air}

to_air_bitset ::proc{sea_to_air_bitset, land_to_air_bitset}

sea_to_air :: #force_inline proc(sea: Sea_ID) -> Air_ID {
	return Air_ID(u8(sea) + u8(len(Land_ID)))
}

land_to_air :: #force_inline proc(land: Land_ID) -> Air_ID {
	return Air_ID(land)
}

action_to_air :: #force_inline proc(act: Action_ID) -> Air_ID {
	return Air_ID(act)
}

land_to_air_bitset :: #force_inline proc(land: Land_Bitset) -> Air_Bitset {
	return transmute(Air_Bitset)u16(transmute(u8)land)
}

sea_to_air_bitset :: #force_inline proc(sea: Sea_Bitset) -> Air_Bitset {
	return transmute(Air_Bitset)(u16(transmute(u8)sea) << len(Land_ID))
}

COASTAL_CONNECTIONS := [?]Coastal_Connection_String {
	{land = "Washington", sea = "Pacific"},
	{land = "Washington", sea = "Atlantic"},
	{land = "London", sea = "Atlantic"},
	{land = "London", sea = "Baltic"},
	{land = "Berlin", sea = "Atlantic"},
	{land = "Berlin", sea = "Baltic"},
	{land = "Moscow", sea = "Baltic"},
	{land = "Tokyo", sea = "Pacific"},
}

initialize_costal_connections :: proc() -> (ok: bool) {
	// for connection in COASTAL_CONNECTIONS {
	// 	land_idx := get_land_idx_from_string(connection.land) or_return
	// 	sea_idx := get_sea_idx_from_string(connection.sea) or_return
	// 	// sa.append(&lands[land_idx].adjacent_seas, &seas[sea_idx])
	// 	sa.push(mm.l2s_1away_via_land[land_idx],sea_idx)
	// 	mm.l2s_1away_via_land_bitset[land_idx].set(sea_idx)
	// 	// sa.append(&seas[sea_idx].adjacent_lands, &lands[land_idx])
	// }
	return true
}

initialize_air_dist :: proc() {
	for terr in Air_ID {
		INFINITY :: 127 // must be less than half of u8
		//mem.set(&terr.air_distances, INFINITY, size_of(terr.air_distances))
		//mm.air_distances[terr][terr] = INFINITY
		mem.set(&mm.air_distances[terr], INFINITY, size_of(mm.air_distances[terr]))
		// Ensure that the distance from a land to itself is 0
		mm.air_distances[terr][terr] = 0
		// Set initial distances based on adjacent lands
		for adjacent_land in sa.slice(&mm.l2l_1away_via_land[to_land(terr)]) {
			mm.air_distances[terr][to_air(adjacent_land)] = 1
			mm.a2a_within_1_moves[terr] += {to_air(adjacent_land)}
		}
	}
	for land in Land_ID {
		for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
			mm.air_distances[to_air(land)][to_air(adjacent_sea)] = 1
			mm.a2a_within_1_moves[to_air(land)] += {to_air(adjacent_sea)}
		}
	}
	for sea in Sea_ID {
		for adjacent_sea in mm.s2s_1away_via_sea[Canal_States - 1][sea] {
			mm.air_distances[to_air(sea)][to_air(adjacent_sea)] = 1
			mm.a2a_within_1_moves[to_air(sea)] += {to_air(adjacent_sea)}
		}
	}
	for mid_idx in Air_ID {
		mid_air_dist := &mm.air_distances[mid_idx]
		for start_idx in Air_ID {
			start_air_dist := &mm.air_distances[start_idx]
			for end_idx in Air_ID {
				new_dist := mid_air_dist[start_idx] + mid_air_dist[end_idx]
				if new_dist < start_air_dist[end_idx] {
					start_air_dist[end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the airs_2_moves_away array
	for air in Air_ID {
		for distance, dest_air_idx in mm.air_distances[air] {
			if distance == 2 {
				mm.a2a_within_2_moves[air] += {dest_air_idx}
			}
		}
	}
}
