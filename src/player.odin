package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:strings"

PLAYERS_COUNT :: len(PLAYER_DATA)

Player_Data :: struct {
	name:     string,
	team:     string,
	color:    string,
	capital:  string,
	is_human: bool,
}

PLAYER_DATA := [?]Player_Data {
	{team = "Allies", name = "Rus", color = "\033[1;31m", capital = "Moscow"},
	{team = "Axis", name = "Ger", color = "\033[1;34m", capital = "Berlin"},
	{team = "Allies", name = "Eng", color = "\033[1;95m", capital = "London"},
	{team = "Axis", name = "Jap", color = "\033[1;33m", capital = "Tokyo"},
	{team = "Allies", name = "USA", color = "\033[1;32m", capital = "Washington"},
}

DEF_COLOR :: "\033[1;0m"

Players :: [PLAYERS_COUNT]Player
Player :: struct {
	factory_locations:  sa.Small_Array(LANDS_COUNT, ^Land),
	capital:            ^Land,
	team:               ^Team,
	money:              int,
	income_per_turn:    int,
	total_player_units: int,
	index:              Player_ID,
}

TEAM_STRINGS := [?]string{"Allies", "Axis"}
TEAMS_COUNT :: len(TEAM_STRINGS)

Teams :: [TEAMS_COUNT]Team
Team :: struct {
	index:         Team_ID,
	players:       SA_Player_Pointers,
	enemy_players: SA_Player_Pointers,
	enemy_team:    ^Team, // not an array, since assumption is 2 teams
	is_allied:     [PLAYERS_COUNT]bool,
}

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

get_player_idx_from_string :: proc(player_name: string) -> (player_idx: int, ok: bool) {
	for player, player_idx in PLAYER_DATA {
		if strings.compare(player.name, player_name) == 0 {
			return player_idx, true
		}
	}
	fmt.eprintln("Error: Player not found: %s\n", player_name)
	return 0, false
}

initialize_teams :: proc(teams: ^Teams, players: ^Players) {
	for &team, team_idx in teams {
		team.index = Team_ID(team_idx)
		for &other_team in teams {
			if &team != &other_team {
				team.enemy_team = &other_team
				break
			}
		}
		for &player, player_idx in players {
			if strings.compare(PLAYER_DATA[player_idx].team, TEAM_STRINGS[team_idx]) == 0 {
				sa.push(&team.players, &player)
				team.is_allied[player_idx] = true
				player.team = &team
				player.index = Player_ID(player_idx)
			} else {
				sa.push(&team.enemy_players, &player)
				team.is_allied[player_idx] = false
			}
		}
	}
}

initialize_player_lands :: proc(lands: ^Lands, players: ^Players) -> (ok: bool) {
	for &player, player_idx in players {
		land_idx := get_land_idx_from_string(PLAYER_DATA[player_idx].capital) or_return
		player.capital = &lands[land_idx]
	}
	for &land, land_idx in lands {
		player_idx, _ := get_player_idx_from_string(LANDS_DATA[land_idx].owner)
		land.original_owner = &players[player_idx]
	}
	return true
}
