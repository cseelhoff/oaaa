package oaaa

import "core:fmt"

Land_Defenders :: struct {
	Infantry:  u8,
	Artillery: u8,
	AntiAir:   u8,
	Tanks:     u8,
	Fighters:  u8,
	Bombers:   u8,
}

Land_Attackers :: struct {
	Infantry:  u8,
	Artillery: u8,
	Tanks:     u8,
	Fighters:  u8,
	Bombers:   u8,
}

Land_Combatants :: struct {
	defenders: Land_Defenders,
	attackers: [3]Land_Attackers,
}

Battle_Results :: struct {
	avg_TUV_swing:   f64,
	invaded_percent: f64,
	avg_survivor_def_power: f64,
}

Land_Combatants_Counter :: struct {
	defenders: Land_Defenders,
	attackers: Land_Attackers,
	counter_attackers: Land_Attackers,
}

get_battle_results :: proc(combatants: Land_Combatants) -> Battle_Results {
	if result, exists := mm.battle_results[combatants]; exists {
		return result
	}
	// Compute battle results if not cached
	result := simulate_battle(combatants)
	mm.battle_results[combatants] = result
	return result
}

simulate_battle :: proc(combatants: Land_Combatants) -> Battle_Results {
	simulations_count := 1000
	invasions := 0
	tuv_swing: i32 = 0
	survivor_def_power: i32 = 0
	for i in 0 ..< simulations_count {
		def := combatants.defenders
		for att_wave in 0 ..< len(combatants.attackers) {
			att := combatants.attackers[att_wave]
			// resolve_naval_bombardment(gc, land)
			sim_tactical_aa_defense(def.AntiAir, &att.Fighters, &att.Bombers, &tuv_swing)
			for combat_round in 0 ..< MAX_COMBAT_ROUNDS {
				if sim_no_defenders_remain(&def) || sim_no_attackers_remain(&att) do break
				attacker_hits := sim_attacker_hits(&att)
				defender_hits := sim_defender_hits(&def)
				remove_attackers(&att, defender_hits, &tuv_swing)
				remove_defenders(&def, attacker_hits, &tuv_swing)
			}

			if sim_no_defenders_remain(&def) {
				if sim_invaders_remain(&att) {
					tuv_swing += i32(def.AntiAir) * i32(Cost_Buy[.BUY_AAGUN_ACTION])
					def.AntiAir = 0
					invasions += 1
					survivor_def_power += i32(att.Infantry) * i32(INFANTRY_DEFENSE)
					survivor_def_power += i32(att.Artillery) * i32(ARTILLERY_DEFENSE)
					survivor_def_power += i32(att.Tanks) * i32(TANK_DEFENSE)
					break
				}
			}
		}
	}
	result := Battle_Results {
		avg_TUV_swing        = f64(tuv_swing) / f64(simulations_count),
		invaded_percent      = f64(invasions) / f64(simulations_count),
		avg_survivor_def_power = f64(survivor_def_power) / f64(simulations_count),
	}
	return result
}

simulate_battle_countered :: proc(combatants: Land_Combatants_Counter) -> Battle_Results {
	simulations_count := 1000
	invasions := 0
	tuv_swing: i32 = 0
	for i in 0 ..< simulations_count {
		def := combatants.defenders
		att := combatants.attackers
		// resolve_naval_bombardment(gc, land)
		sim_tactical_aa_defense(def.AntiAir, &att.Fighters, &att.Bombers, &tuv_swing)
		for combat_round in 0 ..< MAX_COMBAT_ROUNDS {
			if sim_no_defenders_remain(&def) {
				if sim_invaders_remain(&att) {
					//PREPARE FOR COUNTER-ATTACK
					new_defenders := Land_Defenders {
						Infantry = att.Infantry,
						Artillery = att.Artillery,
						Tanks = att.Tanks,
						AntiAir = def.AntiAir,
					}
					
					tuv_swing += i32(def.AntiAir) * i32(Cost_Buy[.BUY_AAGUN_ACTION])
					def.AntiAir = 0
					invasions += 1
				}
				break
			}
			if sim_no_attackers_remain(&att) {
				break
			}
			attacker_hits := sim_attacker_hits(&att)
			defender_hits := sim_defender_hits(&def)
			remove_attackers(&att, defender_hits, &tuv_swing)
			remove_defenders(&def, attacker_hits, &tuv_swing)
		}
	}
	result := Battle_Results {
		avg_TUV_swing   = f64(tuv_swing) / f64(simulations_count),
		invaded_percent = f64(invasions) / f64(simulations_count),
	}
	return result
}


sim_seed := 0
sim_tactical_aa_defense :: proc(total_aaguns: u8, fighters: ^u8, bombers: ^u8, tuv_swing: ^i32) {
	total_air_targets := fighters^ + bombers^
	total_defense_value := u16(min(total_aaguns * 3, total_air_targets))
	hits := sim_low_luck(total_defense_value)
	if hits > fighters^ {
		tuv_swing^ -= i32(fighters^) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
		hits -= fighters^
		fighters^ = 0
	} else {
		fighters^ -= hits
		tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
		return
	}
	if hits > bombers^ {
		tuv_swing^ -= i32(bombers^) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
		bombers^ = 0
		return
	}
	bombers^ -= hits
	tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
	return
}

sim_low_luck :: #force_inline proc(total_attack_value: u16) -> (hits: u8) {
	hits = u8(total_attack_value / DICE_SIDES)
	hits += RANDOM_NUMBERS[sim_seed] % DICE_SIDES < u16(total_attack_value) % DICE_SIDES ? 1 : 0
	sim_seed = (sim_seed + 1) % RANDOM_MAX
	return hits
}

sim_no_defenders_remain :: #force_inline proc(defenders: ^Land_Defenders) -> bool {
	return(
		defenders.Infantry == 0 &&
		defenders.Artillery == 0 &&
		defenders.Tanks == 0 &&
		defenders.Fighters == 0 &&
		defenders.Bombers == 0 \
	)
}

sim_no_attackers_remain :: #force_inline proc(attackers: ^Land_Attackers) -> bool {
	return(
		attackers.Fighters == 0 &&
		attackers.Bombers == 0 &&
		attackers.Infantry == 0 &&
		attackers.Artillery == 0 &&
		attackers.Tanks == 0 \
	)
}

sim_invaders_remain :: #force_inline proc(attackers: ^Land_Attackers) -> bool {
	return attackers.Infantry > 0 || attackers.Artillery > 0 || attackers.Tanks > 0
}

sim_attacker_hits :: #force_inline proc(attackers: ^Land_Attackers) -> u8 {
	damage: u16 = 0
	damage += u16(attackers.Infantry) * INFANTRY_ATTACK
	damage += u16(min(attackers.Infantry, attackers.Artillery)) * INFANTRY_ATTACK
	damage += u16(attackers.Artillery) * ARTILLERY_ATTACK
	damage += u16(attackers.Tanks) * TANK_ATTACK
	damage += u16(attackers.Fighters) * FIGHTER_ATTACK
	damage += u16(attackers.Bombers) * BOMBER_ATTACK
	return sim_low_luck(damage)
}

sim_defender_hits :: #force_inline proc(defenders: ^Land_Defenders) -> u8 {
	return sim_low_luck(
		u16(defenders.Infantry) * INFANTRY_DEFENSE +
		u16(defenders.Artillery) * ARTILLERY_DEFENSE +
		u16(defenders.Tanks) * TANK_DEFENSE +
		u16(defenders.Fighters) * FIGHTER_DEFENSE +
		u16(defenders.Bombers) * BOMBER_DEFENSE,
	)
}

remove_attackers :: proc(attackers: ^Land_Attackers, total_hits: u8, tuv_swing: ^i32) {
	hits := total_hits
	if hits > attackers.Infantry {
		tuv_swing^ -= i32(attackers.Infantry) * i32(Cost_Buy[.BUY_INF_ACTION])
		hits -= attackers.Infantry
		attackers.Infantry = 0
	} else {
		attackers.Infantry -= hits
		tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_INF_ACTION])
		return
	}
	if hits > attackers.Artillery {
		tuv_swing^ -= i32(attackers.Artillery) * i32(Cost_Buy[.BUY_ARTY_ACTION])
		hits -= attackers.Artillery
		attackers.Artillery = 0
	} else {
		attackers.Artillery -= hits
		tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_ARTY_ACTION])
		return
	}
	if hits > attackers.Tanks {
		tuv_swing^ -= i32(attackers.Tanks) * i32(Cost_Buy[.BUY_TANK_ACTION])
		hits -= attackers.Tanks
		attackers.Tanks = 0
	} else {
		attackers.Tanks -= hits
		tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_TANK_ACTION])
		return
	}
	if hits > attackers.Fighters {
		tuv_swing^ -= i32(attackers.Fighters) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
		hits -= attackers.Fighters
		attackers.Fighters = 0
	} else {
		attackers.Fighters -= hits
		tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
		return
	}
	if hits > attackers.Bombers {
		tuv_swing^ -= i32(attackers.Bombers) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
		attackers.Bombers = 0
		return
	}
	attackers.Bombers -= hits
	tuv_swing^ -= i32(hits) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
	return
}
remove_defenders :: proc(defenders: ^Land_Defenders, total_hits: u8, tuv_swing: ^i32) {
	hits := total_hits
	if hits > defenders.Bombers {
		tuv_swing^ += i32(defenders.Bombers) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
		hits -= defenders.Bombers
		defenders.Bombers = 0
	} else {
		defenders.Bombers -= hits
		tuv_swing^ += i32(hits) * i32(Cost_Buy[.BUY_BOMBER_ACTION])
		return
	}
	if hits > defenders.Infantry {
		tuv_swing^ += i32(defenders.Infantry) * i32(Cost_Buy[.BUY_INF_ACTION])
		hits -= defenders.Infantry
		defenders.Infantry = 0
	} else {
		defenders.Infantry -= hits
		tuv_swing^ += i32(hits) * i32(Cost_Buy[.BUY_INF_ACTION])
		return
	}
	if hits > defenders.Artillery {
		tuv_swing^ += i32(defenders.Artillery) * i32(Cost_Buy[.BUY_ARTY_ACTION])
		hits -= defenders.Artillery
		defenders.Artillery = 0
	} else {
		defenders.Artillery -= hits
		tuv_swing^ += i32(hits) * i32(Cost_Buy[.BUY_ARTY_ACTION])
		return
	}
	if hits > defenders.Tanks {
		tuv_swing^ += i32(defenders.Tanks) * i32(Cost_Buy[.BUY_TANK_ACTION])
		hits -= defenders.Tanks
		defenders.Tanks = 0
	} else {
		defenders.Tanks -= hits
		tuv_swing^ += i32(hits) * i32(Cost_Buy[.BUY_TANK_ACTION])
		return
	}
	if hits > defenders.Fighters {
		tuv_swing^ += i32(defenders.Fighters) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
		hits -= defenders.Fighters
		defenders.Fighters = 0
		return
	}
	defenders.Fighters -= hits
	tuv_swing^ += i32(hits) * i32(Cost_Buy[.BUY_FIGHTER_ACTION])
	return
}
