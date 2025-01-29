package oaaa

import sa "core:container/small_array"

MAX_LAND_TO_LAND_CONNECTIONS :: 6
MAX_AIR_TO_AIR_CONNECTIONS :: 7
MAX_LAND_TO_SEA_CONNECTIONS :: 4
MAX_LAND_TO_LAND_2_AWAY :: min(20, len(Land_ID))
MAX_SEA_TO_SEA_2_AWAY :: min(20, len(Sea_ID))

MAX_PATHS_TO_LAND :: 2
Mid_Lands :: sa.Small_Array(MAX_PATHS_TO_LAND, Land_ID)
MAX_PATHS_TO_SEA :: 2
Mid_Seas :: sa.Small_Array(MAX_PATHS_TO_SEA, Sea_ID)

L2S_2_Away :: struct {
	mid_lands: Mid_Lands,
	sea:       Sea_ID,
}

SA_Players :: sa.Small_Array(len(Player_ID), Player_ID)
SA_L2L :: sa.Small_Array(MAX_LAND_TO_LAND_CONNECTIONS, Land_ID)
SA_L2S :: sa.Small_Array(MAX_LAND_TO_SEA_CONNECTIONS, Sea_ID)
SA_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, Sea_ID)
SA_S2L :: sa.Small_Array(MAX_SEA_TO_LAND_CONNECTIONS, Land_ID)
SA_A2A :: sa.Small_Array(MAX_AIR_TO_AIR_CONNECTIONS, Air_ID)

MapData :: struct {
	// teams:                     Teams,
	capital:                      [Player_ID]Land_ID,
	team:                         [Player_ID]Team_ID,
	enemy_team:                   [Player_ID]Team_ID,
	allies:                       [Player_ID]SA_Players,
	enemies:                      [Player_ID]SA_Players,
	orig_owner:                   [Land_ID]Player_ID,
	a2a_within_1_moves:           [Air_ID]Air_Bitset,
	a2a_within_2_moves:           [Air_ID]Air_Bitset,
	a2a_within_3_moves:           [Air_ID]Air_Bitset,
	a2a_within_4_moves:           [Air_ID]Air_Bitset,
	a2a_within_5_moves:           [Air_ID]Air_Bitset,
	a2a_within_6_moves:           [Air_ID]Air_Bitset,
	// l2l_2away_via_land:           L2L_2Away_Via_Land,
	l2l_2away_via_land_bitset:    [Land_ID]Land_Bitset,
	l2l_2away_via_midland_bitset: [Land_ID][Land_ID]Land_Bitset,
	l2l_1away_via_land:           [Land_ID]SA_L2L,
	l2l_1away_via_land_bitset:    [Land_ID]Land_Bitset,
	l2s_1away_via_land:           [Land_ID]SA_L2S,
	l2s_1away_via_land_bitset:    [Land_ID]Sea_Bitset,
	// l2s_2away_via_land:           [Land_ID]SA_L2S_2_Away,
	l2s_2away_via_land_bitset:    [Land_ID]Sea_Bitset,
	l2s_2away_via_midland_bitset: [Land_ID][Sea_ID]Land_Bitset,
	s2l_1away_via_sea:            [Sea_ID]SA_S2L,
	a2a_2away_via_air:            [Air_ID]Air_Bitset,
	land_distances:               [Land_ID][Land_ID]u8,
	air_distances:                [Air_ID][Air_ID]u8,
	value:                        [Land_ID]u8,
	s2s_1away_via_sea:            [Canal_States][Sea_ID]Sea_Bitset,
	s2s_2away_via_sea:            [Canal_States][Sea_ID]Sea_Bitset,
	s2s_2away_via_midseas:        [Canal_States][Sea_ID][Sea_ID]Mid_Seas,
	sea_distances:                [Canal_States][Sea_ID][Sea_ID]u8,
	color:                        [Player_ID]string,
	land_name:                    [Land_ID]string,
	sea_name:                     [Sea_ID]string,
	is_human:                     bit_set[Player_ID;u8],
}

mm: MapData = {
	capital = {.Rus = .Moscow, .Ger = .Berlin, .Eng = .London, .Jap = .Tokyo, .USA = .Washington},
	team = {.Rus = .Allies, .Ger = .Axis, .Eng = .Allies, .Jap = .Axis, .USA = .Allies},
	value = {.Moscow = 8, .Berlin = 10, .London = 8, .Washington = 10, .Tokyo = 8},
	orig_owner = {
		.Moscow = .Rus,
		.Berlin = .Ger,
		.London = .Eng,
		.Tokyo = .Jap,
		.Washington = .USA,
	},
	color = {
		.Rus = "\033[1;31m",
		.Ger = "\033[1;34m",
		.Eng = "\033[1;95m",
		.Jap = "\033[1;33m",
		.USA = "\033[1;32m",
	},
}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_player_data()
	initialize_land_connections()
	initialize_sea_connections()
	initialize_coastal_connections()
	initialize_air_connections()
	return true
}
