package oaaa


MAX_LAND_TO_LAND_CONNECTIONS :: 6
MAX_AIR_TO_AIR_CONNECTIONS :: 7
MAX_LAND_TO_SEA_CONNECTIONS :: 4
MAX_LAND_TO_LAND_2_AWAY :: min(20, len(Land_ID))
MAX_SEA_TO_SEA_2_AWAY :: min(20, len(Sea_ID))

MAX_PATHS_TO_LAND :: 2
Mid_Lands :: [dynamic; MAX_PATHS_TO_LAND]Land_ID
MAX_PATHS_TO_SEA :: 2
Mid_Seas :: [dynamic; MAX_PATHS_TO_SEA]Sea_ID

L2S_2_Away :: struct {
	mid_lands: Mid_Lands,
	sea:       Sea_ID,
}

Nation_List :: [dynamic; len(Nation_ID)]Nation_ID
Lands_Within_1_Move :: [dynamic; MAX_LAND_TO_LAND_CONNECTIONS]Land_ID
Coastal_Seas :: [dynamic; MAX_LAND_TO_SEA_CONNECTIONS]Sea_ID
// S2S :: [dynamic; MAX_SEA_TO_SEA_CONNECTIONS]Sea_ID
Coastal_Lands :: [dynamic; MAX_SEA_TO_LAND_CONNECTIONS]Land_ID
// A2A :: [dynamic; MAX_AIR_TO_AIR_CONNECTIONS]Region_ID

MapData :: struct {
	capital:                      [Nation_ID]Land_ID,
	team:                         [Nation_ID]Team_ID,
	enemy_team:                   [Nation_ID]Team_ID,
	friends:                      [Nation_ID]Nation_List,
	enemies:                      [Nation_ID]Nation_List,
	original_owner:               [Land_ID]Nation_ID,
	regions_within_1_air_move:    [Region_ID]Region_Bitset,
	regions_within_2_air_moves:   [Region_ID]Region_Bitset,
	regions_within_3_air_moves:   [Region_ID]Region_Bitset,
	regions_within_4_air_moves:   [Region_ID]Region_Bitset,
	regions_within_5_air_moves:   [Region_ID]Region_Bitset,
	regions_within_6_air_moves:   [Region_ID]Region_Bitset,
	lands_within_2_moves:               [Land_ID]Land_Bitset,
	lands_within_2_moves_blocked_table: [Land_ID][LANDS_WITHIN_2_MOVES_KEY_COUNT]Land_Bitset,
	adjacent_bit_positions:             [Land_ID][MAX_LAND_TO_LAND_CONNECTIONS]u8,
	lands_between:                      [Land_ID][Land_ID]Land_Bitset,
	lands_within_1_move:                [Land_ID]Lands_Within_1_Move,
	lands_within_1_move_bitset:         [Land_ID]Land_Bitset,
	coastal_seas:                 [Land_ID]Coastal_Seas,
	coastal_seas_bitset:          [Land_ID]Sea_Bitset,
	coastal_lands:                [Sea_ID]Coastal_Lands,
	land_distance:                [Land_ID][Land_ID]u8,
	air_distance:                 [Region_ID][Region_ID]u8,
	value:                        [Land_ID]u8,
	seas_within_1_move:           [Canal_States][Sea_ID]Sea_Bitset,
	seas_within_2_moves:          [Canal_States][Sea_ID]Sea_Bitset,
	seas_between:                 [Canal_States][Sea_ID][Sea_ID]Mid_Seas,
	sea_distance:                 [Canal_States][Sea_ID][Sea_ID]u8,
	color:                        [Nation_ID]string,
	land_name:                    [Land_ID]string,
	sea_name:                     [Sea_ID]string,
	is_human:                     bit_set[Nation_ID;u8],
}

initialize_map_constants :: proc(gc: ^Game_Cache) -> (ok: bool) {
	initialize_player_data()
	initialize_land_connections()
	initialize_sea_connections()
	initialize_coastal_connections()
	initialize_region_connections()
	initialize_lands_within_2_moves_blocked_table()
	return true
}
