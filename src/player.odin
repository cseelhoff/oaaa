package oaaa

import sa "core:container/small_array"

Player_Data :: struct {
	player:   Player_ID,
	team:     Team_ID,
	color:    string,
	capital:  Land_ID,
	is_human: bool,
}

DEF_COLOR :: "\033[1;0m"

Factory_Locations :: sa.Small_Array(len(Land_ID), Land_ID)

Player_ID :: enum {
	Rus,
	Ger,
	Eng,
	Jap,
	USA,
}

Team_ID :: enum {
	Allies,
	Axis,
}

// get_player_idx_from_string :: proc(player_name: string) -> (player_idx: u8, ok: bool) {
// 	for player, player_idx in PLAYER_DATA {
// 		if strings.compare(player.name, player_name) == 0 {
// 			return u8(player_idx), true
// 		}
// 	}
// 	fmt.eprintln("Error: Player not found: %s\n", player_name)
// 	return 0, false
// }
initialize_player_data :: proc() {
	for player in Player_ID {
		mm.enemy_team[player] = Team_ID(len(Team_ID) - int(mm.team[player]) - 1)
		mm.color[player] = mm.color[player]
		for other_player in Player_ID {
			if mm.team[other_player] == mm.team[player] {
				sa.push(&mm.allies[player], player)
			} else {
				sa.push(&mm.enemies[player], player)
			}
		}
	}
}

// initialize_land_data :: proc() -> (ok: bool) {
// 	for land_data in LAND_DATA {
// 		mm.orig_owner[land_data.land] = land_data.orig_owner
// 		mm.value[land_data.land] = land_data.value
// 	}
// 	return true
// }
