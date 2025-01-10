package oaaa

import sa "core:container/small_array"

MAX_LAND_TO_LAND_CONNECTIONS :: 6
MAX_AIR_TO_AIR_CONNECTIONS :: 7

SA_Players :: sa.Small_Array(len(Player_ID), Player_ID)
SA_L2L :: sa.Small_Array(MAX_LAND_TO_LAND_CONNECTIONS, Land_ID)
SA_A2A :: sa.Small_Array(MAX_AIR_TO_AIR_CONNECTIONS, Land_ID)

MapData :: struct {
	teams:              Teams,
	capital:            [Player_ID]Land_ID,
	team:               [Player_ID]Team_ID,
	enemy_team:         [Player_ID]Team_ID,
	allies:             [Player_ID]SA_Players,
	enemies:            [Player_ID]SA_Players,
	adj_l2l:            [Land_ID]SA_L2L,
	adj_a2a:            [Air_ID]SA_A2A,
	orig_owner:         [Land_ID]Player_ID,
	airs_2_moves_away:  [Air_ID]sa.Small_Array(len(Air_ID), Air_ID),
	lands_2_moves_away: [Land_ID]sa.Small_Array(len(Land_ID), Land_ID),
  dst_sea_2_away:     [Land_ID]sa.Small_Array(len(Sea_ID), Sea_ID),
	land_distances:     [Land_ID][Land_ID]u8,
}

mm: MapData = {}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_teams(&gc.teams, &gc.players)
	initialize_territories(&gc.lands, &gc.seas, &gc.territories)
	initialize_player_lands(&gc.lands, &gc.players)
	initialize_land_connections(&gc.lands) or_return
	//initialize_sea_connections(&gc.canal_paths, &gc.seas) or_return
	initialize_sea_connections(&gc.seas) or_return
	initialize_costal_connections(&gc.lands, &gc.seas) or_return
	initialize_canals(&gc.lands) or_return
	initialize_lands_2_moves_away(&gc.lands)
	// initialize_seas_2_moves_away(&gc.seas, &gc.canal_paths)
	initialize_seas_2_moves_away(&gc.seas)
	initialize_air_dist(&gc.lands, &gc.seas, &gc.territories)
	// initialize_land_path()
	// initialize_sea_path()
	// initialize_within_x_moves()
	// intialize_airs_x_to_4_moves_away()
	// initialize_skip_4air_precals()
	return true
}
