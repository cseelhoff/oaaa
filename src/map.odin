package oaaa

import sa "core:container/small_array"

MAX_LAND_TO_LAND_CONNECTIONS :: 6
MAX_AIR_TO_AIR_CONNECTIONS :: 7
MAX_LAND_TO_SEA_CONNECTIONS :: 4

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
SA_L2S_2_Away :: sa.Small_Array(len(Sea_ID), L2S_2_Away)
SA_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, Sea_ID)
SA_S2L :: sa.Small_Array(MAX_SEA_TO_LAND_CONNECTIONS, Land_ID)
SA_A2A :: sa.Small_Array(MAX_AIR_TO_AIR_CONNECTIONS, Air_ID)
L2L_2Away_Via_Land :: [Land_ID]sa.Small_Array(len(Land_ID), Land_2_Moves_Away)
S2S_2Away_Via_Sea :: [Land_ID]sa.Small_Array(len(Sea_ID), Sea_ID)

MapData :: struct {
	teams:                     Teams,
	capital:                   [Player_ID]Land_ID,
	team:                      [Player_ID]Team_ID,
	enemy_team:                [Player_ID]Team_ID,
	allies:                    [Player_ID]SA_Players,
	enemies:                   [Player_ID]SA_Players,
	orig_owner:                [Land_ID]Player_ID,
	a2a_within_1_moves:        [Air_ID]Air_Bitset,
	a2a_within_2_moves:        [Air_ID]Air_Bitset,
	a2a_within_3_moves:        [Air_ID]Air_Bitset,
	a2a_within_4_moves:        [Air_ID]Air_Bitset,
	a2a_within_5_moves:        [Air_ID]Air_Bitset,
	a2a_within_6_moves:        [Air_ID]Air_Bitset,
	l2l_2away_via_land:        L2L_2Away_Via_Land,
	l2l_1away_via_land:        [Land_ID]SA_L2L,
	l2s_1away_via_land:        [Land_ID]SA_L2S,
	l2s_1away_via_land_bitset: [Land_ID]Sea_Bitset,
	l2s_2away_via_land:        [Land_ID]SA_L2S_2_Away,
	s2l_1away_via_sea:				 [Sea_ID]SA_S2L,
	a2a_2away_via_air:         [Air_ID]Air_Bitset,
	land_distances:            [Land_ID][Land_ID]u8,
	air_distances:             [Air_ID][Air_ID]u8,
	value:                     [Land_ID]u8,
	original_owner:            [Land_ID]Player_ID,
	s2s_1away_via_sea:         [Canal_States][Sea_ID]Sea_Bitset,
	s2s_2away_via_sea:         [Canal_States][Sea_ID]Sea_Bitset,
	s2s_2away_via_midseas:     [Canal_States][Sea_ID][Sea_ID]Mid_Seas,
	sea_distances:             [Canal_States][Sea_ID][Sea_ID]u8,
	color:                     [Player_ID]string,
	land_name:                 [Land_ID]string,
	sea_name:                  [Sea_ID]string,
	is_human:                  bit_set[Player_ID;u8],
}

Land_2_Moves_Away :: struct {
	land:      Land_ID,
	mid_lands: Mid_Lands,
}

mm: MapData = {}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_teams()
	// initialize_territories()
	initialize_player_lands()
	// initialize_land_connections() or_return
	//initialize_sea_connections(&gc.canal_paths, &gc.seas) or_return
	initialize_sea_connections() or_return
	initialize_costal_connections() or_return
	initialize_canals() or_return
	initialize_l2l_2away_via_land()
	// initialize_seas_2_moves_away(&gc.seas, &gc.canal_paths)
	initialize_seas_2_moves_away()
	initialize_air_dist()
	// initialize_land_path()
	// initialize_sea_path()
	// initialize_within_x_moves()
	// intialize_airs_x_to_4_moves_away()
	// initialize_skip_4air_precals()
	return true
}
