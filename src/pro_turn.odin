package oaaa

import "base:intrinsics"
import sa "core:container/small_array"
import "core:fmt"
import "core:math/rand"

// Debug separators
SEP_LONG :: "======================================================================"
SEP_MED :: "============================================================"

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

TODO REVIEW: Missing Java Pro AI modules:

1. ProRetreatAi.java - ENTIRE MODULE MISSING
   - shouldRetreat() - Decide if should retreat from battle
   - getRetreatTerritories() - Find valid retreat territories
   - shouldSubmerge() - Decide if subs should submerge
   * Currently: Odin fights to the death (no retreat logic)

2. ProScrambleAi.java - ENTIRE MODULE MISSING
   - shouldScramble() - Decide if defending air should scramble
   - getScrambleDefenders() - Select which planes scramble
   * Currently: Scramble not implemented

3. ProPoliticsAi.java - ENTIRE MODULE MISSING
   - shouldDeclareWar() - Decide war declarations
   - getPoliticalActions() - Choose political actions
   * Currently: No politics support

4. ProTechAi.java - ENTIRE MODULE MISSING
   - shouldResearchTech() - Decide if should research technology
   - getTechToResearch() - Choose which tech to pursue
   * Currently: No technology support

5. AbstractProAi.java delegate methods - PARTIAL
   - selectCasualties() - Choose which units die first
   - selectBombardingTerritories() - Choose bombardment targets
   - selectFixedDice() - For games with dice selection
   * Currently: Uses default casualty selection
*/

/*
=============================================================================
PHASE-BY-PHASE COMPARISON: Java AbstractProAi vs Odin play_full_proai_turn
=============================================================================

JAVA TURN FLOW (from AbstractProAi.java):
------------------------------------------

1. PURCHASE PHASE (purchase() method, lines 140-226)
   Java Flow:
   a. purchaseAi.repair() - Repair damaged factories                    [+] repair_factories_triplea
   b. ProPurchaseUtils.findPurchaseTerritories() - Find factories       [+] find_purchase_territories_triplea
   c. SIMULATION LOOP - Simulate future phases before purchasing:       [!] NOT IMPLEMENTED
      - Simulates combat move via combatMoveAi.doCombatMove()
      - Simulates battles via ProSimulateTurnUtils.simulateBattles()
      - Simulates non-combat via nonCombatMoveAi.simulateNonCombatMove()
      - THEN makes purchase decisions based on simulated state
   d. purchaseAi.purchase() - Make actual purchases                     [+] purchase_triplea
   e. Stores: storedCombatMoveMap, storedFactoryMoveMap                 [-] No stored maps

2. COMBAT MOVE PHASE (move() method with nonCombat=false, lines 108-138)
   Java Flow:
   a. If storedCombatMoveMap exists: combatMoveAi.doMove(storedMap)     [-] No stored map support
   b. Else: combatMoveAi.doCombatMove(moveDel)                          [+] proai_combat_move_phase
   c. If no non-combat phase: also do nonCombatMoveAi.doNonCombatMove() [-] Not checked

3. BATTLE PHASE (implicit - handled by game engine)
   Java: BattleDelegate handles battles, calls back to AI for:
   a. retreatQuery() - Decide retreat/submerge                          [-] NOT IMPLEMENTED
   b. selectCasualties() - Choose casualty order                        [!] Default order used
   c. selectAttackSubs() - Decide sub attack vs retreat                 [-] NOT IMPLEMENTED
   d. shouldBomberBomb() - Confirm strategic bombing                    [-] NOT IMPLEMENTED

4. NON-COMBAT MOVE PHASE (move() with nonCombat=true, lines 108-138)
   Java Flow:
   a. If storedFactoryMoveMap exists: use stored map                    [-] No stored map support
   b. nonCombatMoveAi.doNonCombatMove(storedFactoryMoveMap, ...)       [+] proai_noncombat_move_phase
   c. Clear storedFactoryMoveMap                                        [-] No stored maps

5. PLACE PHASE (place() method, lines 228-238)
   Java Flow:
   a. purchaseAi.place(storedPurchaseTerritories, placeDelegate)        [+] proai_place_units_phase
   b. Clear storedPurchaseTerritories                                   [+] g_purchased_units cleared

6. TECH PHASE (tech() method, lines 240-243)
   Java: ProTechAi.tech(techDelegate, data, player)                     [-] NOT IMPLEMENTED

7. POLITICS PHASE (politicalActions() method, lines 306-315)
   Java: politicsAi.politicalActions() or doActions(storedPoliticalActions)  [-] NOT IMPLEMENTED

CRITICAL MISSING FUNCTIONALITY:
-------------------------------
1. Pre-purchase simulation (simulate combat/battles/noncombat BEFORE purchasing)
   - Java simulates the entire turn before making purchase decisions
   - This allows purchases to account for expected battle outcomes
   - IMPACT: Odin purchases blindly without knowing battle results

2. Stored move maps between phases
   - Java plans moves in purchase phase, executes in move phases
   - IMPACT: Odin re-calculates moves each phase (less coordination)

3. Battle callbacks (retreat, casualty selection, sub attacks)
   - IMPACT: Fights to death, default casualty order

4. Tech and Politics phases
   - IMPACT: No technology research, no war declarations

=============================================================================
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

	resolve_land_battles(gc)
	debug_checks(gc)

	// Phase 4: Non-Combat Move Phase
	// Move remaining units to defensive/strategic positions
	// This includes loading, staging, and unloading transports via stage_and_unload_transports_noncombat()
	proai_noncombat_move_phase(gc) or_return
	debug_checks(gc)

	// Phase 5: Place Units Phase
	// Place purchased units at factories
	proai_place_units_phase(gc) or_return
	debug_checks(gc)

	// Phase 6: Tech Phase (N/A for Axis & Allies 1942 SE)
	// proai_tech_phase(gc) - Not applicable, 1942 SE has no technology research
	
	// Phase 7: Politics Phase (N/A for Axis & Allies 1942 SE)
	// proai_politics_phase(gc) - Not applicable, 1942 SE has no political actions

	// Phase 8: End Turn Phase
	// Clean up, collect income, rotate to next player
	reset_units_fully(gc)
	collect_money(gc)
	debug_checks(gc)
	rotate_turns(gc)
	debug_checks(gc)

	return true
}

/*
=============================================================================
TECH PHASE - NOT APPLICABLE FOR AXIS & ALLIES 1942 SE
=============================================================================

Java Original (AbstractProAi.java lines 240-243):
  @Override
  protected void tech(ITechDelegate techDelegate, GameData data, GamePlayer player) {
    ProTechAi.tech(techDelegate, data, player);
  }

ProTechAi.java implements technology research decisions:
- selectTechRolls() - Choose how many dice to roll
- getTechToResearch() - Choose which technology to pursue
- Technologies include: jet power, rockets, super subs, long range air, etc.

NOT IMPLEMENTED: Axis & Allies 1942 Second Edition does not include
technology research rules. This is a feature of other A&A variants
(Anniversary Edition, Global 1940, etc.).
*/
proai_tech_phase :: proc(gc: ^Game_Cache) {
	// No-op: Technology research not used in A&A 1942 SE
}

/*
=============================================================================
POLITICS PHASE - NOT APPLICABLE FOR AXIS & ALLIES 1942 SE  
=============================================================================

Java Original (AbstractProAi.java lines 306-315):
  @Override
  public void politicalActions() {
    initializeData();
    if (storedPoliticalActions == null) {
      politicsAi.politicalActions();
    } else {
      politicsAi.doActions(storedPoliticalActions);
      storedPoliticalActions = null;
    }
  }

ProPoliticsAi.java implements political action decisions:
- shouldDeclareWar() - Decide when to declare war on neutral nations
- getPoliticalActions() - Choose political actions (alliances, war declarations)
- Politics affect neutral nations, diplomatic relations, etc.

NOT IMPLEMENTED: Axis & Allies 1942 Second Edition does not include
political action rules. All nations are already at war at game start.
This is a feature of other A&A variants (Global 1940, Anniversary, etc.).
*/
proai_politics_phase :: proc(gc: ^Game_Cache) {
	// No-op: Political actions not used in A&A 1942 SE
}

// Test Pro AI for a single turn with debug output
test_proai_single_turn :: proc(gs: ^Game_State) -> bool {
	fmt.println("\n" + SEP_LONG)
	fmt.println("PRO AI SINGLE TURN TEST (TripleA Purchase & Place)")
	fmt.println(SEP_LONG)
	fmt.printf("Starting Player: %v\n", gs.cur_player)
	fmt.printf("Starting Money: %d IPCs\n", gs.money[gs.cur_player])

	// Count initial units for current player only
	total_units := 0
	for land in Land_ID {
		for army in Idle_Army {
			total_units += int(gs.idle_armies[land][gs.cur_player][army])
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
		intrinsics.debug_trap()
		return false
	}

	// Count final units for the player who just played (gs.cur_player, not gc.cur_player which has advanced)
	starting_player := gs.cur_player
	final_units := 0
	for land in Land_ID {
		for army in Idle_Army {
			final_units += int(gc.state.idle_armies[land][starting_player][army])
		}
	}

	fmt.println("\n" + SEP_LONG)
	fmt.println("PRO AI TURN COMPLETE")
	fmt.println(SEP_LONG)
	fmt.printf("Next Player: %v\n", gc.cur_player)
	fmt.printf("Final Money: %d IPCs\n", gc.state.money[starting_player])
	fmt.printf("Units Added: %d\n", final_units - total_units)
	fmt.printf("Game Score: %.1f\n", evaluate_cache(&gc))
	fmt.println(SEP_LONG + "\n")

	// Save the state back
	gs^ = gc.state

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
	debug_checks(gc)
	// Step 1: Find all enemy territories we might want to attack
	when ODIN_DEBUG {
		fmt.println("\n[STEP 1] Finding ALL units that can attack (populateAttackOptions)...")
	}
	my_territory_targets: [Air_ID]Territory_Target = {}
	generate_my_attack_options(gc, &my_territory_targets)

	// Call the FULL TripleA implementation
	// TODO: populate_amphib_attack_options
	// populate_attack_options_triplea(gc, &attack_options)

	// Step 2: Prioritize attack options by strategic value
	when ODIN_DEBUG {
		fmt.println("\n[STEP 2] Prioritizing attack targets by strategic value...")
	}
	debug_checks(gc)
	attack_options := make([dynamic]Attack_Option)
	defer delete(attack_options)
	// prioritize_attack_options_triplea(gc, &attack_options, false)
	prioritize_my_attack_options(gc, &my_territory_targets, &attack_options)

	when ODIN_DEBUG {
		fmt.println("  Attack priority order:")
		count := min(10, len(attack_options)) // Show top 10
		for i := 0; i < count; i += 1 {
			opt := attack_options[i]
			production, is_capital := get_production_and_is_capital_triplea(gc, opt.territory)
			has_factory_flag := has_factory(gc, opt.territory)
			fmt.printf(
				"    %d. %v (value: %.1f, production: %d",
				i + 1,
				opt.territory,
				opt.attack_value,
				production,
			)
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
	debug_checks(gc)
	determine_territories_that_can_be_held_triplea(gc, &attack_options)

	when ODIN_DEBUG {
		holdable_count := 0
		for opt in attack_options {
			if opt.can_hold do holdable_count += 1
		}
		fmt.printf("  -> %d of %d territories can be held\n", holdable_count, len(attack_options))

		// Show first few holdable territories
		shown := 0
		for opt in attack_options {
			if opt.can_hold && shown < 5 {
				fmt.printf("    + %v (can hold)\n", opt.territory)
				shown += 1
			}
		}
	}

	// Step 3b: Evaluate which territories need amphibious reinforcements
	// Note: This is done later on attack_options3 which has the amphib data populated
	// (attack_options here uses old system without potential_amphib_attackers)

	// Step 4: Remove territories not worth attacking
	when ODIN_DEBUG {
		fmt.println("\n[STEP 4] Filtering out low-value targets...")
		initial_count := len(attack_options)
	}
	debug_checks(gc)
	remove_territories_that_arent_worth_attacking_triplea(gc, &attack_options)

	when ODIN_DEBUG {
		removed := initial_count - len(attack_options)
		fmt.printf("  -> Removed %d low-value targets, %d remain\n", removed, len(attack_options))
		if len(attack_options) > 0 {
			fmt.println("  Targets worth attacking:")
			for opt in attack_options {
				fmt.printf(
					"    - %v (value: %.1f, holdable: %v)\n",
					opt.territory,
					opt.attack_value,
					opt.can_hold,
				)
			}
		} else {
			fmt.println("  -> No attacks worth executing (all targets filtered out)")
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


	attack_options2 := make([dynamic]Attack_Option)
	defer delete(attack_options2)
	populate_attack_options_triplea(gc, &attack_options2)
	prioritize_attack_options_triplea(gc, &attack_options2, false)

	attack_options3 := make([dynamic]Attack_Option)
	defer delete(attack_options3)

	for attack_option2 in attack_options2 {
		for attack_option in attack_options {
			if attack_option2.territory == attack_option.territory {
				append(&attack_options3, attack_option2)
				break
			}
		}
	}
	
	// Also add territories that have amphibious attack potential 
	// (from attack_options2) even if they weren't in the old system
	for &attack_option2 in attack_options2 {
		// Skip if already in attack_options3
		already_added := false
		for opt in attack_options3 {
			if opt.territory == attack_option2.territory {
				already_added = true
				break
			}
		}
		if already_added { continue }
		
		// Add if has potential amphibious attackers
		if len(attack_option2.potential_amphib_attackers) > 0 {
			append(&attack_options3, attack_option2)
			when ODIN_DEBUG {
				fmt.printf("  Added amphib-reachable target: %v (amphib attackers: %d)\n", 
					attack_option2.territory, len(attack_option2.potential_amphib_attackers))
			}
		}
	}

	// Step 4b: Evaluate which territories need amphibious reinforcements
	// This checks if land+air alone can win, or if transports are needed
	when ODIN_DEBUG {
		fmt.println("\n[STEP 4b] Evaluating amphibious attack requirements...")
	}
	debug_checks(gc)
	evaluate_need_amphib_units_triplea(gc, &attack_options3)

	when ODIN_DEBUG {
		amphib_count := 0
		for opt in attack_options3 {
			if opt.need_amphib_units do amphib_count += 1
		}
		if amphib_count > 0 {
			fmt.printf("  -> %d territories need amphibious reinforcements\n", amphib_count)
		}
	}

	// Step 5: Determine which territories to actually attack (iterative selection)
	when ODIN_DEBUG {
		fmt.println("\n[STEP 5] Selecting territories to attack (iterative algorithm)...")
		initial_count = len(attack_options3)
	}
	debug_checks(gc)
	determine_territories_to_attack_triplea(gc, &attack_options3)

	when ODIN_DEBUG {
		removed = initial_count - len(attack_options3)
		fmt.printf(
			"  -> Selected %d territories for attack (removed %d unsuccessful)\n",
			len(attack_options3),
			removed,
		)
		if len(attack_options3) > 0 {
			fmt.println("  Final attack targets:")
			for opt in attack_options3 {
				fmt.printf("    - %v (value: %.1f)\n", opt.territory, opt.attack_value)
			}
		}
	}

	if len(attack_options3) == 0 {
		when ODIN_DEBUG {
			fmt.println("  -> No successful attacks possible")
			fmt.println(SEP_MED + "\n")
		}
		return true
	}

	// Step 6: Re-calculate enemy attacks and re-filter with final selection
	when ODIN_DEBUG {
		fmt.println("\n[STEP 6] Re-calculating with final attack selection...")
	}
	debug_checks(gc)
	recalculate_enemy_attacks_after_territory_selection_triplea(gc, &attack_options3)

	when ODIN_DEBUG {
		fmt.printf("  -> %d attacks remain after recalculation\n", len(attack_options3))
	}

	if len(attack_options3) == 0 {
		when ODIN_DEBUG {
			fmt.println("  -> All attacks became unfavorable after recalculation")
			fmt.println(SEP_MED + "\n")
		}
		return true
	}

	// Step 7: Move defenders to border territories
	when ODIN_DEBUG {
		fmt.println("\n[STEP 7] Moving defenders to border territories...")
	}
	debug_checks(gc)
	border_moves := move_one_defender_to_land_territories_bordering_enemy_triplea(
		gc,
		&attack_options3,
	)
	defer delete(border_moves)

	// Step 8: Remove attacks where transports would be exposed
	when ODIN_DEBUG {
		fmt.println("\n[STEP 8] Checking transport safety...")
		initial_count = len(attack_options3)
	}
	debug_checks(gc)
	remove_territories_where_transports_are_exposed_triplea(gc, &attack_options3)

	when ODIN_DEBUG {
		removed = initial_count - len(attack_options3)
		if removed > 0 {
			fmt.printf("  -> Removed %d amphibious attacks (transports exposed)\n", removed)
		} else {
			fmt.println("  -> All transports safe")
		}
	}

	// Step 9: Ensure capital can be defended
	when ODIN_DEBUG {
		fmt.println("\n[STEP 9] Ensuring capital defense...")
		initial_count = len(attack_options3)
	}
	debug_checks(gc)
	remove_attacks_until_capital_can_be_held_triplea(gc, &attack_options3)

	when ODIN_DEBUG {
		removed = initial_count - len(attack_options3)
		if removed > 0 {
			fmt.printf("  -> Removed %d attacks to defend capital\n", removed)
		} else {
			fmt.println("  -> Capital can be defended with current attack plan")
		}

		if len(attack_options3) > 0 {
			fmt.println("\n  FINAL ATTACK PLAN:")
			for opt in attack_options3 {
				fmt.printf(
					"    -> Attack %v (value: %.1f, holdable: %v)\n",
					opt.territory,
					opt.attack_value,
					opt.can_hold,
				)
			}
		} else {
			fmt.println("\n  -> No attacks will be executed (all removed for capital defense)")
		}
	}

	// Step 9b: Plan strategic bombing raids (CMB-002 to CMB-004)
	// This assigns bombers to bomb enemy factories separately from regular attacks
	when ODIN_DEBUG {
		fmt.println("\n[STEP 9b] Planning strategic bombing raids...")
	}
	debug_checks(gc)
	bombing_count := plan_strategic_bombing_raids(gc)
	when ODIN_DEBUG {
		if bombing_count > 0 {
			fmt.printf("  -> Assigned %d bombers to strategic bombing\n", bombing_count)
		} else {
			fmt.println("  -> No strategic bombing raids planned")
		}
	}

	// Step 10: Determine specific units to attack with
	when ODIN_DEBUG {
		fmt.println("\n[STEP 10] Assigning units to each attack...")
	}
	debug_checks(gc)
	determine_units_to_attack_with_triplea(gc, &attack_options3, &border_moves)

	when ODIN_DEBUG {
		if len(attack_options3) > 0 {
			fmt.println("\n  UNIT ASSIGNMENTS:")
			for opt in attack_options3 {
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
				attack_power := calculate_total_attack_power(
					gc,
					opt.attackers,
					opt.amphib_attackers,
				)
				defense_power := calculate_total_defense_power(gc, opt.defenders)
				fmt.printf(
					"      Total: %.1f attack vs %.1f defense\n",
					attack_power,
					defense_power,
				)
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
		fmt.println("\n[STEP 11] Loading transports for amphibious assaults...")
	}
	
	// Load transports with units for amphibious combat
	// NOTE: Currently disabled - amphibious attack planning is not yet implemented.
	// The current code would load ALL adjacent units onto transports, which conflicts
	// with land attack assignments. Proper implementation needs to:
	// 1. Identify territories only reachable by sea (true amphibious)
	// 2. Plan which transports will participate
	// 3. Load only units designated for those specific attacks
	// 
	// For now, existing pre-loaded transports (TRANS_1I, TRANS_1T, TRANS_1A) will
	// be used via assign_amphibious_units() in determine_units_to_attack_with.
	//
	// proai_load_transports_for_combat(gc) or_return
	debug_checks(gc)

	when ODIN_DEBUG {
		fmt.println("\n[STEP 12] Executing combat moves (doMove)")
	}

	// Execute all planned attacks
	execute_combat_moves_triplea(gc, &attack_options3) or_return

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
	debug_checks(gc)
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
	/*
	Pro AI Transport Loading for Combat Phase
	
	Based on TripleA's ProMoveUtils.calculateAmphibRoutes():
	1. Find available transports
	2. For each transport, find adjacent land units that can be loaded
	3. Prioritize loading high-value attack units (tanks > artillery > infantry)
	4. Load units onto transports
	
	This prepares transports for amphibious assaults during combat move.
	The actual movement and unloading happens later in stage_transports/unload_transports.
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Loading transports for combat...")
	}
	
	// Find all empty or partially loaded transports and load them
	for sea in Sea_ID {
		// Load transports at this sea zone
		load_transports_at_sea(gc, sea) or_return
	}
	
	return true
}

// Load transports at a specific sea zone with adjacent land units
load_transports_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> (ok: bool) {
	/*
	Algorithm (from Java ProTransportUtils.getUnitsToTransportFromTerritories):
	1. Find all coastal territories adjacent to this sea zone that we own
	2. For each territory, collect transportable units (infantry, artillery, tanks)
	3. Sort by: transport cost (ascending), then attack power (descending)
	4. Load units onto available transports
	
	Transport capacity: 5 spaces
	- Infantry: 2 spaces
	- Artillery: 3 spaces
	- Tank: 3 spaces
	
	Valid combinations:
	- Empty (5 free)
	- 1I (3 free) - can add 1A or 1T or 1I
	- 1A (2 free) - can add 1I
	- 1T (2 free) - can add 1I
	- 2I (1 free) - full for practical purposes
	- 1I+1A (0 free) - full
	- 1I+1T (0 free) - full
	*/
	
	// Check if we have empty transports at this sea
	player := gc.cur_player
	
	// Get adjacent lands we own
	adjacent_lands := &mm.s2l_1away_via_sea[sea]
	
	// Try to load empty transports first (they have most capacity)
	for gc.idle_ships[sea][player][.TRANS_EMPTY] > 0 {
		// Find best units to load from adjacent lands
		loaded := load_best_units_onto_empty_transport(gc, sea, adjacent_lands)
		if !loaded {
			break // No more units to load
		}
	}
	
	// Try to fill partially loaded transports (1I can take 1A or 1T)
	for gc.idle_ships[sea][player][.TRANS_1I] > 0 {
		loaded := load_second_unit_onto_1i_transport(gc, sea, adjacent_lands)
		if !loaded {
			break
		}
	}
	
	// 1A and 1T can only take infantry
	for gc.idle_ships[sea][player][.TRANS_1A] > 0 {
		loaded := load_infantry_onto_partial_transport(gc, sea, adjacent_lands, .TRANS_1A)
		if !loaded {
			break
		}
	}
	
	for gc.idle_ships[sea][player][.TRANS_1T] > 0 {
		loaded := load_infantry_onto_partial_transport(gc, sea, adjacent_lands, .TRANS_1T)
		if !loaded {
			break
		}
	}
	
	return true
}

// Load best units (prioritize attack value) onto an empty transport
load_best_units_onto_empty_transport :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
) -> bool {
	/*
	Priority for loading (attack efficiency):
	1. Tank (3 attack, 3 cost) - best attacker, fills 3 spaces
	2. Artillery (2 attack, 3 cost) - good attack with support bonus
	3. Infantry (1 attack, 2 cost) - filler unit
	
	Best combinations for attack:
	- 1T + 1I = 4 attack power (tank + infantry)
	- 1A + 1I = 3 attack power (artillery + infantry, +1 support = 4 effective)
	- 2I = 2 attack power (worst but uses capacity)
	*/
	
	player := gc.cur_player
	
	// Try to load tank first (best attacker)
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue // Not our territory
		}
		
		// Check for tanks with movement
		if gc.active_armies[land][.TANK_1_MOVES] > 0 {
			load_unit_onto_transport(gc, land, sea, .TANK_1_MOVES, .TRANS_EMPTY)
			
			// Now try to add infantry to fill remaining space
			for inf_land in sa.slice(adjacent_lands) {
				if mm.team[gc.owner[inf_land]] != mm.team[player] {
					continue
				}
				if gc.active_armies[inf_land][.INF_1_MOVES] > 0 {
					// Load infantry onto the now 1T transport
					load_unit_onto_1t_transport(gc, inf_land, sea)
					break
				}
			}
			return true
		}
		
		if gc.active_armies[land][.TANK_2_MOVES] > 0 {
			load_unit_onto_transport(gc, land, sea, .TANK_2_MOVES, .TRANS_EMPTY)
			
			// Now try to add infantry
			for inf_land in sa.slice(adjacent_lands) {
				if mm.team[gc.owner[inf_land]] != mm.team[player] {
					continue
				}
				if gc.active_armies[inf_land][.INF_1_MOVES] > 0 {
					load_unit_onto_1t_transport(gc, inf_land, sea)
					break
				}
			}
			return true
		}
	}
	
	// No tanks - try artillery
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		if gc.active_armies[land][.ARTY_1_MOVES] > 0 {
			load_unit_onto_transport(gc, land, sea, .ARTY_1_MOVES, .TRANS_EMPTY)
			
			// Add infantry
			for inf_land in sa.slice(adjacent_lands) {
				if mm.team[gc.owner[inf_land]] != mm.team[player] {
					continue
				}
				if gc.active_armies[inf_land][.INF_1_MOVES] > 0 {
					load_unit_onto_1a_transport(gc, inf_land, sea)
					break
				}
			}
			return true
		}
	}
	
	// No tanks or artillery - load 2 infantry if possible
	infantry_loaded := 0
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		for gc.active_armies[land][.INF_1_MOVES] > 0 && infantry_loaded < 2 {
			if infantry_loaded == 0 {
				load_unit_onto_transport(gc, land, sea, .INF_1_MOVES, .TRANS_EMPTY)
			} else {
				load_unit_onto_1i_transport(gc, land, sea)
			}
			infantry_loaded += 1
		}
		
		if infantry_loaded >= 2 {
			break
		}
	}
	
	return infantry_loaded > 0
}

// Load second unit onto a 1I transport (can add 1A, 1T, or 1I)
load_second_unit_onto_1i_transport :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
) -> bool {
	player := gc.cur_player
	
	// Prefer tank or artillery first (better attack)
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		// Try tank
		if gc.active_armies[land][.TANK_1_MOVES] > 0 {
			load_unit_onto_1i_transport_tank(gc, land, sea)
			return true
		}
		if gc.active_armies[land][.TANK_2_MOVES] > 0 {
			load_unit_onto_1i_transport_tank(gc, land, sea)
			return true
		}
		
		// Try artillery
		if gc.active_armies[land][.ARTY_1_MOVES] > 0 {
			load_unit_onto_1i_transport_arty(gc, land, sea)
			return true
		}
	}
	
	// Fallback to infantry
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		if gc.active_armies[land][.INF_1_MOVES] > 0 {
			load_unit_onto_1i_transport(gc, land, sea)
			return true
		}
	}
	
	return false
}

// Load infantry onto a partial transport (1A or 1T)
load_infantry_onto_partial_transport :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
	transport_type: Idle_Ship,
) -> bool {
	player := gc.cur_player
	
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		if gc.active_armies[land][.INF_1_MOVES] > 0 {
			if transport_type == .TRANS_1A {
				load_unit_onto_1a_transport(gc, land, sea)
			} else {
				load_unit_onto_1t_transport(gc, land, sea)
			}
			return true
		}
	}
	
	return false
}

// ===== Low-level transport loading functions =====

// Load a single unit from land onto an empty transport
load_unit_onto_transport :: proc(
	gc: ^Game_Cache,
	src_land: Land_ID,
	dst_sea: Sea_ID,
	unit_type: Active_Army,
	transport_type: Idle_Ship,
) {
	/*
	State transitions for loading onto empty transport:
	- Infantry -> TRANS_EMPTY becomes TRANS_1I (with UNMOVED suffix for active state)
	- Artillery -> TRANS_EMPTY becomes TRANS_1A
	- Tank -> TRANS_EMPTY becomes TRANS_1T
	*/
	
	player := gc.cur_player
	idle_unit := Active_Army_To_Idle[unit_type]
	
	// Remove unit from land
	gc.active_armies[src_land][unit_type] -= 1
	gc.idle_armies[src_land][player][idle_unit] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	// Update armies_available_to_move bitset
	if gc.active_armies[src_land][unit_type] == 0 {
		gc.armies_available_to_move[idle_unit] -= {src_land}
	}
	
	// Determine new transport state
	new_transport_state: Active_Ship
	switch idle_unit {
	case .INF:
		new_transport_state = .TRANS_1I_UNMOVED
	case .ARTY:
		new_transport_state = .TRANS_1A_UNMOVED
	case .TANK:
		new_transport_state = .TRANS_1T_UNMOVED
	case .AAGUN:
		return // AA guns can't be transported
	}
	
	// Update transport state
	gc.idle_ships[dst_sea][player][transport_type] -= 1
	gc.idle_ships[dst_sea][player][Active_Ship_To_Idle[new_transport_state]] += 1
	gc.active_ships[dst_sea][new_transport_state] += 1
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] %v from %v onto transport at sea %v\n", idle_unit, src_land, dst_sea)
	}
}

// Load infantry onto a 1I transport (becomes 2I)
load_unit_onto_1i_transport :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove infantry from land
	gc.active_armies[src_land][.INF_1_MOVES] -= 1
	gc.idle_armies[src_land][player][.INF] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	if gc.active_armies[src_land][.INF_1_MOVES] == 0 {
		gc.armies_available_to_move[.INF] -= {src_land}
	}
	
	// Update transport: 1I -> 2I
	gc.idle_ships[dst_sea][player][.TRANS_1I] -= 1
	gc.idle_ships[dst_sea][player][.TRANS_2I] += 1
	// Active state for 2I (unmoved, loaded this turn)
	gc.active_ships[dst_sea][.TRANS_2I_2_MOVES] += 1
	// Remove old active state (find which one was the 1I)
	if gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] -= 1
	}
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] INF from %v onto 1I transport at sea %v (now 2I)\n", src_land, dst_sea)
	}
}

// Load tank onto a 1I transport (becomes 1I_1T)
load_unit_onto_1i_transport_tank :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Find which tank type to use
	tank_type: Active_Army
	if gc.active_armies[src_land][.TANK_1_MOVES] > 0 {
		tank_type = .TANK_1_MOVES
	} else {
		tank_type = .TANK_2_MOVES
	}
	
	// Remove tank from land
	gc.active_armies[src_land][tank_type] -= 1
	gc.idle_armies[src_land][player][.TANK] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	if gc.active_armies[src_land][tank_type] == 0 {
		gc.armies_available_to_move[.TANK] -= {src_land}
	}
	
	// Update transport: 1I -> 1I_1T
	gc.idle_ships[dst_sea][player][.TRANS_1I] -= 1
	gc.idle_ships[dst_sea][player][.TRANS_1I_1T] += 1
	gc.active_ships[dst_sea][.TRANS_1I_1T_2_MOVES] += 1
	
	// Remove old 1I active state
	if gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] -= 1
	}
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] TANK from %v onto 1I transport at sea %v (now 1I_1T)\n", src_land, dst_sea)
	}
}

// Load artillery onto a 1I transport (becomes 1I_1A)
load_unit_onto_1i_transport_arty :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove artillery from land
	gc.active_armies[src_land][.ARTY_1_MOVES] -= 1
	gc.idle_armies[src_land][player][.ARTY] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	if gc.active_armies[src_land][.ARTY_1_MOVES] == 0 {
		gc.armies_available_to_move[.ARTY] -= {src_land}
	}
	
	// Update transport: 1I -> 1I_1A
	gc.idle_ships[dst_sea][player][.TRANS_1I] -= 1
	gc.idle_ships[dst_sea][player][.TRANS_1I_1A] += 1
	gc.active_ships[dst_sea][.TRANS_1I_1A_2_MOVES] += 1
	
	// Remove old 1I active state
	if gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_2_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_1_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1I_0_MOVES] -= 1
	}
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] ARTY from %v onto 1I transport at sea %v (now 1I_1A)\n", src_land, dst_sea)
	}
}

// Load infantry onto a 1A transport (becomes 1I_1A)
load_unit_onto_1a_transport :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove infantry from land
	gc.active_armies[src_land][.INF_1_MOVES] -= 1
	gc.idle_armies[src_land][player][.INF] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	if gc.active_armies[src_land][.INF_1_MOVES] == 0 {
		gc.armies_available_to_move[.INF] -= {src_land}
	}
	
	// Update transport: 1A -> 1I_1A
	gc.idle_ships[dst_sea][player][.TRANS_1A] -= 1
	gc.idle_ships[dst_sea][player][.TRANS_1I_1A] += 1
	gc.active_ships[dst_sea][.TRANS_1I_1A_2_MOVES] += 1
	
	// Remove old 1A active state
	if gc.active_ships[dst_sea][.TRANS_1A_UNMOVED] > 0 {
		gc.active_ships[dst_sea][.TRANS_1A_UNMOVED] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1A_2_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1A_2_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1A_1_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1A_1_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1A_0_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1A_0_MOVES] -= 1
	}
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] INF from %v onto 1A transport at sea %v (now 1I_1A)\n", src_land, dst_sea)
	}
}

// Load infantry onto a 1T transport (becomes 1I_1T)
load_unit_onto_1t_transport :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove infantry from land
	gc.active_armies[src_land][.INF_1_MOVES] -= 1
	gc.idle_armies[src_land][player][.INF] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	if gc.active_armies[src_land][.INF_1_MOVES] == 0 {
		gc.armies_available_to_move[.INF] -= {src_land}
	}
	
	// Update transport: 1T -> 1I_1T
	gc.idle_ships[dst_sea][player][.TRANS_1T] -= 1
	gc.idle_ships[dst_sea][player][.TRANS_1I_1T] += 1
	gc.active_ships[dst_sea][.TRANS_1I_1T_2_MOVES] += 1
	
	// Remove old 1T active state
	if gc.active_ships[dst_sea][.TRANS_1T_UNMOVED] > 0 {
		gc.active_ships[dst_sea][.TRANS_1T_UNMOVED] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1T_2_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1T_2_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1T_1_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1T_1_MOVES] -= 1
	} else if gc.active_ships[dst_sea][.TRANS_1T_0_MOVES] > 0 {
		gc.active_ships[dst_sea][.TRANS_1T_0_MOVES] -= 1
	}
	
	when ODIN_DEBUG {
		fmt.printf("    [LOAD] INF from %v onto 1T transport at sea %v (now 1I_1T)\n", src_land, dst_sea)
	}
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
