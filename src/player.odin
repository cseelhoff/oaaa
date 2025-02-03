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

initialize_player_data :: proc() {
	for player in Player_ID {
		mm.enemy_team[player] = Team_ID(len(Team_ID) - int(mm.team[player]) - 1)
		mm.color[player] = mm.color[player]
		for other_player in Player_ID {
			if mm.team[other_player] == mm.team[player] {
				sa.push(&mm.allies[player], other_player)
			} else {
				sa.push(&mm.enemies[player], other_player)
			}
		}
	}
}
