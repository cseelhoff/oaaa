package oaaa

import sa "core:container/small_array"

MAX_LAND_TO_LAND_CONNECTIONS :: 6
MAX_AIR_TO_AIR_CONNECTIONS :: 7
MAX_LAND_TO_SEA_CONNECTIONS :: 4

MAX_PATHS_TO_LAND :: 2
Mid_Lands :: sa.Small_Array(MAX_PATHS_TO_LAND, Land_ID)

L2S_2_Away :: struct {
	mid_lands: Mid_Lands,
	sea:       Sea_ID,
}

SA_Players :: sa.Small_Array(len(Player_ID), Player_ID)
SA_L2L :: sa.Small_Array(MAX_LAND_TO_LAND_CONNECTIONS, Land_ID)
SA_L2S :: sa.Small_Array(MAX_LAND_TO_SEA_CONNECTIONS, Sea_ID)
SA_L2S_2_Away :: sa.Small_Array(len(Sea_ID), L2S_2_Away)
SA_S2S :: sa.Small_Array(MAX_SEA_TO_SEA_CONNECTIONS, Sea_ID)
SA_A2A :: sa.Small_Array(MAX_AIR_TO_AIR_CONNECTIONS, Air_ID)

MapData :: struct {
	teams:                  Teams,
	capital:                [Player_ID]Land_ID,
	team:                   [Player_ID]Team_ID,
	enemy_team:             [Player_ID]Team_ID,
	allies:                 [Player_ID]SA_Players,
	enemies:                [Player_ID]SA_Players,
	adj_l2a:                [Land_ID]Air_Bitset,
	air_l2a_2away:          [Land_ID]Air_Bitset,
	adj_l2l:                [Land_ID]SA_L2L,
	adj_l2s:                [Land_ID]SA_L2S,
	adj_l2s_2_away:         [Land_ID]SA_L2S_2_Away,
	//adj_a2a:            [Air_ID]SA_A2A,
	adj_a2l:                [Air_ID]Land_Bitset,
	adj_a2s:                [Air_ID]Sea_Bitset,
	orig_owner:             [Land_ID]Player_ID,
	// airs_2_moves_away:       [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	// airs_3_moves_away:       [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	// airs_4_moves_away:       [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	// airs_5_moves_away:       [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	// airs_6_moves_away:       [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	l2l_within_6_air_moves: [Land_ID]Land_Bitset,
	// air_within_5_air_moves:  [Air_ID]Air_Bitset,
	// air_within_4_air_moves:  [Air_ID]Air_Bitset,
	// air_within_3_air_moves:  [Air_ID]Air_Bitset,
	// air_within_2_air_moves:  [Air_ID]Air_Bitset,
	// air_within_1_air_moves:  [Air_ID]Air_Bitset,
	l2a_within_3_moves:     [Land_ID]Air_Bitset,
	l2a_within_4_air_moves: [Land_ID]Air_Bitset,
	l2a_within_5_air_moves: [Land_ID]Air_Bitset,
	a2a_within_2_air_moves: [Air_ID]Air_Bitset, //fighters use this too
	a2l_within_3_air_moves: [Air_ID]Land_Bitset,
	a2l_within_4_air_moves: [Air_ID]Land_Bitset,
	a2l_within_5_air_moves: [Air_ID]Land_Bitset,
	lands_2_moves_away:     [Land_ID]sa.Small_Array(len(Land_ID), Land_2_Moves_Away),
	dst_sea_2_away:         [Land_ID]sa.Small_Array(len(Sea_ID), Sea_ID),
	land_distances:         [Land_ID][Land_ID]u8,
	air_distances:          [Air_ID][Air_ID]u8,
	value:                  [Land_ID]u8,
	original_owner:         [Land_ID]Player_ID,
	adj_s2s:                [Canal_States][Sea_ID]SA_S2S,
	seas_2_moves_away:      [Canal_States][Sea_ID]SA_S2S,
	sea_distances:          [Canal_States][Sea_ID][Sea_ID]u8,
	color:                  [Player_ID]string,
	air_name:               [Air_ID]string,
	is_human:               bit_set[Player_ID;u8],
}

Land_2_Moves_Away :: struct {
	land:      Land_ID,
	mid_lands: Mid_Lands,
}

mm: MapData = {}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_teams()
	initialize_territories()
	initialize_player_lands()
	initialize_land_connections() or_return
	//initialize_sea_connections(&gc.canal_paths, &gc.seas) or_return
	initialize_sea_connections() or_return
	initialize_costal_connections() or_return
	initialize_canals() or_return
	initialize_lands_2_moves_away()
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
