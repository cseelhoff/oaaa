package oaaa
import "core:fmt"
import "core:slice"

to_region :: proc {
	sea_to_region,
	land_to_region,
	action_to_region,
}

// to_land_bitset :: proc {
// 	air_to_land_bitset,
// }

// to_sea_bitset :: proc {
// 	air_to_sea_bitset,
// }

sea_to_region :: #force_inline proc(sea: Sea_ID) -> Region_ID {
	return Region_ID(u8(sea) + u8(len(Land_ID)))
}

land_to_region :: #force_inline proc(land: Land_ID) -> Region_ID {
	return Region_ID(land)
}

action_to_region :: #force_inline proc(act: Action_ID) -> Region_ID {
	return Region_ID(act)
}

// sea_to_air_bitset :: #force_inline proc(sea: Sea_Bitset) -> Region_Bitset {
// 	return transmute(Region_Bitset)(u128(transmute(u128)sea) << len(Land_ID))
// }

// air_to_land_bitset :: #force_inline proc(region: Region_Bitset) -> Land_Bitset {
// 	return transmute(Land_Bitset)u128(transmute(u128)region)
// }

// air_to_sea_bitset :: #force_inline proc(region: Region_Bitset) -> Sea_Bitset {
// 	return transmute(Sea_Bitset)(u128(transmute(u128)region) >> len(Land_ID))
// }

initialize_coastal_connections :: proc() {
	for connection in COASTAL_CONNECTIONS {
		append(&mm.coastal_seas[connection.land], connection.sea)
		mm.coastal_seas_bitset[connection.land] += {connection.sea}
		append(&mm.coastal_lands[connection.sea], connection.land)
	}
	for src_land in Land_ID {
		for dst_sea in Sea_ID {
			if dst_sea in mm.coastal_seas_bitset[src_land] do continue
			l2s_2_away := L2S_2_Away {
				sea = dst_sea,
			}
			for mid_land in mm.coastal_lands[dst_sea] {
				_ =
				slice.linear_search(
					mm.lands_within_1_move[src_land][:],
					mid_land,
				) or_continue
				append(&l2s_2_away.mid_lands, mid_land)
			}
			mm.l2s_2away_via_land_bitset[src_land] += {dst_sea}
			// append(&mm.l2s_2away_via_land[src_land], l2s_2_away)
		}
	}
}

initialize_region_connections :: proc() {
	INFINITY :: 127 // must be less than half of u8
	for region in Region_ID {
		for dst_region in Region_ID {
			mm.air_distance[region][dst_region] = INFINITY
		}
		// Ensure that the distance from a land to itself is 0
		mm.air_distance[region][region] = 0
		// Set initial distances based on adjacent lands
	}
	for land in Land_ID {
		for adjacent_land in mm.lands_within_1_move[land] {
			mm.air_distance[to_region(land)][to_region(adjacent_land)] = 1
			add_region(&mm.regions_within_1_air_move[to_region(land)], to_region(adjacent_land))
		}
		for adjacent_sea in mm.coastal_seas[land] {
			mm.air_distance[to_region(land)][to_region(adjacent_sea)] = 1
			add_region(&mm.regions_within_1_air_move[to_region(land)], to_region(adjacent_sea))
		}
	}
	for sea in Sea_ID {
		for adjacent_land in mm.coastal_lands[sea] {
			mm.air_distance[to_region(sea)][to_region(adjacent_land)] = 1
			add_region(&mm.regions_within_1_air_move[to_region(sea)], to_region(adjacent_land))
		}
		for adjacent_sea in mm.seas_within_1_move[Canal_States - 1][sea] {
			/*
			AI NOTE: Air Movement Over Sea Zones
			Use Canal_States - 1 (all canals open) because:
			- Air units can move between connected sea zones
			- Air movement ignores canal state restrictions
			- If seas are ever connected (any canal state), region can fly between them
			*/
			mm.air_distance[to_region(sea)][to_region(adjacent_sea)] = 1
			add_region(&mm.regions_within_1_air_move[to_region(sea)], to_region(adjacent_sea))
		}
	}
	for mid_idx in Region_ID {
		mid_air_dist := &mm.air_distance[mid_idx]
		for start_idx in Region_ID {
			start_air_dist := &mm.air_distance[start_idx]
			for end_idx in Region_ID {
				new_dist := mid_air_dist[start_idx] + mid_air_dist[end_idx]
				if new_dist < start_air_dist[end_idx] {
					start_air_dist[end_idx] = new_dist
				}
			}
		}
	}
	// Initialize the airs_2_moves_away array
	for region in Region_ID {
		for distance, dst_region in mm.air_distance[region] {
			// if region == .Karelia_SSR_Air && dst_region == .Russia_Air {
			// 	fmt.println("region", region, "dst_region", dst_region, "distance", distance)
			// }
			switch distance {
			case 1:
				fallthrough
			case 2:
				add_region(&mm.a2a_2away_via_air[region], dst_region)
				add_region(&mm.regions_within_2_air_moves[region], dst_region)
				fallthrough
			case 3:
				add_region(&mm.regions_within_3_air_moves[region], dst_region)
				fallthrough
			case 4:
				add_region(&mm.regions_within_4_air_moves[region], dst_region)
				fallthrough
			case 5:
				add_region(&mm.regions_within_5_air_moves[region], dst_region)
				fallthrough
			case 6:
				add_region(&mm.regions_within_6_air_moves[region], dst_region)
			}
		}
	}
}
