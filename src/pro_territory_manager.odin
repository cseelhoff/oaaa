package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

Unit :: struct {
	owner:     Player_ID,
	unit_type: Idle_Army,
}

find_enemy_attack_options :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	cleared_territories: Land_Bitset,
	territories_to_check: Land_Bitset,
	enemy_attack_options: ^Pro_Other_Move_Options,
) {
	enemy_attack_maps: [Player_ID]map[Air_ID]Pro_Territory = {}
	allied_territories: Land_Bitset = {}
	enemy_territories: Land_Bitset = cleared_territories

	// Loop through each enemy to determine the maximum number of enemy units that can attack each
	// territory
	for enemy_player in sa.slice(&mm.enemies[gc.cur_player]) {
		enemy_unit_territories_land := gc.has_enemy_armies
		enemy_unit_territories_sea := gc.has_enemy_ships
		attack_map := map[Air_ID]Pro_Territory{}
		unit_attack_map := map[Unit]Land_Bitset{}
		transport_attack_map := map[Unit]Land_Bitset{}
		bombard_map := map[Unit]Air_Bitset{}
		enemy_attack_maps[enemy_player] = attack_map
		find_attack_options(
			gc,
			enemy_player,
			enemy_unit_territories_land,
			enemy_unit_territories_sea,
			attack_map,
			unit_attack_map,
			transport_attack_map,
			bombard_map,
			territories_to_check,
		)
		for air_id in attack_map {
			if !is_land(air_id) do continue
			allied_territories += {to_land(air_id)}
		}
		// allied_territories += air_bitset_to_land_bitset(attack_map)
		enemy_territories -= allied_territories
	}
	set_max_move_map(gc, enemy_attack_options, &enemy_attack_maps, player, true)
	set_move_maps(gc, enemy_attack_options, &enemy_attack_maps)
}

find_attack_options :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	my_unit_territories_land: Land_Bitset,
	my_unit_territories_sea: Sea_Bitset,
	move_map: map[Air_ID]Pro_Territory,
	unit_move_map: map[Unit]Land_Bitset,
	transport_move_map: map[Unit]Land_Bitset,
	bombard_map: map[Unit]Air_Bitset,
	enemy_territories: Land_Bitset,
	territories_to_check: Land_Bitset,
	is_checking_enemy_attacks: bool,
) {
	land_routes_map: map[Land_ID]Land_Bitset = {}
	territories_that_cant_be_held: Land_Bitset = enemy_territories
	find_naval_move_options(
		gc,
		player,
		my_unit_territories_sea,
		move_map,
		unit_move_map,
		transport_move_map,
		enemy_territories,
		true,
		is_checking_enemy_attacks,
	)
	find_land_move_options(
		gc,
		player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_air_move_options(
		gc,
		player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_amphib_move_options(
		gc,
		player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_bombard_options(
		gc,
		player,
		enemy_unit_territories_sea,
		attack_map,
		territories_that_cant_be_held,
	)
}

find_naval_move_options :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	my_unit_territories: Sea_Bitset,
	move_map: map[Air_ID]Pro_Territory,
	unit_move_map: map[Unit]Land_Bitset,
	transport_move_map: map[Unit]Land_Bitset,
	territories_that_cant_be_held: Land_Bitset,
	is_combat_move: bool,
	is_checking_enemy_attacks: bool,
) -> (
	ok: bool,
) {
	// Implementation goes here
	for my_unit_territory in my_unit_territories {
		// Find my naval units that have movement left
		possible_move_territories: Land_Bitset = {} // Determine possible move territories for each unit
	}

	return true
}
