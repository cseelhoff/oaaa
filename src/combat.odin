package oaaa
import sa "core:container/small_array"
import "core:fmt"
/*
AI NOTE: Ship Casualty Priority System
Casualty orders optimize for preserving combat effectiveness by taking weaker units first.
Attack/Defense values differ, leading to different optimal orders:

ATTACK VALUES:          DEFENSE VALUES:
- Battleship: 4        - Battleship: 4
- Cruiser: 3          - Cruiser: 3
- Destroyer: 2        - Destroyer: 2
- Carrier: 1          - Carrier: 2
- Transport: 0        - Transport: 0

Key patterns in casualty orders:
1. Transports always last (no combat value)
2. Take weaker units first to preserve strong attackers/defenders
3. Damaged battleships taken before transports but after intact combat ships
4. Bombarded ships (used bombardment) are lower priority than fresh ships

Example sequence (attackers):
Attacker_Sea_Casualty_Order_1: Subs/Destroyers (weakest combat ships)
Attacker_Sea_Casualty_Order_2: Carriers/Used Cruisers (medium value)
Attacker_Sea_Casualty_Order_3: Used/Damaged Battleships
Attacker_Sea_Casualty_Order_4: Transports (no combat value)
*/

Attacker_Sea_Casualty_Order_1 := []Active_Ship{.SUB_0_MOVES, .DESTROYER_0_MOVES}

Air_Casualty_Order_Fighters := []Active_Plane {
	.FIGHTER_0_MOVES,
	.FIGHTER_1_MOVES,
	.FIGHTER_2_MOVES,
	.FIGHTER_3_MOVES,
	.FIGHTER_4_MOVES,
}

Attacker_Sea_Casualty_Order_2 := []Active_Ship{.CARRIER_0_MOVES, .CRUISER_BOMBARDED}

Air_Casualty_Order_Bombers := []Active_Plane {
	.BOMBER_0_MOVES,
	.BOMBER_1_MOVES,
	.BOMBER_2_MOVES,
	.BOMBER_3_MOVES,
	.BOMBER_4_MOVES,
	.BOMBER_5_MOVES,
}
Attacker_Sea_Casualty_Order_3 := []Active_Ship{.BS_DAMAGED_BOMBARDED}

Attacker_Sea_Casualty_Order_4 := []Active_Ship {
	.TRANS_EMPTY_0_MOVES,
	.TRANS_1I_0_MOVES,
	.TRANS_1A_0_MOVES,
	.TRANS_1T_0_MOVES,
	.TRANS_2I_0_MOVES,
	.TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES,
}

Attacker_Land_Casualty_Order_1 := []Active_Army{.INF_0_MOVES, .ARTY_0_MOVES, .TANK_0_MOVES}

Defender_Sub_Casualty := []Idle_Ship{.SUB}

Defender_Sea_Casualty_Order_1 := []Idle_Ship{.DESTROYER, .CARRIER, .CRUISER}

Defender_Sea_Casualty_Order_2 := []Idle_Ship {
	.BS_DAMAGED,
	.TRANS_EMPTY,
	.TRANS_1I,
	.TRANS_1A,
	.TRANS_1T,
	.TRANS_2I,
	.TRANS_1I_1A,
	.TRANS_1I_1T,
}

Defender_Land_Casualty_Order_1 := []Idle_Army{.AAGUN}
Defender_Land_Casualty_Order_2 := []Idle_Army{.INF, .ARTY, .TANK}

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
       !(gc.enemy_subs_total[sea] > 0 && gc.allied_destroyers_total[sea] > 0) {
        return true
    }
    return false
}

count_allied_subs :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (allied_subs: u8) {
	allied_subs = 0
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		allied_subs += gc.idle_ships[sea][ally][.SUB]
	}
	return allied_subs
}

mark_ships_ineligible_for_bombardment :: proc(gc: ^Game_Cache, sea: Sea_ID) {
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
    gc.valid_actions = {}
    if (gc.enemy_blockade_total[src_sea] == 0 && gc.enemy_fighters_total[src_sea] == 0) ||
       do_sea_targets_exist(gc, src_sea) {
        gc.valid_actions += {to_action(src_sea)}
    }
    for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] & ~gc.sea_combat_started {
        if gc.enemy_blockade_total[dst_sea] == 0 && dst_sea not_in gc.more_sea_combat_needed {
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
		for ally in sa.slice(&mm.allies[gc.cur_player]) {
			if ally == gc.cur_player do continue
			number_of_ships = gc.idle_ships[src_sea][ally][Active_Ship_To_Idle[active_ship]]
			gc.idle_ships[dst_sea][ally][Active_Ship_To_Idle[active_ship]] += number_of_ships
			gc.team_sea_units[dst_sea][team] += number_of_ships
			gc.idle_ships[src_sea][ally][Active_Ship_To_Idle[active_ship]] = 0
			gc.team_sea_units[src_sea][team] -= number_of_ships
		}
	}
	gc.more_sea_combat_needed -= {src_sea}
	return true
}

destroy_defender_transports :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if !no_defender_threat_exists(gc, sea) do return false
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

calculate_attacker_hits_low_luck :: proc(gc: ^Game_Cache, total_attack_value: int) -> (attacker_hits: u8) {
    /*
    AI NOTE: Low Luck Combat System
    
    This system reduces variance while preserving expected values:
    1. Guaranteed Hits:
       - Divide total damage by DICE_SIDES
       - Get guaranteed whole number of hits
       - Example: 7 damage / 6 sides = 1 guaranteed hit
    
    2. Fractional Hit Chance:
       - Use remainder after division
       - Roll random number to resolve
       - Example: 7 damage = 1 hit + (1/6 chance of extra hit)
    
    3. Special Monte Carlo Search Logic:
       - During deep search (answers_remaining > 1):
         Use random rolls for fractional hits
       - During final move evaluation:
         If enemy team is "unlucky", attacker always gets fractional hit
    
    This system helps the AI evaluate combat more accurately by:
    - Reducing extreme variance in outcomes
    - Making results more predictable
    - Still preserving some randomness for realism
    */
    // Calculate guaranteed hits (whole number division)
    attacker_hits = u8(total_attack_value / DICE_SIDES)
    
    // When evaluating a single move (answers_remaining <= 1) and enemy team is marked unlucky,
    // the attacker becomes "lucky" because defender will always miss
    if gc.answers_remaining <= 1 && mm.enemy_team[gc.cur_player] in gc.unlucky_teams {
        attacker_hits += 0 < total_attack_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
        return
    }
    
    // For deep search, use random roll for fractional part
    attacker_hits +=
        RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(total_attack_value) % DICE_SIDES ? 1 : 0
    gc.seed = (gc.seed + 1) % RANDOM_MAX
    return
}

calculate_defender_hits_low_luck :: proc(gc: ^Game_Cache, total_defense_value: int) -> (defender_hits: u8) {
    /*
    AI NOTE: Defender Low Luck Mechanics
    
    Defender hits work the same way as attacker hits:
    1. Guaranteed hits from whole number division
    2. Random roll for fractional remainder
    
    Key difference is in Monte Carlo logic:
    - If defending team is "unlucky" during final evaluation
      they NEVER get their fractional hit
    - This creates slight attacker advantage
    - Helps break ties in Monte Carlo search
    */
    // Calculate guaranteed hits (whole number division)
    defender_hits = u8(total_defense_value / DICE_SIDES)
    
    // When evaluating a single move (answers_remaining <= 1) and current team is marked unlucky,
    // the defender becomes "unlucky" and will always miss their fractional attacks
    if gc.answers_remaining <= 1 && mm.team[gc.cur_player] in gc.unlucky_teams {
        defender_hits += 0 < total_defense_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
        return
    }
    
    // For deep search, use random roll for fractional part
    defender_hits +=
        RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u8(total_defense_value) % DICE_SIDES ? 1 : 0
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
        mark_ships_ineligible_for_bombardment(gc, sea)
        enemy_subs_detected := true
        // check_positive_active_ships(gc, sea)
        for {
            if sea in gc.sea_combat_started {
                build_sea_retreat_options(gc, sea)
                dst_air := get_retreat_input(gc, to_air(sea)) or_return
                dst_sea := to_sea(dst_air)
                if dst_sea != sea && sea_retreat(gc, sea, dst_sea) do break
            }
            //if destroy_vulnerable_transports(gc, &sea) do break
            gc.sea_combat_started += {sea}
            sub_total_attack_value := int(count_allied_subs(gc, sea)) * SUB_ATTACK
            sub_attacker_hits := calculate_attacker_hits_low_luck(gc, sub_total_attack_value)
            enemy_subs_detected = enemy_subs_detected && gc.allied_destroyers_total[sea] > 0
            if gc.enemy_destroyer_total[sea] == 0 {
                remove_sea_defenders(gc, sea, &sub_attacker_hits, enemy_subs_detected, false)
            }
            def_damage := 0
            if enemy_subs_detected do def_damage = calculate_sub_defense_value(gc, sea)
            total_attack_value := get_total_attack_value_sea(gc, sea)
            attacker_hits := calculate_attacker_hits_low_luck(gc, total_attack_value)
            def_damage += calculate_naval_defense_value(gc, sea)
            def_hits := calculate_defender_hits_low_luck(gc, def_damage)
            remove_sea_attackers(gc, sea, &def_hits)
            if gc.enemy_destroyer_total[sea] > 0 {
                remove_sea_defenders(gc, sea, &sub_attacker_hits, enemy_subs_detected, false)
            }
            remove_sea_defenders(gc, sea, &attacker_hits, enemy_subs_detected, true)
            if no_allied_units_remain(gc, sea) do break
            if destroy_defender_transports(gc, sea) do break
        }
    }
    return true
}

mark_land_for_combat_resolution :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if gc.team_land_units[land][mm.enemy_team[gc.cur_player]] == 0 do return false
	gc.more_land_combat_needed += {land}
	return true
}

mark_sea_for_combat_resolution :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 do return false
	gc.more_sea_combat_needed += {sea}
	return true
}

check_and_process_land_conquest :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if mm.team[gc.cur_player] == mm.team[gc.owner[land]] do return false
	transfer_land_ownership(gc, land)
	return true
}

resolve_naval_bombardment :: proc(gc: ^Game_Cache, land: Land_ID) {
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
        total_bombardment_value := 0
        for ship in Bombard_Ships {
            ships_available_for_bombardment: u8 = 0
            for ally in sa.slice(&mm.allies[gc.cur_player]) {
                if ally == gc.cur_player do continue
                ships_available_for_bombardment = min(
                    gc.max_bombards[land],
                    gc.idle_ships[sea][ally][Active_Ship_To_Idle[ship]],
                )
                gc.max_bombards[land] -= ships_available_for_bombardment
                total_bombardment_value += int(ships_available_for_bombardment) * Active_Ship_Attack[ship]
            }
            ships_available_for_bombardment = min(gc.max_bombards[land], gc.active_ships[sea][ship])
            gc.max_bombards[land] -= ships_available_for_bombardment
            total_bombardment_value += int(ships_available_for_bombardment) * Active_Ship_Attack[ship]
            gc.active_ships[sea][ship] -= ships_available_for_bombardment
            gc.active_ships[sea][Ship_After_Bombard[ship]] += ships_available_for_bombardment
            if gc.max_bombards[land] == 0 do break
        }
        gc.max_bombards[land] = 0
        attack_hits := calculate_attacker_hits_low_luck(gc, total_bombardment_value)
        remove_land_defenders(gc, land, &attack_hits)
    }
}

resolve_tactical_aa_defense :: proc(gc: ^Game_Cache, land: Land_ID) {
    /*
    AI NOTE: Anti-Aircraft Systems
    The game has TWO distinct AA systems:

    1. Tactical AA (this procedure):
       - Mobile AA gun units that can be built/moved
       - Fire at start of FIRST round of land combat
       - Can target up to 3 air units per AA gun
       - Target priority: Fighters first, then Bombers
       - Used for defending against tactical air support

    2. Strategic AA (in resolve_strategic_bombing_raid ):
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
    total_air_targets :=
        gc.idle_land_planes[land][gc.cur_player][.FIGHTER] +
        gc.idle_land_planes[land][gc.cur_player][.BOMBER]
    // Each AA gun can target up to 3 planes
    total_defense_value := int(min(total_aaguns * 3, total_air_targets))
    defender_hits := calculate_defender_hits_low_luck(gc, total_defense_value)
    for (defender_hits > 0) {
        defender_hits -= 1
        if remove_my_land_planes(gc, land, Air_Casualty_Order_Fighters) do continue
        if remove_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
    }
}

resolve_strategic_bombing_raid  :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
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
       - Damage formula: bombers * 21 (high damage potential)
       
    4. Strategic vs Tactical Bombing:
       - Strategic: Pure bomber raids targeting factories
       - Tactical: Bombers supporting ground assault
       - Can't mix both in same battle
       - Strategic resolves first, if eligible
    */
    bombers := gc.idle_land_planes[land][gc.cur_player][.BOMBER]
    if bombers == 0 || gc.team_land_units[land][mm.team[gc.cur_player]] > bombers {
        return false
    }
    gc.more_land_combat_needed -= {land}
    // Strategic AA fire
    aa_defense_hits := calculate_defender_hits_low_luck(gc, int(bombers))
    for (aa_defense_hits > 0) {
        aa_defense_hits -= 1
        if remove_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
        break
    }
    // Bombing damage
    total_bombing_value := int(gc.idle_land_planes[land][gc.cur_player][.BOMBER]) * 21
    bombing_damage_hits := calculate_attacker_hits_low_luck(gc, total_bombing_value)
    gc.factory_dmg[land] = max(gc.factory_dmg[land] + bombing_damage_hits, gc.factory_prod[land] * 2)
    return true
}

check_and_conquer_land :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
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
        transfer_land_ownership(gc, land)
    }
    return true
}

add_valid_land_retreat_destinations :: proc(gc: ^Game_Cache, land: Land_ID) {
    /*
    AI NOTE: Land Combat Retreat Mechanics
    
    Retreats are a critical tactical option in land combat:
    1. Timing:
       - Available at start of EACH combat round
       - Must decide before casualties are taken
       - Happens after any bombardment/AA fire
    
    2. Valid Retreat Destinations:
       - Can stay in current territory (to_action(land))
       - Can move to adjacent friendly territories that:
         a) Share a land connection (mm.l2l_1away_via_land)
         b) Are friendly-controlled (gc.friendly_owner)
         c) Have no pending combat (not in more_land_combat_needed)
         d) Have no ongoing combat (not in land_combat_started)
    
    3. Unit Movement:
       - All units must retreat together
       - Units become inactive after retreat
       - Combat ends in the source territory
    
    This gives players a chance to preserve units if combat is going poorly,
    but requires careful territory control to ensure retreat paths exist.
    */
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
    
    This is why we check resolve_strategic_bombing_raid  first:
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
            if resolve_strategic_bombing_raid (gc, land) do continue
            
            // Otherwise proceed with traditional combat sequence
            resolve_naval_bombardment(gc, land)
            resolve_tactical_aa_defense(gc, land)
            if no_attackers_remain(gc, land) do continue
            if check_and_conquer_land(gc, land) do continue
        }
        combat_rounds_counter := 0
        for {
            debug_checks(gc)
            combat_rounds_counter += 1
            if combat_rounds_counter > MAX_COMBAT_ROUNDS {
                fmt.eprintln("resolve_land_battles: MAX_COMBAT_ROUNDS reached", combat_rounds_counter)
                print_game_state(gc)
            }
            if land in gc.land_combat_started {
                add_valid_land_retreat_destinations(gc, land)
                dst_air := get_retreat_input(gc, to_air(land)) or_return
                if retreat_land_units(gc, land, to_land(dst_air)) do break
            }
            gc.land_combat_started += {land}
            attacker_hits := calculate_attacker_hits_low_luck(gc, calculate_land_attack_value(gc, land))
            defender_hits := calculate_defender_hits_low_luck(gc, calculate_land_defense_value(gc, land))
            remove_land_attackers(gc, land, &defender_hits)
            remove_land_defenders(gc, land, &attacker_hits)
            destroy_undefended_aaguns(gc, land)
            if no_attackers_remain(gc, land) do break
            if check_and_conquer_land(gc, land) do break
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
    /*
    AI NOTE: Sea Combat Casualty Order
    
    Units are removed in a specific order to optimize fleet survival:
    1. Attacker_Sea_Casualty_Order_1: Subs/Destroyers (weakest combat ships)
    2. Attacker_Sea_Casualty_Order_2: Carriers/Used Cruisers (medium value)
    3. Attacker_Sea_Casualty_Order_3: Used/Damaged Battleships
    4. Attacker_Sea_Casualty_Order_4: Transports (no combat value)
    
    Special Cases:
    - Battleships can take damage before being destroyed
    - Ships that have already bombarded are removed before fresh ones
    - Air units are intermixed based on their relative value
    
    The order is designed to:
    1. Preserve high-value combat ships
    2. Keep fresh bombardment-capable ships
    3. Protect transports until absolutely necessary
    */
	for (hits^ > 0) {
		hits^ -= 1
		if hit_my_battleship(gc, sea) do continue
		if hit_ally_battleship(gc, sea) do continue
		if remove_my_ships(gc, sea, Attacker_Sea_Casualty_Order_1) do continue
		if remove_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_1) do continue
		// if hit_my_sea_planes(gc, sea, Air_Casualty_Order_Fighters) do continue
		if remove_my_sea_fighters(gc, sea) do continue
		// if hit_ally_sea_planes(gc, sea, .FIGHTER) do continue
		if remove_ally_sea_fighters(gc, sea) do continue
		if remove_my_ships(gc, sea, Attacker_Sea_Casualty_Order_2) do continue
		if remove_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_2) do continue
		if remove_my_sea_bombers(gc, sea) do continue
		if remove_my_ships(gc, sea, Attacker_Sea_Casualty_Order_3) do continue
		if remove_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_3) do continue
		if remove_my_ships(gc, sea, Attacker_Sea_Casualty_Order_4) do continue
		if remove_ally_ships(gc, sea, Attacker_Sea_Casualty_Order_4) do continue
		return
	}
}

remove_land_attackers :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
    /*
    AI NOTE: Land Combat Casualty Order
    
    Ground units and air support have different casualty priorities:
    1. Ground Units (Attacker_Land_Casualty_Order_1):
       - Infantry, Artillery, Tanks together
       - No distinction between types (unlike sea combat)
       
    2. Air Support:
       - Fighters first (Air_Casualty_Order_Fighters)
       - Bombers last (Air_Casualty_Order_Bombers)
    
    This ordering:
    1. Treats ground units as equally valuable
    2. Preserves bombers for strategic bombing missions
    3. Uses fighters to protect bombers
    */
	for (hits^ > 0) {
		hits^ -= 1
		if remove_my_armies(gc, land, Attacker_Land_Casualty_Order_1) do continue
		if remove_my_land_planes(gc, land, Air_Casualty_Order_Fighters) do continue
		if remove_my_land_planes(gc, land, Air_Casualty_Order_Bombers) do continue
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
    AI NOTE: Sea Combat Casualty Order
    
    When removing defending units, we follow this order:
    1. Battleships First:
       - They have 2 HP (can take 2 hits)
       - A damaged battleship is as effective as fresh
       - So damaging them first "soaks" hits efficiently
    
    2. Submarines (if targetable):
       - Only if destroyers present to prevent submerging
       - Remove early to prevent surprise attacks
    
    3. Primary Surface Ships:
       - Carriers, Cruisers, Damaged Battleships
       - High-value targets that threaten the fleet
    
    4. Air Units (if targetable):
       - Only fighters can defend at sea (bombers must land)
       - Only if we have anti-air capability
    
    5. Support Ships:
       - Transports and other vulnerable ships
       - Save these for last (least threatening)
    
    Combat Total Updates:
    - Battleships: enemy_blockade_total
    - Submarines: enemy_subs_total
    - Destroyers: enemy_destroyer_total, enemy_blockade_total
    - Carriers/Cruisers: enemy_blockade_total
    - Fighters: enemy_fighters_total, enemy_blockade_total
    - Transports: enemy_subvuln_ships_total
    
    Special Targeting Rules:
    1. Submarines:
       - Enemy subs can submerge if attacker has no destroyers
       - When submerged, subs cannot be targeted (~subs_targetable)
       - Submarines cannot target planes (limitation of weapon type)
       
    2. Planes:
       - Only fighters can defend at sea (bombers must land)
       - Can only be targeted if attacker has anti-air (~planes_targetable)
       - Subs cannot shoot at planes (weapon limitation)
       - But planes can target subs if destroyers present
    
    The assertion at the end verifies that any remaining enemy units
    are only there because we couldn't target them (either submerged
    subs or planes we couldn't shoot at).
    */
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_battleship(gc, sea) do continue
		if subs_targetable && remove_enemy_ships(gc, sea, Defender_Sub_Casualty) do continue
		if remove_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_1) do continue
		if planes_targetable && hit_enemy_sea_fighter(gc, sea) do continue
		if remove_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_2) do continue
		assert(
			gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 ||
			!subs_targetable ||
			!planes_targetable,
		)
		return
	}
}

remove_land_defenders :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if remove_enemy_armies(gc, land, Defender_Land_Casualty_Order_1) do continue
		if remove_enemy_land_planes(gc, land, .BOMBER) do continue
		if remove_enemy_armies(gc, land, Defender_Land_Casualty_Order_2) do continue
		if remove_enemy_land_planes(gc, land, .FIGHTER) do continue
	}
}

calculate_land_attack_value :: proc(gc: ^Game_Cache, land: Land_ID) -> (damage: int = 0) {
    /*
    AI NOTE: Land Combat Damage Mechanics
    
    Combat in each battle round is simultaneous:
    1. Both sides roll at same time
    2. All hits are applied after both sides roll
    3. Units have different attack vs defense values
    
    Special Infantry+Artillery Combo:
    - Each infantry can be "supported" by one artillery
    - Supported infantry get artillery's attack bonus
    - That's why we use min(INF, ARTY) to count supported pairs
    
    Unit Attack Values (from game rules):
    - Infantry: INFANTRY_ATTACK 
    - Artillery: ARTILLERY_ATTACK
    - Tank: TANK_ATTACK
    - Fighter: FIGHTER_ATTACK 
    - Bomber: BOMBER_ATTACK
    
    Total damage is sum of all unit attacks. Each point of damage
    has a chance to hit based on DICE_SIDES (simultaneous with defense rolls).
    */
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

calculate_land_defense_value :: proc(gc: ^Game_Cache, land: Land_ID) -> (damage: int = 0) {
    /*
    AI NOTE: Land Combat Defense Values
    
    Units have separate defense values (usually lower than attack):
    - Infantry: INFANTRY_DEFENSE
    - Artillery: ARTILLERY_DEFENSE  
    - Tank: TANK_DEFENSE
    - Fighter: FIGHTER_DEFENSE
    - Bomber: BOMBER_DEFENSE
    
    Defense rolls happen simultaneously with attack rolls.
    Each point of defensive damage also has a chance to hit
    based on DICE_SIDES.
    
    Note: AA Guns don't participate in normal combat.
    They only fire in the special AA defense phase.
    */
    for player in sa.slice(&mm.enemies[gc.cur_player]) {
        damage += int(gc.idle_armies[land][player][.INF]) * INFANTRY_DEFENSE
        damage += int(gc.idle_armies[land][player][.ARTY]) * ARTILLERY_DEFENSE
        damage += int(gc.idle_armies[land][player][.TANK]) * TANK_DEFENSE
        damage += int(gc.idle_land_planes[land][player][.FIGHTER]) * FIGHTER_DEFENSE
        damage += int(gc.idle_land_planes[land][player][.BOMBER]) * BOMBER_DEFENSE
    }
    return damage
}

hit_my_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
    /*
    AI NOTE: Battleship Damage Mechanics
    
    Battleships are unique in having two health states:
    1. Fresh (.BATTLESHIP) -> Can be damaged
    2. Damaged (.BS_DAMAGED) -> Will be destroyed
    
    Combat totals are preserved when damaged because:
    - Still counts as a combat ship
    - Still has anti-fighter capability
    - Only loses bombardment ability
    */
	if gc.active_ships[sea][.BATTLESHIP_BOMBARDED] > 0 {
		gc.active_ships[sea][.BS_DAMAGED_BOMBARDED] += 1
		gc.idle_ships[sea][gc.cur_player][.BS_DAMAGED] += 1
		gc.active_ships[sea][.BATTLESHIP_BOMBARDED] -= 1
		gc.idle_ships[sea][gc.cur_player][.BATTLESHIP] -= 1
		// Don't update combat totals - damaged battleship still counts
		return true
	}
	return false
}

hit_ally_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
    /*
    AI NOTE: Ally Battleship Damage
    
    Same mechanics as player battleships:
    - Convert from fresh to damaged
    - Preserve combat totals
    - Only lose bombardment
    */
	for ally in sa.slice(&mm.allies[gc.cur_player]) {
		if ally == gc.cur_player do continue
		if gc.idle_ships[sea][ally][.BATTLESHIP] > 0 {
			gc.idle_ships[sea][ally][.BATTLESHIP] -= 1
			gc.idle_ships[sea][ally][.BS_DAMAGED] += 1
			// Don't update combat totals - damaged battleship still counts
			return true
		}
	}
	return false
}

hit_enemy_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		if gc.idle_ships[sea][enemy][.BATTLESHIP] > 0 {
			gc.idle_ships[sea][enemy][.BATTLESHIP] -= 1
            gc.idle_ships[sea][enemy][.BS_DAMAGED] += 1
			return true
		}
	}
	return false
}

remove_my_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Active_Ship) -> bool {
    /*
    AI NOTE: Combat Total Updates During Casualties
    
    When ships are destroyed, we must update several totals:
    1. Basic Tracking:
       - active_ships (current player's ships)
       - idle_ships (all players' ships)
       - team_sea_units (team unit counts)
       
    2. Combat Capability Totals:
       - allied_antifighter_ships_total:
         * Decremented for destroyers/carriers/cruisers
         * These ships can shoot at fighters
       
       - allied_sea_combatants_total:
         * Decremented for all non-transport ships
         * Used for general combat threat checks
       
    3. Special Case: Transports
       - Don't affect combat totals
       - Only tracked in basic unit counts
       - Vulnerable to submarines (enemy_subvuln_ships_total)
    */
	for ship in casualty_order {
		if gc.active_ships[sea][ship] > 0 {
			gc.active_ships[sea][ship] -= 1
			gc.idle_ships[sea][gc.cur_player][Active_Ship_To_Idle[ship]] -= 1
			gc.team_sea_units[sea][mm.team[gc.cur_player]] -= 1
			
			// Update combat totals
			if ship == .DESTROYER_0_MOVES {
				gc.allied_antifighter_ships_total[sea] -= 1
				gc.allied_sea_combatants_total[sea] -= 1
			} else if ship == .CARRIER_0_MOVES || ship == .CRUISER_0_MOVES || 
			          ship == .CRUISER_BOMBARDED || ship == .BS_DAMAGED_BOMBARDED {
				gc.allied_antifighter_ships_total[sea] -= 1
				gc.allied_sea_combatants_total[sea] -= 1
			} 
			// else if ship != .TRANSPORT_0_MOVES {
			// 	// All non-transport ships are combat ships
			// 	gc.allied_sea_combatants_total[sea] -= 1
			// }
			return true
		}
	}
	return false
}

remove_ally_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Active_Ship) -> bool {
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

remove_enemy_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Idle_Ship) -> bool {
	for ship in casualty_order {
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			if gc.idle_ships[sea][enemy][ship] > 0 {
				gc.idle_ships[sea][enemy][ship] -= 1
				gc.team_sea_units[sea][mm.team[enemy]] -= 1
				if ship == .DESTROYER {
					gc.enemy_destroyer_total[sea] -= 1
					gc.enemy_blockade_total[sea] -= 1
				} else if ship == .SUB {
					gc.enemy_subs_total[sea] -= 1
				} else if ship == .CARRIER || ship == .CRUISER || ship == .BS_DAMAGED {
					gc.enemy_blockade_total[sea] -= 1
				} 
				// else if ship == .TRANSPORT {
				// 	gc.enemy_subvuln_ships_total[sea] -= 1
				// }
				return true
			}
		}
	}
	return false
}

remove_my_land_planes :: proc(
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

remove_my_sea_fighters :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for plane in Air_Casualty_Order_Fighters {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			remove_ally_fighters_from_sea(gc, sea, gc.cur_player, 1)
			return true
		}
	}
	return false
}

remove_my_sea_bombers :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
    /*
    AI NOTE: Sea Bomber Removal
    
    When bombers are destroyed at sea, update:
    1. Basic Unit Counts:
       - active_sea_planes (current player's planes)
       - idle_sea_planes (all players' planes)
       - team_sea_units (team unit counts)
       
    2. Combat Totals:
       - allied_antifighter_ships_total (bombers can fight fighters)
       - allied_sea_combatants_total (bombers are combat ships)
    */
	for plane in Air_Casualty_Order_Bombers {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			gc.idle_sea_planes[sea][gc.cur_player][.BOMBER] -= 1
			gc.team_sea_units[sea][mm.team[gc.cur_player]] -= 1
			gc.allied_antifighter_ships_total[sea] -= 1
			gc.allied_sea_combatants_total[sea] -= 1
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
remove_ally_sea_fighters :: proc(
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
    /*
    AI NOTE: Enemy Fighter Removal
    
    When enemy fighters are destroyed, update:
    1. Basic Unit Counts:
       - idle_sea_planes (all players' planes)
       - team_sea_units (team unit counts)
       
    2. Combat Totals:
       - enemy_fighters_total (affects threat detection)
       - enemy_blockade_total (fighters can't blockade)
    */
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

remove_enemy_land_planes :: proc(gc: ^Game_Cache, land: Land_ID, idle_plane: Idle_Plane) -> bool {
    /*
    AI NOTE: Enemy Land Plane Removal
    
    When enemy planes are destroyed on land:
    1. Basic Unit Counts:
       - idle_land_planes (all players' planes)
       - team_land_units (team unit counts)
       
    2. No Combat Totals:
       - Land planes don't affect combat totals
       - Only sea planes have special totals
       - Bombers/fighters treated equally
    */
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

remove_my_armies :: proc(gc: ^Game_Cache, land: Land_ID, casualty_order: []Active_Army) -> bool {
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

remove_enemy_armies :: proc(gc: ^Game_Cache, land: Land_ID, casualty_order: []Idle_Army) -> bool {
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

get_total_attack_value_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
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

calculate_naval_defense_value :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
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
calculate_sub_defense_value :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (damage: int = 0) {
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		damage += int(gc.idle_ships[sea][enemy][.SUB]) * SUB_DEFENSE
	}
	return damage
}

/*
AI NOTE: Enemy bombers cannot defend at sea since they must land after their turn.
The hit_enemy_sea_bomber procedure was removed since it was added by mistake.
*/
