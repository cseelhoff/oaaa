package oaaa
import sa "core:container/small_array"
import "core:fmt"

no_defender_threat_exists :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
    /*
    AI NOTE: Submarine Combat Logic
    Submarines have a special "submerge" mechanic that affects when they are threats:
    1. Subs ALWAYS submerge if they can (makes them untargetable but also unable to attack)
    2. Enemy destroyers PREVENT subs from submerging (act as sub detectors)
    3. Therefore, enemy subs are only a threat when:
       - Enemy has subs in the sea zone AND
       - Friendly forces have destroyers that prevent sub submerging
    
    This is why we check (enemy_subs > 0 && allied_destroyers > 0)
    - If no allied destroyers: enemy subs will submerge (no threat)
    - If no enemy subs: obviously no sub threat
    - Only when BOTH present do subs pose a threat
    */
    if gc.enemy_blockade_total[sea] == 0 &&
       gc.enemy_fighters_total[sea] == 0 &&
       ~(gc.enemy_subs_total[sea] > 0 && gc.allied_destroyers_total[sea] > 0) {
        return true
    }
    return false
}

get_allied_subs_count :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (allied_subs: u8) {
	allied_subs = 0
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		allied_subs += gc.idle_ships[sea][ally][.SUB]
	}
	return allied_subs
}

disable_bombardment :: proc(gc: ^Game_Cache, sea: Sea_ID) {
    /*
    AI NOTE: Bombardment Mechanics
    Bombardment is a special ability for supporting land invasions:
    1. Triggers when transports unload units for land combat
    2. Only cruisers/battleships that haven't engaged in sea combat can bombard
    3. Each ship gets ONE bombardment per turn
    4. Bombardment happens BEFORE first round of land combat
    5. Only affects defending land units
    
    State tracking:
    - Ships start in _0_MOVES state (eligible to bombard)
    - After bombarding, convert to _BOMBARDED state
    - _BOMBARDED ships are lower priority in casualty order since:
      a) They've already used their special ability
      b) Fresh ships still have bombardment available
    */
    gc.active_ships[sea][.CRUISER_BOMBARDED] += gc.active_ships[sea][.CRUISER_0_MOVES]
    gc.active_ships[sea][.CRUISER_0_MOVES] = 0
    gc.active_ships[sea][.BATTLESHIP_BOMBARDED] += gc.active_ships[sea][.BATTLESHIP_0_MOVES]
    gc.active_ships[sea][.BATTLESHIP_0_MOVES] = 0
    gc.active_ships[sea][.BS_DAMAGED_BOMBARDED] += gc.active_ships[sea][.BS_DAMAGED_0_MOVES]
    gc.active_ships[sea][.BS_DAMAGED_0_MOVES] = 0
}

build_sea_retreat_options :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
    /*
    AI NOTE: Sea Combat Retreat Logic
    
    Blockade mechanics:
    1. enemy_blockade_total = sum of enemy:
       - Destroyers
       - Carriers
       - Cruisers
       - Battleships (including damaged)
    2. These ships prevent enemy movement through their sea zone
    
    Retreat validation:
    1. Can stay in current sea if either:
       a) No enemy blockade/fighters (safe to stay)
       b) Have combat units that can fight (do_sea_targets_exist)
    2. NEVER allow staying with just transports because:
       - Transports have no combat value
       - They will be automatically destroyed if they stay
       - This would be a "wasted" move
    
    Valid retreat destinations:
    - Must be 1 sea zone away (mm.s2s_1away_via_sea)
    - Must not have enemy blockade
    - Must not already have combat (sea_combat_started)
    */
    if (gc.enemy_blockade_total[src_sea] == 0 && gc.enemy_fighters_total[src_sea] == 0) ||
       do_sea_targets_exist(gc, src_sea) {
        gc.valid_actions += {to_action(src_sea)}
    }
    for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] & ~gc.sea_combat_started {
        if gc.enemy_blockade_total[dst_sea] == 0 {
            gc.valid_actions += {to_action(dst_sea)}
        }
    }
}

do_sea_targets_exist :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
    /*
    AI NOTE: Valid Combat Target Relationships
    This checks if we have appropriate units to fight what's in the sea zone:

    1. Submarine Combat:
       - Need destroyers to prevent sub submerging
       - Then subs can be targeted normally

    2. Anti-Fighter Combat:
       Enemy fighters can be targeted by:
       - Cruisers, Battleships (including damaged)
       - Destroyers
       - Our own Fighters
       - Carriers
       - Bombers
       
    3. General Ship Combat:
       Enemy vulnerable ships (transports, carriers, etc) can be targeted by:
       - All combat ships (subs, cruisers, battleships, destroyers)
       - Fighters
       - Carriers
       - Bombers

    If ANY of these valid combat matchups exist, we have a reason to stay and fight
    */
    return(
        (gc.enemy_subs_total[sea] > 0 && gc.allied_destroyers_total[sea] > 0) ||
        (gc.enemy_fighters_total[sea] > 0 && gc.allied_antifighter_ships_total[sea] > 0) ||
        (gc.enemy_subvuln_ships_total[sea] > 0 && gc.allied_sea_combatants_total[sea] > 0))
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
	gc.more_sea_combat_needed -= {src_sea}
	return true
}

destroy_defender_transports :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if ~no_defender_threat_exists(gc, sea) do return false
	if gc.allied_sea_combatants_total[sea] > 0 {
		// todo - we can use a SIMD 'AND' to zero out the transports
		enemy_team := mm.enemy_team[gc.cur_player]
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			for transport in Idle_Transports {
				gc.team_sea_units[sea][enemy_team] -= gc.idle_ships[sea][enemy][transport]
				gc.enemy_subvuln_ships_total[sea] -= gc.idle_ships[sea][enemy][transport]
				gc.idle_ships[sea][enemy][transport] = 0
			}
		}
	}
	gc.more_sea_combat_needed -= {sea}
	return true
}

DICE_SIDES :: 6

// Low luck combat system:
// 1. Base hits = damage / DICE_SIDES (guaranteed hits)
// 2. Fractional part handled by either:
//    - Random roll when doing deep search (answers_remaining > 1)
//    - Forced worst case when evaluating single move (answers_remaining <= 1)
// This reduces variance while maintaining same average as regular dice

get_attacker_hits_low_luck :: proc(gc: ^Game_Cache, attacker_damage: int) -> (attacker_hits: u8) {
    /*
    AI NOTE: Low Luck Combat System
    Instead of rolling individual dice, low luck:
    1. Sums all unit damage
    2. Divides by DICE_SIDES (6) to get guaranteed hits
    3. Uses ONE roll for the remainder to determine fractional hits
    
    MCTS Strategy Considerations:
    - When evaluating single moves (answers_remaining <= 1):
      * Mark certain teams as "unlucky" to be pessimistic
      * Always round fractional hits DOWN for unlucky teams
      * This prevents MCTS from overvaluing risky moves
      * A path isn't "good" just because we got lucky once
    
    - For deep search (answers_remaining > 1):
      * Use random rolls for fractional parts
      * This gives more realistic long-term evaluation
    */
    // Calculate guaranteed hits (whole number division)
    attacker_hits = u8(attacker_damage / DICE_SIDES)
    
    // When evaluating a single move (answers_remaining <= 1) and enemy team is marked unlucky,
    // the attacker becomes "lucky" because defender will always miss
    if gc.answers_remaining <= 1 && mm.enemy_team[gc.cur_player] in gc.unlucky_teams {
        attacker_hits += 0 < attacker_damage % DICE_SIDES ? 1 : 0 // Round up fractional hits
        return
    }
    
    // For deep search, use random roll for fractional part
    attacker_hits +=
        RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(attacker_damage) % DICE_SIDES ? 1 : 0
    gc.seed = (gc.seed + 1) % RANDOM_MAX
    return
}

get_defender_hits_low_luck :: proc(gc: ^Game_Cache, defender_damage: int) -> (defender_hits: u8) {
    // Calculate guaranteed hits (whole number division)
    defender_hits = u8(defender_damage / DICE_SIDES)
    
    // When evaluating a single move (answers_remaining <= 1) and current team is marked unlucky,
    // the defender becomes "unlucky" and will always miss their fractional attacks
    if gc.answers_remaining <= 1 && mm.team[gc.cur_player] in gc.unlucky_teams {
        defender_hits += 0 < defender_damage % DICE_SIDES ? 1 : 0 // Round up fractional hits
        return
    }
    
    // For deep search, use random roll for fractional part
    defender_hits +=
        RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(defender_damage) % DICE_SIDES ? 1 : 0
    gc.seed = (gc.seed + 1) % RANDOM_MAX
    return
}

no_allied_units_remain :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.team_sea_units[sea][mm.team[gc.cur_player]] > 0 do return false
	gc.more_sea_combat_needed -= {sea}
	return true
}

SUB_ATTACK :: 2
SUB_DEFENSE :: 1
resolve_sea_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
    /*
    AI NOTE: Sea Combat Resolution Order
    Combat has special ordering rules for submarines:
    1. If NO enemy destroyers present:
       - Subs get "sneak attack" (fire first before any other combat)
       - This represents subs surprising the enemy fleet
    2. If enemy destroyers present:
       - Subs attack AFTER regular combat
       - Destroyers prevent the surprise attack advantage
    
    This is why sub attacks are conditionally executed either before
    or after the main combat phase based on enemy destroyer presence.
    */
    for sea in gc.more_sea_combat_needed {
        if sea not_in gc.more_sea_combat_needed do continue
        if destroy_defender_transports(gc, sea) do continue
        disable_bombardment(gc, sea)
        def_subs_targetable := true
        // check_positive_active_ships(gc, sea)
        for {
            if sea in gc.sea_combat_started {
                build_sea_retreat_options(gc, sea)
                dst_air_idx := get_retreat_input(gc, to_air(sea)) or_return
                if sea_retreat(gc, sea, to_sea(dst_air_idx)) do break
            }
            //if destroy_vulnerable_transports(gc, &sea) do break
            gc.sea_combat_started += {sea}
            sub_attacker_damage := int(get_allied_subs_count(gc, sea)) * SUB_ATTACK
            sub_attacker_hits := get_attacker_hits_low_luck(gc, sub_attacker_damage)
            def_subs_targetable = def_subs_targetable && gc.allied_destroyers_total[sea] > 0
            if gc.enemy_destroyer_total[sea] == 0 {
                remove_sea_defenders(gc, sea, &sub_attacker_hits, def_subs_targetable, false)
            }
            def_damage := 0
            if def_subs_targetable do def_damage = get_defender_damage_sub(gc, sea)
            attacker_damage := get_attacker_damage_sea(gc, sea)
            attacker_hits := get_attacker_hits_low_luck(gc, attacker_damage)
            def_damage += get_defender_damage_sea(gc, sea)
            def_hits := get_defender_hits_low_luck(gc, def_damage)
            remove_sea_attackers(gc, sea, &def_hits)
            if gc.enemy_destroyer_total[sea] > 0 {
                remove_sea_defenders(gc, sea, &sub_attacker_hits, def_subs_targetable, false)
            }
            remove_sea_defenders(gc, sea, &attacker_hits, def_subs_targetable, true)
            if no_allied_units_remain(gc, sea) do break
            if destroy_defender_transports(gc, sea) do break
        }
    }
    return true
}

flag_for_land_enemy_combat :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if gc.team_land_units[land][mm.enemy_team[gc.cur_player]] == 0 do return false
	gc.more_land_combat_needed += {land}
	return true
}

flag_for_sea_enemy_combat :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 do return false
	gc.more_sea_combat_needed += {sea}
	return true
}

check_for_conquer :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if mm.team[gc.cur_player] == mm.team[gc.owner[land]] do return false
	conquer_land(gc, land)
	return true
}

sea_bombardment :: proc(gc: ^Game_Cache, land: Land_ID) {
    /*
    AI NOTE: Bombardment Tracking System
    
    Bombardment Limits:
    1. max_bombards[land] is set when units unload from transports
       - Each unloaded unit allows 1 bombardment support
       - This prevents excessive bombardment for small landings
    
    Current Limitation:
    - active_ships track bombardment state (_BOMBARDED suffix)
    - idle_ships (allied ships) don't track bombardment state
    - This means allied ships could theoretically bombard multiple times
    
    Impact Assessment:
    1. This is a known limitation but low priority because:
       - Requires specific circumstances (allied ships near invasion)
       - Bombardments rarely significantly impact battle outcomes
       - Actual occurrence in gameplay is very rare
    
    Future Enhancement:
    - Add bombardment state tracking to idle_ships
    - Would need new idle ship states like CRUISER_BOMBARDED
    - Consider memory/performance tradeoff of additional states
    */
    //todo fix so allied ships don't get unlimited bombards
    //since idle_ship doesn't distinguish
    for sea in sa.slice(&mm.l2s_1away_via_land[land]) {
        if gc.max_bombards[land] == 0 do return
        attacker_damage := 0
        for ship in Bombard_Ships {
            bombarding_ships: u8 = 0
            for ally in sa.slice(&mm.allies[gc.cur_player]) {
                if ally == gc.cur_player do continue
                bombarding_ships = min(
                    gc.max_bombards[land],
                    gc.idle_ships[sea][ally][Active_Ship_To_Idle[ship]],
                )
                gc.max_bombards[land] -= bombarding_ships
                attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
            }
            bombarding_ships = min(gc.max_bombards[land], gc.active_ships[sea][ship])
            gc.max_bombards[land] -= bombarding_ships
            attacker_damage += int(bombarding_ships) * Active_Ship_Attack[ship]
            gc.active_ships[sea][ship] -= bombarding_ships
            gc.active_ships[sea][Ship_After_Bombard[ship]] += bombarding_ships
            if gc.max_bombards[land] == 0 do break
        }
        gc.max_bombards[land] = 0
        attack_hits := get_attacker_hits_low_luck(gc, attacker_damage)
        remove_land_defenders(gc, land, &attack_hits)
    }
}

fire_tact_aaguns :: proc(gc: ^Game_Cache, land: Land_ID) {
    /*
    AI NOTE: Anti-Aircraft Systems
    The game has TWO distinct AA systems:

    1. Tactical AA (this procedure):
       - Mobile AA gun units that can be built/moved
       - Fire at start of FIRST round of land combat
       - Can target up to 3 air units per AA gun
       - Target priority: Fighters first, then Bombers
       - Used for defending against tactical air support

    2. Strategic AA (in strategic_bombing):
       - Built into factories (1 per factory)
       - Only fire during strategic bombing raids
       - Only target bombers (fighters can't strategic bomb)
       - Used for defending industrial capacity
    
    This split system means:
    - Tactical AA protects ground forces from air support
    - Strategic AA protects economy from bombing raids
    */
    total_aaguns: u8 = 0
    for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
        total_aaguns += gc.idle_armies[land][enemy][.AAGUN]
    }
    total_air_units :=
        gc.idle_land_planes[land][gc.cur_player][.FIGHTER] +
        gc.idle_land_planes[land][gc.cur_player][.BOMBER]
    // Each AA gun can target up to 3 planes
    defender_damage := int(min(total_aaguns * 3, total_air_units))
    defender_hits := get_defender_hits_low_luck(gc, defender_damage)
    for (defender_hits > 0) {
        defender_hits -= 1
        if hit_my_land_planes(gc, land, Air_Casualty_Order_Fighters) do continue
        if hit_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
    }
}

strategic_bombing :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
    /*
    AI NOTE: Strategic Bombing Sequence
    This is a special combat phase that happens before regular land combat:
    1. Check if this is a pure bombing raid:
       - Must have bombers
       - Total friendly units must not exceed bomber count
         (prevents mixing with ground assault)
    
    2. Strategic AA Defense:
       - Factory's built-in AA fires at bombers
       - No fighter targeting (unlike tactical AA)
       - One shot per bomber present
    
    3. Bombing Damage:
       - Each surviving bomber rolls to damage factory
       - Factory damage caps at 2x production value
       - This prevents complete factory destruction
    */
    bombers := gc.idle_land_planes[land][gc.cur_player][.BOMBER]
    if bombers == 0 || gc.team_land_units[land][mm.team[gc.cur_player]] > bombers {
        return false
    }
    gc.more_land_combat_needed -= {land}
    // Strategic AA fire
    defender_hits := get_defender_hits_low_luck(gc, int(bombers))
    for (defender_hits > 0) {
        defender_hits -= 1
        if hit_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
        break
    }
    // Bombing damage
    attacker_damage := int(gc.idle_land_planes[land][gc.cur_player][.BOMBER]) * 21
    attacker_hits := get_attacker_hits_low_luck(gc, attacker_damage)
    gc.factory_dmg[land] = max(gc.factory_dmg[land] + attacker_hits, gc.factory_prod[land] * 2)
    return true
}

attempt_conquer_land :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
    /*
    AI NOTE: Territory Conquest Rules
    1. Only ground combat units can conquer territory:
       - Infantry, Artillery, Tanks
       - Air units cannot capture (fighters/bombers)
       
    2. AA Gun Movement Timing:
       - AA guns are technically ground units
       - BUT they move AFTER resolve_land_battles()
       - So they're never present during conquest checks
       - This is why we don't check for AA guns here
    
    This timing sequence (AA moves after combat) means:
    - AA guns can't participate in attacks
    - They're purely defensive units
    - They must wait for territory to be secured before moving in
    */
    if gc.team_land_units[land][mm.enemy_team[gc.cur_player]] > 0 do return false
    // Only check for combat units that can be present during conquest
    if gc.idle_armies[land][gc.cur_player][.INF] > 0 ||
       gc.idle_armies[land][gc.cur_player][.ARTY] > 0 ||
       gc.idle_armies[land][gc.cur_player][.TANK] > 0 {
        conquer_land(gc, land)
    }
    return true
}

build_land_retreat_options :: proc(gc: ^Game_Cache, land: Land_ID) {
	gc.valid_actions = {to_action(land)}
	for &dst_land in sa.slice(&mm.l2l_1away_via_land[land]) {
		if dst_land in (gc.friendly_owner & ~gc.more_land_combat_needed & ~gc.land_combat_started)
		{
			gc.valid_actions += {to_action(dst_land)}
		}
	}
}

destroy_undefended_aaguns :: proc(gc: ^Game_Cache, land: Land_ID) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_armies[land][enemy][.AAGUN] > 0 {
			aaguns := gc.idle_armies[land][enemy][.AAGUN]
			gc.idle_armies[land][enemy][.AAGUN] = 0
			gc.team_land_units[land][mm.team[enemy]] -= aaguns
		}
	}
}

MAX_COMBAT_ROUNDS :: 100
resolve_land_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
    /*
    AI NOTE: Land Combat Types
    A land battle will be ONE of two types, never both:
    1. Strategic Bombing:
       - Only bombers present (no ground units)
       - Targets factory production
       - Uses factory's built-in AA defense
       - Ends after one round
       
    2. Traditional Land Combat:
       - Ground units and/or mixed air support
       - Follows full combat sequence:
         a) Sea bombardment support
         b) Tactical AA defense
         c) Regular combat rounds
       - Can continue multiple rounds
    
    This is why we check strategic_bombing first:
    - If it succeeds, skip all other combat
    - If it fails, proceed with traditional combat
    */
    for land in gc.more_land_combat_needed {
        if no_attackers_remain(gc, land) {
            gc.more_land_combat_needed -= {land}
            continue
        }
        if land not_in gc.land_combat_started {
            // Try strategic bombing first - if successful, skip traditional combat
            if strategic_bombing(gc, land) do continue
            
            // Otherwise proceed with traditional combat sequence
            sea_bombardment(gc, land)
            fire_tact_aaguns(gc, land)
            if no_attackers_remain(gc, land) do continue
            if attempt_conquer_land(gc, land) do continue
        }
        combat_rounds := 0
        for {
            combat_rounds += 1
            if combat_rounds > MAX_COMBAT_ROUNDS {
                fmt.eprintln("resolve_land_battles: MAX_COMBAT_ROUNDS reached", combat_rounds)
                print_game_state(gc)
            }
            if land in gc.land_combat_started {
                build_land_retreat_options(gc, land)
                dst_air := get_retreat_input(gc, to_air(land)) or_return
                if retreat_land_units(gc, land, Land_ID(dst_air)) do break
            }
            gc.land_combat_started += {land}
            attacker_hits := get_attacker_hits_low_luck(gc, get_attcker_damage_land(gc, land))
            defender_hits := get_defender_hits_low_luck(gc, get_defender_damage_land(gc, land))
            remove_land_attackers(gc, land, &defender_hits)
            remove_land_defenders(gc, land, &attacker_hits)
            destroy_undefended_aaguns(gc, land)
            if no_attackers_remain(gc, land) do break
            if attempt_conquer_land(gc, land) do break
        }
    }
    return true
}

no_attackers_remain :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if gc.team_land_units[land][mm.team[gc.cur_player]] == 0 {
		gc.more_land_combat_needed -= {land}
		return true
	}
	return false
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
	gc.more_land_combat_needed -= {src_land}
	return true
}

remove_sea_attackers :: proc(gc: ^Game_Cache, sea: Sea_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_battleship(gc, sea) do continue
		if hit_ally_battleship(gc, sea) do continue
		if hit_my_ships(gc, sea, Attacker_Sea_Casualty_Order_1) do continue
		if hit_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_1) do continue
		// if hit_my_sea_planes(gc, sea, Air_Casualty_Order_Fighters) do continue
		if hit_my_sea_fighters(gc, sea) do continue
		// if hit_ally_sea_planes(gc, sea, .FIGHTER) do continue
		if hit_ally_sea_fighters(gc, sea) do continue
		if hit_my_ships(gc, sea, Attacker_Sea_Casualty_Order_2) do continue
		if hit_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_2) do continue
		if hit_my_sea_bombers(gc, sea) do continue
		if hit_my_ships(gc, sea, Attacker_Sea_Casualty_Order_3) do continue
		if hit_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_3) do continue
		if hit_my_ships(gc, sea, Attacker_Sea_Casualty_Order_4) do continue
		if hit_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_4) do continue
		return
	}
}

remove_sea_defenders :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	hits: ^u8,
	subs_targetable: bool,
	planes_targetable: bool,
) {
    /*
    AI NOTE: Battleship Damage Mechanics
    Battleships are unique in having two "health states":
    1. Undamaged (.BATTLESHIP) -> Can be damaged to (.BS_DAMAGED)
    2. Damaged (.BS_DAMAGED) -> Can be destroyed
    
    Critical: We ALWAYS check undamaged battleships first because:
    - They effectively have 2 HP (can take 2 hits before dying)
    - A damaged battleship functions identically to an undamaged one
    - Therefore, damaging an undamaged battleship "soaks" a hit without losing capability
    - This is more efficient than losing a different ship entirely
    
    After battleships, targeting depends on:
    - subs_targetable: Only true if destroyers present to prevent submerging
    - planes_targetable: Affects when fighters can be hit
    */
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_battleship(gc, sea) do continue
		if subs_targetable && hit_enemy_ships(gc, sea, Defender_Sub_Casualty) do continue
		if hit_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_1) do continue
		if planes_targetable && hit_enemy_sea_fighter(gc, sea) do continue
		if hit_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_2) do continue
		assert(
			gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 ||
			!subs_targetable ||
			!planes_targetable,
		)
		return
	}
}

remove_land_attackers :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_armies(gc, land, Attacker_Land_Casualty_Order_1) do continue
		if hit_my_land_planes(gc, land, Air_Casualty_Order_Fighters) do continue
		if hit_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
	}

}
remove_land_defenders :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_armies(gc, land, Defender_Land_Casualty_Order_1) do continue
		if hit_enemy_land_planes(gc, land, .BOMBER) do continue
		if hit_enemy_armies(gc, land, Defender_Land_Casualty_Order_2) do continue
		if hit_enemy_land_planes(gc, land, .FIGHTER) do continue
	}
}

hit_my_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.active_ships[sea][.BATTLESHIP_BOMBARDED] > 0 {
		gc.active_ships[sea][.BS_DAMAGED_BOMBARDED] += 1
		gc.idle_ships[sea][gc.cur_player][.BS_DAMAGED] += 1
		gc.active_ships[sea][.BATTLESHIP_BOMBARDED] -= 1
		gc.idle_ships[sea][gc.cur_player][.BATTLESHIP] -= 1
		return true
	}
	return false
}

hit_ally_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		if ally == gc.cur_player do continue
		if gc.idle_ships[sea][ally][.BATTLESHIP] > 0 {
			gc.idle_ships[sea][ally][.BATTLESHIP] -= 1
			gc.idle_ships[sea][ally][.BS_DAMAGED] += 1
			return true
		}
	}
	return false
}

hit_enemy_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_ships[sea][enemy][.BATTLESHIP] > 0 {
			gc.idle_ships[sea][enemy][.BATTLESHIP] -= 1
			gc.team_sea_units[sea][mm.team[enemy]] -= 1
			gc.enemy_blockade_total[sea] -= 1
			return true
		}
	}
	return false
}

hit_my_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Active_Ship) -> bool {
	for ship in casualty_order {
		if gc.active_ships[sea][ship] > 0 {
			gc.active_ships[sea][ship] -= 1
			gc.idle_ships[sea][gc.cur_player][Active_Ship_To_Idle[ship]] -= 1
			gc.team_sea_units[sea][mm.team[gc.cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_ally_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Active_Ship) -> bool {
	for ship in casualty_order {
		for ally in sa.slice(&mm.allies[gc.cur_player]) {
			if ally == gc.cur_player do continue
			if gc.idle_ships[sea][ally][Active_Ship_To_Idle[ship]] > 0 {
				gc.idle_ships[sea][ally][Active_Ship_To_Idle[ship]] -= 1
				gc.team_sea_units[sea][mm.team[ally]] -= 1
				return true
			}
		}
	}
	return false
}

hit_enemy_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Idle_Ship) -> bool {
	for ship in casualty_order {
		for player in sa.slice(&mm.enemies[gc.cur_player]) {
			if gc.idle_ships[sea][player][ship] > 0 {
				gc.idle_ships[sea][player][ship] -= 1
				gc.team_sea_units[sea][mm.team[player]] -= 1
				if ship == .DESTROYER {
					gc.enemy_destroyer_total[sea] -= 1
					gc.enemy_blockade_total[sea] -= 1
				} else if ship == .SUB {
					gc.enemy_subs_total[sea] -= 1
				} else if ship == .CARRIER || ship == .CRUISER || ship == .BS_DAMAGED {
					gc.enemy_blockade_total[sea] -= 1
				}
				return true
			}
		}
	}
	return false
}

hit_my_land_planes :: proc(
	gc: ^Game_Cache,
	land: Land_ID,
	casualty_order: []Active_Plane,
) -> bool {
	for plane in casualty_order {
		if gc.active_land_planes[land][plane] > 0 {
			gc.active_land_planes[land][plane] -= 1
			gc.idle_land_planes[land][gc.cur_player][Active_Plane_To_Idle[plane]] -= 1
			gc.team_land_units[land][mm.team[gc.cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_my_sea_fighters :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for plane in Air_Casualty_Order_Fighters {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			remove_ally_fighters_from_sea(gc, sea, gc.cur_player, 1)
			return true
		}
	}
	return false
}

hit_my_sea_bombers :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for plane in Air_Casualty_Order_Bombers {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			gc.idle_sea_planes[sea][gc.cur_player][Active_Plane_To_Idle[plane]] -= 1
			gc.team_sea_units[sea][mm.team[gc.cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_ally_land_planes :: proc(gc: ^Game_Cache, land: Land_ID, idle_plane: Idle_Plane) -> bool {
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		if ally == gc.cur_player do continue
		if gc.idle_land_planes[land][ally][idle_plane] > 0 {
			gc.idle_land_planes[land][ally][idle_plane] -= 1
			gc.team_land_units[land][mm.team[gc.cur_player]] -= 1
			return true
		}
	}
	return false
}
hit_ally_sea_fighters :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	// idle_plane: Idle_Plane,
) -> bool {
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		if ally == gc.cur_player do continue
		if gc.idle_sea_planes[sea][ally][.FIGHTER] > 0 {
			remove_ally_fighters_from_sea(gc, sea, ally, 1)
			return true
		}
	}
	return false
}

hit_enemy_sea_fighter :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_sea_planes[sea][enemy][.FIGHTER] > 0 {
			gc.idle_sea_planes[sea][enemy][.FIGHTER] -= 1
			gc.team_sea_units[sea][mm.team[enemy]] -= 1
			gc.enemy_fighters_total[sea] -= 1
			return true
		}
	}
	return false
}

hit_enemy_land_planes :: proc(gc: ^Game_Cache, land: Land_ID, idle_plane: Idle_Plane) -> bool {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
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

hit_my_armies :: proc(gc: ^Game_Cache, land: Land_ID, casualty_order: []Active_Army) -> bool {
	for army in casualty_order {
		if gc.active_armies[land][army] > 0 {
			gc.active_armies[land][army] -= 1
			gc.idle_armies[land][gc.cur_player][Active_Army_To_Idle[army]] -= 1
			gc.team_land_units[land][mm.team[gc.cur_player]] -= 1
			return true
		}
	}
	return false
}

hit_enemy_armies :: proc(gc: ^Game_Cache, land: Land_ID, casualty_order: []Idle_Army) -> bool {
	for army in casualty_order {
		for player in sa.slice(&mm.enemies[gc.cur_player]) {
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
