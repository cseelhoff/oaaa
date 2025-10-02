package oaaa

import "core:fmt"
import "core:math/rand"
import sa "core:container/small_array"

// Debug separators
SEP_LONG :: "======================================================================"
SEP_MED  :: "============================================================"

/*
Pro AI Turn Implementation

This file implements a TripleA-style Pro AI turn structure designed for fast MCTS rollouts.
The Pro AI makes quick, reasonable decisions to reach terminal states faster than random play.

Turn Phases (matching TripleA structure):
1. Purchase Phase - Decide what units to buy
2. Combat Move Phase - Move units to attack territories
3. Combat Phase - Resolve all battles
4. Non-Combat Move Phase - Move remaining units to safe positions
5. Place Units Phase - Place newly purchased units
6. End Turn Phase - Collect income and advance to next player

Key Differences from play_full_turn:
- Makes strategic decisions rather than enumerating all possibilities
- Focuses on quick evaluation and good-enough moves
- Designed for rollout speed, not exhaustive search
*/

// Main Pro AI turn function - called during MCTS rollouts when use_pro_ai_rollout flag is set
play_full_proai_turn :: proc(gc: ^Game_Cache) -> (ok: bool) {
	debug_checks(gc)
	
	// Phase 1: Purchase Phase
	// Pro AI decides what units to purchase based on strategic needs
	proai_purchase_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 2: Combat Move Phase
	// Move air units, naval units, and ground units into combat positions
	proai_combat_move_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 3: Combat Phase
	// Resolve all sea and land battles
	proai_combat_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 4: Non-Combat Move Phase
	// Move remaining units to defensive/strategic positions
	proai_noncombat_move_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 5: Place Units Phase
	// Place purchased units at factories
	proai_place_units_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 6: End Turn Phase
	// Clean up, collect income, rotate to next player
	rotate_turns(gc)
	debug_checks(gc)
	
	return true
}

// Test Pro AI for a single turn with debug output
test_proai_single_turn :: proc(gs: ^Game_State) -> bool {
	fmt.println("\n" + SEP_LONG)
	fmt.println("PRO AI SINGLE TURN TEST (TripleA Purchase & Place)")
	fmt.println(SEP_LONG)
	fmt.printf("Starting Player: %v\n", gs.cur_player)
	fmt.printf("Starting Money: %d IPCs\n", gs.money[gs.cur_player])
	
	// Count initial units
	total_units := 0
	for land in Land_ID {
		for player in Player_ID {
			for army in Idle_Army {
				total_units += int(gs.idle_armies[land][player][army])
			}
		}
	}
	fmt.printf("Total units on board: %d\n", total_units)
	fmt.println(SEP_LONG)
	
	gc: Game_Cache
	load_cache_from_state(&gc, gs)
	gc.answers_remaining = 65000
	gc.seed = u16(rand.int_max(RANDOM_MAX))
	
	debug_checks(&gc)
	
	// Run a single Pro AI turn using TripleA methods
	if !play_full_proai_turn(&gc) {
		fmt.eprintln("\n" + SEP_LONG)
		fmt.eprintln("*** PRO AI TURN FAILED! ***")
		fmt.eprintln(SEP_LONG + "\n")
		return false
	}
	
	// Count final units
	final_units := 0
	for land in Land_ID {
		for player in Player_ID {
			for army in Idle_Army {
				final_units += int(gc.state.idle_armies[land][player][army])
			}
		}
	}
	
	fmt.println("\n" + SEP_LONG)
	fmt.println("PRO AI TURN COMPLETE")
	fmt.println(SEP_LONG)
	fmt.printf("Next Player: %v\n", gc.cur_player)
	fmt.printf("Final Money: %d IPCs\n", gc.state.money[gs.cur_player])
	fmt.printf("Units Added: %d\n", final_units - total_units)
	fmt.printf("Game Score: %.1f\n", evaluate_cache(&gc))
	fmt.println(SEP_LONG + "\n")
	
	// Save the state back
	gs^ = gc.state
	
	return true
}

/*
Phase 1: Purchase Phase

Pro AI strategic purchasing decisions using TripleA's ProPurchaseAi.java logic.
This includes:
- Evaluating current board state
- Determining strategic priorities (offense vs defense)
- Purchasing units that best serve immediate needs
- Considering factory placement if economically viable
*/
proai_purchase_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	starting_money := gc.money[gc.cur_player]
	
	when ODIN_DEBUG {
		fmt.println("\n" + SEP_MED)
		fmt.println("PURCHASE PHASE")
		fmt.println(SEP_MED)
		fmt.printf("Player: %v\n", gc.cur_player)
		fmt.printf("Starting Money: %d IPCs\n", starting_money)
		fmt.println()
	}
	
	// Call TripleA purchase implementation
	if !purchase_triplea(gc) {
		when ODIN_DEBUG {
			fmt.println("\n*** PURCHASE PHASE FAILED ***")
		}
		return false
	}
	
	when ODIN_DEBUG {
		money_spent := starting_money - gc.money[gc.cur_player]
		fmt.printf("\nRemaining Money: %d IPCs\n", gc.money[gc.cur_player])
		fmt.printf("Money Spent: %d IPCs\n", money_spent)
		if money_spent == 0 && starting_money > 0 {
			fmt.println("  [WARNING] No money was spent despite having IPCs available!")
			fmt.println("  This may indicate purchase logic is not executing properly.")
		}
		fmt.println(SEP_MED + "\n")
	}
	
	return true
}

/*
Phase 2: Combat Move Phase

Pro AI combat movement strategy using TripleA's ProCombatMoveAi.java logic.
The implementation uses the TripleA methods from pro_combat_move_triplea_methods.odin.

For now, simplified version with detailed debug output showing decision logic.
*/
proai_combat_move_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("\n" + SEP_MED)
		fmt.println("COMBAT MOVE PHASE")
		fmt.println(SEP_MED)
	}
	
	// Step 1: Find all enemy territories we might want to attack
	attack_options := make([dynamic]Attack_Option)
	defer delete(attack_options)
	
	when ODIN_DEBUG {
		fmt.println("\n[STEP 1] Finding ALL units that can attack (populateAttackOptions)...")
	}
	
	// Call the FULL TripleA implementation
	populate_attack_options_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		fmt.printf("  → Found %d potential attack targets\n", len(attack_options))
	}
	
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println("  → No enemy territories found")
			fmt.println(SEP_MED + "\n")
		}
		return true
	}
	
	// Step 2: Prioritize attack options by strategic value
	when ODIN_DEBUG {
		fmt.println("\n[STEP 2] Prioritizing attack targets by strategic value...")
	}
	
	prioritize_attack_options_triplea(gc, &attack_options, false)
	
	when ODIN_DEBUG {
		fmt.println("  Attack priority order:")
		count := min(10, len(attack_options)) // Show top 10
		for i := 0; i < count; i += 1 {
			opt := attack_options[i]
			production, is_capital := get_production_and_is_capital_triplea(gc, opt.territory)
			has_factory_flag := has_factory(gc, opt.territory)
			fmt.printf("    %d. %v (value: %.1f, production: %d", 
				i+1, opt.territory, opt.attack_value, production)
			if is_capital do fmt.printf(", CAPITAL")
			if has_factory_flag do fmt.printf(", FACTORY")
			fmt.printf(")\n")
		}
		if len(attack_options) > 10 {
			fmt.printf("    ... and %d more targets\n", len(attack_options) - 10)
		}
	}
	
	// Step 3: Check which territories can be held after capture
	when ODIN_DEBUG {
		fmt.println("\n[STEP 3] Checking which territories can be held after capture...")
	}
	
	determine_territories_that_can_be_held_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		holdable_count := 0
		for opt in attack_options {
			if opt.can_hold do holdable_count += 1
		}
		fmt.printf("  → %d of %d territories can be held\n", 
			holdable_count, len(attack_options))
		
		// Show first few holdable territories
		shown := 0
		for opt in attack_options {
			if opt.can_hold && shown < 5 {
				fmt.printf("    ✓ %v (can hold)\n", opt.territory)
				shown += 1
			}
		}
	}
	
	// Step 4: Remove territories not worth attacking
	when ODIN_DEBUG {
		fmt.println("\n[STEP 4] Filtering out low-value targets...")
		initial_count := len(attack_options)
	}
	
	remove_territories_that_arent_worth_attacking_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		removed := initial_count - len(attack_options)
		fmt.printf("  → Removed %d low-value targets, %d remain\n", removed, len(attack_options))
		if len(attack_options) > 0 {
			fmt.println("  Targets worth attacking:")
			for opt in attack_options {
				fmt.printf("    - %v (value: %.1f, holdable: %v)\n", 
					opt.territory, opt.attack_value, opt.can_hold)
			}
		} else {
			fmt.println("  → No attacks worth executing (all targets filtered out)")
			fmt.println("  Reasons: low strategic value, can't hold after capture, or too risky")
		}
	}
	
	// Early exit if no attacks to execute
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println(SEP_MED + "\n")
		}
		return true
	}
	
	// Step 5: Determine which territories to actually attack (iterative selection)
	when ODIN_DEBUG {
		fmt.println("\n[STEP 5] Selecting territories to attack (iterative algorithm)...")
		initial_count = len(attack_options)
	}
	
	determine_territories_to_attack_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		removed = initial_count - len(attack_options)
		fmt.printf("  → Selected %d territories for attack (removed %d unsuccessful)\n", 
			len(attack_options), removed)
		if len(attack_options) > 0 {
			fmt.println("  Final attack targets:")
			for opt in attack_options {
				fmt.printf("    - %v (value: %.1f)\n", opt.territory, opt.attack_value)
			}
		}
	}
	
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println("  → No successful attacks possible")
			fmt.println(SEP_MED + "\n")
		}
		return true
	}
	
	// Step 6: Re-calculate enemy attacks and re-filter with final selection
	when ODIN_DEBUG {
		fmt.println("\n[STEP 6] Re-calculating with final attack selection...")
	}
	
	recalculate_enemy_attacks_after_territory_selection_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		fmt.printf("  → %d attacks remain after recalculation\n", len(attack_options))
	}
	
	if len(attack_options) == 0 {
		when ODIN_DEBUG {
			fmt.println("  → All attacks became unfavorable after recalculation")
			fmt.println(SEP_MED + "\n")
		}
		return true
	}
	
	// Step 7: Move defenders to border territories
	when ODIN_DEBUG {
		fmt.println("\n[STEP 7] Moving defenders to border territories...")
	}
	
	border_moves := move_one_defender_to_land_territories_bordering_enemy_triplea(gc, &attack_options)
	defer delete(border_moves)
	
	when ODIN_DEBUG {
		fmt.printf("  → Made %d border defender moves\n", len(border_moves))
	}
	
	// Step 8: Remove attacks where transports would be exposed
	when ODIN_DEBUG {
		fmt.println("\n[STEP 8] Checking transport safety...")
		initial_count = len(attack_options)
	}
	
	remove_territories_where_transports_are_exposed_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		removed = initial_count - len(attack_options)
		if removed > 0 {
			fmt.printf("  → Removed %d amphibious attacks (transports exposed)\n", removed)
		} else {
			fmt.println("  → All transports safe")
		}
	}
	
	// Step 9: Ensure capital can be defended
	when ODIN_DEBUG {
		fmt.println("\n[STEP 9] Ensuring capital defense...")
		initial_count = len(attack_options)
	}
	
	remove_attacks_until_capital_can_be_held_triplea(gc, &attack_options)
	
	when ODIN_DEBUG {
		removed = initial_count - len(attack_options)
		if removed > 0 {
			fmt.printf("  → Removed %d attacks to defend capital\n", removed)
		} else {
			fmt.println("  → Capital can be defended with current attack plan")
		}
		
		if len(attack_options) > 0 {
			fmt.println("\n  FINAL ATTACK PLAN:")
			for opt in attack_options {
				fmt.printf("    → Attack %v (value: %.1f, holdable: %v)\n", 
					opt.territory, opt.attack_value, opt.can_hold)
			}
		} else {
			fmt.println("\n  → No attacks will be executed (all removed for capital defense)")
		}
	}
	
	// Step 10: Determine specific units to attack with
	when ODIN_DEBUG {
		fmt.println("\n[STEP 10] Assigning units to each attack...")
	}
	
	determine_units_to_attack_with_triplea(gc, &attack_options, &border_moves)
	
	when ODIN_DEBUG {
		if len(attack_options) > 0 {
			fmt.println("\n  UNIT ASSIGNMENTS:")
			for opt in attack_options {
				attacker_count := len(opt.attackers)
				amphib_count := len(opt.amphib_attackers)
				bombard_count := len(opt.bombard_units)
				
				fmt.printf("    %v:\n", opt.territory)
				
				// Show ground/air attackers with source territories
				if attacker_count > 0 {
					fmt.printf("      Ground/Air attackers (%d units):\n", attacker_count)
					// Group by unit type for cleaner output
					unit_type_counts: map[Unit_Type][dynamic]Land_ID
					defer {
						for _, sources in unit_type_counts {
							delete(sources)
						}
						delete(unit_type_counts)
					}
					
					for unit in opt.attackers {
						if unit.unit_type not_in unit_type_counts {
							unit_type_counts[unit.unit_type] = make([dynamic]Land_ID)
						}
						append(&unit_type_counts[unit.unit_type], unit.from_territory)
					}
					
					// Print grouped by type
					for unit_type, sources in unit_type_counts {
						fmt.printf("        - %d x %v from: ", len(sources), unit_type)
						for source, i in sources {
							if i > 0 do fmt.printf(", ")
							fmt.printf("%v", source)
						}
						fmt.printf("\n")
					}
				}
				
				// Show amphibious attackers
				if amphib_count > 0 {
					fmt.printf("      Amphibious attackers (%d units):\n", amphib_count)
					unit_type_counts: map[Unit_Type][dynamic]Land_ID
					defer {
						for _, sources in unit_type_counts {
							delete(sources)
						}
						delete(unit_type_counts)
					}
					
					for unit in opt.amphib_attackers {
						if unit.unit_type not_in unit_type_counts {
							unit_type_counts[unit.unit_type] = make([dynamic]Land_ID)
						}
						append(&unit_type_counts[unit.unit_type], unit.from_territory)
					}
					
					for unit_type, sources in unit_type_counts {
						fmt.printf("        - %d x %v from sea zones: ", len(sources), unit_type)
						for source, i in sources {
							if i > 0 do fmt.printf(", ")
							fmt.printf("Sea_%v", source)
						}
						fmt.printf("\n")
					}
				}
				
				// Show bombardment support
				if bombard_count > 0 {
					fmt.printf("      Bombardment support (%d units):\n", bombard_count)
				}
				
				// Show attack vs defense strength
				attack_power := calculate_total_attack_power(gc, opt.attackers, opt.amphib_attackers)
				defense_power := calculate_total_defense_power(gc, opt.defenders)
				fmt.printf("      Total: %.1f attack vs %.1f defense\n", attack_power, defense_power)
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.println(SEP_MED + "\n")
	}
	
	// Step 11: Execute combat moves (doMove)
	// Java Original: ProCombatMoveAi.doMove() (lines 153-167)
	/*
	  void doMove(
	      final Map<Territory, ProTerritory> attackMap,
	      final IMoveDelegate moveDel,
	      final GameData data,
	      final GamePlayer player) {
	    this.data = data;
	    this.player = player;

	    ProMoveUtils.doMove(
	        proData, ProMoveUtils.calculateMoveRoutes(proData, player, attackMap, true), moveDel);
	    ProMoveUtils.doMove(
	        proData, ProMoveUtils.calculateAmphibRoutes(proData, player, attackMap, true), moveDel);
	    ProMoveUtils.doMove(
	        proData, ProMoveUtils.calculateBombardMoveRoutes(proData, player, attackMap), moveDel);
	    isBombing = true;
	    ProMoveUtils.doMove(
	        proData, ProMoveUtils.calculateBombingRoutes(proData, player, attackMap), moveDel);
	    isBombing = false;
	  }
	*/
	
	when ODIN_DEBUG {
		fmt.println("\n[STEP 11] Executing combat moves (doMove)")
	}
	
	// Execute all planned attacks
	execute_combat_moves_triplea(gc, &attack_options) or_return
	
	return true
}

/*
Phase 3: Combat Phase

Resolve all battles:
- Sea battles (can affect amphibious assaults)
- Land battles (territorial control)
- Pro AI makes tactical combat decisions (retreat vs fight)

NOTE: Tactical combat resolution (retreat vs fight decisions) will NOT be implemented
for quite some time. This phase uses standard OAAA combat resolution.

Reasoning: Tactical combat decisions during battle are complex and require:
1. Monte Carlo simulation of battle outcomes with retreat at various points
2. Analysis of unit preservation vs territory capture trade-offs
3. Prediction of enemy counter-attacks after retreat
4. Integration with overall strategy (when to trade units, when to preserve)

For MCTS rollouts, standard combat resolution (fight to the end) is sufficient
and much faster. The strategic value comes from good attack/defense positioning,
not from retreat micro-decisions.

Future Enhancement: Could add simple retreat logic like:
- Retreat if battle odds drop below 30%
- Retreat if losing expensive units (tanks, bombers) with poor odds
- Never retreat from capital or critical territories
*/
proai_combat_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// Use standard OAAA combat resolution
	// No special Pro AI tactical decisions (stubbed for future)
	
	// Resolve sea battles first (affects transports)
	resolve_sea_battles(gc) or_return
	
	// Unload surviving transports
	unload_transports(gc) or_return
	
	// Resolve land battles
	resolve_land_battles(gc) or_return
	
	return true
}

/*
Phase 4: Non-Combat Move Phase

Pro AI non-combat movement strategy.
This is implemented in pro_noncombat_move.odin and includes:
- Moving air units to safe landing zones
- Repositioning naval units for defense/next turn
- Moving ground units to defensive positions
- Consolidating forces in key territories
- Moving AA guns to important locations

The proai_noncombat_move_phase function is defined in pro_noncombat_move.odin.
*/

/*
Phase 5: Place Units Phase

Pro AI unit placement strategy using TripleA's ProPurchaseAi.java logic.
This is implemented in pro_place.odin and includes:
- Place units purchased during purchase phase
- Prioritize threatened territories needing defense
- Place defenders at capital and factories first
- Place remaining units at strategic locations
- Respect factory production capacity limits

The proai_place_units_phase function is defined in pro_place.odin
and uses the TripleA methods from pro_purchase_triplea_methods.odin.
*/

/*
Phase 6: End Turn Phase

Clean up and prepare for next player:
- Repair damaged battleships
- Collect income
- Rotate to next player
*/
proai_end_turn_phase :: proc(gc: ^Game_Cache) {
	reset_units_fully(gc)
	collect_money(gc)
	rotate_turns(gc)
}

// ===== Combat Move Phase Helper Functions =====

proai_move_air_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart fighter/bomber combat positioning
	// Strategy: Move air to territories where they tip the battle odds favorably
	
	// Stub: For now, skip air combat moves for rapid rollout
	return true
}

proai_move_ships_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
	Naval Combat Movement Strategy (based on ship.odin move_combat_ships):
	
	1. Attack weak enemy naval forces (no destroyers, just transports)
	2. Clear sea zones blocking amphibious assaults
	3. Position destroyers to detect enemy subs
	4. Protect our transports with combat ships
	5. Control strategic sea zones (near enemy coasts)
	
	Ship Movement Rules (from ship.odin):
	- All combat ships have 2 moves (Unmoved_Blockade_Ships)
	- Ships automatically mark seas for combat when entering enemy zones
	- Submarines can move through enemy blockades unless destroyers present
	- Other ships blocked by enemy blockade (destroyer/carrier/cruiser/battleship)
	
	For MCTS rollouts, we use simplified heuristics:
	- Attack if we outnumber enemy (quick power comparison)
	- Don't expose transports unnecessarily
	- Maintain sea control near our territories
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Naval combat movement phase (simplified)")
	}
	
	// Find target enemy sea zones to attack
	for sea in Sea_ID {
		// Skip if no enemy units
		if gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 {
			continue
		}
		
		// Skip if we don't have ships nearby
		if !has_friendly_ships_adjacent(gc, sea) {
			continue
		}
		
		// Simple heuristic: Only attack if enemy has no blockade ships
		// (just transports or subs without destroyer protection)
		if gc.enemy_blockade_total[sea] == 0 ||
		   (gc.enemy_subs_total[sea] > 0 && gc.enemy_destroyer_total[sea] == 0) {
			// Worthwhile target - clear it out
			when ODIN_DEBUG {
				fmt.printf("[PRO-AI] Would attack weak enemy fleet at sea %v\n", sea)
			}
			// Actual movement would use pro_move_execute.odin execute_sea_move
			// For now, just note the opportunity
		}
	}
	
	// For rapid MCTS rollouts, we skip detailed naval combat for now
	// Naval battles are secondary to land control in most scenarios
	// Future: Implement targeted naval attacks using execute_sea_move
	
	return true
}

// Check if we have friendly combat ships adjacent to a sea zone
has_friendly_ships_adjacent :: proc(gc: ^Game_Cache, target_sea: Sea_ID) -> bool {
	canal_state := transmute(u8)gc.canals_open
	
	for adjacent_sea in mm.s2s_1away_via_sea[canal_state][target_sea] {
		// Check for combat ships (not transports)
		if gc.idle_ships[adjacent_sea][gc.cur_player][.SUB] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.DESTROYER] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.CRUISER] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.BATTLESHIP] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.BS_DAMAGED] > 0 do return true
	}
	
	return false
}

proai_load_transports_for_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart transport loading for amphibious assaults
	// Strategy: Load transports with units to capture valuable territories
	
	// Stub: For now, skip transport loading for rapid rollout
	return true
}

proai_move_ground_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart ground unit combat positioning
	// Strategy: Attack weak territories, consolidate forces for major attacks
	
	// Stub: For now, skip ground combat moves for rapid rollout
	return true
}

// ===== Non-Combat Move Phase Helper Functions =====

proai_land_fighters_safe :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart fighter landing
	// Strategy: Land on carriers or friendly territories with defensive value
	
	// Stub: Use existing landing logic for now
	land_remaining_fighters(gc) or_return
	return true
}

proai_land_bombers_safe :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart bomber landing
	// Strategy: Land in territories that provide good offensive reach for next turn
	
	// Stub: Use existing landing logic for now
	land_remaining_bombers(gc) or_return
	return true
}

proai_move_ships_noncombat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart non-combat naval movement
	// Strategy: Move ships to defensive positions or staging areas
	
	// Stub: For now, skip non-combat naval moves for rapid rollout
	return true
}

proai_move_ground_noncombat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart non-combat ground movement
	// Strategy: Consolidate forces, reinforce threatened territories
	
	// Stub: For now, skip non-combat ground moves for rapid rollout
	return true
}

/*
Future Enhancement Notes:

The stub functions above should eventually implement Pro AI decision-making logic:

1. Territory Evaluation:
   - Calculate value of each territory (IPC value, strategic importance)
   - Assess threat level (enemy units nearby)
   - Determine control status (friendly, enemy, contested)

2. Attack Planning:
   - Calculate battle odds for potential attacks
   - Prioritize high-value, low-risk targets
   - Consider follow-up attacks and defensive needs

3. Defense Planning:
   - Identify threatened friendly territories
   - Calculate minimum defense needed
   - Move units to reinforce weak points

4. Unit Routing:
   - Use movement range efficiently
   - Prefer safe paths when possible
   - Consider unit types and their roles

5. Economic Considerations:
   - Balance offense vs defense spending
   - Prioritize unit types based on game situation
   - Consider long-term strategic value

The goal is to make decisions quickly (no exhaustive search) while still playing reasonably well,
allowing MCTS rollouts to reach terminal states faster than random play.
*/
