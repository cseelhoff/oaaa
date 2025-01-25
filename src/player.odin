package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:strings"

Player_Data :: struct {
	player:     Player_ID,
	team:     Team_ID,
	color:    string,
	capital:  Land_ID,
	is_human: bool,
}

PLAYER_DATA := [?]Player_Data {
	{team = .Allies, player = .Rus, color = "\033[1;31m", capital = .Moscow},
	{team = .Axis, player = .Ger, color = "\033[1;34m", capital = .Berlin},
	{team = .Allies, player = .Eng, color = "\033[1;95m", capital = .London},
	{team = .Axis, player = .Jap, color = "\033[1;33m", capital = .Tokyo},
	{team = .Allies, player = .USA, color = "\033[1;32m", capital = .Washington},
}

DEF_COLOR :: "\033[1;0m"

Factory_Locations :: sa.Small_Array(len(Land_ID), Land_ID)

Player :: struct {
	factory_locations:  Factory_Locations,
	index:              Player_ID,
	money:              u8,
	income_per_turn:    u8,
}

TEAM_STRINGS :: [?]string{"Allies", "Axis"}
TEAMS_COUNT :: len(TEAM_STRINGS)

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
initialize_player_data :: proc () {
	for player_data in PLAYER_DATA {
		mm.capital[player_data.player] = player_data.capital
		mm.team[player_data.player] = player_data.team
		mm.enemy_team[player_data.player] = Team_ID(len(Team_ID) - int(player_data.team) - 1)
		mm.color[player_data.player] = player_data.color
		for other_player in PLAYER_DATA {
			if other_player.team == player_data.team {
			sa.push(&mm.allies[player_data.player], other_player.player)
			} else {
				sa.push(&mm.enemies[player_data.player], other_player.player)
			}
		}
	}
}

	initialize_land_data :: proc() -> (ok: bool) {
	for land_data in LAND_DATA {
		mm.orig_owner[land_data.land] = land_data.orig_owner
		mm.value[land_data.land] = land_data.value
	}
	return true
}
