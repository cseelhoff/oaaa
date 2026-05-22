package oaaa
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
attacker_sea_casualty_order_1: Submarines/Destroyers (weakest combat ships)
attacker_sea_casualty_order_2: Carriers/Used Cruisers (medium value)
attacker_sea_casualty_order_3: Used/Damaged Battleships
attacker_sea_casualty_order_4: Transports (no combat value)
*/

attacker_sea_casualty_order_1 := []Active_Ship{.Submarine_0_Moves, .Destroyer_0_Moves}

air_casualty_order_fighters := []Active_Plane {
	.Fighter_0_Moves,
	.Fighter_1_Moves,
	.Fighter_2_Moves,
	.Fighter_3_Moves,
	.Fighter_4_Moves,
}

attacker_sea_casualty_order_2 := []Active_Ship{.Carrier_0_Moves, .Cruiser_Bombarded}

air_casualty_order_bombers := []Active_Plane {
	.Bomber_0_Moves,
	.Bomber_1_Moves,
	.Bomber_2_Moves,
	.Bomber_3_Moves,
	.Bomber_4_Moves,
	.Bomber_5_Moves,
}
attacker_sea_casualty_order_3 := []Active_Ship{.Battleship_Damaged_Bombarded}

attacker_sea_casualty_order_4 := []Active_Ship {
	.Transport_Empty_0_Moves,
	.Transport_Infantry_0_Moves,
	.Transport_Artillery_0_Moves,
	.Transport_Tank_0_Moves,
	.Transport_Infantry_Infantry_0_Moves,
	.Transport_Infantry_Artillery_0_Moves,
	.Transport_Infantry_Tank_0_Moves,
}

attacker_land_casualty_order_1 := []Active_Army{.Infantry_0_Moves, .Artillery_0_Moves, .Tank_0_Moves}

defender_submarine_casualty := []Idle_Ship{.Submarine}

Defender_Sea_Casualty_Order_1 := []Idle_Ship{.Destroyer, .Carrier, .Cruiser}

Defender_Sea_Casualty_Order_2 := []Idle_Ship {
	.Battleship_Damaged,
	.Transport_Empty,
	.Transport_Infantry,
	.Transport_Artillery,
	.Transport_Tank,
	.Transport_Infantry_Infantry,
	.Transport_Infantry_Artillery,
	.Transport_Infantry_Tank,
}

Defender_Land_Casualty_Order_1 := []Idle_Army{.AAGun}
Defender_Land_Casualty_Order_2 := []Idle_Army{.Infantry, .Artillery, .Tank}

no_defender_threat_exists :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	/*
    AI NOTE: Submarine Combat Logic
    Submarines have a special "submerge" mechanic that affects when they are threats:
    1. Submarines ALWAYS submerge if they can (makes them untargetable but also unable to attack)
    2. Enemy destroyers PREVENT submarines from submerging (act as submarine detectors)
    3. Therefore, enemy submarines are only a threat when:
       - Enemy has submarines in the sea zone AND
       - Friendly forces have destroyers that prevent submarine submerging
    
    This is why we check (enemy_submarines > 0 && friendly_destroyers > 0)
    - If no friendly destroyers: enemy submarines will submerge (no threat)
    - If no enemy submarines: obviously no submarine threat
    - Only when BOTH present do submarines pose a threat
    */
	if gc.enemy_blockade_total[sea] == 0 &&
	   gc.enemy_fighters_total[sea] == 0 &&
	   !(gc.enemy_submarines_total[sea] > 0 && gc.friendly_destroyers_total[sea] > 0) {
		return true
	}
	return false
}

count_friendly_submarines :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (friendly_submarines: u8) {
	friendly_submarines = 0
	for ally in mm.allies[gc.acting_nation] {
		friendly_submarines += gc.idle_ships[sea][ally][.Submarine]
	}
	return friendly_submarines
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
    - Ships start in _0_Moves state (eligible to bombard)
    - After bombarding, convert to _BOMBARDED state
    - _BOMBARDED ships are lower priority in casualty order since:
      a) They've already used their special ability
      b) Fresh ships still have bombardment available
    */
	gc.active_ships[sea][.Cruiser_Bombarded] += gc.active_ships[sea][.Cruiser_0_Moves]
	gc.active_ships[sea][.Cruiser_0_Moves] = 0
	gc.active_ships[sea][.Battleship_Bombarded] += gc.active_ships[sea][.Battleship_0_Moves]
	gc.active_ships[sea][.Battleship_0_Moves] = 0
	gc.active_ships[sea][.Battleship_Damaged_Bombarded] += gc.active_ships[sea][.Battleship_Damaged_0_Moves]
	gc.active_ships[sea][.Battleship_Damaged_0_Moves] = 0
}

build_sea_retreat_options :: proc(gc: ^Game_Cache) {
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
    - Must be 1 sea zone away (mm.seas_within_1_move)
    - Must not have enemy blockade
    - Must not already have combat (sea_battle_started)
    */
	gc.valid_actions = {}
	src_sea := to_sea(gc.current_territory)
	if (gc.enemy_blockade_total[src_sea] == 0 && gc.enemy_fighters_total[src_sea] == 0) ||
	   do_sea_targets_exist(gc, src_sea) {
		// add_valid_action(gc, to_action(src_sea))
		add_valid_action(gc, .Skip_Action)
	}
	for dst_sea in mm.seas_within_1_move[transmute(u8)gc.canals_open][src_sea] & ~gc.sea_battle_started {
		if gc.enemy_blockade_total[dst_sea] == 0 && dst_sea not_in gc.more_sea_battles_needed {
			add_valid_action(gc, to_action(dst_sea))
		}
	}
}

do_sea_targets_exist :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	/*
    AI NOTE: Valid Combat Target Relationships
    This checks if we have appropriate units to fight what's in the sea zone:

    1. Submarine Combat:
       - Need destroyers to prevent submarine submerging
       - Then submarines can be targeted normally

    2. Anti-Fighter Combat:
       Enemy fighters can be targeted by:
       - Cruisers, Battleships (including damaged)
       - Destroyers
       - Our own Fighters
       - Carriers
       - Bombers
       
    3. General Ship Combat:
       Enemy vulnerable ships (transports, carriers, etc) can be targeted by:
       - All combat ships (submarines, cruisers, battleships, destroyers)
       - Fighters
       - Carriers
       - Bombers

    If ANY of these valid combat matchups exist, we have a reason to stay and fight
    */
	return(
		(gc.enemy_submarines_total[sea] > 0 && gc.friendly_destroyers_total[sea] > 0) ||
		(gc.enemy_fighters_total[sea] > 0 && gc.friendly_antifighter_ships_total[sea] > 0) ||
		(gc.enemy_subvuln_ships_total[sea] > 0 && gc.friendly_sea_combatants_total[sea] > 0) \
	)
}

sea_retreat :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_action: Action_ID) -> bool {
	// if src_sea == dst_sea do return false
	debug_checks(gc)
	// if(GLOBAL_TICK == 18758) {
	// 	fmt.println(GLOBAL_TICK)		
	// }
	dst_sea := to_sea(dst_action)
	team := mm.team[gc.acting_nation]
	for active_ship in retreatable_ships {
		number_of_ships := gc.active_ships[src_sea][active_ship]
		gc.active_ships[dst_sea][ships_after_retreat[active_ship]] += number_of_ships
		gc.idle_ships[dst_sea][gc.acting_nation][active_ship_to_idle[active_ship]] += number_of_ships
		gc.team_sea_units[dst_sea][team] += number_of_ships
		gc.active_ships[src_sea][active_ship] = 0
		gc.idle_ships[src_sea][gc.acting_nation][active_ship_to_idle[active_ship]] = 0
		gc.team_sea_units[src_sea][team] -= number_of_ships
		for ally in mm.allies[gc.acting_nation] {
			if ally == gc.acting_nation do continue
			number_of_ships = gc.idle_ships[src_sea][ally][active_ship_to_idle[active_ship]]
			gc.idle_ships[dst_sea][ally][active_ship_to_idle[active_ship]] += number_of_ships
			gc.team_sea_units[dst_sea][team] += number_of_ships
			gc.idle_ships[src_sea][ally][active_ship_to_idle[active_ship]] = 0
			gc.team_sea_units[src_sea][team] -= number_of_ships
		}
	}
	gc.more_sea_battles_needed -= {src_sea}
	return true
}

destroy_defender_transports :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if !no_defender_threat_exists(gc, sea) do return false
	if gc.friendly_sea_combatants_total[sea] > 0 {
		// todo - we can use a SIMD 'AND' to zero out the transports
		enemy_team := mm.enemy_team[gc.acting_nation]
		for enemy in mm.enemies[gc.acting_nation] {
			for transport in idle_transports {
				gc.team_sea_units[sea][enemy_team] -= gc.idle_ships[sea][enemy][transport]
				gc.enemy_subvuln_ships_total[sea] -= gc.idle_ships[sea][enemy][transport]
				gc.idle_ships[sea][enemy][transport] = 0
			}
		}
	}
	gc.more_sea_battles_needed -= {sea}
	return true
}

DICE_SIDES :: 6

// Low luck combat system:
// 1. Base hits = total attack value / DICE_SIDES (guaranteed hits)
// 2. Fractional part handled by either:
//    - Random roll when doing deep search (answers_remaining > 1)
//    - Forced worst case when evaluating single move (answers_remaining <= 1)
// This reduces variance while maintaining same average as regular dice

LOW_LUCK_THRESHOLD :: 3 // 0 is always win, 1 is win 5/6... 5 is win 1/6

calculate_attacker_hits_low_luck :: proc(
	gc: ^Game_Cache,
	total_attack_value: int,
) -> (
	attacker_hits: u8,
) {
	/*
    AI NOTE: Low Luck Combat System
    
    This system reduces variance while preserving expected values:
    1. Guaranteed Hits:
       - Divide total attack value by DICE_SIDES
       - Get guaranteed whole number of hits
       - Example: 7 attack value / 6 sides = 1 guaranteed hit
    
    2. Fractional Hit Chance:
       - Use remainder after division
       - Roll random number to resolve
       - Example: 7 attack value = 1 hit + (1/6 chance of extra hit)
    
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
	if gc.answers_remaining <= 1 {
		if mm.enemy_team[gc.acting_nation] in gc.unlucky_teams &&
		   mm.team[gc.acting_nation] not_in gc.unlucky_teams {
			attacker_hits +=
				(LOW_LUCK_THRESHOLD - (volley_counter / 10)) < total_attack_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
			return
		}
		attacker_hits +=
			(11 - (volley_counter / 10)) < total_attack_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
		return
	}

	// For deep search, use random roll for fractional part
	attacker_hits +=
		RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u16(total_attack_value) % DICE_SIDES ? 1 : 0
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	return
}

calculate_defender_hits_low_luck :: proc(
	gc: ^Game_Cache,
	total_defense_value: int,
) -> (
	defender_hits: u8,
) {
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
	if gc.answers_remaining <= 1 {
		if mm.team[gc.acting_nation] in gc.unlucky_teams &&
		   mm.enemy_team[gc.acting_nation] not_in gc.unlucky_teams {
			defender_hits +=
				(LOW_LUCK_THRESHOLD - (volley_counter / 10)) < total_defense_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
			return
		}
		defender_hits +=
			(11 - (volley_counter / 10)) < total_defense_value % DICE_SIDES ? 1 : 0 // Round up fractional hits
		return
	}

	// For deep search, use random roll for fractional part
	defender_hits +=
		RANDOM_NUMBERS[gc.seed] % DICE_SIDES < u16(total_defense_value) % DICE_SIDES ? 1 : 0
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	return
}

no_friendly_units_remain :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.team_sea_units[sea][mm.team[gc.acting_nation]] > 0 do return false
	gc.more_sea_battles_needed -= {sea}
	return true
}

SUBMARINE_ATTACK_VALUE :: 2
SUBMARINE_DEFENSE_VALUE :: 1
volley_counter := 0
resolve_sea_battles :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
    AI NOTE: Sea Combat Resolution Order
    Combat has special ordering rules for submarines:
    1. If NO enemy destroyers present:
       - Submarines get First Strike (fire first before any other combat)
       - This represents submarines surprising the enemy fleet
    2. If enemy destroyers present:
       - Submarines attack AFTER regular combat
       - Destroyers prevent the First Strike advantage
    
    This is why submarine attacks are conditionally executed either before
    or after the main combat phase based on enemy destroyer presence.
    */
	for sea in gc.more_sea_battles_needed {
		if sea not_in gc.more_sea_battles_needed do continue
		if destroy_defender_transports(gc, sea) do continue
		mark_ships_ineligible_for_bombardment(gc, sea)
		defender_submarines_detected := true
		// check_positive_active_ships(gc, sea)
		volley_counter = 0
		for {
			volley_counter += 1
			if sea in gc.sea_battle_started {
				gc.current_territory = to_region(sea)
				build_sea_retreat_options(gc)
				load_dyn_arr_actions(gc)
				if len(gc.dyn_arr_valid_actions) > 0 {
					dst_action := get_action_input(gc) or_return
					if dst_action != .Skip_Action && sea_retreat(gc, sea, dst_action) {
						debug_checks(gc)
						break
					}
				}
			}
			//if destroy_vulnerable_transports(gc, &sea) do break
			gc.sea_battle_started += {sea}
			submarine_total_attack_value := int(count_friendly_submarines(gc, sea)) * SUBMARINE_ATTACK_VALUE
			submarine_attacker_hits := calculate_attacker_hits_low_luck(gc, submarine_total_attack_value)
			defender_submarines_detected = defender_submarines_detected && gc.friendly_destroyers_total[sea] > 0
			if gc.enemy_destroyers_total[sea] == 0 {
				remove_sea_defenders(gc, sea, &submarine_attacker_hits, defender_submarines_detected, false)
			}
			def_total_defense_value := 0
			if defender_submarines_detected do def_total_defense_value = calculate_submarine_defense_value(gc, sea)
			total_attack_value := get_total_attack_value_sea(gc, sea)
			attacker_hits := calculate_attacker_hits_low_luck(gc, total_attack_value)
			def_total_defense_value += calculate_naval_defense_value(gc, sea)
			def_hits := calculate_defender_hits_low_luck(gc, def_total_defense_value)
			remove_sea_attackers(gc, sea, &def_hits)
			if gc.enemy_destroyers_total[sea] > 0 {
				remove_sea_defenders(gc, sea, &submarine_attacker_hits, defender_submarines_detected, false)
			}
			remove_sea_defenders(gc, sea, &attacker_hits, defender_submarines_detected, true)
			if no_friendly_units_remain(gc, sea) {
				debug_checks(gc)
				break
			}
			if destroy_defender_transports(gc, sea) {
				debug_checks(gc)
				break
			}
		}
		debug_checks(gc)
	}
	return true
}

mark_land_for_combat_resolution :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if gc.team_land_units[land][mm.enemy_team[gc.acting_nation]] == 0 do return false
	gc.more_land_battles_needed += {land}
	return true
}

mark_sea_for_combat_resolution :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	if gc.team_sea_units[sea][mm.enemy_team[gc.acting_nation]] == 0 do return false
	gc.more_sea_battles_needed += {sea}
	return true
}

check_and_process_land_conquest :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if mm.team[gc.acting_nation] == mm.team[gc.owner[land]] do return false
	transfer_land_ownership(gc, land)
	return true
}

resolve_naval_bombardment :: proc(gc: ^Game_Cache, land: Land_ID) {
	/*
    AI NOTE: Bombardment Tracking System
    
    Bombardment Limits:
    1. max_bombardment_dice[land] is set when units unload from transports
       - Each unloaded unit allows 1 bombardment support
       - This prevents excessive bombardment for small landings
    
    Current Limitation:
    - active_ships track bombardment state (_BOMBARDED suffix)
    - idle_ships (friendly ships) don't track bombardment state
    - This means friendly ships could theoretically bombard multiple times
    
    Impact Assessment:
    1. This is a known limitation but low priority because:
       - Requires specific circumstances (friendly ships near invasion)
       - Bombardments rarely significantly impact battle outcomes
       - Actual occurrence in gameplay is very rare
    
    Future Enhancement:
    - Add bombardment state tracking to idle_ships
    - Would need new idle ship states like Cruiser_Bombarded
    - Consider memory/performance tradeoff of additional states
    */
	//todo fix so friendly ships don't get unlimited bombards
	//since idle_ship doesn't distinguish
	for sea in mm.coastal_seas[land] {
		if gc.max_bombardment_dice[land] == 0 do return
		total_bombardment_value := 0
		for ship in bombardment_ships {
			ships_available_for_bombardment: u8 = 0
			for ally in mm.allies[gc.acting_nation] {
				if ally == gc.acting_nation do continue
				ships_available_for_bombardment = min(
					gc.max_bombardment_dice[land],
					gc.idle_ships[sea][ally][active_ship_to_idle[ship]],
				)
				gc.max_bombardment_dice[land] -= ships_available_for_bombardment
				total_bombardment_value +=
					int(ships_available_for_bombardment) * active_ship_attack[ship]
			}
			ships_available_for_bombardment = min(
				gc.max_bombardment_dice[land],
				gc.active_ships[sea][ship],
			)
			gc.max_bombardment_dice[land] -= ships_available_for_bombardment
			total_bombardment_value +=
				int(ships_available_for_bombardment) * active_ship_attack[ship]
			gc.active_ships[sea][ship] -= ships_available_for_bombardment
			gc.active_ships[sea][ship_after_bombardment[ship]] += ships_available_for_bombardment
			if gc.max_bombardment_dice[land] == 0 do break
		}
		gc.max_bombardment_dice[land] = 0
		attack_hits := calculate_attacker_hits_low_luck(gc, total_bombardment_value)
		remove_land_defenders(gc, land, &attack_hits)
	}
}

resolve_tactical_aa_fire :: proc(gc: ^Game_Cache, land: Land_ID) {
	/*
    AI NOTE: Anti-Aircraft Systems
    The game has TWO distinct AA systems:

    1. Tactical AA (this procedure):
       - Mobile AA gun units that can be built/moved
       - Fire at start of FIRST round of land combat
       - Can target up to 3 air units per AA gun
       - Target priority: Fighters first, then Bombers
       - Used for defending against tactical air support

    2. Strategic AA (in resolve_raid ):
       - Built into factories (1 per factory)
       - Only fire during strategic bombing raids
       - Only target bombers (fighters can't strategic bomb)
       - Used for defending industrial capacity
    
    This split system means:
    - Tactical AA protects ground forces from air support
    - Strategic AA protects economy from bombing raids
    */
	total_aaguns: u8 = 0
	for enemy in mm.enemies[gc.acting_nation] {
		total_aaguns += gc.idle_armies[land][enemy][.AAGun]
	}
	total_air_targets :=
		gc.idle_land_planes[land][gc.acting_nation][.Fighter] +
		gc.idle_land_planes[land][gc.acting_nation][.Bomber]
	// Each AA gun can target up to 3 planes
	total_defense_value := int(min(total_aaguns * 3, total_air_targets))
	defender_hits := calculate_defender_hits_low_luck(gc, total_defense_value)
	for (defender_hits > 0) {
		defender_hits -= 1
		if remove_my_land_planes(gc, land, air_casualty_order_fighters) do continue
		if remove_my_land_planes(gc, land, air_casualty_order_bombers) do continue
	}
}

resolve_raid :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
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
	bombers := gc.idle_land_planes[land][gc.acting_nation][.Bomber]
	if bombers == 0 || gc.team_land_units[land][mm.team[gc.acting_nation]] > bombers {
		return false
	}
	gc.more_land_battles_needed -= {land}
	// Strategic AA fire
	aa_defense_hits := calculate_defender_hits_low_luck(gc, int(bombers))
	for (aa_defense_hits > 0) {
		aa_defense_hits -= 1
		if remove_my_land_planes(gc, land, air_casualty_order_bombers) do continue
		break
	}
	// Bombing damage
	total_bombing_value := int(gc.idle_land_planes[land][gc.acting_nation][.Bomber]) * 21
	raid_hits := calculate_attacker_hits_low_luck(gc, total_bombing_value)
	gc.factory_dmg[land] = max(
		gc.factory_dmg[land] + raid_hits,
		gc.factory_prod[land] * 2,
	)
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
	if gc.team_land_units[land][mm.enemy_team[gc.acting_nation]] > 0 do return false
	// Only check for combat units that can be present during conquest
	if gc.idle_armies[land][gc.acting_nation][.Infantry] > 0 ||
	   gc.idle_armies[land][gc.acting_nation][.Artillery] > 0 ||
	   gc.idle_armies[land][gc.acting_nation][.Tank] > 0 {
		transfer_land_ownership(gc, land)
	}
	return true
}

add_valid_land_retreat_destinations :: proc(gc: ^Game_Cache) {
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
         a) Share a land connection (mm.lands_within_1_move)
         b) Are friendly-controlled (gc.friendly_owner)
         c) Have no pending combat (not in more_land_battles_needed)
         d) Have no ongoing combat (not in land_battle_started)
    
    3. Unit Movement:
       - All units must retreat together
       - Units become inactive after retreat
       - Combat ends in the source territory
    
    This gives players a chance to preserve units if combat is going poorly,
    but requires careful territory control to ensure retreat paths exist.
    */
	src_land := to_land(gc.current_territory)
	reset_valid_actions(gc)
	for &dst_land in mm.lands_within_1_move[src_land] {
		if dst_land in
		   (gc.friendly_owner & ~gc.more_land_battles_needed & ~gc.land_battle_started) {
			add_valid_action(gc, to_action(dst_land))
		}
	}
}

destroy_undefended_aaguns :: proc(gc: ^Game_Cache, land: Land_ID) {
	for enemy in mm.enemies[gc.acting_nation] {
		if gc.idle_armies[land][enemy][.AAGun] > 0 {
			aaguns := gc.idle_armies[land][enemy][.AAGun]
			gc.idle_armies[land][enemy][.AAGun] = 0
			gc.team_land_units[land][mm.team[enemy]] -= aaguns
		}
	}
}

MAX_VOLLEYS_PER_BATTLE :: 120
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
    
    This is why we check resolve_raid  first:
    - If it succeeds, skip all other combat
    - If it fails, proceed with traditional combat
    */
	for land in gc.more_land_battles_needed {
		if no_attackers_remain(gc, land) {
			gc.more_land_battles_needed -= {land}
			continue
		}
		if land not_in gc.land_battle_started {
			// Try strategic bombing first - if successful, skip traditional combat
			if resolve_raid(gc, land) do continue

			// Otherwise proceed with traditional combat sequence
			resolve_naval_bombardment(gc, land)
			resolve_tactical_aa_fire(gc, land)
			if no_attackers_remain(gc, land) do continue
			if check_and_conquer_land(gc, land) do continue
		}
		volley_counter = 0
		for {
			debug_checks(gc)
			volley_counter += 1
			if volley_counter > MAX_VOLLEYS_PER_BATTLE {
				fmt.eprintln(
					"resolve_land_battles: MAX_VOLLEYS_PER_BATTLE reached",
					volley_counter,
				)
				print_game_state(gc)
			}
			if land in gc.land_battle_started {
				gc.current_territory = to_region(land)
				add_valid_land_retreat_destinations(gc)
				dst_action := get_action_input(gc) or_return
				if retreat_land_units(gc, dst_action) do break
			}
			gc.land_battle_started += {land}
			attacker_hits := calculate_attacker_hits_low_luck(
				gc,
				calculate_land_attack_value(gc, land),
			)
			defender_hits := calculate_defender_hits_low_luck(
				gc,
				calculate_land_defense_value(gc, land),
			)
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
	if gc.team_land_units[land][mm.team[gc.acting_nation]] == 0 {
		gc.more_land_battles_needed -= {land}
		return true
	}
	return false
}

retreat_land_units :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> bool {
	if dst_action == .Skip_Action do return false
	src_land := to_land(gc.current_territory)
	dst_land := to_land(dst_action)
	for army in Active_Army {
		number_of_armies := gc.active_armies[src_land][army]
		gc.active_armies[dst_land][army] += number_of_armies
		gc.idle_armies[dst_land][gc.acting_nation][active_army_to_idle[army]] += number_of_armies
		gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += number_of_armies
		gc.active_armies[src_land][army] = 0
		gc.idle_armies[src_land][gc.acting_nation][active_army_to_idle[army]] = 0
		gc.team_land_units[src_land][mm.team[gc.acting_nation]] -= number_of_armies
	}
	gc.more_land_battles_needed -= {src_land}
	return true
}

remove_sea_attackers :: proc(gc: ^Game_Cache, sea: Sea_ID, hits: ^u8) {
	/*
    AI NOTE: Sea Combat Casualty Order
    
    Units are removed in a specific order to optimize fleet survival:
    1. attacker_sea_casualty_order_1: Submarines/Destroyers (weakest combat ships)
    2. attacker_sea_casualty_order_2: Carriers/Used Cruisers (medium value)
    3. attacker_sea_casualty_order_3: Used/Damaged Battleships
    4. attacker_sea_casualty_order_4: Transports (no combat value)
    
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
		if remove_my_ships(gc, sea, attacker_sea_casualty_order_1) do continue
		if remove_ally_ships(gc, sea, attacker_sea_casualty_order_1) do continue
		// if hit_my_sea_planes(gc, sea, air_casualty_order_fighters) do continue
		if remove_my_sea_fighters(gc, sea) do continue
		// if hit_ally_sea_planes(gc, sea, .Fighter) do continue
		if remove_ally_sea_fighters(gc, sea) do continue
		if remove_my_ships(gc, sea, attacker_sea_casualty_order_2) do continue
		if remove_ally_ships(gc, sea, attacker_sea_casualty_order_2) do continue
		if remove_my_sea_bombers(gc, sea) do continue
		if remove_my_ships(gc, sea, attacker_sea_casualty_order_3) do continue
		if remove_ally_ships(gc, sea, attacker_sea_casualty_order_3) do continue
		if remove_my_ships(gc, sea, attacker_sea_casualty_order_4) do continue
		if remove_ally_ships(gc, sea, attacker_sea_casualty_order_4) do continue
		return
	}
}

remove_land_attackers :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
	/*
    AI NOTE: Land Combat Casualty Order
    
    Ground units and air support have different casualty priorities:
    1. Ground Units (attacker_land_casualty_order_1):
       - Infantry, Artillery, Tanks together
       - No distinction between types (unlike sea combat)
       
    2. Air Support:
       - Fighters first (air_casualty_order_fighters)
       - Bombers last (air_casualty_order_bombers)
    
    This ordering:
    1. Treats ground units as equally valuable
    2. Preserves bombers for strategic bombing missions
    3. Uses fighters to protect bombers
    */
	for (hits^ > 0) {
		hits^ -= 1
		if remove_my_armies(gc, land, attacker_land_casualty_order_1) do continue
		if remove_my_land_planes(gc, land, air_casualty_order_fighters) do continue
		if remove_my_land_planes(gc, land, air_casualty_order_bombers) do continue
	}

}

remove_sea_defenders :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	hits: ^u8,
	submarines_targetable: bool,
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
       - Remove early to prevent First Strike
    
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
    - Submarines: enemy_submarines_total
    - Destroyers: enemy_destroyers_total, enemy_blockade_total
    - Carriers/Cruisers: enemy_blockade_total
    - Fighters: enemy_fighters_total, enemy_blockade_total
    - Transports: enemy_subvuln_ships_total
    
    Special Targeting Rules:
    1. Submarines:
       - Enemy submarines can submerge if attacker has no destroyers
       - When submerged, submarines cannot be targeted (~submarines_targetable)
       - Submarines cannot target planes (limitation of weapon type)
       
    2. Planes:
       - Only fighters can defend at sea (bombers must land)
       - Can only be targeted if attacker has anti-air (~planes_targetable)
       - Submarines cannot shoot at planes (weapon limitation)
       - But planes can target submarines if destroyers present
    
    The assertion at the end verifies that any remaining enemy units
    are only there because we couldn't target them (either submerged
    submarines or planes we couldn't shoot at).
    */
	for (hits^ > 0) {
		hits^ -= 1
		if hit_enemy_battleship(gc, sea) do continue
		if submarines_targetable && remove_enemy_ships(gc, sea, defender_submarine_casualty) do continue
		if remove_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_1) do continue
		if planes_targetable && hit_enemy_sea_fighter(gc, sea) do continue
		if remove_enemy_ships(gc, sea, Defender_Sea_Casualty_Order_2) do continue
		assert(
			gc.team_sea_units[sea][mm.enemy_team[gc.acting_nation]] == 0 ||
			!submarines_targetable ||
			!planes_targetable,
		)
		return
	}
}

remove_land_defenders :: proc(gc: ^Game_Cache, land: Land_ID, hits: ^u8) {
	for (hits^ > 0) {
		hits^ -= 1
		if remove_enemy_armies(gc, land, Defender_Land_Casualty_Order_1) do continue
		if remove_enemy_land_planes(gc, land, .Bomber) do continue
		if remove_enemy_armies(gc, land, Defender_Land_Casualty_Order_2) do continue
		if remove_enemy_land_planes(gc, land, .Fighter) do continue
	}
}

calculate_land_attack_value :: proc(gc: ^Game_Cache, land: Land_ID) -> (total_attack_value: int = 0) {
	/*
    AI NOTE: Land Combat Attack-Value Mechanics
    
    Combat in each battle round is simultaneous:
    1. Both sides roll at same time
    2. All hits are applied after both sides roll
    3. Units have different attack vs defense values
    
    Special Infantry+Artillery Combo:
    - Each infantry can be "supported" by one artillery
    - Supported infantry get artillery's attack bonus
    - That's why we use min(Infantry, Artillery) to count supported pairs
    
    Unit Attack Values (from game rules):
    - Infantry: INFANTRY_ATTACK_VALUE 
    - Artillery: ARTILLERY_ATTACK_VALUE
    - Tank: TANK_ATTACK_VALUE
    - Fighter: FIGHTER_ATTACK_VALUE 
    - Bomber: BOMBER_ATTACK_VALUE
    
    Total attack value is sum of all unit attack values. Each point of attack value
    has a chance to hit based on DICE_SIDES (simultaneous with defense rolls).
    */
	player := gc.acting_nation
	total_attack_value += int(gc.idle_armies[land][player][.Infantry]) * INFANTRY_ATTACK_VALUE
	total_attack_value +=
		int(min(gc.idle_armies[land][player][.Infantry], gc.idle_armies[land][player][.Artillery])) *
		INFANTRY_ATTACK_VALUE
	total_attack_value += int(gc.idle_armies[land][player][.Artillery]) * ARTILLERY_ATTACK_VALUE
	total_attack_value += int(gc.idle_armies[land][player][.Tank]) * TANK_ATTACK_VALUE
	total_attack_value += int(gc.idle_land_planes[land][player][.Fighter]) * FIGHTER_ATTACK_VALUE
	total_attack_value += int(gc.idle_land_planes[land][player][.Bomber]) * BOMBER_ATTACK_VALUE
	return total_attack_value
}

calculate_land_defense_value :: proc(gc: ^Game_Cache, land: Land_ID) -> (total_defense_value: int = 0) {
	/*
    AI NOTE: Land Combat Defense Values
    
    Units have separate defense values (usually lower than attack):
    - Infantry: INFANTRY_DEFENSE_VALUE
    - Artillery: ARTILLERY_DEFENSE_VALUE  
    - Tank: TANK_DEFENSE_VALUE
    - Fighter: FIGHTER_DEFENSE_VALUE
    - Bomber: BOMBER_DEFENSE_VALUE
    
    Defense rolls happen simultaneously with attack rolls.
    Each point of defensive damage also has a chance to hit
    based on DICE_SIDES.
    
    Note: AA Guns don't participate in normal combat.
    They only fire in the special AA defense phase.
    */
	for player in mm.enemies[gc.acting_nation] {
		total_defense_value += int(gc.idle_armies[land][player][.Infantry]) * INFANTRY_DEFENSE_VALUE
		total_defense_value += int(gc.idle_armies[land][player][.Artillery]) * ARTILLERY_DEFENSE_VALUE
		total_defense_value += int(gc.idle_armies[land][player][.Tank]) * TANK_DEFENSE_VALUE
		total_defense_value += int(gc.idle_land_planes[land][player][.Fighter]) * FIGHTER_DEFENSE_VALUE
		total_defense_value += int(gc.idle_land_planes[land][player][.Bomber]) * BOMBER_DEFENSE_VALUE
	}
	return total_defense_value
}

hit_my_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	/*
    AI NOTE: Battleship Damage Mechanics
    
    Battleships are unique in having two health states:
    1. Fresh (.Battleship) -> Can be damaged
    2. Damaged (.Battleship_Damaged) -> Will be destroyed
    
    Combat totals are preserved when damaged because:
    - Still counts as a combat ship
    - Still has anti-fighter capability
    - Only loses bombardment ability
    */
	if gc.active_ships[sea][.Battleship_Bombarded] > 0 {
		gc.active_ships[sea][.Battleship_Damaged_Bombarded] += 1
		gc.idle_ships[sea][gc.acting_nation][.Battleship_Damaged] += 1
		gc.active_ships[sea][.Battleship_Bombarded] -= 1
		gc.idle_ships[sea][gc.acting_nation][.Battleship] -= 1
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
	for ally in mm.allies[gc.acting_nation] {
		if ally == gc.acting_nation do continue
		if gc.idle_ships[sea][ally][.Battleship] > 0 {
			gc.idle_ships[sea][ally][.Battleship] -= 1
			gc.idle_ships[sea][ally][.Battleship_Damaged] += 1
			// Don't update combat totals - damaged battleship still counts
			return true
		}
	}
	return false
}

hit_enemy_battleship :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for enemy in mm.enemies[gc.acting_nation] {
		if gc.idle_ships[sea][enemy][.Battleship] > 0 {
			gc.idle_ships[sea][enemy][.Battleship] -= 1
			gc.idle_ships[sea][enemy][.Battleship_Damaged] += 1
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
       - friendly_antifighter_ships_total:
         * Decremented for destroyers/carriers/cruisers
         * These ships can shoot at fighters
       
       - friendly_sea_combatants_total:
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
			gc.idle_ships[sea][gc.acting_nation][active_ship_to_idle[ship]] -= 1
			gc.team_sea_units[sea][mm.team[gc.acting_nation]] -= 1

			// Update combat totals
			if ship == .Destroyer_0_Moves {
				gc.friendly_antifighter_ships_total[sea] -= 1
				gc.friendly_sea_combatants_total[sea] -= 1
			} else if ship == .Carrier_0_Moves ||
			   ship == .Cruiser_0_Moves ||
			   ship == .Cruiser_Bombarded ||
			   ship == .Battleship_Damaged_Bombarded {
				gc.friendly_antifighter_ships_total[sea] -= 1
				gc.friendly_sea_combatants_total[sea] -= 1
			}
			// else if ship != .TRANSPORT_0_Moves {
			// 	// All non-transport ships are combat ships
			// 	gc.friendly_sea_combatants_total[sea] -= 1
			// }
			return true
		}
	}
	return false
}

remove_ally_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Active_Ship) -> bool {
	for ship in casualty_order {
		for ally in mm.allies[gc.acting_nation] {
			if ally == gc.acting_nation do continue
			if gc.idle_ships[sea][ally][active_ship_to_idle[ship]] > 0 {
				gc.idle_ships[sea][ally][active_ship_to_idle[ship]] -= 1
				gc.team_sea_units[sea][mm.team[ally]] -= 1
				return true
			}
		}
	}
	return false
}

remove_enemy_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, casualty_order: []Idle_Ship) -> bool {
	for ship in casualty_order {
		for enemy in mm.enemies[gc.acting_nation] {
			if gc.idle_ships[sea][enemy][ship] > 0 {
				gc.idle_ships[sea][enemy][ship] -= 1
				gc.team_sea_units[sea][mm.team[enemy]] -= 1
				if ship == .Destroyer {
					gc.enemy_destroyers_total[sea] -= 1
					gc.enemy_blockade_total[sea] -= 1
				} else if ship == .Submarine {
					gc.enemy_submarines_total[sea] -= 1
				} else if ship == .Carrier || ship == .Cruiser || ship == .Battleship_Damaged {
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
			gc.idle_land_planes[land][gc.acting_nation][active_plane_to_idle[plane]] -= 1
			gc.team_land_units[land][mm.team[gc.acting_nation]] -= 1
			return true
		}
	}
	return false
}

remove_my_sea_fighters :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for plane in air_casualty_order_fighters {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			remove_ally_fighters_from_sea(gc, sea, gc.acting_nation, 1)
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
       - friendly_antifighter_ships_total (bombers can fight fighters)
       - friendly_sea_combatants_total (bombers are combat ships)
    */
	for plane in air_casualty_order_bombers {
		if gc.active_sea_planes[sea][plane] > 0 {
			gc.active_sea_planes[sea][plane] -= 1
			gc.idle_sea_planes[sea][gc.acting_nation][.Bomber] -= 1
			gc.team_sea_units[sea][mm.team[gc.acting_nation]] -= 1
			gc.friendly_antifighter_ships_total[sea] -= 1
			gc.friendly_sea_combatants_total[sea] -= 1
			return true
		}
	}
	return false
}

hit_ally_land_planes :: proc(gc: ^Game_Cache, land: Land_ID, idle_plane: Idle_Plane) -> bool {
	for ally in mm.allies[gc.acting_nation] {
		if ally == gc.acting_nation do continue
		if gc.idle_land_planes[land][ally][idle_plane] > 0 {
			gc.idle_land_planes[land][ally][idle_plane] -= 1
			gc.team_land_units[land][mm.team[gc.acting_nation]] -= 1
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
	for ally in mm.allies[gc.acting_nation] {
		if ally == gc.acting_nation do continue
		if gc.idle_sea_planes[sea][ally][.Fighter] > 0 {
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
	for enemy in mm.enemies[gc.acting_nation] {
		if gc.idle_sea_planes[sea][enemy][.Fighter] > 0 {
			gc.idle_sea_planes[sea][enemy][.Fighter] -= 1
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
	for enemy in mm.enemies[gc.acting_nation] {
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
	enemies: ^Nation_List,
) -> bool {
	for enemy in enemies {
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
			gc.idle_armies[land][gc.acting_nation][active_army_to_idle[army]] -= 1
			gc.team_land_units[land][mm.team[gc.acting_nation]] -= 1
			return true
		}
	}
	return false
}

remove_enemy_armies :: proc(gc: ^Game_Cache, land: Land_ID, casualty_order: []Idle_Army) -> bool {
	for army in casualty_order {
		for player in mm.enemies[gc.acting_nation] {
			if gc.idle_armies[land][player][army] > 0 {
				gc.idle_armies[land][player][army] -= 1
				gc.team_land_units[land][mm.team[player]] -= 1
				return true
			}
		}
	}
	return false
}

get_total_attack_value_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (total_attack_value: int = 0) {
	for ally in mm.allies[gc.acting_nation] {
		total_attack_value += int(gc.idle_ships[sea][ally][.Destroyer]) * DESTROYER_ATTACK_VALUE
		total_attack_value += int(gc.idle_ships[sea][ally][.Carrier]) * CARRIER_ATTACK_VALUE
		total_attack_value += int(gc.idle_ships[sea][ally][.Cruiser]) * CRUISER_ATTACK_VALUE
		total_attack_value += int(gc.idle_ships[sea][ally][.Battleship]) * BATTLESHIP_ATTACK_VALUE
		total_attack_value += int(gc.idle_ships[sea][ally][.Battleship_Damaged]) * BATTLESHIP_ATTACK_VALUE
		total_attack_value += int(gc.idle_sea_planes[sea][ally][.Fighter]) * FIGHTER_ATTACK_VALUE
	}
	total_attack_value += int(gc.idle_sea_planes[sea][gc.acting_nation][.Bomber]) * BOMBER_ATTACK_VALUE
	return total_attack_value
}

calculate_naval_defense_value :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (total_defense_value: int = 0) {
	for enemy in mm.enemies[gc.acting_nation] {
		total_defense_value += int(gc.idle_ships[sea][enemy][.Destroyer]) * DESTROYER_DEFENSE_VALUE
		total_defense_value += int(gc.idle_ships[sea][enemy][.Carrier]) * CARRIER_DEFENSE_VALUE
		total_defense_value += int(gc.idle_ships[sea][enemy][.Cruiser]) * CRUISER_DEFENSE_VALUE
		total_defense_value += int(gc.idle_ships[sea][enemy][.Battleship]) * BATTLESHIP_DEFENSE_VALUE
		total_defense_value += int(gc.idle_ships[sea][enemy][.Battleship_Damaged]) * BATTLESHIP_DEFENSE_VALUE
		total_defense_value += int(gc.idle_sea_planes[sea][enemy][.Fighter]) * FIGHTER_DEFENSE_VALUE
	}
	return total_defense_value
}
calculate_submarine_defense_value :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (total_defense_value: int = 0) {
	for enemy in mm.enemies[gc.acting_nation] {
		total_defense_value += int(gc.idle_ships[sea][enemy][.Submarine]) * SUBMARINE_DEFENSE_VALUE
	}
	return total_defense_value
}

/*
AI NOTE: Enemy bombers cannot defend at sea since they must land after their turn.
The hit_enemy_sea_bomber procedure was removed since it was added by mistake.
*/
