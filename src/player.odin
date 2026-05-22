package oaaa


Player_Data :: struct {
	player:   Nation_ID,
	team:     Team_ID,
	color:    string,
	capital:  Land_ID,
	is_human: bool,
}

DEF_COLOR :: "\033[1;0m"

Factory_Locations :: [dynamic; len(Land_ID)]Land_ID

Nation_ID :: enum {
	Russia,
	Germany,
	United_Kingdom,
	Japan,
	USA,
}

Team_ID :: enum {
	Allies,
	Axis,
}

initialize_player_data :: proc() {
	for player in Nation_ID {
		mm.enemy_team[player] = Team_ID(len(Team_ID) - int(mm.team[player]) - 1)
		mm.color[player] = mm.color[player]
		for other_player in Nation_ID {
			if mm.team[other_player] == mm.team[player] {
				append(&mm.allies[player], other_player)
			} else {
				append(&mm.enemies[player], other_player)
			}
		}
	}
}
