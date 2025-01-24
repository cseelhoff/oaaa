package oaaa
import sa "core:container/small_array"
import "core:fmt"

// allied_fighters_exist :: proc(gc: ^Game_Cache, air: Air_ID) -> bool {
// 	for player in sa.slice(&mm.allies[gc.cur_player]) {
// 		if gc.idle_planes[air][player][.FIGHTER] > 0 {
// 			return true
// 		}
// 	}
// 	return false
// }

no_defender_threat_exists :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	if gc.enemy_blockade_total[src_sea] == 0 &&
	   gc.enemy_fighters_total[src_sea] == 0 &&
	   ~(gc.enemy_subs_total[src_sea] > 0 && gc.allied_destroyers_total[src_sea] > 0) {
		return true
	}
	return false
}

get_allied_subs_count :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> (allied_subs: u8) {
	allied_subs = 0
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		allied_subs += gc.idle_ships[src_sea][player][.SUB]
	}
	return
}

disable_bombardment :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	gc.active_ships[src_sea][.CRUISER_BOMBARDED] += gc.active_ships[src_sea][.CRUISER_0_MOVES]
	gc.active_ships[src_sea][.CRUISER_0_MOVES] = 0
	gc.active_ships[src_sea][.BATTLESHIP_BOMBARDED] +=
		gc.active_ships[src_sea][.BATTLESHIP_0_MOVES]
	gc.active_ships[src_sea][.BATTLESHIP_0_MOVES] = 0
	gc.active_ships[src_sea][.BS_DAMAGED_BOMBARDED] +=
		gc.active_ships[src_sea][.BS_DAMAGED_0_MOVES]
	gc.active_ships[src_sea][.BS_DAMAGED_0_MOVES] = 0
}

non_dest_non_sub_exist :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		if gc.idle_ships[src_sea][player][.CARRIER] > 0 ||
		   gc.idle_ships[src_sea][player][.CRUISER] > 0 ||
		   gc.idle_ships[src_sea][player][.BATTLESHIP] > 0 ||
		   gc.idle_ships[src_sea][player][.BS_DAMAGED] > 0 ||
		   gc.idle_sea_planes[src_sea][player][.FIGHTER] > 0 ||
		   gc.idle_sea_planes[src_sea][player][.BOMBER] > 0 {
			return true
		}
	}
	return false
}

build_sea_retreat_options :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	//gc.valid_actions = {to_action(src_sea)}
	if (gc.enemy_blockade_total[src_sea] == 0 && gc.enemy_fighters_total[src_sea] == 0) ||
	   do_sea_targets_exist(gc, src_sea) {
		// I am allowed to stay because I have combat units or no enemy blockade remains
		// otherwise I am possibly wasting transports
		gc.valid_actions += {to_action(src_sea)}
	}
	for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] & gc.sea_no_combat {
		if gc.enemy_blockade_total[dst_sea] == 0 {
			gc.valid_actions += {to_action(dst_sea)}
		}
	}
}

sea_retreat :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) -> bool {
	team := mm.team[gc.cur_player]
	for active_ship in Retreatable_Ships {
		number_of_ships := gc.active_ships[src_sea][active_ship]
		gc.active_ships[dst_sea][Ships_After_Retreat[active_ship]] += number_of_ships
		gc.idle_ships[dst_sea][gc.cur_player][Active_Ship_To_Idle[active_ship]] += number_of_ships
		gc.team_sea_units[dst_sea][team] += number_of_ships
		gc.active_ships[src_sea][active_ship] = 0
		gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[active_ship]] = 0
		gc.team_sea_units[src_sea][team] -= number_of_ships
		for player in sa.slice(&mm.allies[gc.cur_player]) {
			if player == gc.cur_player do continue
			number_of_ships = gc.idle_ships[src_sea][player][Active_Ship_To_Idle[active_ship]]
			gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[active_ship]] += number_of_ships
			gc.team_sea_units[dst_sea][team] += number_of_ships
			gc.idle_ships[src_sea][player][Active_Ship_To_Idle[active_ship]] = 0
			gc.team_sea_units[src_sea][team] -= number_of_ships
		}
	}
	gc.sea_combat_status[src_sea] = .POST_COMBAT
	return true
}

do_sea_targets_exist :: #force_inline proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	return(
		(gc.enemy_subs_total[src_sea] > 0 && gc.allied_destroyers_total[src_sea] > 0) ||
		(gc.enemy_fighters_total[src_sea] > 0 && gc.allied_antifighter_ships_total[src_sea] > 0) ||
		(gc.enemy_subvuln_ships_total[src_sea] > 0 &&
				gc.allied_sea_combatants_total[src_sea] > 0) \
	)
}

// destroy_vulnerable_transports :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
// 	if do_sea_targets_exist(gc, src_sea) do return false
// 	// Perhaps it may be possible to have enemy fighters and friendly subs here?
// 	player_idx := gc.cur_player.index
// 	if src_sea.team_units[gc.cur_player.team.enemy_team.index] > src_sea.enemy_subs_total {
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
				gc.team_sea_units[src_sea][enemy_team] -= gc.idle_ships[src_sea][enemy][transport]
				gc.idle_ships[src_sea][enemy][transport] = 0
			}
		}
	}
	gc.sea_combat_status[src_sea] = .POST_COMBAT
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
	attacker_hits += RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(attacker_damage) % DICE_SIDES ? 1 : 0
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
	defender_hits += RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(defender_damage) % DICE_SIDES ? 1 : 0
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	return
}

no_allied_units_remain :: proc(gc: ^Game_Cache, src_sea: Sea_ID) -> bool {
	if gc.team_sea_units[src_sea][mm.team[gc.cur_player]] > 0 do return false
	gc.sea_combat_status[src_sea] = .POST_COMBAT
	return true
}


resolve_sea_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for src_sea in Sea_ID {
		if gc.sea_combat_status[src_sea] == .NO_COMBAT || gc.sea_combat_status[src_sea] == .POST_COMBAT do continue
		if destroy_defender_transports(gc, src_sea) do continue
		disable_bombardment(gc, src_sea)
		def_subs_targetable := true
		check_positive_active_ships(gc, src_sea)
		for {
			if gc.sea_combat_status[src_sea] == .MID_COMBAT {
				build_sea_retreat_options(gc, src_sea)
				dst_air_idx := get_retreat_input(gc, to_air(src_sea)) or_return
				if sea_retreat(gc, src_sea, to_sea(dst_air_idx)) do break
			}
			//if destroy_vulnerable_transports(gc, &src_sea) do break
			gc.sea_combat_status[src_sea] = .MID_COMBAT
			sub_attacker_damage := int(get_allied_subs_count(gc, src_sea)) * SUB_ATTACK
			sub_attacker_hits := get_attacker_hits(gc, sub_attacker_damage)
			def_subs_targetable = def_subs_targetable && gc.allied_destroyers_total[src_sea] > 0
			if gc.enemy_destroyer_total[src_sea] == 0 {
				remove_sea_defenders(gc, src_sea, &sub_attacker_hits, def_subs_targetable, false)
			}
			def_damage := 0
			if def_subs_targetable do def_damage = get_defender_damage_sub(gc, src_sea)
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

flag_for_land_enemy_combat :: proc(
	gc: ^Game_Cache,
	dst_land: Land_ID,
	enemy_team: Team_ID,
) -> bool {
	if gc.team_land_units[dst_land][enemy_team] == 0 do return false
	gc.land_combat_status[dst_land] = .PRE_COMBAT
	return true
}

flag_for_sea_enemy_combat :: proc(gc: ^Game_Cache, dst_sea: Sea_ID, enemy_team: Team_ID) -> bool {
	if gc.team_sea_units[dst_sea][enemy_team] == 0 do return false
	gc.sea_combat_status[dst_sea] = .PRE_COMBAT
	return true
}

check_for_conquer :: proc(gc: ^Game_Cache, dst_land: Land_ID) -> bool {
	if mm.team[gc.cur_player] == mm.team[gc.owner[dst_land]] do return false
	conquer_land(gc, dst_land)
	return true
}

sea_bombardment :: proc(gc: ^Game_Cache, dst_land: Land_ID) {
	//todo allied ships get unlimited bombards
	for src_sea in sa.slice(&mm.l2s_1away_via_land[dst_land]) {
		if gc.max_bombards[dst_land] == 0 do return
		attacker_damage := 0
		for ship in Bombard_Ships {
			bombarding_ships: u8 = 0
			for ally in sa.slice(&mm.allies[gc.cur_player]) {
				if ally == gc.cur_player do continue
				bombarding_ships = min(
					gc.max_bombards[dst_land],
					gc.idle_ships[src_sea][ally][Active_Ship_To_Idle[ship]],
				)
				gc.max_bombards[dst_land] -= bombarding_ships
				attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
			}
			bombarding_ships = min(gc.max_bombards[dst_land], gc.active_ships[src_sea][ship])
			gc.max_bombards[dst_land] -= bombarding_ships
			attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
			gc.active_ships[src_sea][ship] -= bombarding_ships
			gc.active_ships[src_sea][Ship_After_Bombard[ship]] += bombarding_ships
			if gc.max_bombards[dst_land] == 0 do break
		}
		gc.max_bombards[dst_land] = 0
		attack_hits := get_attacker_hits(gc, attacker_damage)
		remove_land_defenders(gc, dst_land, &attack_hits)
	}
}

fire_tact_aaguns :: proc(gc: ^Game_Cache, dst_land: Land_ID) {
	//todo
	total_aaguns: u8 = 0
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		total_aaguns += gc.idle_armies[dst_land][enemy][.AAGUN]
	}
	total_air_units :=
		gc.idle_land_planes[dst_land][gc.cur_player][.FIGHTER] +
		gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER]
	defender_damage := int(min(total_aaguns * 3, total_air_units))
	defender_hits := get_defender_hits(gc, defender_damage)
	for (defender_hits > 0) {
		defender_hits -= 1
		if hit_my_land_planes(gc, dst_land, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_my_land_planes(gc, dst_land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
	}
}

attempt_conquer_land :: proc(gc: ^Game_Cache, src_land: Land_ID) -> bool {
	if gc.team_land_units[src_land][mm.enemy_team[gc.cur_player]] > 0 do return false
	// if infantry, artillery, tanks exist then capture
	if gc.idle_armies[src_land][gc.cur_player][.INF] > 0 ||
	   gc.idle_armies[src_land][gc.cur_player][.ARTY] > 0 ||
	   gc.idle_armies[src_land][gc.cur_player][.TANK] > 0 {
		conquer_land(gc, src_land)
	}
	return true
}

build_land_retreat_options :: proc(gc: ^Game_Cache, src_land: Land_ID) {
	gc.valid_actions = {to_action(src_land)}
	for &dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
		if gc.land_combat_status[dst_land] == .NO_COMBAT &&
		   mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] {
			gc.valid_actions += {to_action(dst_land)}
		}
	}
}

destroy_undefended_aaguns :: proc(gc: ^Game_Cache, src_land: Land_ID) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_armies[src_land][enemy][Idle_Army.AAGUN] > 0 {
			aaguns := gc.idle_armies[src_land][enemy][Idle_Army.AAGUN]
			gc.idle_armies[src_land][enemy][Idle_Army.AAGUN] = 0
			gc.team_land_units[src_land][mm.team[enemy]] -= aaguns
		}
	}
}

MAX_COMBAT_ROUNDS :: 100
resolve_land_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for src_land in Land_ID {
		if gc.land_combat_status[src_land] == .NO_COMBAT || gc.land_combat_status[src_land] == .POST_COMBAT do continue
		if no_attackers_remain(gc, src_land) do continue
		if gc.land_combat_status[src_land] == .PRE_COMBAT {
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
			if gc.land_combat_status[src_land] == .MID_COMBAT {
				build_land_retreat_options(gc, src_land)
				dst_air := get_retreat_input(gc, to_air(src_land)) or_return
				if retreat_land_units(gc, src_land, Land_ID(dst_air)) do break
			}
			gc.land_combat_status[src_land] = .MID_COMBAT
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
	if gc.team_land_units[src_land][mm.team[gc.cur_player]] == 0 {
		gc.land_combat_status[src_land] = .POST_COMBAT
		return true
	}
	return false
}

strategic_bombing :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	bombers := gc.idle_land_planes[land][gc.cur_player][.BOMBER]
	if bombers == 0 || gc.team_land_units[land][mm.team[gc.cur_player]] > bombers {
		return false
	}
	gc.land_combat_status[land] = .POST_COMBAT
	defender_hits := get_defender_hits(gc, int(bombers))
	for (defender_hits > 0) {
		defender_hits -= 1
		if hit_my_land_planes(gc, land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
		break
	}
	attacker_damage := int(gc.idle_land_planes[land][gc.cur_player][.BOMBER]) * 21
	attacker_hits := get_attacker_hits(gc, attacker_damage)
	gc.factory_dmg[land] = max(gc.factory_dmg[land] + attacker_hits, gc.factory_prod[land] * 2)
	return true
}

retreat_land_units :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) -> bool {
	if dst_land == src_land do return false
	for army in Active_Army {
		number_of_armies := gc.active_armies[src_land][army]
		gc.active_armies[dst_land][army] += number_of_armies
		gc.idle_armies[dst_land][gc.cur_player][Active_Army_To_Idle[army]] += number_of_armies
		gc.team_land_units[dst_land][mm.team[gc.cur_player]] += number_of_armies
		gc.active_armies[src_land][army] = 0
		gc.idle_armies[src_land][gc.cur_player][Active_Army_To_Idle[army]] = 0
		gc.team_land_units[src_land][mm.team[gc.cur_player]] -= number_of_armies
	}
	gc.land_combat_status[src_land] = .POST_COMBAT
	return true
}

remove_sea_attackers :: proc(gc: ^Game_Cache, src_sea: Sea_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_battleship(gc, src_sea, gc.cur_player) do continue
		if hit_ally_battleship(gc, src_sea, gc.cur_player) do continue
		if hit_my_ships(gc, src_sea, Attacker_Sea_Casualty_Order_1, gc.cur_player) do continue
		if hit_ally_ships(gc, src_sea, Attacker_Sea_Casualty_Order_1, gc.cur_player) do continue
		if hit_my_sea_planes(gc, src_sea, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_ally_sea_planes(gc, src_sea, .FIGHTER, gc.cur_player) do continue
		if hit_my_ships(gc, src_sea, Attacker_Sea_Casualty_Order_2, gc.cur_player) do continue
		if hit_ally_ships(gc, src_sea, Attacker_Sea_Casualty_Order_2, gc.cur_player) do continue
		if hit_my_sea_planes(gc, src_sea, Air_Casualty_Order_Bombers, gc.cur_player) do continue
		if hit_my_ships(gc, src_sea, Attacker_Sea_Casualty_Order_3, gc.cur_player) do continue
		if hit_ally_ships(gc, src_sea, Attacker_Sea_Casualty_Order_3, gc.cur_player) do continue
		if hit_my_ships(gc, src_sea, Attacker_Sea_Casualty_Order_4, gc.cur_player) do continue
		if hit_ally_ships(gc, src_sea, Attacker_Sea_Casualty_Order_4, gc.cur_player) do continue
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
		if hit_enemy_battleship(gc, src_sea, &mm.enemies[gc.cur_player]) do continue
		if subs_targetable && hit_enemy_ships(gc, src_sea, Defender_Sub_Casualty, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_ships(gc, src_sea, Defender_Sea_Casualty_Order_1, &mm.enemies[gc.cur_player]) do continue
		if planes_targetable && hit_enemy_sea_fighter(gc, src_sea, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_ships(gc, src_sea, Defender_Sea_Casualty_Order_2, &mm.enemies[gc.cur_player]) do continue
		assert(
			gc.team_sea_units[src_sea][mm.enemy_team[gc.cur_player]] == 0 ||
			!subs_targetable ||
			!planes_targetable,
		)
		return
	}
}

remove_land_attackers :: proc(gc: ^Game_Cache, src_land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_armies(gc, src_land, Attacker_Land_Casualty_Order_1, gc.cur_player) do continue
		if hit_my_land_planes(gc, src_land, Air_Casualty_Order_Fighters, gc.cur_player) do continue
		if hit_my_land_planes(gc, src_land, Air_Casualty_Order_Bombers, gc.cur_player) do continue
	}

}
remove_land_defenders :: proc(gc: ^Game_Cache, src_land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_armies(gc, src_land, Defender_Land_Casualty_Order_1, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_land_planes(gc, src_land, .BOMBER, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_armies(gc, src_land, Defender_Land_Casualty_Order_2, &mm.enemies[gc.cur_player]) do continue
		if hit_enemy_land_planes(gc, src_land, .FIGHTER, &mm.enemies[gc.cur_player]) do continue
	}
}

hit_my_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	if gc.active_ships[sea][.BATTLESHIP_BOMBARDED] > 0 {
		gc.active_ships[sea][.BS_DAMAGED_BOMBARDED] += 1
		gc.idle_ships[sea][player][.BS_DAMAGED] += 1
		gc.active_ships[sea][.BATTLESHIP_BOMBARDED] -= 1
		gc.idle_ships[sea][player][.BATTLESHIP] -= 1
		return true
	}
	return false
}

hit_ally_battleship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, cur_player: Player_ID) -> bool {
	for player in sa.slice(&mm.allies[cur_player]) {
		if player == cur_player do continue
		if gc.idle_ships[src_sea][player][.BATTLESHIP] > 0 {
			gc.idle_ships[src_sea][player][.BATTLESHIP] -= 1
			gc.idle_ships[src_sea][player][.BS_DAMAGED] += 1
			return true
		}
	}
	return false
}

hit_enemy_battleship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, enemies: ^SA_Players) -> bool {
	for player in sa.slice(enemies) {
		if gc.idle_ships[src_sea][player][Idle_Ship.BATTLESHIP] > 0 {
			gc.idle_ships[src_sea][player][Idle_Ship.BATTLESHIP] -= 1
			gc.team_sea_units[src_sea][mm.team[player]] -= 1
			gc.enemy_blockade_total[src_sea] -= 1
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
			gc.team_sea_units[src_sea][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_ally_ships :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	casualty_order: []Active_Ship,
	cur_player: Player_ID,
) -> bool {
	for ship in casualty_order {
		for ally in sa.slice(&mm.allies[cur_player]) {
			if ally == cur_player do continue
			if gc.idle_ships[src_sea][ally][Active_Ship_To_Idle[ship]] > 0 {
				gc.idle_ships[src_sea][ally][Active_Ship_To_Idle[ship]] -= 1
				gc.team_sea_units[src_sea][mm.team[ally]] -= 1
				return true
			}
		}
	}
	return false
}

hit_enemy_ships :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	casualty_order: []Idle_Ship,
	enemies: ^SA_Players,
) -> bool {
	for ship in casualty_order {
		for player in sa.slice(enemies) {
			if gc.idle_ships[src_sea][player][ship] > 0 {
				gc.idle_ships[src_sea][player][ship] -= 1
				gc.team_sea_units[src_sea][mm.team[player]] -= 1
				if ship == .DESTROYER {
					gc.enemy_destroyer_total[src_sea] -= 1
					gc.enemy_blockade_total[src_sea] -= 1
				} else if ship == .SUB {
					gc.enemy_subs_total[src_sea] -= 1
				} else if ship == .CARRIER || ship == .CRUISER || ship == .BS_DAMAGED {
					gc.enemy_blockade_total[src_sea] -= 1
				}
				return true
			}
		}
	}
	return false
}

hit_my_land_planes :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	casualty_order: []Active_Plane,
	cur_player: Player_ID,
) -> bool {
	for plane in casualty_order {
		if gc.active_land_planes[src_land][plane] > 0 {
			gc.active_land_planes[src_land][plane] -= 1
			gc.idle_land_planes[src_land][cur_player][Active_Plane_To_Idle[plane]] -= 1
			gc.team_land_units[src_land][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_my_sea_planes :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	casualty_order: []Active_Plane,
	cur_player: Player_ID,
) -> bool {
	for plane in casualty_order {
		if gc.active_sea_planes[src_sea][plane] > 0 {
			gc.active_sea_planes[src_sea][plane] -= 1
			gc.idle_sea_planes[src_sea][cur_player][Active_Plane_To_Idle[plane]] -= 1
			gc.team_sea_units[src_sea][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_ally_land_planes :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	idle_plane: Idle_Plane,
	cur_player: Player_ID,
) -> bool {
	for ally in sa.slice(&mm.allies[cur_player]) {
		if ally == cur_player do continue
		if gc.idle_land_planes[src_land][ally][idle_plane] > 0 {
			gc.idle_land_planes[src_land][ally][idle_plane] -= 1
			gc.team_land_units[src_land][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}
hit_ally_sea_planes :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	idle_plane: Idle_Plane,
	cur_player: Player_ID,
) -> bool {
	for ally in sa.slice(&mm.allies[cur_player]) {
		if ally == cur_player do continue
		if gc.idle_sea_planes[src_sea][ally][idle_plane] > 0 {
			gc.idle_sea_planes[src_sea][ally][idle_plane] -= 1
			gc.team_sea_units[src_sea][mm.team[cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_enemy_sea_fighter :: proc(gc: ^Game_Cache, sea: Sea_ID, enemies: ^SA_Players) -> bool {
	for enemy in sa.slice(enemies) {
		if gc.idle_sea_planes[sea][enemy][.FIGHTER] > 0 {
			gc.idle_sea_planes[sea][enemy][.FIGHTER] -= 1
			gc.team_sea_units[sea][mm.team[enemy]] -= 1
			gc.enemy_fighters_total[sea] -= 1
			return true
		}
	}
	return false
}

hit_enemy_land_planes :: proc(
	gc: ^Game_Cache,
	land: Land_ID,
	idle_plane: Idle_Plane,
	enemies: ^SA_Players,
) -> bool {
	for enemy in sa.slice(enemies) {
		if gc.idle_land_planes[land][enemy][idle_plane] > 0 {
			gc.idle_land_planes[land][enemy][idle_plane] -= 1
			gc.team_land_units[land][mm.team[enemy]] -= 1
			return true
		}
	}
	return false
}

hit_enemy_sea_planes :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	idle_plane: Idle_Plane,
	enemies: ^SA_Players,
) -> bool {
	for enemy in sa.slice(enemies) {
		if gc.idle_sea_planes[sea][enemy][idle_plane] > 0 {
			gc.idle_sea_planes[sea][enemy][idle_plane] -= 1
			gc.team_sea_units[sea][mm.team[enemy]] -= 1
			return true
		}
	}
	return false
}

hit_my_armies :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	casualty_order: []Active_Army,
	player: Player_ID,
) -> bool {
	for army in casualty_order {
		if gc.active_armies[src_land][army] > 0 {
			gc.active_armies[src_land][army] -= 1
			gc.idle_armies[src_land][player][Active_Army_To_Idle[army]] -= 1
			gc.team_land_units[src_land][mm.team[player]] -= 1
			return true
		}
	}
	return false
}

hit_enemy_armies :: proc(
	gc: ^Game_Cache,
	land: Land_ID,
	casualty_order: []Idle_Army,
	enemy_players: ^SA_Players,
) -> bool {
	for army in casualty_order {
		for player in sa.slice(enemy_players) {
			if gc.idle_armies[land][player][army] > 0 {
				gc.idle_armies[land][player][army] -= 1
				gc.team_land_units[land][mm.team[player]] -= 1
				return true
			}
		}
	}
	return false
}

get_attacker_damage_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		damage += int(gc.idle_ships[sea][ally][.DESTROYER]) * DESTROYER_ATTACK
		damage += int(gc.idle_ships[sea][ally][.CARRIER]) * CARRIER_ATTACK
		damage += int(gc.idle_ships[sea][ally][.CRUISER]) * CRUISER_ATTACK
		damage += int(gc.idle_ships[sea][ally][.BATTLESHIP]) * BATTLESHIP_ATTACK
		damage += int(gc.idle_ships[sea][ally][.BS_DAMAGED]) * BATTLESHIP_ATTACK
		damage += int(gc.idle_sea_planes[sea][ally][.FIGHTER]) * FIGHTER_ATTACK
	}
	damage += int(gc.idle_sea_planes[sea][gc.cur_player][.BOMBER]) * BOMBER_ATTACK
	return damage
}

get_defender_damage_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		damage += int(gc.idle_ships[sea][enemy][.DESTROYER]) * DESTROYER_DEFENSE
		damage += int(gc.idle_ships[sea][enemy][.CARRIER]) * CARRIER_DEFENSE
		damage += int(gc.idle_ships[sea][enemy][.CRUISER]) * CRUISER_DEFENSE
		damage += int(gc.idle_ships[sea][enemy][.BATTLESHIP]) * BATTLESHIP_DEFENSE
		damage += int(gc.idle_ships[sea][enemy][.BS_DAMAGED]) * BATTLESHIP_DEFENSE
		damage += int(gc.idle_sea_planes[sea][enemy][.FIGHTER]) * FIGHTER_DEFENSE
	}
	return damage
}
get_defender_damage_sub :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		damage += int(gc.idle_ships[sea][enemy][.SUB]) * SUB_DEFENSE
	}
	return damage
}

get_attcker_damage_land :: proc(gc: ^Game_Cache, land: Land_ID) -> (damage: int = 0) {
	player := gc.cur_player
	damage += int(gc.idle_armies[land][player][.INF]) * INFANTRY_ATTACK
	damage +=
		int(min(gc.idle_armies[land][player][.INF], gc.idle_armies[land][player][.ARTY])) *
		INFANTRY_ATTACK
	damage += int(gc.idle_armies[land][player][.ARTY]) * ARTILLERY_ATTACK
	damage += int(gc.idle_armies[land][player][.TANK]) * TANK_ATTACK
	damage += int(gc.idle_land_planes[land][player][.FIGHTER]) * FIGHTER_ATTACK
	damage += int(gc.idle_land_planes[land][player][.BOMBER]) * BOMBER_ATTACK
	return damage
}

get_defender_damage_land :: proc(gc: ^Game_Cache, land: Land_ID) -> (damage: int = 0) {
	for player in sa.slice(&mm.enemies[gc.cur_player]) {
		damage += int(gc.idle_armies[land][player][.INF]) * INFANTRY_DEFENSE
		damage += int(gc.idle_armies[land][player][.ARTY]) * ARTILLERY_DEFENSE
		damage += int(gc.idle_armies[land][player][.TANK]) * TANK_DEFENSE
		damage += int(gc.idle_land_planes[land][player][.FIGHTER]) * FIGHTER_DEFENSE
		damage += int(gc.idle_land_planes[land][player][.BOMBER]) * BOMBER_DEFENSE
	}
	return damage
}
