package oaaa
import sa "core:container/small_array"
import "core:slice"

Coastal_Connection :: struct {
	land: Land_ID,
	sea:  Sea_ID,
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

to_air :: proc {
	sea_to_air,
	land_to_air,
	action_to_air,
}

to_air_bitset :: proc {
	sea_to_air_bitset,
	land_to_air_bitset,
}

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

COASTAL_CONNECTIONS := [?]Coastal_Connection {
	{land = .Washington, sea = .Pacific},
	{land = .Washington, sea = .Atlantic},
	{land = .London, sea = .Atlantic},
	{land = .London, sea = .Baltic},
	{land = .Berlin, sea = .Atlantic},
	{land = .Berlin, sea = .Baltic},
	{land = .Moscow, sea = .Baltic},
	{land = .Tokyo, sea = .Pacific},
}

initialize_costal_connections :: proc() {
	for connection in COASTAL_CONNECTIONS {
		sa.push(&mm.l2s_1away_via_land[connection.land], connection.sea)
		mm.l2s_1away_via_land_bitset[connection.land] += {connection.sea}
		sa.push(&mm.s2l_1away_via_sea[connection.sea], connection.land)
	}
	for src_land in Land_ID {
		for dst_sea in Sea_ID {
			if dst_sea in mm.l2s_1away_via_land_bitset[src_land] do continue
			l2s_2_away := L2S_2_Away {
				sea = dst_sea,
			}
			for mid_land in sa.slice(&mm.s2l_1away_via_sea[dst_sea]) {
				_ =
				slice.linear_search(
					sa.slice(&mm.l2l_1away_via_land[src_land]),
					mid_land,
				) or_continue
				sa.push(&l2s_2_away.mid_lands, mid_land)
			}
			sa.push(&mm.l2s_2away_via_land[src_land], l2s_2_away)
		}
	}
}

initialize_air_connections :: proc() {
	INFINITY :: 127 // must be less than half of u8
	for air in Air_ID {
		for dst_air in Air_ID {
			mm.air_distances[air][dst_air] = INFINITY
		}
		//mem.set(&air.air_distances, INFINITY, size_of(air.air_distances))
		//mm.air_distances[air][air] = INFINITY
		// Ensure that the distance from a land to itself is 0
		mm.air_distances[air][air] = 0
		// Set initial distances based on adjacent lands
	}
	for land in Land_ID {
		for adjacent_land in sa.slice(&mm.l2l_1away_via_land[land]) {
			mm.air_distances[to_air(land)][to_air(adjacent_land)] = 1
			mm.a2a_within_1_moves[to_air(land)] += {to_air(adjacent_land)}
		}
		for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
			mm.air_distances[to_air(land)][to_air(adjacent_sea)] = 1
			mm.a2a_within_1_moves[to_air(land)] += {to_air(adjacent_sea)}
		}
	}
	for sea in Sea_ID {
		for adjacent_land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
			mm.air_distances[to_air(sea)][to_air(adjacent_land)] = 1
			mm.a2a_within_1_moves[to_air(sea)] += {to_air(adjacent_land)}
		}
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
		for distance, dst_air in mm.air_distances[air] {
			switch distance {
			case 2:
				mm.a2a_2away_via_air[air] += {dst_air}
				mm.a2a_within_2_moves[air] += {dst_air}
				fallthrough
			case 3:
				mm.a2a_within_3_moves[air] += {dst_air}
				fallthrough
			case 4:
				mm.a2a_within_4_moves[air] += {dst_air}
				fallthrough
			case 5:
				mm.a2a_within_5_moves[air] += {dst_air}
				fallthrough
			case 6:
				mm.a2a_within_6_moves[air] += {dst_air}
			}
		}
	}
}
