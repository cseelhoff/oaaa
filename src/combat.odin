package oaaa
import sa "core:container/small_array"
import "core:fmt"

allied_fighters_exist :: proc(gc: ^Game_Cache, air: Air_ID) -> bool {
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if gc.idle_planes[air][player][.FIGHTER] > 0 {
			return true
		}
	}
	return false
}

no_defender_threat_exists :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	if gc.enemy_blockade_total[src_sea] == 0 && gc.enemy_fighters_total[src_sea] == 0 {
		if gc.enemy_submarines_total[src_sea] == 0 do return true
		if do_allied_destroyers_exist(gc, src_sea) do return false
		return true
	}
	return false
}

get_allied_subs_count :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> (allied_subs: u8) {
	allied_subs = 0
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		allied_subs += gc.idle_ships[src_sea][player][Idle_Ship.SUB]
	}
	return
}

do_allied_destroyers_exist :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if gc.idle_ships[src_sea][player][Idle_Ship.DESTROYER] > 0 {
			return true
		}
	}
	return false
}

disable_bombardment :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	gc.active_ships[src_sea][Active_Ship.CRUISER_BOMBARDED] +=
		gc.active_ships[src_sea][Active_Ship.CRUISER_0_MOVES]
	gc.active_ships[src_sea][Active_Ship.CRUISER_0_MOVES] = 0
	gc.active_ships[src_sea][Active_Ship.BATTLESHIP_BOMBARDED] +=
		gc.active_ships[src_sea][Active_Ship.BATTLESHIP_0_MOVES]
	gc.active_ships[src_sea][Active_Ship.BATTLESHIP_0_MOVES] = 0
	gc.active_ships[src_sea][Active_Ship.BS_DAMAGED_BOMBARDED] +=
		gc.active_ships[src_sea][Active_Ship.BS_DAMAGED_0_MOVES]
	gc.active_ships[src_sea][Active_Ship.BS_DAMAGED_0_MOVES] = 0
}

non_dest_non_sub_exist :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if gc.idle_ships[src_sea][player][Idle_Ship.CARRIER] > 0 ||
		   gc.idle_ships[src_sea][player][Idle_Ship.CRUISER] > 0 ||
		   gc.idle_ships[src_sea][player][Idle_Ship.BATTLESHIP] > 0 ||
		   gc.idle_ships[src_sea][player][Idle_Ship.BS_DAMAGED] > 0 ||
		   gc.idle_planes[s2aid(src_sea)][player][Idle_Plane.FIGHTER] > 0 ||
		   gc.idle_planes[s2aid(src_sea)][player][Idle_Plane.BOMBER] > 0 {
			return true
		}
	}
	return false
}

build_sea_retreat_options :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	reset_valid_moves(gc, s2aid(src_sea))
	if gc.enemy_blockade_total[src_sea] == 0 &&
		   gc.team_units[s2aid(src_sea)][mm.enemy_team[gc.cur_player]] ==
			   gc.enemy_submarines_total[src_sea] ||
	   gc.active_ships[src_sea][Active_Ship.SUB_0_MOVES] > 0 ||
	   gc.active_ships[src_sea][Active_Ship.DESTROYER_0_MOVES] > 0 ||
	   non_dest_non_sub_exist(gc, src_sea) {
		// I am allowed to stay because I have combat units or no enemy blockade remains
		// otherwise I am possibly wasting transports
		sa.push(&gc.valid_actions, u8(src_sea))
	}

	//for dst_sea in sa.slice(&src_sea.canal_paths[gc.canal_state].adjacent_seas) {
	for dst_sea in sa.slice(&mm.canal_paths[src_sea][transmute(u8)gc.canals_open].adjacent_seas) {
		// todo only allow retreat to valid territories where attack originated
		if dst_sea.enemy_blockade_total == 0 && dst_sea.combat_status == .NO_COMBAT {
			sa.push(&gc.valid_actions, u8(dst_sea.territory_index))
		}
	}
}

sea_retreat :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_air: Air_ID) -> bool {
	if dst_air == s2aid(src_sea) do return false
	dst_sea := get_sea_id(dst_air)
	player_idx := gc.cur_player
	team := mm.team[gc.cur_player]
	for active_ship in Retreatable_Ships {
		number_of_ships := gc.active_ships[src_sea][active_ship]
		gc.active_ships[dst_sea][Ships_After_Retreat[active_ship]] += number_of_ships
		gc.idle_ships[dst_sea][player_idx][Active_Ship_To_Idle[active_ship]] += number_of_ships
		gc.team_units[s2aid(dst_sea)][team] += number_of_ships
		gc.active_ships[src_sea][active_ship] = 0
		gc.idle_ships[src_sea][player_idx][Active_Ship_To_Idle[active_ship]] = 0
		gc.team_units[s2aid(src_sea)][team] -= number_of_ships
		for player in sa.slice(&mm.allies[gc.cur_player]) {
			if player == gc.cur_player do continue
			number_of_ships = gc.idle_ships[src_sea][player][Active_Ship_To_Idle[active_ship]]
			gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[active_ship]] += number_of_ships
			gc.team_units[s2aid(dst_sea)][team] += number_of_ships
			gc.idle_ships[src_sea][player][Active_Ship_To_Idle[active_ship]] = 0
			gc.team_units[s2aid(src_sea)][team] -= number_of_ships
		}
	}
	gc.combat_status[s2aid(src_sea)] = .POST_COMBAT
	return true
}

do_sea_targets_exist :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	enemy_team_idx := mm.enemy_team[gc.cur_player]
	if gc.active_ships[src_sea][Active_Ship.DESTROYER_0_MOVES] > 0 {
		return gc.team_units[s2aid(src_sea)][enemy_team_idx] > 0
	} else if non_dest_non_sub_exist(gc, src_sea) {
		return gc.team_units[s2aid(src_sea)][enemy_team_idx] > gc.enemy_submarines_total[src_sea]
	} else if get_allied_subs_count(gc, src_sea) > 0 {
		return(
			gc.team_units[s2aid(src_sea)][enemy_team_idx] >
			gc.enemy_submarines_total[src_sea] + gc.enemy_fighters_total[src_sea] \
		)
	}
	return false
}

// destroy_vulnerable_transports :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
// 	if do_sea_targets_exist(gc, src_sea) do return false
// 	// Perhaps it may be possible to have enemy fighters and friendly subs here?
// 	player_idx := gc.cur_player.index
// 	if src_sea.team_units[gc.cur_player.team.enemy_team.index] > src_sea.enemy_submarines_total {
// 		// I dont think this is reachable
// 		fmt.eprintln("destroy_vulnerable_transports: unreachable code")
// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_EMPTY] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_EMPTY_0_MOVES] = 0

// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_1I_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_1I] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_1I_0_MOVES] = 0

// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_1A_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_1A] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_1A_0_MOVES] = 0

// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_1T_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_1T] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_1T_0_MOVES] = 0

// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_1I_1A_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_1I_1A] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_1I_1A_0_MOVES] = 0

// 		src_sea.team_units[gc.cur_player.team.index] -=
// 			gc.active_ships[src_sea][Active_Ship.TRANS_1I_1T_0_MOVES]
// 		src_sea.idle_ships[player_idx][Idle_Ship.TRANS_1I_1T] = 0
// 		gc.active_ships[src_sea][Active_Ship.TRANS_1I_1T_0_MOVES] = 0
// 	}
// 	src_sea.combat_status = .POST_COMBAT
// 	return true
// }

destroy_defender_transports :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	if !no_defender_threat_exists(gc, src_sea) do return false
	if do_sea_targets_exist(gc, src_sea) {
		enemy_team := mm.enemy_team[gc.cur_player]
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			for transport in Idle_Transports {
				gc.team_units[s2aid(src_sea)][enemy_team] -=
					gc.idle_ships[src_sea][enemy][transport]
				gc.idle_ships[src_sea][enemy][transport] = 0
			}
		}
	}
	gc.combat_status[s2aid(src_sea)] = .POST_COMBAT
	return true
}
DICE_SIDES :: 6
get_attacker_hits :: proc(gc: ^Game_Cache, attacker_damage: int) -> (attacker_hits: u8) {
	attacker_hits = u8(attacker_damage / DICE_SIDES)
	// todo why does this check for 2 answers remaining?
	if gc.answers_remaining <= 1 {
		if mm.enemy_team[gc.cur_player] in gc.unlucky_teams { 	// attacker is lucky
			attacker_hits += 0 < attacker_damage % DICE_SIDES ? 1 : 0 // no dice, round up
			return
		}
	}
	attacker_hits += RANDOM_NUMBERS[gc.seed] % DICE_SIDES < attacker_damage % DICE_SIDES ? 1 : 0
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	return
}

get_defender_hits :: proc(gc: ^Game_Cache, defender_damage: int) -> (defender_hits: u8) {
	defender_hits = u8(defender_damage / DICE_SIDES)
	if gc.answers_remaining <= 1 {
		if mm.team[gc.cur_player] in gc.unlucky_teams { 	// attacker is unlucky
			defender_hits += 0 < defender_damage % DICE_SIDES ? 1 : 0 // no dice, round up
			return
		}
	}
	defender_hits += RANDOM_NUMBERS[gc.seed] % DICE_SIDES < defender_damage % DICE_SIDES ? 1 : 0
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	return
}

no_allied_units_remain :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	if gc.team_units[s2aid(src_sea)][mm.team[gc.cur_player]] > 0 do return false
	gc.combat_status[s2aid(src_sea)] = .POST_COMBAT
	return true
}

resolve_sea_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for src_sea in Sea_ID {
		if gc.combat_status[s2aid(src_sea)] == .NO_COMBAT || gc.combat_status[s2aid(src_sea)] == .POST_COMBAT do continue
		if destroy_defender_transports(gc, src_sea) do continue
		disable_bombardment(gc, src_sea)
		def_subs_targetable := true
		check_positive_active_ships(gc, src_sea)
		for {
			if gc.combat_status[s2aid(src_sea)] == .MID_COMBAT {
				build_sea_retreat_options(gc, src_sea)
				dst_air_idx := get_retreat_input(gc, s2aid(src_sea)) or_return
				if sea_retreat(gc, src_sea, dst_air_idx) do break
			}
			//if destroy_vulnerable_transports(gc, &src_sea) do break
			gc.combat_status[s2aid(src_sea)] = .MID_COMBAT
			sub_attacker_damage := int(get_allied_subs_count(gc, src_sea)) * SUB_ATTACK
			sub_attacker_hits := get_attacker_hits(gc, sub_attacker_damage)
			def_subs_targetable = def_subs_targetable && do_allied_destroyers_exist(gc, src_sea)
			if gc.enemy_destroyer_total[src_sea] == 0 {
				remove_sea_defenders(gc, src_sea, &sub_attacker_hits, def_subs_targetable, false)
			}
			def_damage := 0
			if def_subs_targetable do def_damage = int(gc.enemy_submarines_total[src_sea]) * SUB_DEFENSE
			attacker_damage := get_attacker_damage_sea(gc, src_sea)
			attacker_hits := get_attacker_hits(gc, attacker_damage)
			def_damage += get_defender_damage_sea(gc, src_sea)
			def_hits := get_defender_hits(gc, def_damage)
			remove_sea_attackers(gc, src_sea, &def_hits)
			if gc.enemy_destroyer_total[src_sea] > 0 {
				remove_sea_defenders(gc, src_sea, &sub_attacker_hits, def_subs_targetable, false)
			}
			remove_sea_defenders(gc, src_sea, &attacker_hits, def_subs_targetable, true)
			if no_allied_units_remain(gc, src_sea) do break
			if destroy_defender_transports(gc, src_sea) do break
		}
	}
	return true
}

flag_for_enemy_combat :: proc(gc: ^Game_Cache, dst_air: Air_ID, enemy_team: Team_ID) -> bool {
	if gc.team_units[dst_air][enemy_team] == 0 do return false
	gc.combat_status[dst_air] = .PRE_COMBAT
	return true
}

check_for_conquer :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> bool {
	if mm.team[gc.cur_player] == mm.team[gc.owner[dst_land]] do return false
	conquer_land(gc, dst_land)
	return true
}

sea_bombardment :: proc(gc: ^Game_Cache, dst_land: Land_ID) {
	//todo allied ships get unlimited bombards
	for src_sea in sa.slice(&mm.adj_l2s[dst_land]) {
		if gc.max_bombards[dst_land] == 0 do return
		attacker_damage := 0
		for ship in Bombard_Ships {
			bombarding_ships: u8 = 0
			for ally in sa.slice(&mm.allies[gc.cur_player]) {
				if ally == gc.cur_player do continue
				bombarding_ships = min(
					dst_land.max_bombards,
					src_sea.idle_ships[ally][Active_Ship_To_Idle[ship]],
				)
				dst_land.max_bombards -= bombarding_ships
				attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
			}
			bombarding_ships = min(dst_land.max_bombards, gc.active_ships[src_sea][ship])
			dst_land.max_bombards -= bombarding_ships
			attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
			gc.active_ships[src_sea][ship] -= bombarding_ships
			gc.active_ships[src_sea][Ship_After_Bombard[ship]] += bombarding_ships
			if dst_land.max_bombards == 0 do break
		}
		dst_land.max_bombards = 0
		attack_hits := get_attacker_hits(gc, attacker_damage)
		remove_land_defenders(gc, dst_land, &attack_hits)
	}
}

fire_tact_aaguns :: proc(gc: ^Game_Cache, dst_land: Land_ID) {
	//todo
	total_aaguns: u8 = 0
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		total_aaguns += gc.idle_armies[dst_land][enemy][Idle_Army.AAGUN]
	}
	total_air_units :=
		gc.idle_planes[dst_land][gc.cur_player][Idle_Plane.FIGHTER] +
		gc.idle_planes[dst_land][gc.cur_player][Idle_Plane.BOMBER]
	defender_damage := int(min(total_aaguns * 3, total_air_units))
	defender_hits := get_defender_hits(gc, defender_damage)
	for (defender_hits > 0) {
		defender_hits -= 1
		if hit_my_planes(dst_land, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_my_planes(dst_land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
	}
}

attempt_conquer_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> bool {
	if gc.team_units[l2aid(src_land)][mm.enemy_team[gc.cur_player]] > 0 do return false
	// if infantry, artillery, tanks exist then capture
	if gc.idle_armies[src_land][gc.cur_player][Idle_Army.INF] > 0 ||
	   gc.idle_armies[src_land][gc.cur_player][Idle_Army.ARTY] > 0 ||
	   gc.idle_armies[src_land][gc.cur_player][Idle_Army.TANK] > 0 {
		conquer_land(gc, src_land)
	}
	return true
}

build_land_retreat_options :: proc(gc: ^Game_Cache, src_land: Land_ID) {
	reset_valid_moves(gc, l2aid(src_land))
	for &dst_land in sa.slice(&mm.adj_l2l[src_land]) {
		if gc.combat_status[l2aid(dst_land)] == .NO_COMBAT &&
		   mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] {
			sa.push(&gc.valid_actions, u8(dst_land))
		}
	}
}

destroy_undefended_aaguns :: proc(gc: ^Game_Cache, src_land: Land_ID) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_armies[src_land][enemy][Idle_Army.AAGUN] > 0 {
			aaguns := gc.idle_armies[src_land][enemy][Idle_Army.AAGUN]
			gc.idle_armies[src_land][enemy][Idle_Army.AAGUN] = 0
			gc.team_units[l2aid(src_land)][mm.team[enemy]] -= aaguns
		}
	}
}

MAX_COMBAT_ROUNDS :: 100
resolve_land_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for src_land in Land_ID {
		if gc.combat_status[src_land] == .NO_COMBAT || gc.combat_status[src_land] == .POST_COMBAT do continue
		if no_attackers_remain(gc, src_land) do continue
		if src_land.combat_status == .PRE_COMBAT {
			if strategic_bombing(gc, src_land) do continue
			sea_bombardment(gc, src_land)
			fire_tact_aaguns(gc, src_land)
			if no_attackers_remain(gc, src_land) do continue
			if attempt_conquer_land(gc, src_land) do continue
		}
		combat_rounds := 0
		for {
			combat_rounds += 1
			if combat_rounds > MAX_COMBAT_ROUNDS {
				fmt.eprintln("resolve_land_battles: MAX_COMBAT_ROUNDS reached", combat_rounds)
				print_game_state(gc)
			}
			if gc.combat_status[src_land] == .MID_COMBAT {
				build_land_retreat_options(gc, src_land)
				dst_air_idx := get_retreat_input(gc, src_land) or_return
				if retreat_land_units(gc, src_land, dst_air_idx) do break
			}
			gc.combat_status[src_land] = .MID_COMBAT
			attacker_hits := get_attacker_hits(gc, get_attcker_damage_land(gc, src_land))
			defender_hits := get_defender_hits(gc, get_defender_damage_land(gc, src_land))
			remove_land_attackers(gc, src_land, &defender_hits)
			remove_land_defenders(gc, src_land, &attacker_hits)
			destroy_undefended_aaguns(gc, src_land)
			if no_attackers_remain(gc, src_land) do break
			if attempt_conquer_land(gc, src_land) do break
		}
	}
	return true
}

no_attackers_remain :: proc(gc: ^Game_Cache, src_land: Land_ID) -> bool {
	if src_land.team_units[gc.cur_player.team.index] == 0 {
		src_land.combat_status = .POST_COMBAT
		return true
	}
	return false
}

strategic_bombing :: proc(gc: ^Game_Cache, src_land: Land_ID) -> bool {
	bombers := src_land.idle_planes[gc.cur_player.index][Idle_Plane.BOMBER]
	if bombers == 0 || src_land.team_units[gc.cur_player.team.index] > bombers {
		return false
	}
	src_land.combat_status = .POST_COMBAT
	// if src_land.factory_dmg == src_land.factory_prod do return true
	defender_hits := get_defender_hits(gc, int(bombers))
	for (defender_hits > 0) {
		defender_hits -= 1
		if hit_my_planes(src_land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
		break
	}
	attacker_damage := int(src_land.idle_planes[gc.cur_player.index][Idle_Plane.BOMBER]) * 21
	attacker_hits := get_attacker_hits(gc, attacker_damage)
	src_land.factory_dmg = max(src_land.factory_dmg + attacker_hits, src_land.factory_prod * 2)
	return true
}

retreat_land_units :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_air_idx: Air_ID) -> bool {
	dst_land := get_land(gc, dst_air_idx)
	if dst_land == src_land do return false
	for army in Active_Army {
		number_of_armies := gc.active_armies[src_land][army]
		gc.active_armies[dst_land][army] += number_of_armies
		gc.idle_armies[dst_land][gc.cur_player.index][Active_Army_To_Idle[army]] +=
			number_of_armies
		gc.team_units[dst_land][gc.cur_player.team.index] += number_of_armies
		gc.active_armies[src_land][army] = 0
		gc.idle_armies[src_land][gc.cur_player.index][Active_Army_To_Idle[army]] = 0
		src_land.team_units[gc.cur_player.team.index] -= number_of_armies
	}
	src_land.combat_status = .POST_COMBAT
	return true
}

remove_sea_attackers :: proc(gc: ^Game_Cache, src_sea: Sea_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_battleship(src_sea, gc.cur_player) do continue
		if hit_ally_battleship(src_sea, gc.cur_player) do continue
		if hit_my_ships(src_sea, Attacker_Sea_Casualty_Order_1, gc.cur_player) do continue
		if hit_ally_ships(src_sea, Attacker_Sea_Casualty_Order_1, gc.cur_player) do continue
		if hit_my_planes(src_sea, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_ally_planes(src_sea, .FIGHTER, gc.cur_player) do continue
		if hit_my_ships(src_sea, Attacker_Sea_Casualty_Order_2, gc.cur_player) do continue
		if hit_ally_ships(src_sea, Attacker_Sea_Casualty_Order_2, gc.cur_player) do continue
		if hit_my_planes(src_sea, Air_Casualty_Order_Bombers, gc.cur_player) do continue
		if hit_my_ships(src_sea, Attacker_Sea_Casualty_Order_3, gc.cur_player) do continue
		if hit_ally_ships(src_sea, Attacker_Sea_Casualty_Order_3, gc.cur_player) do continue
		if hit_my_ships(src_sea, Attacker_Sea_Casualty_Order_4, gc.cur_player) do continue
		if hit_ally_ships(src_sea, Attacker_Sea_Casualty_Order_4, gc.cur_player) do continue
		return
	}
}

remove_sea_defenders :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	hits: ^u8,
	subs_targetable: bool,
	planes_targetable: bool,
) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_battleship(src_sea, &mm.enemies[gc.cur_player]) do continue
		if subs_targetable && hit_enemy_ships(src_sea, Defender_Sub_Casualty, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_ships(src_sea, Defender_Sea_Casualty_Order_1, &mm.enemies[gc.cur_player]) do continue
		if planes_targetable && hit_enemy_sea_fighter(src_sea, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_ships(src_sea, Defender_Sea_Casualty_Order_2, &mm.enemies[gc.cur_player]) do continue
		assert(
			src_sea.team_units[gc.cur_player.team.enemy_team.index] == 0 ||
			!subs_targetable ||
			!planes_targetable,
		)
		return
	}
}

remove_land_attackers :: proc(gc: ^Game_Cache, src_land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_armies(src_land, Attacker_Land_Casualty_Order_1, gc.cur_player) do continue
		if hit_my_planes(src_land, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_my_planes(src_land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
	}

}
remove_land_defenders :: proc(gc: ^Game_Cache, src_land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_armies(src_land, Defender_Land_Casualty_Order_1, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_planes(src_land, .BOMBER, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_armies(src_land, Defender_Land_Casualty_Order_2, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_planes(src_land, .FIGHTER, &mm.enemies[gc.cur_player]) do continue
	}
}

hit_my_battleship :: proc(src_sea: Sea_ID, player: Player_ID) -> bool {
	if gc.active_ships[src_sea][Active_Ship.BATTLESHIP_BOMBARDED] > 0 {
		gc.active_ships[src_sea][Active_Ship.BS_DAMAGED_BOMBARDED] += 1
		src_sea.idle_ships[player][Idle_Ship.BS_DAMAGED] += 1
		gc.active_ships[src_sea][Active_Ship.BATTLESHIP_BOMBARDED] -= 1
		src_sea.idle_ships[player][Idle_Ship.BATTLESHIP] -= 1
		return true
	}
	return false
}

hit_ally_battleship :: proc(src_sea: Sea_ID, cur_player: Player_ID) -> bool {
	for player in sa.slice(&mm.allies[cur_player]) {
		if player == cur_player do continue
		if src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP] > 0 {
			src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP] -= 1
			src_sea.idle_ships[player.index][Idle_Ship.BS_DAMAGED] += 1
			return true
		}
	}
	return false
}

hit_enemy_battleship :: proc(src_sea: Sea_ID, enemies: [Player_ID]SA_Players) -> bool {
	for player in sa.slice(enemies) {
		if src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP] > 0 {
			src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP] -= 1
			src_sea.team_units[player.team.index] -= 1
			src_sea.enemy_blockade_total -= 1
			return true
		}
	}
	return false
}

hit_my_ships :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	casualty_order: []Active_Ship,
	cur_player: Player_ID,
) -> bool {
	for ship in casualty_order {
		if gc.active_ships[src_sea][ship] > 0 {
			gc.active_ships[src_sea][ship] -= 1
			gc.idle_ships[src_sea][cur_player][Active_Ship_To_Idle[ship]] -= 1
			gc.team_units[src_sea][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_ally_ships :: proc(
	src_sea: Sea_ID,
	casualty_order: []Active_Ship,
	cur_player: ^Player,
) -> bool {
	for ship in casualty_order {
		for player in sa.slice(&cur_player.team.players) {
			if player == cur_player do continue
			if src_sea.idle_ships[player.index][Active_Ship_To_Idle[ship]] > 0 {
				src_sea.idle_ships[player.index][Active_Ship_To_Idle[ship]] -= 1
				src_sea.team_units[player.team.index] -= 1
				return true
			}
		}
	}
	return false
}

hit_enemy_ships :: proc(
	src_sea: Sea_ID,
	casualty_order: []Idle_Ship,
	enemy_players: ^SA_Player_Pointers,
) -> bool {
	for ship in casualty_order {
		for player in sa.slice(enemy_players) {
			if src_sea.idle_ships[player.index][ship] > 0 {
				src_sea.idle_ships[player.index][ship] -= 1
				src_sea.team_units[player.team.index] -= 1
				if ship == .DESTROYER {
					src_sea.enemy_destroyer_total -= 1
					src_sea.enemy_blockade_total -= 1
				} else if ship == .SUB {
					src_sea.enemy_submarines_total -= 1
				} else if ship == .CARRIER || ship == .CRUISER || ship == .BS_DAMAGED {
					src_sea.enemy_blockade_total -= 1
				}
				return true
			}
		}
	}
	return false
}

hit_my_planes :: proc(
	src_air: Air_ID,
	casualty_order: []Active_Plane,
	cur_player: ^Player,
) -> bool {
	for plane in casualty_order {
		if src_air.active_planes[plane] > 0 {
			src_air.active_planes[plane] -= 1
			src_air.idle_planes[cur_player.index][Active_Plane_To_Idle[plane]] -= 1
			src_air.team_units[cur_player.team.index] -= 1
			return true
		}
	}
	return false
}

hit_ally_planes :: proc(src_air: Air_ID, idle_plane: Idle_Plane, cur_player: ^Player) -> bool {
	for player in sa.slice(&cur_player.team.players) {
		if player == cur_player do continue
		if src_air.idle_planes[player.index][idle_plane] > 0 {
			src_air.idle_planes[player.index][idle_plane] -= 1
			src_air.team_units[player.team.index] -= 1
			return true
		}
	}
	return false
}

hit_enemy_sea_fighter :: proc(src_sea: Sea_ID, enemy_players: ^SA_Player_Pointers) -> bool {
	for player in sa.slice(enemy_players) {
		if src_sea.idle_planes[player.index][Idle_Plane.FIGHTER] > 0 {
			src_sea.idle_planes[player.index][Idle_Plane.FIGHTER] -= 1
			src_sea.team_units[player.team.index] -= 1
			src_sea.enemy_fighters_total -= 1
			return true
		}
	}
	return false
}

hit_enemy_planes :: proc(
	src_air: Air_ID,
	idle_plane: Idle_Plane,
	enemy_players: ^SA_Player_Pointers,
) -> bool {
	for player in sa.slice(enemy_players) {
		if src_air.idle_planes[player.index][idle_plane] > 0 {
			src_air.idle_planes[player.index][idle_plane] -= 1
			src_air.team_units[player.team.index] -= 1
			return true
		}
	}
	return false
}

hit_my_armies :: proc(
	src_land: Land_ID,
	casualty_order: []Active_Army,
	cur_player: ^Player,
) -> bool {
	for army in casualty_order {
		if gc.active_armies[src_land][army] > 0 {
			gc.active_armies[src_land][army] -= 1
			gc.idle_armies[src_land][cur_player.index][Active_Army_To_Idle[army]] -= 1
			src_land.team_units[cur_player.team.index] -= 1
			return true
		}
	}
	return false
}

hit_enemy_armies :: proc(
	src_land: Land_ID,
	casualty_order: []Idle_Army,
	enemy_players: ^SA_Player_Pointers,
) -> bool {
	for army in casualty_order {
		for player in sa.slice(enemy_players) {
			if gc.idle_armies[src_land][player.index][army] > 0 {
				gc.idle_armies[src_land][player.index][army] -= 1
				src_land.team_units[player.team.index] -= 1
				return true
			}
		}
	}
	return false
}

get_attacker_damage_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> (damage: int = 0) {
	for player in sa.slice(&gc.cur_player.team.players) {
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.DESTROYER]) * DESTROYER_ATTACK
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.CARRIER]) * CARRIER_ATTACK
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.CRUISER]) * CRUISER_ATTACK
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP]) * BATTLESHIP_ATTACK
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.BS_DAMAGED]) * BATTLESHIP_ATTACK
		damage += int(src_sea.idle_planes[player.index][Idle_Plane.FIGHTER]) * FIGHTER_ATTACK
	}
	damage += int(src_sea.idle_planes[gc.cur_player.index][Idle_Plane.BOMBER]) * BOMBER_ATTACK
	return damage
}

get_defender_damage_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> (damage: int = 0) {
	for player in sa.slice(&gc.cur_player.team.enemy_players) {
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.DESTROYER]) * DESTROYER_DEFENSE
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.CARRIER]) * CARRIER_DEFENSE
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.CRUISER]) * CRUISER_DEFENSE
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.BATTLESHIP]) * BATTLESHIP_DEFENSE
		damage += int(src_sea.idle_ships[player.index][Idle_Ship.BS_DAMAGED]) * BATTLESHIP_DEFENSE
		damage += int(src_sea.idle_planes[player.index][Idle_Plane.FIGHTER]) * FIGHTER_DEFENSE
	}
	return damage
}

get_attcker_damage_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> (damage: int = 0) {
	player_idx := gc.cur_player.index
	damage += int(gc.idle_armies[src_land][player_idx][Idle_Army.INF]) * INFANTRY_ATTACK
	damage +=
		int(
			min(
				gc.idle_armies[src_land][player_idx][Idle_Army.INF],
				gc.idle_armies[src_land][player_idx][Idle_Army.ARTY],
			),
		) *
		INFANTRY_ATTACK
	damage += int(gc.idle_armies[src_land][player_idx][Idle_Army.ARTY]) * ARTILLERY_ATTACK
	damage += int(gc.idle_armies[src_land][player_idx][Idle_Army.TANK]) * TANK_ATTACK
	damage += int(src_land.idle_planes[player_idx][Idle_Plane.FIGHTER]) * FIGHTER_ATTACK
	damage += int(src_land.idle_planes[player_idx][Idle_Plane.BOMBER]) * BOMBER_ATTACK
	return damage
}

get_defender_damage_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> (damage: int = 0) {
	for player in sa.slice(&gc.cur_player.team.enemy_players) {
		damage += int(gc.idle_armies[src_land][player.index][Idle_Army.INF]) * INFANTRY_DEFENSE
		damage += int(gc.idle_armies[src_land][player.index][Idle_Army.ARTY]) * ARTILLERY_DEFENSE
		damage += int(gc.idle_armies[src_land][player.index][Idle_Army.TANK]) * TANK_DEFENSE
		damage += int(src_land.idle_planes[player.index][Idle_Plane.FIGHTER]) * FIGHTER_DEFENSE
		damage += int(src_land.idle_planes[player.index][Idle_Plane.BOMBER]) * BOMBER_DEFENSE
	}
	return damage
}
