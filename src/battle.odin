package oaaa

import "core:fmt"

// =============================================================================
// LAND BATTLE STRUCTURES
// =============================================================================

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

// =============================================================================
// SEA BATTLE STRUCTURES
// =============================================================================

Sea_Defenders :: struct {
	Subs:        u8,
	Destroyers:  u8,
	Cruisers:    u8,
	Carriers:    u8,
	Battleships: u8,
	BS_Damaged:  u8,
	Fighters:    u8,  // on carriers
	Transports:  u8,  // fodder
}

Sea_Attackers :: struct {
	Subs:        u8,
	Destroyers:  u8,
	Cruisers:    u8,
	Carriers:    u8,
	Battleships: u8,
	BS_Damaged:  u8,
	Fighters:    u8,
	Bombers:     u8,
}

Sea_Combatants :: struct {
	defenders: Sea_Defenders,
	attackers: Sea_Attackers,
}

Sea_Battle_Results :: struct {
	avg_TUV_swing:   f64,
	win_percent:     f64,  // Probability attackers win (defenders destroyed)
	avg_survivors:   f64,  // Average defending units remaining
}

// =============================================================================
// LAND BATTLE FUNCTIONS
// =============================================================================

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

// =============================================================================
// SEA BATTLE FUNCTIONS
// =============================================================================

/*
Sea Battle Simulation for AI Purchase Decisions

This simulates sea combat to predict outcomes, similar to land battle simulation.
Used by purchase AI to decide if we can defend sea zones.

Key differences from actual combat resolution (combat.odin resolve_sea_battles):
1. No retreat decisions - simulates fight to the finish
2. No transport unloading - pure combat simulation
3. Simplified sub rules - subs always get sneak attack if no enemy destroyer
4. No bombardment - that's land combat

The simulation matches combat.odin logic for:
- Submarine sneak attacks (attack first if no enemy destroyer)
- Casualty selection order
- Low-luck dice resolution
*/

// Get cached sea battle results or compute if not cached
get_sea_battle_results :: proc(combatants: Sea_Combatants) -> Sea_Battle_Results {
	// Note: We could add caching like land battles if needed
	// For now, compute each time since sea battles are less common
	return simulate_sea_battle(combatants)
}

// Monte Carlo simulation of sea battle
// Returns: win_percent (attacker wins), tuv_swing, avg_survivors
simulate_sea_battle :: proc(combatants: Sea_Combatants) -> Sea_Battle_Results {
	simulations_count := 1000
	attacker_wins := 0
	tuv_swing: i32 = 0
	total_survivors: i32 = 0
	
	for i in 0 ..< simulations_count {
		def := combatants.defenders
		att := combatants.attackers
		
		// Check if attackers have destroyer (affects sub sneak attack)
		attacker_has_destroyer := att.Destroyers > 0
		defender_has_destroyer := def.Destroyers > 0
		
		for combat_round in 0 ..< MAX_COMBAT_ROUNDS {
			if sim_sea_no_defenders_remain(&def) || sim_sea_no_attackers_remain(&att) do break
			
			// Submarine sneak attack phase (if no enemy destroyer)
			if !defender_has_destroyer && att.Subs > 0 {
				sub_hits := sim_low_luck(u16(att.Subs) * SUB_ATTACK)
				sim_remove_sea_defenders(&def, sub_hits, &tuv_swing, false) // subs can't hit air
			}
			if !attacker_has_destroyer && def.Subs > 0 {
				sub_hits := sim_low_luck(u16(def.Subs) * SUB_DEFENSE)
				sim_remove_sea_attackers(&att, sub_hits, &tuv_swing, false)
			}
			
			// Main combat phase
			attacker_hits := sim_sea_attacker_hits(&att, defender_has_destroyer)
			defender_hits := sim_sea_defender_hits(&def, attacker_has_destroyer)
			
			// Apply hits
			sim_remove_sea_attackers(&att, defender_hits, &tuv_swing, true)
			sim_remove_sea_defenders(&def, attacker_hits, &tuv_swing, true)
			
			// Update destroyer status for next round
			attacker_has_destroyer = att.Destroyers > 0
			defender_has_destroyer = def.Destroyers > 0
		}
		
		// Count outcome
		if sim_sea_no_defenders_remain(&def) {
			attacker_wins += 1
		}
		
		// Count surviving defenders
		total_survivors += i32(def.Subs + def.Destroyers + def.Cruisers + 
		                       def.Carriers + def.Battleships + def.BS_Damaged + 
		                       def.Fighters)
	}
	
	result := Sea_Battle_Results {
		avg_TUV_swing = f64(tuv_swing) / f64(simulations_count),
		win_percent   = f64(attacker_wins) / f64(simulations_count) * 100.0,
		avg_survivors = f64(total_survivors) / f64(simulations_count),
	}
	return result
}

// Check if all combat defenders are gone (transports don't count)
sim_sea_no_defenders_remain :: #force_inline proc(def: ^Sea_Defenders) -> bool {
	return def.Subs == 0 && 
	       def.Destroyers == 0 && 
	       def.Cruisers == 0 && 
	       def.Carriers == 0 && 
	       def.Battleships == 0 && 
	       def.BS_Damaged == 0 &&
	       def.Fighters == 0
}

sim_sea_no_attackers_remain :: #force_inline proc(att: ^Sea_Attackers) -> bool {
	return att.Subs == 0 && 
	       att.Destroyers == 0 && 
	       att.Cruisers == 0 && 
	       att.Carriers == 0 && 
	       att.Battleships == 0 && 
	       att.BS_Damaged == 0 &&
	       att.Fighters == 0 &&
	       att.Bombers == 0
}

// Calculate attacker hits (excluding sub hits which are handled separately)
sim_sea_attacker_hits :: #force_inline proc(att: ^Sea_Attackers, enemy_has_destroyer: bool) -> u8 {
	damage: u16 = 0
	// Subs only included if enemy has destroyer (otherwise handled in sneak attack)
	if enemy_has_destroyer {
		damage += u16(att.Subs) * SUB_ATTACK
	}
	damage += u16(att.Destroyers) * DESTROYER_ATTACK
	damage += u16(att.Cruisers) * CRUISER_ATTACK
	damage += u16(att.Carriers) * CARRIER_ATTACK
	damage += u16(att.Battleships) * BATTLESHIP_ATTACK
	damage += u16(att.BS_Damaged) * BATTLESHIP_ATTACK
	damage += u16(att.Fighters) * FIGHTER_ATTACK
	damage += u16(att.Bombers) * BOMBER_ATTACK
	return sim_low_luck(damage)
}

sim_sea_defender_hits :: #force_inline proc(def: ^Sea_Defenders, enemy_has_destroyer: bool) -> u8 {
	damage: u16 = 0
	// Subs only included if enemy has destroyer (otherwise handled in sneak attack)
	if enemy_has_destroyer {
		damage += u16(def.Subs) * SUB_DEFENSE
	}
	damage += u16(def.Destroyers) * DESTROYER_DEFENSE
	damage += u16(def.Cruisers) * CRUISER_DEFENSE
	damage += u16(def.Carriers) * CARRIER_DEFENSE
	damage += u16(def.Battleships) * BATTLESHIP_DEFENSE
	damage += u16(def.BS_Damaged) * BATTLESHIP_DEFENSE
	damage += u16(def.Fighters) * FIGHTER_DEFENSE
	return sim_low_luck(damage)
}

// Remove attacker casualties - cheapest first (opposite of land where attackers are valuable)
sim_remove_sea_attackers :: proc(att: ^Sea_Attackers, total_hits: u8, tuv_swing: ^i32, can_hit_air: bool) {
	hits := total_hits
	
	// Subs are cheap fodder (6 IPC)
	if hits > 0 && att.Subs > 0 {
		taken := min(hits, att.Subs)
		att.Subs -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 6  // SUB cost
	}
	// Destroyers (8 IPC)
	if hits > 0 && att.Destroyers > 0 {
		taken := min(hits, att.Destroyers)
		att.Destroyers -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 8
	}
	// Cruisers (12 IPC)
	if hits > 0 && att.Cruisers > 0 {
		taken := min(hits, att.Cruisers)
		att.Cruisers -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 12
	}
	// Carriers (14 IPC) - but air on them might die too
	if hits > 0 && att.Carriers > 0 {
		taken := min(hits, att.Carriers)
		att.Carriers -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 14
	}
	// Damaged battleships (20 IPC)
	if hits > 0 && att.BS_Damaged > 0 {
		taken := min(hits, att.BS_Damaged)
		att.BS_Damaged -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 20
	}
	// Fresh battleships take 2 hits - first hit damages
	if hits > 0 && att.Battleships > 0 {
		taken := min(hits, att.Battleships)
		att.Battleships -= taken
		att.BS_Damaged += taken  // Convert to damaged
		hits -= taken
		// No TUV loss yet - just damaged
	}
	// Fighters (10 IPC) - only if can_hit_air (subs can't hit air)
	if can_hit_air && hits > 0 && att.Fighters > 0 {
		taken := min(hits, att.Fighters)
		att.Fighters -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 10
	}
	// Bombers (12 IPC)
	if can_hit_air && hits > 0 && att.Bombers > 0 {
		taken := min(hits, att.Bombers)
		att.Bombers -= taken
		hits -= taken
		tuv_swing^ -= i32(taken) * 12
	}
}

// Remove defender casualties - cheapest first, transports last (they're defenseless)
sim_remove_sea_defenders :: proc(def: ^Sea_Defenders, total_hits: u8, tuv_swing: ^i32, can_hit_air: bool) {
	hits := total_hits
	
	// Subs are cheap fodder (6 IPC)
	if hits > 0 && def.Subs > 0 {
		taken := min(hits, def.Subs)
		def.Subs -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 6  // Positive = good for attacker
	}
	// Destroyers (8 IPC)
	if hits > 0 && def.Destroyers > 0 {
		taken := min(hits, def.Destroyers)
		def.Destroyers -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 8
	}
	// Cruisers (12 IPC)
	if hits > 0 && def.Cruisers > 0 {
		taken := min(hits, def.Cruisers)
		def.Cruisers -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 12
	}
	// Carriers (14 IPC)
	if hits > 0 && def.Carriers > 0 {
		taken := min(hits, def.Carriers)
		def.Carriers -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 14
	}
	// Damaged battleships (20 IPC)
	if hits > 0 && def.BS_Damaged > 0 {
		taken := min(hits, def.BS_Damaged)
		def.BS_Damaged -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 20
	}
	// Fresh battleships take 2 hits - first hit damages
	if hits > 0 && def.Battleships > 0 {
		taken := min(hits, def.Battleships)
		def.Battleships -= taken
		def.BS_Damaged += taken
		hits -= taken
	}
	// Fighters (10 IPC) - only if can_hit_air
	if can_hit_air && hits > 0 && def.Fighters > 0 {
		taken := min(hits, def.Fighters)
		def.Fighters -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 10
	}
	// Transports are defenseless fodder (7 IPC) - taken last since they can't fight back
	if hits > 0 && def.Transports > 0 {
		taken := min(hits, def.Transports)
		def.Transports -= taken
		hits -= taken
		tuv_swing^ += i32(taken) * 7
	}
}
