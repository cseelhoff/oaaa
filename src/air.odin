package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

to_air :: proc {
	sea_to_air,
	land_to_air,
	action_to_air,
}

// to_land_bitset :: proc {
// 	air_to_land_bitset,
// }

// to_sea_bitset :: proc {
// 	air_to_sea_bitset,
// }

sea_to_air :: #force_inline proc(sea: Sea_ID) -> Air_ID {
	return Air_ID(u8(sea) + u8(len(Land_ID)))
}

land_to_air :: #force_inline proc(land: Land_ID) -> Air_ID {
	return Air_ID(land)
}

action_to_air :: #force_inline proc(act: Action_ID) -> Air_ID {
	return Air_ID(act)
}

// sea_to_air_bitset :: #force_inline proc(sea: Sea_Bitset) -> Air_Bitset {
// 	return transmute(Air_Bitset)(u128(transmute(u128)sea) << len(Land_ID))
// }

// air_to_land_bitset :: #force_inline proc(air: Air_Bitset) -> Land_Bitset {
// 	return transmute(Land_Bitset)u128(transmute(u128)air)
// }

// air_to_sea_bitset :: #force_inline proc(air: Air_Bitset) -> Sea_Bitset {
// 	return transmute(Sea_Bitset)(u128(transmute(u128)air) >> len(Land_ID))
// }

initialize_coastal_connections :: proc() {
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
			mm.l2s_2away_via_land_bitset[src_land] += {dst_sea}
			// sa.push(&mm.l2s_2away_via_land[src_land], l2s_2_away)
		}
	}
}

initialize_air_connections :: proc() {
	INFINITY :: 127 // must be less than half of u8
	for air in Air_ID {
		for dst_air in Air_ID {
			mm.air_distances[air][dst_air] = INFINITY
		}
		// Ensure that the distance from a land to itself is 0
		mm.air_distances[air][air] = 0
		// Set initial distances based on adjacent lands
	}
	for land in Land_ID {
		for adjacent_land in sa.slice(&mm.l2l_1away_via_land[land]) {
			mm.air_distances[to_air(land)][to_air(adjacent_land)] = 1
			add_air(&mm.a2a_within_1_moves[to_air(land)], to_air(adjacent_land))
		}
		for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
			mm.air_distances[to_air(land)][to_air(adjacent_sea)] = 1
			add_air(&mm.a2a_within_1_moves[to_air(land)], to_air(adjacent_sea))
		}
	}
	for sea in Sea_ID {
		for adjacent_land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
			mm.air_distances[to_air(sea)][to_air(adjacent_land)] = 1
			add_air(&mm.a2a_within_1_moves[to_air(sea)], to_air(adjacent_land))
		}
		for adjacent_sea in mm.s2s_1away_via_sea[Canal_States - 1][sea] {
			/*
			AI NOTE: Air Movement Over Sea Zones
			Use Canal_States - 1 (all canals open) because:
			- Air units can move between connected sea zones
			- Air movement ignores canal state restrictions
			- If seas are ever connected (any canal state), air can fly between them
			*/
			mm.air_distances[to_air(sea)][to_air(adjacent_sea)] = 1
			add_air(&mm.a2a_within_1_moves[to_air(sea)], to_air(adjacent_sea))
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
			// if air == .Karelia_SSR_Air && dst_air == .Russia_Air {
			// 	fmt.println("air", air, "dst_air", dst_air, "distance", distance)
			// }
			switch distance {
			case 1:
				fallthrough
			case 2:
				add_air(&mm.a2a_2away_via_air[air], dst_air)
				add_air(&mm.a2a_within_2_moves[air], dst_air)
				fallthrough
			case 3:
				add_air(&mm.a2a_within_3_moves[air], dst_air)
				fallthrough
			case 4:
				add_air(&mm.a2a_within_4_moves[air], dst_air)
				fallthrough
			case 5:
				add_air(&mm.a2a_within_5_moves[air], dst_air)
				fallthrough
			case 6:
				add_air(&mm.a2a_within_6_moves[air], dst_air)
			}
		}
	}
}
