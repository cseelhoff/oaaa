package oaaa

/*
=============================================================================
TRIPLEA ProCombatMoveAi.java METHOD MAPPING
=============================================================================

This file contains implementations of methods from TripleA's ProCombatMoveAi.java.
Each method is implemented in Odin based on the original Java logic.

Current Implementation Status:
- [+] prioritizeAttackOptions - Calculate attack value and sort territories (80%)
- [+] determineTerritoriesToAttack - Iteratively select territories to attack
- [+] determineTerritoriesThatCanBeHeld - Check if conquered territories can be defended
- [+] removeTerritoriesThatArentWorthAttacking - Filter low-value targets
- [+] moveOneDefenderToLandTerritoriesBorderingEnemy - Defensive positioning
- [+] removeTerritoriesWhereTransportsAreExposed - Protect naval units
- [+] determineUnitsToAttackWith - Assign specific units to each attack
- [PARTIAL] determineTerritoriesThatCanBeBombed - Strategic bombing (stub execution)
- [PARTIAL] determineBestBombingAttackForBomber - Targeting (simplified)
- [PARTIAL] tryToAttackTerritories - 4 phases vs Java's 6 phases
- [+] checkContestedSeaTerritories - Sub warfare in contested seas
- [+] logAttackMoves - Debug output
- [+] canAirSafelyLandAfterAttack - Air unit safety check

TODO REVIEW: Minor gaps in ProCombatMoveAi.java (2,031 lines):

1. tryToAttackTerritories (Java lines 1245-1778) - PARTIAL
   - Odin has 4 phases, Java has 6 phases
   - Missing: transport casualty restriction handling (property check)
   - Missing: full sub retreat before battle calculation

2. determineTerritoriesThatCanBeBombed/determineBestBombingAttackForBomber - PARTIAL
   - Air battle filtering not implemented (canAirBattle property)
   - Damage-to-units property simplified
   - Same-target bomber counting simplified

3. prioritizeAttackOptions (Java lines 177-299) - Minor gap
   - Neutral territory nearby enemy value calculation simplified

4. Full naval bombardment execution - STUB
   - Ships assigned but bombardment not fully executed

5. Strategic bombing execution - STUB
   - Target selection done, execution simplified

6. Unit value map - Uses hardcoded values instead of proData.getUnitValue()
*/

import "core:fmt"
import "core:math"
import sa "core:container/small_array"

// Data structures for TripleA combat move methods

// Unit_Type - unified enum for all unit types (for TripleA compatibility)
Unit_Type :: enum {
	// Land units
	Infantry,
	Artillery,
	Tank,
	AAGun,
	// Air units
	Fighter,
	Bomber,
	// Sea units
	Transport,
	Submarine,
	Destroyer,
	Cruiser,
	Battleship,
	Carrier,
}

// Unit_Info represents a single unit and where it's moving from
Unit_Info :: struct {
	unit_type:      Unit_Type,
	from_territory: Land_ID,
}

// Attack_Option represents a planned attack on a territory
Attack_Option :: struct {
	territory:          Land_ID,
	// Assigned units (populated in Step 10)
	attackers:          [dynamic]Unit_Info,
	amphib_attackers:   [dynamic]Unit_Info,
	bombard_units:      [dynamic]Unit_Info,
	// Potential units (populated in Step 1, used for holdability check in Step 3)
	potential_attackers:       [dynamic]Unit_Info,
	potential_amphib_attackers: [dynamic]Unit_Info,
	// Enemy defenders
	defenders:          [dynamic]Unit_Info,
	// Battle metrics
	attack_value:       f64,
	win_percentage:     f64,
	tuv_swing:          f64,
	can_hold:           bool,
	is_amphib:          bool,
	need_amphib_units:  bool,  // True if land+air can't win, but amphibious units available
	is_strafing:        bool,
	avg_survivor_def_power: f64,
	// Transport assignment for amphibious attacks
	assigned_transports: [dynamic]Transport_Assignment,
}

// Transport_Assignment tracks which transport is assigned to which attack
Transport_Assignment :: struct {
	sea_zone:        Sea_ID,
	transport_state: Idle_Ship,  // e.g., TRANS_1I, TRANS_1T
	unload_sea:      Sea_ID,     // Sea zone to unload from
}

/*
=============================================================================
METHOD 1: prioritizeAttackOptions
=============================================================================

Java Original (lines 192-299):

  private void prioritizeAttackOptions(
      final GamePlayer player, final List<ProTerritory> attackOptions) {

    ProLogger.info("Prioritizing territories to try to attack");

    // Calculate value of attacking territory
    for (final Iterator<ProTerritory> it = attackOptions.iterator(); it.hasNext(); ) {
      final ProTerritory patd = it.next();
      final Territory t = patd.getTerritory();

      // Determine territory attack properties
      final int isLand = !t.isWater() ? 1 : 0;
      final int isNeutral = ProUtils.isNeutralLand(t) ? 1 : 0;
      final int isCanHold = patd.isCanHold() ? 1 : 0;
      final int isAmphib = patd.isNeedAmphibUnits() ? 1 : 0;
      final List<Unit> defendingUnits =
          CollectionUtils.getMatches(
              patd.getMaxEnemyDefenders(player), ProMatches.unitIsEnemyAndNotInfa(player));
      final int isEmptyLand =
          (!t.isWater() && defendingUnits.isEmpty() && !patd.isNeedAmphibUnits()) ? 1 : 0;
      final boolean isAdjacentToMyCapital =
          !data.getMap().getNeighbors(t, Matches.territoryIs(proData.getMyCapital())).isEmpty();
      final int isNotNeutralAdjacentToMyCapital =
          (isAdjacentToMyCapital
                  && ProMatches.territoryIsEnemyNotPassiveNeutralLand(player).test(t))
              ? 1
              : 0;
      final int isFactory = ProMatches.territoryHasInfraFactoryAndIsLand().test(t) ? 1 : 0;
      final int isFfa = ProUtils.isFfa(data, player) ? 1 : 0;

      // Determine production value and if it is an enemy capital
      ProductionAndIsCapital productionAndIsCapital = getProductionAndIsCapital(t);

      // Calculate attack value for prioritization
      double tuvSwing = patd.getMaxBattleResult().getTuvSwing();
      if (isFfa == 1 && tuvSwing > 0) {
        tuvSwing *= 0.5;
      }
      final double territoryValue =
          (1 + isLand + isCanHold * (1 + 2.0 * isFfa * isLand))
              * (1 + isEmptyLand)
              * (1 + isFactory)
              * (1 - 0.5 * isAmphib)
              * productionAndIsCapital.production;
      double attackValue =
          (tuvSwing + territoryValue)
              * (1 + 4.0 * productionAndIsCapital.isCapital)
              * (1 + 2.0 * isNotNeutralAdjacentToMyCapital)
              * (1 - 0.9 * isNeutral);

      // Check if a negative value neutral territory should be attacked
      if (attackValue <= 0 && !patd.isNeedAmphibUnits() && ProUtils.isNeutralLand(t)) {
        // [Calculate nearby enemy value logic - lines 239-282]
      }

      // Remove negative value territories
      patd.setValue(attackValue);
      if (attackValue <= 0
          || (isDefensive
              && attackValue <= 8
              && data.getMap().getDistance(proData.getMyCapital(), t) <= 3)) {
        it.remove();
      }
    }

    // Sort attack territories by value
    attackOptions.sort(Comparator.comparingDouble(ProTerritory::getValue).reversed());
  }
*/

// Odin Implementation:
prioritize_attack_options_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, is_defensive: bool) {
	when ODIN_DEBUG {
		fmt.println("Prioritizing territories to try to attack")
	}
	
	// Calculate value of attacking territory
	for i := len(options) - 1; i >= 0; i -= 1 {
		option := &options[i]
		territory := option.territory
		
		// Determine territory attack properties
		is_land := !is_water_territory(territory) ? 1 : 0
		is_neutral := false //is_neutral_land(gc, territory) ? 1 : 0
		is_can_hold := option.can_hold ? 1 : 0
		is_amphib := option.is_amphib ? 1 : 0
		
		// Count non-infantry defenders
		defending_units := count_non_infantry_defenders(option)
		is_empty_land := (is_land == 1 && defending_units == 0 && !option.is_amphib) ? 1 : 0
		
		// Check if adjacent to capital
		is_adjacent_to_capital := is_adjacent_to_my_capital(gc, territory)
		is_not_neutral_adj_capital := (is_adjacent_to_capital && !is_neutral_land(gc, territory)) ? 1 : 0
		
		// Check for factory
		is_factory := gc.factory_prod[territory] > 0 ? 1 : 0
		
		// Check if FFA mode (more than 2 teams)
		is_ffa := is_free_for_all(gc) ? 1 : 0
		
		// Get production value and capital status
		production, is_capital := get_production_and_is_capital_triplea(gc, territory)
		
		// Calculate attack value for prioritization
		tuv_swing := option.tuv_swing
		if is_ffa == 1 && tuv_swing > 0 {
			tuv_swing *= 0.5
		}
		
		territory_value := f64(1 + is_land + is_can_hold * (1 + 2 * is_ffa * is_land)) *
			f64(1 + is_empty_land) * f64(1 + is_factory) * (1 - 0.5 * f64(is_amphib)) * f64(production)
		
		is_capital_value := is_capital ? 1.0 : 0.0
		is_neutral_value := 0.0
		attack_value := (tuv_swing + territory_value) * (1 + 4.0 * is_capital_value) *
			(1 + 2.0 * f64(is_not_neutral_adj_capital))
		
		// Remove negative value territories
		option.attack_value = attack_value
		
		if attack_value <= 0 || (is_defensive && attack_value <= 8 && 
			calculate_distance(gc, get_my_capital(gc), territory) <= 3) {
			unordered_remove(options, i)
		}
	}
	
	// Sort attack territories by value (highest first)
	slice.sort_by(options[:], proc(a, b: Attack_Option) -> bool {
		return a.attack_value > b.attack_value
	})
}

/*
=============================================================================
METHOD 2: determineTerritoriesToAttack
=============================================================================

Java Original (lines 301-393):

  private void determineTerritoriesToAttack(final List<ProTerritory> prioritizedTerritories) {

    ProLogger.info("Determine which territories to attack");

    // Assign units to territories by prioritization
    int numToAttack = Math.min(1, prioritizedTerritories.size());
    boolean haveRemovedAllAmphibTerritories = false;
    while (true) {
      final List<ProTerritory> territoriesToTryToAttack =
          prioritizedTerritories.subList(0, numToAttack);
      ProLogger.debug("Current number of territories: " + numToAttack);
      tryToAttackTerritories(territoriesToTryToAttack, List.of());

      // Determine if all attacks are successful
      boolean areSuccessful = true;
      for (final ProTerritory patd : territoriesToTryToAttack) {
        final Territory t = patd.getTerritory();
        if (patd.getBattleResult() == null) {
          areSuccessful = false;
        }
        ProLogger.trace(patd.getResultString() + " with attackers: " + patd.getUnits());
        final double estimate =
            ProBattleUtils.estimateStrengthDifference(
                t, patd.getUnits(), patd.getMaxEnemyDefenders(player));
        final ProBattleResult result = patd.getBattleResult();
        if (!patd.isStrafing()
            && estimate < patd.getStrengthEstimate()
            && (result.getWinPercentage() < proData.getMinWinPercentage()
                || !result.isHasLandUnitRemaining())) {
          areSuccessful = false;
        }
      }

      // Determine whether to try more territories, remove a territory, or end
      if (areSuccessful) {
        // [Logic for handling success - lines 353-381]
        numToAttack++;
        if (numToAttack > prioritizedTerritories.size()) {
          break;
        }
      } else {
        prioritizedTerritories.remove(numToAttack - 1);
        if (numToAttack > prioritizedTerritories.size()) {
          break;
        }
      }
    }
  }
*/

// Odin Implementation:
determine_territories_to_attack_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("Determine which territories to attack")
	}
	
	// Assign units to territories by prioritization
	num_to_attack := min(1, len(options))
	have_removed_all_amphib := false
	
	for {
		// Get sublist of territories to try attacking
		when ODIN_DEBUG {
			fmt.printf("Current number of territories: %d\n", num_to_attack)
		}
		
		// Try to attack with current set
		_ = try_to_attack_territories_triplea(gc, options, num_to_attack)
		
		// Determine if all attacks are successful
		are_successful := true
		for i := 0; i < num_to_attack && i < len(options); i += 1 {
			option := &options[i]
			fmt.println("Trying ", option.territory)
			// Estimate battle result if not already done
			if option.win_percentage == 0 {
				combatants := Land_Combatants{}
				// Count land and air attackers
				for attacker in option.attackers {
					#partial switch attacker.unit_type {
						case .Infantry:
							combatants.attackers[0].Infantry += 1
						case .Artillery:
							combatants.attackers[0].Artillery += 1
						case .Tank:
							combatants.attackers[0].Tanks += 1
						case .Fighter:
							combatants.attackers[1].Fighters += 1
						case .Bomber:
							combatants.attackers[2].Bombers += 1
					}
				}
				// Also count amphib attackers
				for attacker in option.amphib_attackers {
					#partial switch attacker.unit_type {
						case .Infantry:
							combatants.attackers[0].Infantry += 1
						case .Artillery:
							combatants.attackers[0].Artillery += 1
						case .Tank:
							combatants.attackers[0].Tanks += 1
					}
				}
				for defender in option.defenders {
					#partial switch defender.unit_type {
						case .Infantry:
							combatants.defenders.Infantry += 1
						case .Artillery:
							combatants.defenders.Artillery += 1
						case .Tank:
							combatants.defenders.Tanks += 1
						case .Fighter:
							combatants.defenders.Fighters += 1
						case .Bomber:
							combatants.defenders.Bombers += 1
					}
				}
				results := simulate_battle(combatants)
				fmt.println("Simulated battle results: ", results)
				option.win_percentage = results.invaded_percent

				// // Simple estimation: if we have 1.2x their power, assume 70% win
				// attack_power := calculate_available_attack_power(gc, option.territory)
				// defense_power := estimate_defender_power(gc, option.territory)
				// if attack_power > defense_power * 1.2 {
				// 	option.win_percentage = 0.7
				// } else if attack_power > defense_power {
				// 	option.win_percentage = 0.5
				// } else {
				// 	option.win_percentage = 0.3
				// }
			}
			
			when ODIN_DEBUG {
				total_attackers := len(option.attackers) + len(option.amphib_attackers)
				fmt.printf("%s: %.1f%% win, attackers=%d (land/air=%d, amphib=%d)\n",
					option.territory, option.win_percentage * 100, total_attackers,
					len(option.attackers), len(option.amphib_attackers))
			}
			
			// Check if successful (need 60% win + land units remaining)
			MIN_WIN_PERCENTAGE :: 0.6
			if !option.is_strafing && option.win_percentage < MIN_WIN_PERCENTAGE {
				are_successful = false
			}
		}
		
		// Determine whether to try more territories, remove a territory, or end
		if are_successful {
			// All successful - mark them and try adding one more
			for i := 0; i < num_to_attack && i < len(options); i += 1 {
				// Mark as can attack (keep in list)
			}
			
			// If used all transports, remove remaining amphib territories
			// (Simplified: skip this complex check for now)
			
			// Try adding one more territory
			num_to_attack += 1
			if num_to_attack > len(options) {
				break
			}
		} else {
			// Not all successful - remove the last territory
			when ODIN_DEBUG {
				if num_to_attack > 0 && num_to_attack <= len(options) {
					fmt.printf("Removing territory: %s\n",
						options[num_to_attack - 1].territory)
				}
			}
			
			if num_to_attack > 0 {
				unordered_remove(options, num_to_attack - 1)
			}
			
			if num_to_attack > len(options) {
				num_to_attack = len(options)
			}
			
			// If we removed everything, stop
			if num_to_attack == 0 || len(options) == 0 {
				break
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("Final number of territories to attack: %d\n", len(options))
	}
}

/*
=============================================================================
METHOD 3: determineTerritoriesThatCanBeHeld
=============================================================================

Java Original (lines 395-524):

  private void determineTerritoriesThatCanBeHeld(
      final List<ProTerritory> prioritizedTerritories, final List<Territory> clearedTerritories) {

    ProLogger.info("Check if we should try to hold attack territories");

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();
    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();

    // Determine which territories to try and hold
    final Set<Territory> territoriesToCheck = new HashSet<>();
    for (final ProTerritory patd : prioritizedTerritories) {
      final Territory t = patd.getTerritory();
      territoriesToCheck.add(t);
      final List<Unit> nonAirAttackers =
          CollectionUtils.getMatches(patd.getMaxUnits(), Matches.unitIsNotAir());
      for (final Unit u : nonAirAttackers) {
        territoriesToCheck.add(proData.getUnitTerritory(u));
      }
    }
    final Map<Territory, Double> territoryValueMap =
        ProTerritoryValueUtils.findTerritoryValues(
            proData, player, List.of(), clearedTerritories, territoriesToCheck);
    
    for (final ProTerritory patd : prioritizedTerritories) {
      final Territory t = patd.getTerritory();

      // If strafing then can't hold
      if (patd.isStrafing()) {
        patd.setCanHold(false);
        continue;
      }

      // Set max enemy attackers
      final ProTerritory enemyAttackMax = enemyAttackOptions.getMax(t);
      if (enemyAttackMax != null) {
        // [Set enemy units logic]
      }

      // [Determine whether its worth trying to hold - lines 450-524]
    }
  }
*/

// Odin Implementation:
determine_territories_that_can_be_held_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("Check if we should try to hold attack territories")
	}
	
	for i := 0; i < len(options); i += 1 {
		option := &options[i]
		t := option.territory
		
		// If strafing then can't hold
		if option.is_strafing {
			option.can_hold = false
			when ODIN_DEBUG {
				fmt.printf("%s: CANNOT HOLD (strafing attack)\n", t)
			}
			continue
		}
		
		// Check if avg_survivor_def_power was already computed in Step 2
		// If so, use it directly instead of re-simulating
		surviving_def_power := option.avg_survivor_def_power
		
		if surviving_def_power == 0 && (len(option.potential_attackers) > 0 || len(option.defenders) > 0) {
			// Fallback: Build Land_Combatants from potential attackers and defenders for simulation
			combatants := build_land_combatants_from_option(option)
			
			when ODIN_DEBUG {
				fmt.printf("  Combatants for %s (from arrays):\n", t)
				fmt.printf("    potential_attackers count: %d\n", len(option.potential_attackers))
				fmt.printf("    potential_amphib_attackers count: %d\n", len(option.potential_amphib_attackers))
				fmt.printf("    defenders count: %d\n", len(option.defenders))
				fmt.printf("    Built attackers[0]: INF=%d, ARTY=%d, TANK=%d\n", 
					combatants.attackers[0].Infantry, combatants.attackers[0].Artillery, combatants.attackers[0].Tanks)
				fmt.printf("    Built attackers[1]: FIGH=%d\n", combatants.attackers[1].Fighters)
				fmt.printf("    Built attackers[2]: BOMB=%d\n", combatants.attackers[2].Bombers)
				fmt.printf("    Built defenders: INF=%d, ARTY=%d, TANK=%d, FIGH=%d, BOMB=%d, AA=%d\n",
					combatants.defenders.Infantry, combatants.defenders.Artillery, combatants.defenders.Tanks,
					combatants.defenders.Fighters, combatants.defenders.Bombers, combatants.defenders.AntiAir)
			}
			
			// Use battle.odin's simulate_battle for accurate battle prediction
			battle_result := simulate_battle(combatants)
			surviving_def_power = battle_result.avg_survivor_def_power
			option.avg_survivor_def_power = surviving_def_power
			
			when ODIN_DEBUG {
				fmt.printf("  Battle sim for %s: win=%.1f%%, TUV=%.1f, survivor_def=%.1f\n",
					t, battle_result.invaded_percent * 100, battle_result.avg_TUV_swing, 
					battle_result.avg_survivor_def_power)
			}
		} else {
			when ODIN_DEBUG {
				fmt.printf("  %s: Using pre-computed survivor_def_power=%.1f from Step 2\n", t, surviving_def_power)
			}
		}
		
		// Now simulate the enemy counter-attack against our survivors
		// Build enemy counter-attack force from adjacent territories
		counter_combatants := build_counter_attack_combatants(gc, t, surviving_def_power)
		
		when ODIN_DEBUG {
			fmt.printf("    Our survivors (defenders):\n")
			if counter_combatants.defenders.Infantry > 0 do fmt.printf("      Infantry: %d\n", counter_combatants.defenders.Infantry)
			if counter_combatants.defenders.Artillery > 0 do fmt.printf("      Artillery: %d\n", counter_combatants.defenders.Artillery)
			if counter_combatants.defenders.Tanks > 0 do fmt.printf("      Tank: %d\n", counter_combatants.defenders.Tanks)
			if counter_combatants.defenders.Fighters > 0 do fmt.printf("      Fighter: %d\n", counter_combatants.defenders.Fighters)
			if counter_combatants.defenders.Bombers > 0 do fmt.printf("      Bomber: %d\n", counter_combatants.defenders.Bombers)
			if counter_combatants.defenders.AntiAir > 0 do fmt.printf("      AAGun: %d\n", counter_combatants.defenders.AntiAir)
			
			fmt.printf("    Enemy attackers:\n")
			// Wave 0: Land units
			if counter_combatants.attackers[0].Infantry > 0 do fmt.printf("      Infantry: %d\n", counter_combatants.attackers[0].Infantry)
			if counter_combatants.attackers[0].Artillery > 0 do fmt.printf("      Artillery: %d\n", counter_combatants.attackers[0].Artillery)
			if counter_combatants.attackers[0].Tanks > 0 do fmt.printf("      Tank: %d\n", counter_combatants.attackers[0].Tanks)
			// Wave 1: Fighters
			if counter_combatants.attackers[1].Fighters > 0 do fmt.printf("      Fighter: %d\n", counter_combatants.attackers[1].Fighters)
			// Wave 2: Bombers
			if counter_combatants.attackers[2].Bombers > 0 do fmt.printf("      Bomber: %d\n", counter_combatants.attackers[2].Bombers)
		}
		
		// Simulate the counter-attack
		counter_result := simulate_battle(counter_combatants)
		
		when ODIN_DEBUG {
			fmt.printf("    Enemy_win=%.1f%%, TUV=%.1f\n",
				counter_result.invaded_percent * 100, counter_result.avg_TUV_swing)
		}
		
		// Java logic for can_hold (ProCombatMoveAi.java lines 497-499):
		// canHold = (!result2.isHasLandUnitRemaining() && !t.isWater())
		//        || (result2.getTuvSwing() < 0)
		//        || (result2.getWinPercentage() < proData.getMinWinPercentage())
		//
		// Translation:
		// - Enemy counter-attack has low win percentage (<60%)
		// - OR enemy counter-attack has negative TUV swing (they lose more value than us)
		MIN_WIN_PERCENTAGE :: 0.6
		
		enemy_win_pct := counter_result.invaded_percent
		enemy_tuv_swing := counter_result.avg_TUV_swing
		
		// Can hold if:
		// 1. Enemy has less than 60% chance to retake
		// 2. OR enemy would lose more TUV than they gain (bad trade for them)
		when ODIN_DEBUG {
			if (enemy_win_pct < MIN_WIN_PERCENTAGE) {
				fmt.printf("    Can hold because enemy win pct %.1f%% < %.1f%%\n",
					enemy_win_pct * 100, MIN_WIN_PERCENTAGE * 100)
			}
			if (enemy_tuv_swing < 0) {
				fmt.printf("    Can hold because enemy TUV swing %.1f < 0\n", enemy_tuv_swing)
			}
		}
		
		option.can_hold = (enemy_win_pct < MIN_WIN_PERCENTAGE) || (enemy_tuv_swing < 0)
		
		when ODIN_DEBUG {
			production, is_capital := get_production_and_is_capital_triplea(gc, t)
			is_high_value := is_capital || production >= 5
			
			if option.can_hold {
				fmt.printf("    [CAN HOLD]")
			} else {
				fmt.printf("    [CANNOT HOLD]")
			}
			fmt.printf(" (survivors=%.1f def power, enemy_win=%.1f%%, enemy_TUV=%.1f",
				surviving_def_power, enemy_win_pct * 100, enemy_tuv_swing)
			if is_high_value do fmt.printf(", HIGH VALUE")
			fmt.printf(")\n")
		}
	}
}

// Helper: Build Land_Combatants from Attack_Option for battle simulation
build_land_combatants_from_option :: proc(option: ^Attack_Option) -> Land_Combatants {
	combatants := Land_Combatants{}
	
	// Count attackers by type (wave 0 = land units, wave 1 = fighters, wave 2 = bombers)
	for unit in option.potential_attackers {
		#partial switch unit.unit_type {
		case .Infantry:
			combatants.attackers[0].Infantry += 1
		case .Artillery:
			combatants.attackers[0].Artillery += 1
		case .Tank:
			combatants.attackers[0].Tanks += 1
		case .Fighter:
			combatants.attackers[1].Fighters += 1
		case .Bomber:
			combatants.attackers[2].Bombers += 1
		}
	}
	
	// Also count amphib attackers
	for unit in option.potential_amphib_attackers {
		#partial switch unit.unit_type {
		case .Infantry:
			combatants.attackers[0].Infantry += 1
		case .Artillery:
			combatants.attackers[0].Artillery += 1
		case .Tank:
			combatants.attackers[0].Tanks += 1
		}
	}
	
	// Count defenders
	for unit in option.defenders {
		#partial switch unit.unit_type {
		case .Infantry:
			combatants.defenders.Infantry += 1
		case .Artillery:
			combatants.defenders.Artillery += 1
		case .Tank:
			combatants.defenders.Tanks += 1
		case .Fighter:
			combatants.defenders.Fighters += 1
		case .Bomber:
			combatants.defenders.Bombers += 1
		case .AAGun:
			combatants.defenders.AntiAir += 1
		}
	}
	
	return combatants
}

// Helper: Build counter-attack combatants for enemy response simulation
// surviving_def_power is the defense power of our surviving attackers
build_counter_attack_combatants :: proc(gc: ^Game_Cache, target: Land_ID, surviving_def_power: f64) -> Land_Combatants {
	combatants := Land_Combatants{}
	
	// Convert surviving defense power back to approximate unit counts
	// Defense values: INF=2, ARTY=2, TANK=3
	// Assume survivors are mostly infantry and tanks (common attack composition)
	// Use weighted average: ~2.5 defense per land unit
	if surviving_def_power > 0 {
		// Rough conversion: survivors are ~60% inf, 40% tanks (by count)
		// Average defense = 0.6*2 + 0.4*3 = 2.4
		estimated_survivors := int(surviving_def_power / 2.4)
		inf_count := int(f64(estimated_survivors) * 0.6)
		tank_count := estimated_survivors - inf_count
		
		// Our survivors become defenders
		combatants.defenders.Infantry = u8(min(inf_count, 255))
		combatants.defenders.Tanks = u8(min(tank_count, 255))
	}
	
	// Build enemy counter-attack force from adjacent territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		// Check if enemy territory
		if mm.team[gc.owner[adjacent]] == mm.team[gc.cur_player] {
			continue // Skip friendly territories
		}
		
		// Count enemy units that could counter-attack
		for player in Player_ID {
			if mm.team[player] != mm.team[gc.cur_player] {
				combatants.attackers[0].Infantry += gc.idle_armies[adjacent][player][.INF]
				combatants.attackers[0].Artillery += gc.idle_armies[adjacent][player][.ARTY]
				combatants.attackers[0].Tanks += gc.idle_armies[adjacent][player][.TANK]
				// Note: AA guns don't attack, they stay for defense
			}
		}
	}
	
	// Also count enemy planes that could attack from 2 territories away
	for land in Land_ID {
		// Check if within fighter range (4 moves, so up to 2 territories for attack + return)
		dist := calculate_distance(gc, land, target)
		if dist > 2 {
			continue
		}
		
		for player in Player_ID {
			if mm.team[player] != mm.team[gc.cur_player] {
				combatants.attackers[1].Fighters += gc.idle_land_planes[land][player][.FIGHTER]
				combatants.attackers[2].Bombers += gc.idle_land_planes[land][player][.BOMBER]
			}
		}
	}
	
	return combatants
}

/*
=============================================================================
EVALUATE NEED_AMPHIB_UNITS
=============================================================================

Java Original: ProTerritoryManager.setNeedAmphibUnits (line 186)

  if (patd.getMaxBattleResult().getWinPercentage() < proData.getWinPercentage()
      && !patd.getMaxAmphibUnits().isEmpty()) {
    patd.setNeedAmphibUnits(true);
  }

This checks if:
1. Land+air attackers alone can't achieve the required win percentage (typically 60-95%)
2. AND there are amphibious units available that could help

If both conditions are true, the territory is flagged as "needing amphibious units"
which causes the AI to commit transports to this attack.
*/

evaluate_need_amphib_units_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	WIN_THRESHOLD :: 0.60  // 60% win rate needed
	
	when ODIN_DEBUG {
		fmt.println("\n[AMPHIB EVAL] Evaluating which territories need amphibious reinforcements...")
	}
	
	for &option in options {
		t := option.territory
		
		// Skip if already flagged
		if option.need_amphib_units {
			continue
		}
		
		// Check if there are any potential amphibious attackers
		if len(option.potential_amphib_attackers) == 0 {
			when ODIN_DEBUG {
				fmt.printf("  %v: No amphib units available\n", t)
			}
			continue
		}
		
		// Simulate battle with ONLY land+air attackers (no amphib)
		combatants_no_amphib := build_land_combatants_without_amphib(&option)
		
		// Run battle simulation
		result_no_amphib := simulate_battle(combatants_no_amphib)
		
		// Check if land+air alone can win
		land_air_win_pct := result_no_amphib.invaded_percent
		
		if land_air_win_pct >= WIN_THRESHOLD {
			// Land+air can win alone, no amphib needed
			option.need_amphib_units = false
			when ODIN_DEBUG {
				fmt.printf("  %v: Land+Air win=%.1f%% >= %.1f%% - NO AMPHIB NEEDED\n", 
					t, land_air_win_pct * 100, WIN_THRESHOLD * 100)
			}
		} else {
			// Land+air can't win, check if adding amphib helps
			combatants_with_amphib := build_land_combatants_from_option(&option)
			result_with_amphib := simulate_battle(combatants_with_amphib)
			
			if result_with_amphib.invaded_percent >= WIN_THRESHOLD {
				// Adding amphib makes the attack viable!
				option.need_amphib_units = true
				option.is_amphib = true
				when ODIN_DEBUG {
					fmt.printf("  %v: Land+Air win=%.1f%%, WITH AMPHIB win=%.1f%% - NEED AMPHIB UNITS\n", 
						t, land_air_win_pct * 100, result_with_amphib.invaded_percent * 100)
				}
			} else {
				// Even with amphib, still can't win reliably
				option.need_amphib_units = false
				when ODIN_DEBUG {
					fmt.printf("  %v: Land+Air win=%.1f%%, WITH AMPHIB win=%.1f%% - Still too weak\n", 
						t, land_air_win_pct * 100, result_with_amphib.invaded_percent * 100)
				}
			}
		}
	}
}

// Helper: Build Land_Combatants from Attack_Option WITHOUT amphibious attackers
// Used to check if land+air alone can win
build_land_combatants_without_amphib :: proc(option: ^Attack_Option) -> Land_Combatants {
	combatants := Land_Combatants{}
	
	// Count ONLY land+air attackers (no amphib)
	for unit in option.potential_attackers {
		#partial switch unit.unit_type {
		case .Infantry:
			combatants.attackers[0].Infantry += 1
		case .Artillery:
			combatants.attackers[0].Artillery += 1
		case .Tank:
			combatants.attackers[0].Tanks += 1
		case .Fighter:
			combatants.attackers[1].Fighters += 1
		case .Bomber:
			combatants.attackers[2].Bombers += 1
		}
	}
	
	// Count defenders (same as full version)
	for unit in option.defenders {
		#partial switch unit.unit_type {
		case .Infantry:
			combatants.defenders.Infantry += 1
		case .Artillery:
			combatants.defenders.Artillery += 1
		case .Tank:
			combatants.defenders.Tanks += 1
		case .Fighter:
			combatants.defenders.Fighters += 1
		case .Bomber:
			combatants.defenders.Bombers += 1
		case .AAGun:
			combatants.defenders.AntiAir += 1
		}
	}
	
	return combatants
}

/*
=============================================================================
METHOD 4: removeTerritoriesThatArentWorthAttacking
=============================================================================

Java Original (lines 526-634):

  private void removeTerritoriesThatArentWorthAttacking(
      final List<ProTerritory> prioritizedTerritories) {
    ProLogger.info("Remove territories that aren't worth attacking");

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Loop through all prioritized territories
    for (final Iterator<ProTerritory> it = prioritizedTerritories.iterator(); it.hasNext(); ) {
      final ProTerritory patd = it.next();
      final Territory t = patd.getTerritory();

      // Remove empty convoy zones that can't be held
      if (!patd.isCanHold()
          && enemyAttackOptions.getMax(t) != null
          && t.isWater()
          && !t.anyUnitsMatch(Matches.enemyUnit(player))) {
        it.remove();
        continue;
      }

      // Remove neutral and low value amphib land territories that can't be held
      // [Lines 564-590]

      // Remove neutral territories where attackers are adjacent to enemy territories
      // [Lines 595-631]
    }
  }
*/

// Odin Implementation:
remove_territories_that_arent_worth_attacking_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("Remove territories that aren't worth attacking")
	}
	
	// Loop through all prioritized territories
	for i := len(options) - 1; i >= 0; i -= 1 {
		option := &options[i]
		t := option.territory
		
		// Remove empty convoy zones that can't be held
		if !option.can_hold && is_water_territory(t) && 
			count_enemy_units_at_territory(gc, t) == 0 {
			unordered_remove(options, i)
			continue
		}
		
		// Remove neutral and low value amphib land territories that can't be held
		if !option.can_hold && option.is_amphib && is_neutral_land(gc, t) &&
			option.attack_value < 5 {
			unordered_remove(options, i)
			continue
		}
		
		// Remove neutral territories where attackers are adjacent to enemy territories
		if is_neutral_land(gc, t) && has_attackers_adjacent_to_enemy(gc, option) {
			unordered_remove(options, i)
			continue
		}
	}
}

/*
=============================================================================
METHOD 5: moveOneDefenderToLandTerritoriesBorderingEnemy
=============================================================================

Java Original (lines 636-682):

  private List<Unit> moveOneDefenderToLandTerritoriesBorderingEnemy(
      final List<ProTerritory> prioritizedTerritories) {

    ProLogger.info("Determine which territories to defend with one land unit");

    final Map<Unit, Set<Territory>> unitMoveMap =
        territoryManager.getAttackOptions().getUnitMoveMap();

    // Get list of territories to attack
    final List<Territory> territoriesToAttack = new ArrayList<>();
    for (final ProTerritory patd : prioritizedTerritories) {
      territoriesToAttack.add(patd.getTerritory());
    }

    // Find land territories without units and adjacent to enemy land units
    final List<Unit> alreadyMovedUnits = new ArrayList<>();
    for (final Territory t : proData.getMyUnitTerritories()) {
      final boolean hasAlliedLandUnits =
          t.anyUnitsMatch(ProMatches.unitCantBeMovedAndIsAlliedDefenderAndNotInfra(player, t));
      final Set<Territory> enemyNeighbors =
          data.getMap()
              .getNeighbors(t, [filter for enemy territories with land units]);
      enemyNeighbors.removeAll(territoriesToAttack);
      if (!t.isWater() && !hasAlliedLandUnits && !enemyNeighbors.isEmpty()) {
        // [Find cheapest unit to leave - lines 670-679]
      }
    }
    return alreadyMovedUnits;
  }
*/

// Odin Implementation:
move_one_defender_to_land_territories_bordering_enemy_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
) -> [dynamic]Unit_Info {
	when ODIN_DEBUG {
		fmt.println("  Searching for empty border territories needing defenders...")
	}
	
	already_moved := make([dynamic]Unit_Info)
	
	// Get list of territories we're attacking
	territories_to_attack := make([dynamic]Land_ID)
	defer delete(territories_to_attack)
	for option in options {
		append(&territories_to_attack, option.territory)
	}
	
	// Find land territories without units and adjacent to enemy land units
	for land_tid in Land_ID {
		if gc.owner[land_tid] != gc.cur_player {
			continue
		}
		
		// Check if has allied land units
		has_allied_units := false
		for army in gc.idle_armies[land_tid][gc.cur_player] {
			if army > 0 {
				has_allied_units = true
				break
			}
		}
		
		if has_allied_units do continue
		
		// Find enemy neighbors (that we're not attacking)
		enemy_neighbor_count := 0
		for adj in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
			if mm.team[gc.owner[adj]] != mm.team[gc.cur_player] {
				// Check if we're attacking this territory
				is_attack_target := false
				for target in territories_to_attack {
					if target == adj {
						is_attack_target = true
						break
					}
				}
				
				if !is_attack_target {
					enemy_neighbor_count += 1
				}
			}
		}
		
		// If no units and has enemy neighbors, move one defender here
		if enemy_neighbor_count > 0 {
			when ODIN_DEBUG {
				fmt.printf("    %s: empty territory with %d enemy neighbor(s)\n",
					land_tid, enemy_neighbor_count)
			}
			
			// Find cheapest unit from adjacent friendly territory
			cheapest_cost := 999
			cheapest_from := max(Land_ID)
			cheapest_army := Active_Army.INF_1_MOVES
			tracked_army :Unit_Type= .Infantry
			
			for adj in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj]] == mm.team[gc.cur_player] {
					// Try infantry first (cheapest)
					if gc.idle_armies[adj][gc.cur_player][.INF] > 0 {
						if 3 < cheapest_cost {
							cheapest_cost = 3
							cheapest_from = adj
							cheapest_army = .INF_1_MOVES
							tracked_army = .Infantry
						}
					}
					
					// Try artillery
					if gc.idle_armies[adj][gc.cur_player][.ARTY] > 0 {
						if 4 < cheapest_cost {
							cheapest_cost = 4
							cheapest_from = adj
							cheapest_army = .ARTY_1_MOVES
							tracked_army = .Artillery
						}
					}
					
					// Try tank
					if gc.idle_armies[adj][gc.cur_player][.TANK] > 0 {
						if 5 < cheapest_cost {
							cheapest_cost = 5
							cheapest_from = adj
							cheapest_army = .TANK_2_MOVES
							tracked_army = .Tank
						}
					}
				}
			}
			
			// Move the unit
			if cheapest_from != max(Land_ID) {
				gc.current_territory = to_air(cheapest_from)
				gc.current_active_unit = to_unit(cheapest_army)
				move_single_army_land(gc, to_action(land_tid), cheapest_army)
				// gc.idle_armies[cheapest_from][gc.cur_player][cheapest_army] -= 1
				// gc.idle_armies[land_tid][gc.cur_player][cheapest_army] += 1
				
				// Track the move
				append(&already_moved, Unit_Info{
					unit_type = tracked_army,
					from_territory = cheapest_from,
				})
				
				when ODIN_DEBUG {
					fmt.printf("      -> Moved 1x %v from %s to %s\n",
						cheapest_army,
						cheapest_from,
						land_tid)
				}
			} else {
				when ODIN_DEBUG {
					fmt.printf("      -> No available units to move (skipping)\n")
				}
			}
		}
	}
	
	when ODIN_DEBUG {
		if len(already_moved) == 0 {
			fmt.println("  (No border territories needed defenders)")
		} else {
			fmt.printf("  Summary: Made %d border defender move(s)\n", len(already_moved))
		}
	}
	
	return already_moved
}

/*
=============================================================================
METHOD 6: removeTerritoriesWhereTransportsAreExposed
=============================================================================

Java Original (lines 684-827):

  private void removeTerritoriesWhereTransportsAreExposed() {

    ProLogger.info("Remove territories where transports are exposed");

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();
    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Find maximum defenders for each transport territory
    final List<Territory> clearedTerritories = [...]
    territoryManager.populateDefenseOptions(clearedTerritories);
    final Map<Territory, ProTerritory> defendMap =
        territoryManager.getDefendOptions().getTerritoryMap();

    // Remove units that have already attacked
    // [Lines 704-713]

    // Loop through all prioritized territories
    for (final Map.Entry<Territory, ProTerritory> attackEntry : attackMap.entrySet()) {
      final Territory t = attackEntry.getKey();
      final ProTerritory patd = attackEntry.getValue();
      
      if (!patd.getTerritory().isWater() && !patd.getTransportTerritoryMap().isEmpty()) {
        // [Find all transports and bombard units - lines 727-790]
        
        // Determine whether its worth attacking
        final ProBattleResult result = calc.calculateBattleResults([...]);
        double attackValue = result.getTuvSwing() + production * (1 + 3.0 * isCapital);
        if (!patd.isStrafing() && (0.75 * enemyTuvSwing) > attackValue) {
          // Remove attack
        }
      }
    }
  }
*/

// Odin Implementation:
remove_territories_where_transports_are_exposed_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("Remove territories where transports are exposed")
	}
	
	// Loop through all amphib attacks (backwards to allow removal)
	for i := len(options) - 1; i >= 0; i -= 1 {
		option := &options[i]
		
		if !option.is_amphib {
			continue
		}
		
		// Find sea zones with transports for this attack
		transport_zones := make(map[Sea_ID]bool)
		defer delete(transport_zones)
		
		// Find which sea zones border the target land
		target := option.territory
		for sea_tid in sa.slice(&mm.l2s_1away_via_land[target]) {
			// Check if we have transports here
			if gc.idle_ships[sea_tid][gc.cur_player][.TRANS_EMPTY] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1A] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1T] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_2I] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I_1A] > 0 ||
			   gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I_1T] > 0 {
				transport_zones[sea_tid] = true
			}
		}
		
		if len(transport_zones) == 0 do continue
		
		// Calculate enemy attack potential on these transport zones
		max_transport_loss := f64(0)
		
		for sea_tid in transport_zones {
			enemy_attack := f64(0)
			
			// Count enemy units that could attack this sea zone
			canal_state := transmute(u8)gc.canals_open
			for enemy_sea in mm.s2s_1away_via_sea[canal_state][sea_tid] {
				// Sea zones don't have owners in same way - check ships instead
				has_enemy_ships := false
				for player in Player_ID {
					if mm.team[player] != mm.team[gc.cur_player] {
						for ship in Idle_Ship {
							if gc.idle_ships[enemy_sea][player][ship] > 0 {
								has_enemy_ships = true
								break
							}
						}
					}
					if has_enemy_ships do break
				}
				if has_enemy_ships {
					// Count all enemy ships in this zone
					for player in Player_ID {
						if mm.team[player] != mm.team[gc.cur_player] {
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.DESTROYER]) * 3.0
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.CRUISER]) * 3.0
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.CARRIER]) * 1.0
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.BATTLESHIP]) * 4.0
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.BS_DAMAGED]) * 4.0
							enemy_attack += f64(gc.idle_ships[enemy_sea][player][.SUB]) * 2.0
						}
					}
				}
			}
			
			// Count enemy planes that could reach (simplified - just check adjacent)
			for land_tid in Land_ID {
				owner := gc.owner[land_tid]
				if mm.team[owner] != mm.team[gc.cur_player] {
					// Check if this land is adjacent to the sea zone
					for adj_sea in sa.slice(&mm.l2s_1away_via_land[land_tid]) {
						if adj_sea == sea_tid {
							// Fighters and bombers can reach from adjacent land (range 4 and 6)
							enemy_attack += f64(gc.idle_land_planes[land_tid][owner][.FIGHTER]) * 3.0
							enemy_attack += f64(gc.idle_land_planes[land_tid][owner][.BOMBER]) * 4.0
							break
						}
					}
				}
			}
			
			// Calculate potential transport losses (transports defend at 0)
			transport_count := f64(gc.idle_ships[sea_tid][gc.cur_player][.TRANS_EMPTY] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1A] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1T] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_2I] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I_1A] +
			                       gc.idle_ships[sea_tid][gc.cur_player][.TRANS_1I_1T])
			transport_value := transport_count * 8.0 // Transports cost 8 IPC
			
			if enemy_attack > transport_value * 0.75 {
				max_transport_loss = max(max_transport_loss, transport_value)
			}
		}
		
		// If transports are too exposed, remove the attack
		if max_transport_loss > 0 && max_transport_loss * 0.75 > option.attack_value {
			when ODIN_DEBUG {
				fmt.printf("  Removing amphib attack on %s - transports exposed (%.1f loss vs %.1f value)\n",
					option.territory, max_transport_loss, option.attack_value)
			}
			
			unordered_remove(options, i)
		}
	}
}

/*
=============================================================================
METHOD 7: determineUnitsToAttackWith
=============================================================================

Java Original (lines 847-1158):

  private void determineUnitsToAttackWith(
      final List<ProTerritory> prioritizedTerritories, final List<Unit> alreadyMovedUnits) {

    ProLogger.info("Determine units to attack each territory with");

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();
    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();
    final Map<Unit, Set<Territory>> unitAttackMap =
        territoryManager.getAttackOptions().getUnitMoveMap();

    // Assign units to territories by prioritization
    while (true) {
      Map<Unit, Set<Territory>> sortedUnitAttackOptions =
          tryToAttackTerritories(prioritizedTerritories, alreadyMovedUnits);

      // Clear bombers
      attackMap.values().forEach(proTerritory -> proTerritory.getBombers().clear());

      // Get all units that have already moved
      final Set<Unit> alreadyAttackedWithUnits = new HashSet<>();
      // [Lines 866-872]

      // Check to see if any territories can be bombed
      determineTerritoriesThatCanBeBombed(
          attackMap, sortedUnitAttackOptions, alreadyAttackedWithUnits);

      // Re-sort attack options and assign units in phases:
      // 1. Air units in territories with no AA
      // 2. Units for territories that can be held
      // 3. Sea units that increase TUV gain
      // [Lines 875-1002]

      // Determine if all attacks are worth it
      // [Lines 1005-1148]

      // Determine whether all attacks are successful or try to hold fewer territories
      if (territoryToRemove == null) {
        break;
      }
      prioritizedTerritories.remove(territoryToRemove);
    }
  }
*/

// Odin Implementation:
determine_units_to_attack_with_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
	already_moved: ^[dynamic]Unit_Info,
) {
	when ODIN_DEBUG {
		fmt.println("[determineUnitsToAttackWith] Assigning units to attacks...")
	}
	
	// Main loop: keep trying to assign units until all attacks are valid
	for {
		// Clear all existing assignments
		for i := 0; i < len(options); i += 1 {
			clear(&options[i].attackers)
			clear(&options[i].amphib_attackers)
			clear(&options[i].bombard_units)
			clear(&options[i].defenders)
		}
		
		// Try to assign units to all selected territories
		when ODIN_DEBUG {
			fmt.println("  Attempting to assign units to attacks...")
		}
		
		// For each territory being attacked, assign units that can reach it
		for i := 0; i < len(options); i += 1 {
			opt := &options[i]
			target_land := opt.territory
			
			when ODIN_DEBUG {
				fmt.printf("    Assigning units to attack %v...\n", target_land)
			}
			
			// Strategy 1: Assign adjacent land units
			assign_adjacent_land_units(gc, opt, already_moved, options)
			
			// Strategy 2: Assign air units within range
			assign_air_units_within_range(gc, opt, already_moved, options)
			
			// Strategy 3: Assign amphibious units
			assign_amphibious_units(gc, opt, already_moved, options)
			
			// Populate defenders for calculating attack power
			populate_defenders(gc, opt)
			
			when ODIN_DEBUG {
				attacker_count := len(opt.attackers)
				amphib_count := len(opt.amphib_attackers)
				fmt.printf("      -> Assigned %d land/air, %d amphib\n", attacker_count, amphib_count)
			}
		}
		
		// Check if all attacks are worthwhile
		territory_to_remove := -1
		
		for i := 0; i < len(options); i += 1 {
			opt := &options[i]
			
			// Calculate actual attack power from assigned units
			attack_power := calculate_total_attack_power(gc, opt.attackers, opt.amphib_attackers)
			defense_power := calculate_total_defense_power(gc, opt.defenders)
			
			when ODIN_DEBUG {
				fmt.printf("    %v: %.1f attack vs %.1f defense\n", 
					opt.territory, attack_power, defense_power)
			}
			
			// If no units assigned, this attack is invalid
			if len(opt.attackers) == 0 && len(opt.amphib_attackers) == 0 {
				when ODIN_DEBUG {
					fmt.printf("    -> Removing %v (no units assigned)\n", opt.territory)
				}
				territory_to_remove = i
				break
			}
			
			// If attack power is too low, remove this attack
			if attack_power == 0 {
				when ODIN_DEBUG {
					fmt.printf("    -> Removing %v (zero attack power)\n", opt.territory)
				}
				territory_to_remove = i
				break
			}
		}
		
		// If all attacks are valid, we're done
		if territory_to_remove == -1 {
			when ODIN_DEBUG {
				fmt.println("  -> All attacks have units assigned")
			}
			break
		}
		
		// Remove the invalid attack and try again
		ordered_remove(options, territory_to_remove)
		
		// If no attacks left, we're done
		if len(options) == 0 {
			when ODIN_DEBUG {
				fmt.println("  -> No valid attacks possible")
			}
			break
		}
	}
}

// Helper: Count units already assigned in options array
count_units_assigned_in_options :: proc(
	options: ^[dynamic]Attack_Option,
	from: Land_ID,
	unit_type: Unit_Type,
) -> int {
	count := 0
	for option in options {
		for unit in option.attackers {
			if unit.from_territory == from && unit.unit_type == unit_type {
				count += 1
			}
		}
		for unit in option.amphib_attackers {
			if unit.from_territory == from && unit.unit_type == unit_type {
				count += 1
			}
		}
	}
	return count
}

// Helper: Get available units of a type from active_armies (units that can still move)
get_active_unit_count_for_combat :: proc(gc: ^Game_Cache, location: Land_ID, unit_type: Unit_Type) -> int {
	#partial switch unit_type {
	case .Infantry:
		return int(gc.active_armies[location][.INF_1_MOVES])
	case .Artillery:
		return int(gc.active_armies[location][.ARTY_1_MOVES])
	case .Tank:
		// Tanks can have 2 moves or 1 move remaining
		return int(gc.active_armies[location][.TANK_2_MOVES]) + 
		       int(gc.active_armies[location][.TANK_1_MOVES])
	case .AAGun:
		return int(gc.active_armies[location][.AAGUN_1_MOVES])
	}
	return 0
}

// Helper: Get available air units from active planes
get_active_air_count_for_combat :: proc(gc: ^Game_Cache, location: Land_ID, unit_type: Unit_Type) -> int {
	#partial switch unit_type {
	case .Fighter:
		return int(gc.active_land_planes[location][.FIGHTER_UNMOVED]) +
		       int(gc.active_land_planes[location][.FIGHTER_4_MOVES]) +
		       int(gc.active_land_planes[location][.FIGHTER_3_MOVES]) +
		       int(gc.active_land_planes[location][.FIGHTER_2_MOVES]) +
		       int(gc.active_land_planes[location][.FIGHTER_1_MOVES])
	case .Bomber:
		return int(gc.active_land_planes[location][.BOMBER_UNMOVED]) +
		       int(gc.active_land_planes[location][.BOMBER_5_MOVES]) +
		       int(gc.active_land_planes[location][.BOMBER_4_MOVES]) +
		       int(gc.active_land_planes[location][.BOMBER_3_MOVES]) +
		       int(gc.active_land_planes[location][.BOMBER_2_MOVES]) +
		       int(gc.active_land_planes[location][.BOMBER_1_MOVES])
	}
	return 0
}

// Helper: Assign land units adjacent to target
assign_adjacent_land_units :: proc(
	gc: ^Game_Cache,
	opt: ^Attack_Option,
	already_moved: ^[dynamic]Unit_Info,
	options: ^[dynamic]Attack_Option,
) {
	target_land := opt.territory
	
	// Find all adjacent friendly territories with units
	for source_land in sa.slice(&mm.l2l_1away_via_land[target_land]) {
		if gc.owner[source_land] != gc.cur_player {
			continue
		}
		
		// Add infantry (but check how many are available after previous assignments)
		total_inf := get_active_unit_count_for_combat(gc, source_land, .Infantry)
		assigned_inf := count_units_assigned_in_options(options, source_land, .Infantry)
		available_inf := total_inf - assigned_inf
		
		for i in 0..<available_inf {
			unit := Unit_Info{
				unit_type = .Infantry,
				from_territory = source_land,
			}
			if !is_already_moved(unit, already_moved^) {
				append(&opt.attackers, unit)
			}
		}
		
		// Add artillery
		total_arty := get_active_unit_count_for_combat(gc, source_land, .Artillery)
		assigned_arty := count_units_assigned_in_options(options, source_land, .Artillery)
		available_arty := total_arty - assigned_arty
		
		for i in 0..<available_arty {
			unit := Unit_Info{
				unit_type = .Artillery,
				from_territory = source_land,
			}
			if !is_already_moved(unit, already_moved^) {
				append(&opt.attackers, unit)
			}
		}
		
		// Add tanks
		total_tank := get_active_unit_count_for_combat(gc, source_land, .Tank)
		assigned_tank := count_units_assigned_in_options(options, source_land, .Tank)
		available_tank := total_tank - assigned_tank
		
		for i in 0..<available_tank {
			unit := Unit_Info{
				unit_type = .Tank,
				from_territory = source_land,
			}
			if !is_already_moved(unit, already_moved^) {
				append(&opt.attackers, unit)
			}
		}
	}
	
	// Tanks can also blitz from 2 territories away
	for adj1 in sa.slice(&mm.l2l_1away_via_land[target_land]) {
		if gc.owner[adj1] != gc.cur_player {
			continue
		}
		
		if has_enemy_units(gc, adj1) {
			continue // Can't blitz through enemy units
		}
		
		for source_land in sa.slice(&mm.l2l_1away_via_land[adj1]) {
			if source_land == target_land {
				continue
			}
			if gc.owner[source_land] != gc.cur_player {
				continue
			}
			
			// Add tanks that can blitz (check availability)
			total_tank := get_active_unit_count_for_combat(gc, source_land, .Tank)
			assigned_tank := count_units_assigned_in_options(options, source_land, .Tank)
			available_tank := total_tank - assigned_tank
			
			for i in 0..<available_tank {
				unit := Unit_Info{
					unit_type = .Tank,
					from_territory = source_land,
				}
				if !is_already_moved(unit, already_moved^) && !unit_in_list(unit, &opt.attackers) {
					append(&opt.attackers, unit)
				}
			}
		}
	}
}

// Helper: Assign air units within range (2 moves for now)
assign_air_units_within_range :: proc(
	gc: ^Game_Cache,
	opt: ^Attack_Option,
	already_moved: ^[dynamic]Unit_Info,
	options: ^[dynamic]Attack_Option,
) {
	target_land := opt.territory
	
	// Find all territories with air units within range
	for source_land in Land_ID {
		if gc.owner[source_land] != gc.cur_player {
			continue
		}
		
		// Check if reachable in 1 move
		can_reach_in_1 := false
		for adj in sa.slice(&mm.l2l_1away_via_land[source_land]) {
			if adj == target_land {
				can_reach_in_1 = true
				break
			}
		}
		
		// Check if reachable in 2 moves
		can_reach_in_2 := false
		if !can_reach_in_1 {
			for adj1 in sa.slice(&mm.l2l_1away_via_land[source_land]) {
				for adj2 in sa.slice(&mm.l2l_1away_via_land[adj1]) {
					if adj2 == target_land {
						can_reach_in_2 = true
						break
					}
				}
				if can_reach_in_2 do break
			}
		}
		
		if !can_reach_in_1 && !can_reach_in_2 {
			continue
		}
		
		// Add fighters (check availability)
		total_fighters := get_active_air_count_for_combat(gc, source_land, .Fighter)
		assigned_fighters := count_units_assigned_in_options(options, source_land, .Fighter)
		available_fighters := total_fighters - assigned_fighters
		
		for i in 0..<available_fighters {
			unit := Unit_Info{
				unit_type = .Fighter,
				from_territory = source_land,
			}
			if !is_already_moved(unit, already_moved^) {
				append(&opt.attackers, unit)
			}
		}
		
		// Add bombers (check availability)
		total_bombers := get_active_air_count_for_combat(gc, source_land, .Bomber)
		assigned_bombers := count_units_assigned_in_options(options, source_land, .Bomber)
		available_bombers := total_bombers - assigned_bombers
		
		for i in 0..<available_bombers {
			unit := Unit_Info{
				unit_type = .Bomber,
				from_territory = source_land,
			}
			if !is_already_moved(unit, already_moved^) {
				append(&opt.attackers, unit)
			}
		}
	}
}

// Helper: Assign amphibious units from transports
assign_amphibious_units :: proc(
	gc: ^Game_Cache,
	opt: ^Attack_Option,
	already_moved: ^[dynamic]Unit_Info,
	options: ^[dynamic]Attack_Option,
) {
	target_land := opt.territory
	canal_state := transmute(u8)gc.canals_open
	
	// All loaded transport types
	loaded_types := [?]struct{type: Idle_Ship, inf: u8, arty: u8, tank: u8}{
		{.TRANS_1I, 1, 0, 0},
		{.TRANS_1T, 0, 0, 1},
		{.TRANS_1A, 0, 1, 0},
		{.TRANS_2I, 2, 0, 0},
		{.TRANS_1I_1A, 1, 1, 0},
		{.TRANS_1I_1T, 1, 0, 1},
	}
	
	// Find all sea zones that can reach target (adjacent or 1 move away)
	for sea_id in Sea_ID {
		// Check if this sea zone can reach the target
		is_adjacent := false
		is_one_away := false
		
		// Check if directly adjacent
		for coastal_land in sa.slice(&mm.s2l_1away_via_sea[sea_id]) {
			if coastal_land == target_land {
				is_adjacent = true
				break
			}
		}
		
		// Check if 1 sea zone away from an adjacent sea
		if !is_adjacent {
			for adj_sea in mm.s2s_1away_via_sea[canal_state][sea_id] {
				// Skip blocked sea zones
				if gc.enemy_blockade_total[adj_sea] > 0 {
					continue
				}
				for land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
					if land == target_land {
						is_one_away = true
						break
					}
				}
				if is_one_away { break }
			}
		}
		
		if !is_adjacent && !is_one_away {
			continue
		}
		
		// Add units from all loaded transports at this sea zone
		for info in loaded_types {
			count := gc.idle_ships[sea_id][gc.cur_player][info.type]
			if count == 0 { continue }
			
			// Add infantry from these transports
			for i in 0..<(count * info.inf) {
				unit := Unit_Info{
					unit_type = .Infantry,
					from_territory = Land_ID(sea_id),
				}
				append(&opt.amphib_attackers, unit)
			}
			
			// Add artillery from these transports
			for i in 0..<(count * info.arty) {
				unit := Unit_Info{
					unit_type = .Artillery,
					from_territory = Land_ID(sea_id),
				}
				append(&opt.amphib_attackers, unit)
			}
			
			// Add tanks from these transports
			for i in 0..<(count * info.tank) {
				unit := Unit_Info{
					unit_type = .Tank,
					from_territory = Land_ID(sea_id),
				}
				append(&opt.amphib_attackers, unit)
			}
		}
	}
}

// Helper: Populate defenders for attack calculation
populate_defenders :: proc(
	gc: ^Game_Cache,
	opt: ^Attack_Option,
) {
	target_land := opt.territory
	
	// Add all enemy units in territory as defenders
	for player in Player_ID {
		if mm.team[player] == mm.team[gc.cur_player] {
			continue
		}
		
		// Add enemy armies
		infantry_count := gc.idle_armies[target_land][player][.INF]
		for i in 0..<infantry_count {
			append(&opt.defenders, Unit_Info{unit_type = .Infantry, from_territory = target_land})
		}
		
		artillery_count := gc.idle_armies[target_land][player][.ARTY]
		for i in 0..<artillery_count {
			append(&opt.defenders, Unit_Info{unit_type = .Artillery, from_territory = target_land})
		}
		
		tank_count := gc.idle_armies[target_land][player][.TANK]
		for i in 0..<tank_count {
			append(&opt.defenders, Unit_Info{unit_type = .Tank, from_territory = target_land})
		}
		
		// Add enemy planes
		fighter_count := gc.idle_land_planes[target_land][player][.FIGHTER]
		for i in 0..<fighter_count {
			append(&opt.defenders, Unit_Info{unit_type = .Fighter, from_territory = target_land})
		}
		
		bomber_count := gc.idle_land_planes[target_land][player][.BOMBER]
		for i in 0..<bomber_count {
			append(&opt.defenders, Unit_Info{unit_type = .Bomber, from_territory = target_land})
		}
	}
}

// Helper: Check if unit is already moved
is_already_moved :: proc(unit: Unit_Info, moved_units: [dynamic]Unit_Info) -> bool {
	for moved in moved_units {
		if moved.unit_type == unit.unit_type && moved.from_territory == unit.from_territory {
			return true
		}
	}
	return false
}

// Helper: Check if unit is already assigned to any attack
is_unit_assigned_to_any_attack :: proc(unit: Unit_Info, options: ^[dynamic]Attack_Option) -> bool {
	for opt in options {
		// Check regular attackers
		for attacker in opt.attackers {
			if attacker.unit_type == unit.unit_type && attacker.from_territory == unit.from_territory {
				return true
			}
		}
		// Check amphibious attackers
		for attacker in opt.amphib_attackers {
			if attacker.unit_type == unit.unit_type && attacker.from_territory == unit.from_territory {
				return true
			}
		}
	}
	return false
}

// Helper: Check if unit is in list
unit_in_list :: proc(unit: Unit_Info, unit_list: ^[dynamic]Unit_Info) -> bool {
	for u in unit_list {
		if u.unit_type == unit.unit_type && u.from_territory == unit.from_territory {
			return true
		}
	}
	return false
}

// Helper: Calculate total attack power
calculate_total_attack_power :: proc(
	gc: ^Game_Cache,
	attackers: [dynamic]Unit_Info,
	amphib_attackers: [dynamic]Unit_Info,
) -> f64 {
	power := f64(0)
	
	for unit in attackers {
		#partial switch unit.unit_type {
		case .Infantry:   power += 1.0
		case .Artillery:  power += 2.0
		case .Tank:       power += 3.0
		case .Fighter:    power += 4.0
		case .Bomber:     power += 4.0
		}
	}
	
	for unit in amphib_attackers {
		#partial switch unit.unit_type {
		case .Infantry:   power += 1.0
		case .Artillery:  power += 2.0
		case .Tank:       power += 3.0
		}
	}
	
	return power
}

// Helper: Calculate total defense power
calculate_total_defense_power :: proc(
	gc: ^Game_Cache,
	defenders: [dynamic]Unit_Info,
) -> f64 {
	power := f64(0)
	
	for unit in defenders {
		#partial switch unit.unit_type {
		case .Infantry:   power += 2.0
		case .Artillery:  power += 2.0
		case .Tank:       power += 3.0
		case .Fighter:    power += 5.0
		case .Bomber:     power += 1.0
		case .AAGun:      power += 1.0
		}
	}
	
	return power
}

/*
=============================================================================
METHOD 8: determineTerritoriesThatCanBeBombed
=============================================================================

Java Original (lines 1160-1184):

  private void determineTerritoriesThatCanBeBombed(
      final Map<Territory, ProTerritory> attackMap,
      final Map<Unit, Set<Territory>> sortedUnitAttackOptions,
      final Set<Unit> alreadyAttackedWithUnits) {
    final boolean raidsMayBePrecededByAirBattles =
        Properties.getRaidsMayBePreceededByAirBattles(data.getProperties());
    for (final Map.Entry<Unit, Set<Territory>> bomberEntry :
        territoryManager.getAttackOptions().getBomberMoveMap().entrySet()) {
      final Unit bomber = bomberEntry.getKey();
      if (alreadyAttackedWithUnits.contains(bomber)) {
        continue;
      }
      Collection<Territory> bomberTargetTerritories = bomberEntry.getValue();
      if (raidsMayBePrecededByAirBattles) {
        // [Filter out air battle territories]
      }
      determineBestBombingAttackForBomber(
          attackMap, sortedUnitAttackOptions, bomberTargetTerritories, bomber);
    }
  }
*/

// Odin Implementation:
determine_territories_that_can_be_bombed_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
	already_attacked: ^[dynamic]Unit_Info,
) {
	// Find all bombers that haven't been assigned yet
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player {
			continue
		}
		
		// Check for idle bombers
		bomber_count := gc.idle_land_planes[land][gc.cur_player][.BOMBER]
		for i := 0; i < int(bomber_count); i += 1 {
			bomber := Unit_Info{unit_type = .Bomber, from_territory = land}
			
			// Check if already used
			if is_unit_already_used(bomber, already_attacked) {
				continue
			}
			
			// Find best bombing target for this bomber
			determine_best_bombing_attack_for_bomber_triplea(gc, options, bomber)
		}
	}
}

/*
=============================================================================
METHOD 9: determineBestBombingAttackForBomber  
=============================================================================

Java Original (lines 1186-1243):

  private void determineBestBombingAttackForBomber(
      final Map<Territory, ProTerritory> attackMap,
      final Map<Unit, Set<Territory>> sortedUnitAttackOptions,
      final Collection<Territory> bomberTargetTerritories,
      final Unit bomber) {
    final Predicate<Unit> bombingTargetMatch =
        Matches.unitCanProduceUnitsAndCanBeDamaged()
            .and(Matches.unitIsLegalBombingTargetBy(bomber));
    Optional<Territory> maxBombingTerritory = Optional.empty();
    int maxBombingScore = MIN_BOMBING_SCORE;
    for (final Territory t : bomberTargetTerritories) {
      final List<Unit> targetUnits = t.getMatches(bombingTargetMatch);
      if (!targetUnits.isEmpty() && canAirSafelyLandAfterAttack(bomber, t)) {
        // [Calculate bombing score - lines 1208-1236]
      }
    }
    if (maxBombingTerritory.isPresent()) {
      final Territory t = maxBombingTerritory.get();
      attackMap.get(t).getBombers().add(bomber);
      sortedUnitAttackOptions.remove(bomber);
    }
  }
*/

// Odin Implementation:
determine_best_bombing_attack_for_bomber_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
	bomber: Unit_Info,
) {
	MIN_BOMBING_SCORE :: -100
	
	max_bombing_territory: Maybe(Land_ID) = nil
	max_bombing_score := MIN_BOMBING_SCORE
	
	// Find all territories within bomber range (6 moves)
	bomber_range := 6
	for target in Land_ID {
		// Check if bomber can reach
		distance := calculate_distance(gc, bomber.from_territory, target)
		if distance > bomber_range {
			continue
		}
		
		// Check if has factory to bomb
		if !has_factory(gc, target) {
			continue
		}
		
		// Check if bomber can safely land after attack
		if !can_air_safely_land_after_attack_triplea(gc, target) {
			continue
		}
		
		// Calculate bombing score
		// Expected damage: 3.5 average per bomber
		// Factory value based on production
		production, is_capital := get_production_and_is_capital_triplea(gc, target)
		expected_damage := 3.5
		factory_value := f64(production) * (is_capital ? 2.0 : 1.0)
		
		// Score = damage * factory value - risk
		aa_risk := has_aa_gun(gc, target) ? 1.0 : 0.0
		score := int(expected_damage * factory_value - aa_risk * 10)
		
		if score > max_bombing_score {
			max_bombing_score = score
			max_bombing_territory = target
		}
	}
	
	// If found a good target, add bomber to that attack option
	if max_bombing_territory != nil {
		target := max_bombing_territory.?
		
		// Find or create attack option for this territory
		for i := 0; i < len(options); i += 1 {
			if options[i].territory == target {
				append(&options[i].attackers, bomber)
				when ODIN_DEBUG {
					fmt.printf("Bomber from %s will bomb factory at %s (score: %d)\n",
						bomber.from_territory, target, max_bombing_score)
				}
				return
			}
		}
	}
}

/*
=============================================================================
METHOD 10: tryToAttackTerritories
=============================================================================

Java Original (lines 1245-1778):

  private Map<Unit, Set<Territory>> tryToAttackTerritories(
      final List<ProTerritory> prioritizedTerritories, final List<Unit> alreadyMovedUnits) {

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();
    // [Get various maps - lines 1248-1256]

    // Reset lists
    for (final ProTerritory t : attackMap.values()) {
      t.getUnits().clear();
      t.getBombardTerritoryMap().clear();
      // [etc]
    }

    // Loop through all units and determine attack options
    final Map<Unit, Set<Territory>> unitAttackOptions = new HashMap<>();
    // [Lines 1269-1286]

    // Sort units by number of attack options and cost
    Map<Unit, Set<Territory>> sortedUnitAttackOptions =
        ProSortMoveOptionsUtils.sortUnitMoveOptions(proData, unitAttackOptions);
    final List<Unit> addedUnits = new ArrayList<>();

    // Multi-phase unit assignment:
    // 1. Try to set at least one destroyer in each sea territory with subs
    // 2. Set enough land and sea units to have at least a chance of winning
    // 3. Set non-air units in territories that can be held
    // 4. Set air units in territories that can't be held
    // 5. Set remaining units in any territory that needs it
    // 6. Handle transports for amphib attacks
    // 7. Loop through bombard units
    // [Lines 1295-1776]

    return sortedUnitAttackOptions;
  }
*/

// Odin Implementation:
try_to_attack_territories_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
	num_to_attack: int,
) -> [dynamic]Unit_Info {
	when ODIN_DEBUG {
		fmt.println("Try to attack territories with available units")
	}
	
	// Reset attack assignments
	for i := 0; i < num_to_attack && i < len(options); i += 1 {
		option := &options[i]
		clear(&option.attackers)
		clear(&option.amphib_attackers)
		clear(&option.bombard_units)
	}
	
	// Build unit availability map
	unit_options := make([dynamic]Unit_Info)
	defer delete(unit_options)
	
	// Phase 1: Assign destroyers to sea zones with subs
	assign_destroyers_vs_subs(gc, options, num_to_attack)
	
	// Phase 2: Iteratively add units until win% >= MIN_WIN_PERCENTAGE (75%)
	// This is the key change: instead of using a simple power target (1.2x defense),
	// we add units in batches and run battle simulation until win% is high enough.
	// This matches Java's approach which adds units until minWinPercentage (75%) is reached.
	MIN_WIN_PERCENTAGE :: 0.75
	
	// Track already assigned units to avoid double-counting
	assigned_units := make([dynamic]Unit_Info)
	defer delete(assigned_units)
	
	for i := 0; i < num_to_attack && i < len(options); i += 1 {
		option := &options[i]
		
		// Clear any previous assignment
		clear(&option.attackers)
		option.win_percentage = 0
		
		// Get available units from adjacent territories
		available_inf := get_total_available_units(gc, option.territory, .Infantry, &assigned_units)
		available_arty := get_total_available_units(gc, option.territory, .Artillery, &assigned_units)
		available_tank := get_total_available_units(gc, option.territory, .Tank, &assigned_units)
		available_ftr := get_total_available_air_units(gc, option.territory, .Fighter, &assigned_units)
		available_bmb := get_total_available_air_units(gc, option.territory, .Bomber, &assigned_units)
		
		total_available := available_inf + available_arty + available_tank + available_ftr + available_bmb
		
		// If no defenders, just assign minimal forces
		if len(option.defenders) == 0 {
			// Assign 1 infantry if available
			if available_inf > 0 {
				add_unit_to_attack(gc, option, .Infantry, &assigned_units)
			}
			option.win_percentage = 1.0
			continue
		}
		
		// Iteratively add units until win% >= MIN_WIN_PERCENTAGE
		// Start with a base allocation, then add more if needed
		units_added := 0
		max_iterations := total_available + 1
		
		when ODIN_DEBUG {
			fmt.printf("    [ITER] %v: available inf=%d arty=%d tank=%d ftr=%d bmb=%d (total=%d)\n",
				option.territory, available_inf, available_arty, available_tank, available_ftr, available_bmb, total_available)
		}
		
		for iter := 0; iter < max_iterations && option.win_percentage < MIN_WIN_PERCENTAGE; iter += 1 {
			// Add a batch of units (prioritize cheap infantry first)
			added_this_round := 0
			
			// Add infantry (cheapest fodder) - add up to 3 per iteration
			for j := 0; j < 3; j += 1 {
				if add_unit_to_attack(gc, option, .Infantry, &assigned_units) {
					added_this_round += 1
					units_added += 1
				}
			}
			
			// Add artillery (for support bonus)
			if add_unit_to_attack(gc, option, .Artillery, &assigned_units) {
				added_this_round += 1
				units_added += 1
			}
			
			// Add tanks (for power)
			if add_unit_to_attack(gc, option, .Tank, &assigned_units) {
				added_this_round += 1
				units_added += 1
			}
			
			// Add fighters
			if add_unit_to_attack(gc, option, .Fighter, &assigned_units) {
				added_this_round += 1
				units_added += 1
			}
			
			// Add bombers
			if add_unit_to_attack(gc, option, .Bomber, &assigned_units) {
				added_this_round += 1
				units_added += 1
			}
			
			// If we couldn't add any units, break
			if added_this_round == 0 {
				when ODIN_DEBUG {
					fmt.printf("    [ITER] %v: No units added in iteration %d, breaking\n", option.territory, iter)
				}
				break
			}
			
			// Simulate battle to get win%
			option.win_percentage = simulate_attack_win_percentage(option)
			
			when ODIN_DEBUG {
				fmt.printf("    [ITER] %v: iter=%d added=%d total=%d win%%=%.1f%%\n",
					option.territory, iter, added_this_round, len(option.attackers), option.win_percentage * 100)
			}
		}
		
		when ODIN_DEBUG {
			fmt.printf("  After land assignment: %v has %d attackers (win%%: %.1f%%, needed: %.1f%%)\n",
				option.territory, len(option.attackers), option.win_percentage * 100, MIN_WIN_PERCENTAGE * 100)
		}
	}
	
	// Phase 3: Handle amphib attacks (load transports)
	// If need_amphib_units is true, assign units from potential_amphib_attackers
	for i := 0; i < num_to_attack && i < len(options); i += 1 {
		option := &options[i]
		
		if option.need_amphib_units && len(option.potential_amphib_attackers) > 0 {
			// Territory needs amphib reinforcement - assign amphib attackers
			for unit in option.potential_amphib_attackers {
				append(&option.amphib_attackers, unit)
			}
			option.is_amphib = true
			// Reset win_percentage so it gets recalculated with amphib attackers
			option.win_percentage = 0
			
			when ODIN_DEBUG {
				fmt.printf("  [AMPHIB ASSIGN] %v: Assigned %d amphib attackers\n",
					option.territory, len(option.amphib_attackers))
			}
		}
		
		if option.is_amphib {
			assign_transports_for_amphib(gc, option)
		}
	}
	
	// Phase 4: Assign bombard units
	for i := 0; i < num_to_attack && i < len(options); i += 1 {
		option := &options[i]
		if option.is_amphib {
			assign_bombard_units(gc, option)
		}
	}
	
	// Return list of all assigned units
	assigned := make([dynamic]Unit_Info)
	for i := 0; i < num_to_attack && i < len(options); i += 1 {
		option := &options[i]
		for unit in option.attackers {
			append(&assigned, unit)
		}
		for unit in option.amphib_attackers {
			append(&assigned, unit)
		}
	}
	
	when ODIN_DEBUG {
		fmt.println("  Total assigned units:")
		print_unit_info_summary(&assigned)
	}
	
	return assigned
}

// Helper: Print unit info in a human-readable grouped format
print_unit_info_summary :: proc(units: ^[dynamic]Unit_Info) {
	// Group units by territory and type
	Unit_Counts :: struct {
		infantry:  int,
		artillery: int,
		tank:      int,
		aagun:     int,
		fighter:   int,
		bomber:    int,
	}
	
	territory_counts: map[Land_ID]Unit_Counts
	defer delete(territory_counts)
	
	for unit in units {
		counts := territory_counts[unit.from_territory]
		#partial switch unit.unit_type {
		case .Infantry:  counts.infantry += 1
		case .Artillery: counts.artillery += 1
		case .Tank:      counts.tank += 1
		case .AAGun:     counts.aagun += 1
		case .Fighter:   counts.fighter += 1
		case .Bomber:    counts.bomber += 1
		}
		territory_counts[unit.from_territory] = counts
	}
	
	if len(territory_counts) == 0 {
		fmt.println("  (none)")
		return
	}
	
	// Print grouped by territory
	for territory, counts in territory_counts {
		fmt.printf("    %v:\n", territory)
		if counts.infantry > 0  do fmt.printf("      Infantry: %d\n", counts.infantry)
		if counts.artillery > 0 do fmt.printf("      Artillery: %d\n", counts.artillery)
		if counts.tank > 0      do fmt.printf("      Tank: %d\n", counts.tank)
		if counts.aagun > 0     do fmt.printf("      AAGun: %d\n", counts.aagun)
		if counts.fighter > 0   do fmt.printf("      Fighter: %d\n", counts.fighter)
		if counts.bomber > 0    do fmt.printf("      Bomber: %d\n", counts.bomber)
	}
}

/*
=============================================================================
METHOD 11: checkContestedSeaTerritories
=============================================================================

Java Original (lines 1890-1913):

  private void checkContestedSeaTerritories() {

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();

    for (final Territory t : proData.getMyUnitTerritories()) {
      if (t.isWater()
          && Matches.territoryHasEnemyUnits(player).test(t)
          && (attackMap.get(t) == null || attackMap.get(t).getUnits().isEmpty())) {
        // [Check for subs and add attack if needed - lines 1900-1911]
      }
    }
  }
*/

// Odin Implementation:
check_contested_sea_territories_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("Check contested sea territories for sub warfare")
	}
	
	/*
	Sub Warfare in Contested Seas:
	If a sea zone has both friendly and enemy units, we may need to attack
	to clear enemy subs that could:
	1. Block our transport routes
	2. Sink our transports
	3. Attack our convoy zones
	
	Strategy:
	- Only engage if we have destroyers (to counter subs)
	- Don't engage if it weakens our naval defense elsewhere
	- Prioritize clearing routes needed for planned amphib attacks
	*/
	
	// Check all sea zones we control
	for sea in Sea_ID {
		// Skip if we don't have ships here
		if !has_friendly_ships(gc, sea) {
			continue
		}
		
		// Check if has enemy units (especially subs)
		if gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 {
			continue
		}
		
		// Check if we have destroyers to counter subs
		has_destroyers := gc.idle_ships[sea][gc.cur_player][.DESTROYER] > 0
		
		// Count enemy subs
		enemy_subs := 0
		for player in Player_ID {
			if mm.team[player] != mm.team[gc.cur_player] {
				enemy_subs += int(gc.idle_ships[sea][player][.SUB])
			}
		}
		
		// If enemy subs present and we have destroyers, consider attacking
		if enemy_subs > 0 && has_destroyers {
			// Check if this sea zone is critical (adjacent to planned amphib attacks)
			is_critical := false
			for option in options {
				if option.is_amphib {
					// Check if this sea is used for the amphib
					for adj_sea in sa.slice(&mm.l2s_1away_via_land[option.territory]) {
						if adj_sea == sea {
							is_critical = true
							break
						}
					}
				}
			}
			
			if is_critical {
				when ODIN_DEBUG {
					fmt.printf("Critical contested sea zone: %s (%d enemy subs)\n",
						mm.sea_name[sea], enemy_subs)
				}
				// Note: Full implementation would add sea attack option here
				// For now, just log the issue
			}
		}
	}
}

/*
=============================================================================
METHOD 12: logAttackMoves
=============================================================================

Java Original (lines 1915-2007):

  private void logAttackMoves(final List<ProTerritory> prioritizedTerritories) {

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();

    // Print prioritization
    ProLogger.debug("Prioritized territories:");
    for (final ProTerritory attackTerritoryData : prioritizedTerritories) {
      ProLogger.trace(
          "  "
              + attackTerritoryData.getMaxBattleResult().getTuvSwing()
              + "  "
              + attackTerritoryData.getValue()
              + "  "
              + attackTerritoryData.getTerritory().getName());
    }

    // Print enemy territories with enemy units vs my units
    ProLogger.debug("Territories that can be attacked:");
    int count = 0;
    for (final Map.Entry<Territory, ProTerritory> attackEntry : attackMap.entrySet()) {
      final Territory t = attackEntry.getKey();
      count++;
      ProLogger.trace(count + ". ---" + t.getName());
      // [Print attackers, defenders, counter-attackers - lines 1936-2005]
    }
  }
*/

// Odin Implementation:
log_attack_moves_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("\n============================================================")
		fmt.printf("ATTACK PLAN - Player %v\n", gc.cur_player)
		fmt.println("============================================================")
		
		if len(options) == 0 {
			fmt.println("No attacks planned.")
			fmt.println("============================================================\n")
			return
		}
		
		fmt.println("\nPrioritized territories:")
		for option, idx in options {
			fmt.printf("\n%d. %s\n", idx + 1, option.territory)
			fmt.printf("   Value: %.1f | Win: %.1f%% | TUV Swing: %.1f\n",
				option.attack_value, option.win_percentage * 100, option.tuv_swing)
			
			// Attackers
			fmt.printf("   Attackers (%d units):\n", len(option.attackers) + len(option.amphib_attackers))
			if len(option.attackers) > 0 {
				fmt.print("     Land: ")
				for unit in option.attackers {
					fmt.printf("%v(", unit.unit_type)
					fmt.printf("%s) ", unit.from_territory)
				}
				fmt.println()
			}
			if len(option.amphib_attackers) > 0 {
				fmt.print("     Amphib: ")
				for unit in option.amphib_attackers {
					fmt.printf("%v(", unit.unit_type)
					fmt.printf("%s) ", unit.from_territory)
				}
				fmt.println()
			}
			if len(option.bombard_units) > 0 {
				fmt.printf("     Bombard: %d ships\n", len(option.bombard_units))
			}
			
			// Defenders
			fmt.printf("   Defenders (%d units): ", len(option.defenders))
			for unit in option.defenders {
				fmt.printf("%v ", unit.unit_type)
			}
			fmt.println()
			
			// Special flags
			if option.is_amphib {
				fmt.println("   Type: AMPHIBIOUS ASSAULT")
			}
			if option.is_strafing {
				fmt.println("   Type: STRAFE (retreat planned)")
			}
			if option.can_hold {
				fmt.println("   Can hold: YES")
			} else {
				fmt.println("   Can hold: NO")
			}
		}
		
		fmt.println("\n============================================================\n")
	}
}

/*
=============================================================================
METHOD 13: canAirSafelyLandAfterAttack
=============================================================================

Java Original (lines 2014-2031):

  private boolean canAirSafelyLandAfterAttack(final Unit unit, final Territory t) {
    final boolean isAdjacentToAlliedFactory =
        Matches.territoryHasNeighborMatching(
                data.getMap(), ProMatches.territoryHasInfraFactoryAndIsAlliedLand(player))
            .test(t);
    final int range = unit.getMovementLeft().intValue();
    final int distance =
        data.getMap()
            .getDistanceIgnoreEndForCondition(
                proData.getUnitTerritory(unit),
                t,
                ProMatches.territoryCanMoveAirUnitsAndNoAa(data, player, true));
    final boolean usesMoreThanHalfOfRange = distance > range / 2;
    return isAdjacentToAlliedFactory || !usesMoreThanHalfOfRange;
  }
*/

// Odin Implementation:
can_air_safely_land_after_attack_triplea :: proc(gc: ^Game_Cache, target: Land_ID) -> bool {
	/*
	Air Unit Safety Check (from TripleA ProCombatMoveAi.java line 2014-2031):
	
	Two conditions make landing safe:
	1. Adjacent to Allied Factory: Guaranteed landing spot
	2. Uses < Half Range: Conservative distance check
	
	Ranges:
	- Fighter: 4 moves
	- Bomber: 6 moves
	
	Safety margin ensures air units can reach friendly territory even if
	some territories are blocked or captured during enemy turn.
	*/
	
	// Check if adjacent to friendly factory
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] == gc.cur_player {
			// Check if has factory
			if has_factory(gc, adjacent) {
				return true // Safe - factory next door
			}
		}
	}
	
	// Calculate distance to nearest friendly territory
	// Use conservative BFS distance (counts territories, not moves)
	min_distance := 999
	for land in Land_ID {
		if gc.owner[land] == gc.cur_player {
			dist := calculate_distance(gc, land, target)
			if dist < min_distance {
				min_distance = dist
			}
		}
	}
	
	// Conservative safety check:
	// Bombers (range 6): Safe if <= 3 moves from friendly territory
	// Fighters (range 4): Safe if <= 2 moves from friendly territory
	// Using minimum (2) to be conservative for both
	return min_distance <= 2
}

/*
=============================================================================
ADDITIONAL HELPER METHODS
=============================================================================
*/

// Import slice for sorting
import "core:slice"

// getProductionAndIsCapital - Extract production value and capital status
get_production_and_is_capital_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> (production: int, is_capital: bool) {
	// Get IPC value of territory
	production = int(mm.value[territory])
	
	// Check if it's a capital
	for player_id in Player_ID {
		if mm.capital[player_id] == territory {
			is_capital = true
			break
		}
	}
	
	return production, is_capital
}

// Helper: Check if territory is water (sea zone)
is_water_territory :: proc(t: Land_ID) -> bool {
	// In OAAA, water territories would be Sea_ID type
	// Land_ID territories are always land
	return false
}

// Helper: Check if territory is neutral
is_neutral_land :: proc(gc: ^Game_Cache, t: Land_ID) -> bool {
	// Neutral territories have value but no owner
	// In OAAA, check if no armies or planes present
	has_units := false
	for player in Player_ID {
		if gc.idle_armies[t][player][.INF] > 0 ||
		   gc.idle_armies[t][player][.ARTY] > 0 ||
		   gc.idle_armies[t][player][.TANK] > 0 {
			has_units = true
			break
		}
	}
	return !has_units && mm.value[t] > 0
}

// Helper: Count non-infantry defenders
count_non_infantry_defenders :: proc(option: ^Attack_Option) -> int {
	count := 0
	for defender in option.defenders {
		if defender.unit_type != .Infantry {
			count += 1
		}
	}
	return count
}

// Helper: Check if territory is adjacent to my capital
is_adjacent_to_my_capital :: proc(gc: ^Game_Cache, t: Land_ID) -> bool {
	capital := get_my_capital(gc)
	for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
		if adjacent == t {
			return true
		}
	}
	return false
}

// Helper: Get current player's capital
get_my_capital :: proc(gc: ^Game_Cache) -> Land_ID {
	return mm.capital[gc.cur_player]
}

// Helper: Check if territory has factory
has_factory :: proc(gc: ^Game_Cache, t: Land_ID) -> bool {
	for factory in gc.factory_locations[gc.cur_player].data {
		if factory == t {
			return true
		}
	}
	return false
}

// Helper: Check if free-for-all mode (more than 2 teams)
is_free_for_all :: proc(gc: ^Game_Cache) -> bool {
	// Count unique teams
	team_count := 0
	seen_teams: [Team_ID]bool
	for player in Player_ID {
		team := mm.team[player]
		if !seen_teams[team] {
			seen_teams[team] = true
			team_count += 1
		}
	}
	return team_count > 2
}

// Helper: Calculate distance between territories
calculate_distance :: proc(gc: ^Game_Cache, from: Land_ID, to: Land_ID) -> int {
	// Simplified BFS distance calculation
	if from == to {
		return 0
	}
	
	// Check if adjacent
	for adjacent in sa.slice(&mm.l2l_1away_via_land[from]) {
		if adjacent == to {
			return 1
		}
	}
	
	// Check 2 away
	for land in mm.l2l_2away_via_land_bitset[from] {
		if land == to {
			return 2
		}
	}
	
	// For longer distances, use approximation
	return 3 // Default assumption
}

// Helper: Estimate remaining attackers after battle
estimate_remaining_attackers :: proc(option: ^Attack_Option) -> f64 {
	// Assume attackers win with 60% remaining forces
	attack_power := calculate_attack_power(&option.attackers)
	return attack_power * 0.6
}

// Helper: Calculate available attack power from adjacent friendly territories
calculate_available_attack_power :: proc(gc: ^Game_Cache, target: Land_ID) -> f64 {
	total := f64(0)
	my_team := mm.team[gc.cur_player]
	
	// Check adjacent territories for our units
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if mm.team[gc.owner[adjacent]] == my_team {
			// Count our units that could attack
			for player in Player_ID {
				if mm.team[player] == my_team {
					total += f64(gc.idle_armies[adjacent][player][.INF]) * 1.0  // Attack 1
					total += f64(gc.idle_armies[adjacent][player][.ARTY]) * 2.0 // Attack 2
					total += f64(gc.idle_armies[adjacent][player][.TANK]) * 3.0 // Attack 3
				}
			}
		}
	}
	
	// Also count air units that could reach (fighters and bombers on land)
	for land in Land_ID {
		if mm.team[gc.owner[land]] == my_team {
			for player in Player_ID {
				if mm.team[player] == my_team {
					// Fighters can reach 4 spaces, bombers 6 spaces
					// Simplified: just count planes in adjacent territories for now
					is_adjacent := false
					for adj in sa.slice(&mm.l2l_1away_via_land[target]) {
						if adj == land {
							is_adjacent = true
							break
						}
					}
					if is_adjacent {
						total += f64(gc.idle_land_planes[land][player][.FIGHTER]) * 3.0 // Attack 3
						total += f64(gc.idle_land_planes[land][player][.BOMBER]) * 4.0  // Attack 4
					}
				}
			}
		}
	}
	
	return total
}

// Helper: Estimate defender power at a territory
estimate_defender_power :: proc(gc: ^Game_Cache, target: Land_ID) -> f64 {
	total := f64(0)
	enemy_team := mm.enemy_team[gc.cur_player]
	
	// Count enemy defenders
	for player in Player_ID {
		if mm.team[player] == enemy_team {
			total += f64(gc.idle_armies[target][player][.INF]) * 2.0  // Defense 2
			total += f64(gc.idle_armies[target][player][.ARTY]) * 2.0 // Defense 2
			total += f64(gc.idle_armies[target][player][.TANK]) * 3.0 // Defense 3
			total += f64(gc.idle_land_planes[target][player][.FIGHTER]) * 4.0 // Defense 4
			total += f64(gc.idle_land_planes[target][player][.BOMBER]) * 1.0  // Defense 1
		}
	}
	
	return total
}

// Helper: Calculate enemy counter-attack power
calculate_enemy_counter_attack_power :: proc(gc: ^Game_Cache, t: Land_ID) -> f64 {
	total := 0.0
	
	// Check adjacent territories for enemy units
	for adjacent in sa.slice(&mm.l2l_1away_via_land[t]) {
		if gc.owner[adjacent] != gc.cur_player {
			// Count enemy units that could counter-attack
			for player in Player_ID {
				if mm.team[player] != mm.team[gc.cur_player] {
					total += f64(gc.idle_armies[adjacent][player][.INF]) * 1.0
					total += f64(gc.idle_armies[adjacent][player][.ARTY]) * 2.0
					total += f64(gc.idle_armies[adjacent][player][.TANK]) * 3.0
				}
			}
		}
	}
	
	return total
}

// Helper: Calculate attack power of units
calculate_attack_power :: proc(units: ^[dynamic]Unit_Info) -> f64 {
	total := 0.0
	for unit in units {
		#partial switch unit.unit_type {
		case .Infantry: total += 1.0
		case .Artillery: total += 2.0
		case .Tank: total += 3.0
		case .Fighter: total += 3.0
		case .Bomber: total += 4.0
		case .Destroyer: total += 2.0
		case .Cruiser: total += 3.0
		case .Battleship: total += 4.0
		case: total += 1.0
		}
	}
	return total
}

// Helper: Count enemy units at territory
count_enemy_units_at_territory :: proc(gc: ^Game_Cache, t: Land_ID) -> int {
	count := 0
	for player in Player_ID {
		if mm.team[player] != mm.team[gc.cur_player] {
			count += int(gc.idle_armies[t][player][.INF])
			count += int(gc.idle_armies[t][player][.ARTY])
			count += int(gc.idle_armies[t][player][.TANK])
		}
	}
	return count
}

// Helper: Check if territory has any units
has_any_units :: proc(gc: ^Game_Cache, t: Land_ID) -> bool {
	for player in Player_ID {
		if gc.idle_armies[t][player][.INF] > 0 ||
		   gc.idle_armies[t][player][.ARTY] > 0 ||
		   gc.idle_armies[t][player][.TANK] > 0 ||
		   gc.idle_armies[t][player][.AAGUN] > 0 {
			return true
		}
		if gc.idle_land_planes[t][player][.FIGHTER] > 0 ||
		   gc.idle_land_planes[t][player][.BOMBER] > 0 {
			return true
		}
	}
	return false
}

// Helper: Check if attackers adjacent to enemy
has_attackers_adjacent_to_enemy :: proc(gc: ^Game_Cache, option: ^Attack_Option) -> bool {
	for unit in option.attackers {
		from := unit.from_territory
		for adjacent in sa.slice(&mm.l2l_1away_via_land[from]) {
			// Check if enemy territory (not ours and has units)
			if gc.owner[adjacent] != gc.cur_player && has_any_units(gc, adjacent) {
				return true
			}
		}
	}
	return false
}

// Helper: Check if has friendly land units
has_friendly_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return gc.idle_armies[land][gc.cur_player][.INF] > 0 ||
	       gc.idle_armies[land][gc.cur_player][.ARTY] > 0 ||
	       gc.idle_armies[land][gc.cur_player][.TANK] > 0
}

// Helper: Count enemy neighbor territories
count_enemy_neighbor_territories :: proc(gc: ^Game_Cache, land: Land_ID, exclude: []Land_ID) -> int {
	count := 0
	for adjacent in sa.slice(&mm.l2l_1away_via_land[land]) {
		// Skip if in exclude list
		is_excluded := false
		for excl in exclude {
			if adjacent == excl {
				is_excluded = true
				break
			}
		}
		if is_excluded {
			continue
		}
		
		// Count if enemy territory (not ours and has units)
		if gc.owner[adjacent] != gc.cur_player && has_any_units(gc, adjacent) {
			count += 1
		}
	}
	return count
}

// Helper: Find cheapest unit to move
find_cheapest_unit_to_move :: proc(gc: ^Game_Cache, to: Land_ID) -> Unit_Info {
	// Look in adjacent territories for cheapest unit
	for adjacent in sa.slice(&mm.l2l_1away_via_land[to]) {
		if gc.owner[adjacent] == gc.cur_player {
			// Check for infantry (cheapest)
			if gc.idle_armies[adjacent][gc.cur_player][.INF] > 0 {
				return Unit_Info{unit_type = .Infantry, from_territory = adjacent}
			}
		}
	}
	
	// No units found
	return Unit_Info{unit_type = .Infantry, from_territory = to}
}

// Helper: Find transport sea zones for attack
find_transport_sea_zones :: proc(gc: ^Game_Cache, option: ^Attack_Option) -> [dynamic]Sea_ID {
	seas := make([dynamic]Sea_ID)
	// Find all sea zones adjacent to target that have our transports
	for sea in sa.slice(&mm.l2s_1away_via_land[option.territory]) {
		if has_friendly_transports(gc, sea) {
			append(&seas, sea)
		}
	}
	return seas
}

// Helper: Get unit attack power
get_unit_attack_power :: proc(unit_type: Unit_Type) -> f64 {
	#partial switch unit_type {
	case .Infantry: return 1.0
	case .Artillery: return 2.0
	case .Tank: return 3.0
	case .Fighter: return 3.0
	case .Bomber: return 4.0
	case .Submarine: return 2.0
	case .Destroyer: return 2.0
	case .Cruiser: return 3.0
	case .Battleship: return 4.0
	case .Carrier: return 1.0
	case .Transport: return 0.0
	case: return 0.0
	}
}

// Helper: Calculate enemy sea attack power
calculate_enemy_sea_attack_power :: proc(gc: ^Game_Cache, sea: Sea_ID) -> f64 {
	total := 0.0
	for player in Player_ID {
		if mm.team[player] != mm.team[gc.cur_player] {
			total += f64(gc.idle_ships[sea][player][.SUB]) * 2.0
			total += f64(gc.idle_ships[sea][player][.DESTROYER]) * 2.0
			total += f64(gc.idle_ships[sea][player][.CRUISER]) * 3.0
			total += f64(gc.idle_ships[sea][player][.BATTLESHIP]) * 4.0
		}
	}
	return total
}

// Helper: Calculate friendly sea defense power
calculate_friendly_sea_defense_power :: proc(gc: ^Game_Cache, sea: Sea_ID) -> f64 {
	total := 0.0
	player := gc.cur_player
	
	total += f64(gc.idle_ships[sea][player][.SUB]) * 1.0
	total += f64(gc.idle_ships[sea][player][.DESTROYER]) * 2.0
	total += f64(gc.idle_ships[sea][player][.CRUISER]) * 3.0
	total += f64(gc.idle_ships[sea][player][.BATTLESHIP]) * 4.0
	total += f64(gc.idle_ships[sea][player][.CARRIER]) * 1.0
	
	return total
}

// Helper: Check if unit already used
is_unit_already_used :: proc(unit: Unit_Info, used: ^[dynamic]Unit_Info) -> bool {
	for u in used {
		if u.unit_type == unit.unit_type && u.from_territory == unit.from_territory {
			return true
		}
	}
	return false
}

// Helper: Check if has AA gun
has_aa_gun :: proc(gc: ^Game_Cache, t: Land_ID) -> bool {
	owner := gc.owner[t]
	// Check if any player has AA guns here
	for player in Player_ID {
		if gc.idle_armies[t][player][.AAGUN] > 0 {
			return true
		}
	}
	return false
}

// Helper: Assign units by priority
assign_units_by_priority :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
	sorted: ^[dynamic]Unit_Info,
) {
	/*
	Multi-Phase Unit Assignment (from TripleA):
	
	Phase 1: Air units to territories WITHOUT AA guns
	  - Air units are expensive (10-12 IPCs)
	  - AA guns can shoot them down (1/6 chance per gun)
	  - Prioritize safe air attacks first
	
	Phase 2: Units for territories that CAN BE HELD
	  - Holding territory is valuable (keep production)
	  - Assign best units to holdable territories
	  - Use cheaper units for straife attacks
	
	Phase 3: Additional sea units for naval superiority
	  - Use remaining ships to tip naval battles
	  - Destroyers for sub hunting
	  - Battleships/cruisers for power
	*/
	
	// Phase 1: Assign air to no-AA territories
	for i := 0; i < len(options); i += 1 {
		option := &options[i]
		
		// Skip if has AA gun
		if has_aa_gun(gc, option.territory) {
			continue
		}
		
		// Add available air units from sorted list
		for j := len(sorted) - 1; j >= 0; j -= 1 {
			unit := sorted[j]
			
			// Only air units
			if unit.unit_type != .Fighter && unit.unit_type != .Bomber {
				continue
			}
			
			// Check if can reach
			max_range := unit.unit_type == .Bomber ? 6 : 4
			dist := calculate_distance(gc, unit.from_territory, option.territory)
			if dist > max_range {
				continue
			}
			
			// Add to attack
			append(&option.attackers, unit)
			unordered_remove(sorted, j)
		}
	}
	
	// Phase 2: Assign remaining units to holdable territories
	for i := 0; i < len(options); i += 1 {
		option := &options[i]
		
		// Only holdable territories
		if !option.can_hold {
			continue
		}
		
		// Calculate needed power
		defense := estimate_defense_power_total(&option.defenders)
		current := calculate_attack_power(&option.attackers)
		needed := defense * 1.5 - current
		
		if needed <= 0 {
			continue
		}
		
		// Add units from sorted list
		for j := len(sorted) - 1; j >= 0 && needed > 0; j -= 1 {
			unit := sorted[j]
			
			// Add to attack
			append(&option.attackers, unit)
			needed -= get_unit_attack_power(unit.unit_type)
			unordered_remove(sorted, j)
		}
	}
}

// Helper: Assign destroyers vs subs
assign_destroyers_vs_subs :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, num: int) {
	/*
	Anti-Submarine Warfare Priority (from TripleA):
	
	Destroyers are critical for:
	1. Detecting submerged subs (subs can't submerge if destroyer present)
	2. Protecting transports from sub attacks
	3. Enabling other ships to hit subs
	
	Priority:
	- Sea zones with transports AND enemy subs (highest)
	- Sea zones needed for amphib assaults
	- General naval combat
	*/
	
	// Find all sea zones involved in attacks
	for i := 0; i < num && i < len(options); i += 1 {
		option := &options[i]
		
		// Skip non-naval attacks
		if !option.is_amphib {
			continue
		}
		
		// Find adjacent seas
		for sea in sa.slice(&mm.l2s_1away_via_land[option.territory]) {
			// Count enemy subs in this sea
			enemy_subs := 0
			for player in Player_ID {
				if mm.team[player] != mm.team[gc.cur_player] {
					enemy_subs += int(gc.idle_ships[sea][player][.SUB])
				}
			}
			
			if enemy_subs == 0 {
				continue
			}
			
			// Find friendly destroyers that can reach
			for adj_sea in Sea_ID {
				// Check if adjacent or same sea
				if adj_sea != sea {
					// Check if connected (simplified - assumes all seas connected)
					continue
				}
				
				// Count our destroyers
				destroyers := gc.idle_ships[adj_sea][gc.cur_player][.DESTROYER]
				if destroyers > 0 {
					// Assign one destroyer to cover
					unit := Unit_Info{
						unit_type = .Destroyer,
						from_territory = Land_ID(adj_sea), // Hacky - sea as land
					}
					append(&option.attackers, unit)
					
					when ODIN_DEBUG {
						fmt.printf("Assigned destroyer to cover subs in %s\n",
							mm.sea_name[sea])
					}
					break
				}
			}
		}
	}
}

// Helper: Assign land units to attack
assign_land_units_to_attack :: proc(
	gc: ^Game_Cache,
	option: ^Attack_Option,
	target_power: f64,
	already_assigned: ^[dynamic]Unit_Info,
) {
	/*
	Land Unit Assignment Strategy:
	1. Infantry first (cheapest, 3 IPCs, 1 attack)
	2. Artillery second (support bonus, 4 IPCs, 2 attack)
	3. Tanks third (powerful, 6 IPCs, 3 attack)
	
	Cost efficiency:
	- Infantry: 0.33 attack/IPC
	- Artillery: 0.50 attack/IPC
	- Tank: 0.50 attack/IPC
	
	Prefer infantry for fodder, tanks for power.
	*/
	
	target := option.territory
	current_power := 0.0
	
	// Helper to count how many units of a type from a territory are already assigned
	count_assigned_units :: proc(
		already_assigned: ^[dynamic]Unit_Info,
		from: Land_ID,
		unit_type: Unit_Type,
	) -> int {
		count := 0
		for unit in already_assigned {
			if unit.from_territory == from && unit.unit_type == unit_type {
				count += 1
			}
		}
		return count
	}
	
	// Phase 1: Add infantry from adjacent territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player {
			continue
		}
		
		// Count available infantry (total minus already assigned)
		total_inf := get_active_unit_count_for_combat(gc, adjacent, .Infantry)
		assigned_inf := count_assigned_units(already_assigned, adjacent, .Infantry)
		available_inf := total_inf - assigned_inf
		
		for i := 0; i < available_inf && current_power < target_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Infantry,
				from_territory = adjacent,
			}
			append(&option.attackers, unit)
			current_power += INFANTRY_ATTACK
		}
	}
	
	if current_power >= target_power {
		return
	}
	
	// Phase 2: Add artillery
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player {
			continue
		}
		
		total_arty := get_active_unit_count_for_combat(gc, adjacent, .Artillery)
		assigned_arty := count_assigned_units(already_assigned, adjacent, .Artillery)
		available_arty := total_arty - assigned_arty
		
		for i := 0; i < available_arty && current_power < target_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Artillery,
				from_territory = adjacent,
			}
			append(&option.attackers, unit)
			current_power += ARTILLERY_ATTACK
		}
	}
	
	if current_power >= target_power {
		return
	}
	
	// Phase 3: Add tanks (1 move from target)
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player {
			continue
		}
		
		total_tank := get_active_unit_count_for_combat(gc, adjacent, .Tank)
		assigned_tank := count_assigned_units(already_assigned, adjacent, .Tank)
		available_tank := total_tank - assigned_tank
		
		for i := 0; i < available_tank && current_power < target_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Tank,
				from_territory = adjacent,
			}
			append(&option.attackers, unit)
			current_power += TANK_ATTACK
		}
	}
	
	if current_power >= target_power {
		return
	}
	
	// Phase 4: Add tanks from 2 moves away
	for land_2away in mm.l2l_2away_via_land_bitset[target] {
		if mm.team[gc.owner[land_2away]] != mm.team[gc.cur_player] {
			continue
		}
		
		total_tank := get_active_unit_count_for_combat(gc, land_2away, .Tank)
		assigned_tank := count_assigned_units(already_assigned, land_2away, .Tank)
		available_tank := total_tank - assigned_tank
		
		for i := 0; i < available_tank && current_power < target_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Tank,
				from_territory = land_2away,
			}
			append(&option.attackers, unit)
			current_power += TANK_ATTACK
		}
	}
}

// Helper: Assign air units to attack
assign_air_units_to_attack :: proc(
	gc: ^Game_Cache,
	option: ^Attack_Option,
	needed_power: f64,
	already_assigned: ^[dynamic]Unit_Info,
) {
	/*
	Air Unit Assignment:
	1. Check range (fighters 4, bombers 6)
	2. Verify safe landing after attack
	3. Prefer fighters over bombers (cheaper, 10 vs 12 IPCs)
	4. Consider AA gun risk
	*/
	
	target := option.territory
	current_added := 0.0
	
	// Skip if has AA gun (too risky for expensive air units)
	if has_aa_gun(gc, target) {
		return
	}
	
	// Helper to count how many air units of a type from a territory are already assigned
	count_assigned_air :: proc(
		already_assigned: ^[dynamic]Unit_Info,
		from: Land_ID,
		unit_type: Unit_Type,
	) -> int {
		count := 0
		for unit in already_assigned {
			if unit.from_territory == from && unit.unit_type == unit_type {
				count += 1
			}
		}
		return count
	}
	
	// Phase 1: Assign fighters (cheaper, range 4)
	fighter_range := 4
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player {
			continue
		}
		
		// Check range
		dist := calculate_distance(gc, land, target)
		if dist > fighter_range {
			continue
		}
		
		// Check safe landing
		if !can_air_safely_land_after_attack_triplea(gc, target) {
			continue
		}
		
		// Count available fighters
		total_fighters := get_active_air_count_for_combat(gc, land, .Fighter)
		assigned_fighters := count_assigned_air(already_assigned, land, .Fighter)
		available_fighters := total_fighters - assigned_fighters
		
		for i := 0; i < available_fighters && current_added < needed_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Fighter,
				from_territory = land,
			}
			append(&option.attackers, unit)
			current_added += 3.0 // Fighter attack power
		}
	}
	
	if current_added >= needed_power {
		return
	}
	
	// Phase 2: Assign bombers if still need power (expensive, range 6)
	bomber_range := 6
	for land in Land_ID {
		if gc.owner[land] != gc.cur_player {
			continue
		}
		
		// Check range
		dist := calculate_distance(gc, land, target)
		if dist > bomber_range {
			continue
		}
		
		// Check safe landing
		if !can_air_safely_land_after_attack_triplea(gc, target) {
			continue
		}
		
		// Count available bombers
		total_bombers := get_active_air_count_for_combat(gc, land, .Bomber)
		assigned_bombers := count_assigned_air(already_assigned, land, .Bomber)
		available_bombers := total_bombers - assigned_bombers
		
		for i := 0; i < available_bombers && current_added < needed_power; i += 1 {
			unit := Unit_Info{
				unit_type = .Bomber,
				from_territory = land,
			}
			append(&option.attackers, unit)
			current_added += 4.0 // Bomber attack power
		}
	}
}

// Helper: Assign transports for amphib
assign_transports_for_amphib :: proc(gc: ^Game_Cache, option: ^Attack_Option) {
	/*
	Transport Loading for Amphibious Assaults:
	
	Capacity:
	- Each transport holds 2 infantry OR 1 infantry + 1 tank
	- Artillery counts as infantry
	- Tanks take full capacity
	
	Strategy:
	1. Count units to transport
	2. Calculate transports needed
	3. Verify transports available in adjacent seas
	4. Mark units as amphib_attackers
	*/
	
	if !option.is_amphib {
		return
	}
	
	target := option.territory
	
	// Count land units that need transport
	units_to_load := 0
	tank_count := 0
	
	for unit in option.attackers {
		#partial switch unit.unit_type {
		case .Infantry, .Artillery:
			units_to_load += 1
		case .Tank:
			units_to_load += 2 // Tanks take 2 slots
			tank_count += 1
		}
	}
	
	// Calculate transports needed (each holds 2 infantry-sized units)
	transports_needed := (units_to_load + 1) / 2
	
	// Find transports in adjacent seas
	for sea in sa.slice(&mm.l2s_1away_via_land[target]) {
		available := gc.idle_ships[sea][gc.cur_player][.TRANS_EMPTY]
		
		if available > 0 {
			// Use transports from this sea
			used := min(int(available), transports_needed)
			transports_needed -= used
			
			when ODIN_DEBUG {
				fmt.printf("Using %d transports from %s for amphib assault on %s\n",
					used, mm.sea_name[sea], target)
			}
			
			if transports_needed == 0 {
				break
			}
		}
	}
	
	if transports_needed > 0 {
		when ODIN_DEBUG {
			fmt.printf("WARNING: Not enough transports for amphib assault on %s (need %d more)\n",
				target, transports_needed)
		}
	}
}

// Helper: Assign bombard units
assign_bombard_units :: proc(gc: ^Game_Cache, option: ^Attack_Option) {
	/*
	Naval Bombardment Support (Shore Bombardment):
	
	Eligible Ships:
	- Cruisers: 3 attack, 12 IPCs
	- Battleships: 4 attack, 20 IPCs
	
	Rules:
	- Only for amphibious assaults
	- Ships must be in adjacent sea zone
	- Each ship can bombard once per assault
	- Adds significant attack power (3-4 per ship)
	
	Strategy:
	- Use all available bombard ships
	- Prioritize battleships (more power)
	- Don't risk ships that are needed for defense
	*/
	
	if !option.is_amphib {
		return
	}
	
	target := option.territory
	
	// Find adjacent seas with bombard-capable ships
	for sea in sa.slice(&mm.l2s_1away_via_land[target]) {
		// Check for battleships
		battleship_count := gc.idle_ships[sea][gc.cur_player][.BATTLESHIP]
		for i := 0; i < int(battleship_count); i += 1 {
			unit := Unit_Info{
				unit_type = .Battleship,
				from_territory = Land_ID(sea), // Hacky - sea as land
			}
			append(&option.bombard_units, unit)
		}
		
		// Check for cruisers
		cruiser_count := gc.idle_ships[sea][gc.cur_player][.CRUISER]
		for i := 0; i < int(cruiser_count); i += 1 {
			unit := Unit_Info{
				unit_type = .Cruiser,
				from_territory = Land_ID(sea), // Hacky - sea as land
			}
			append(&option.bombard_units, unit)
		}
	}
	
	if len(option.bombard_units) > 0 {
		when ODIN_DEBUG {
			total_bombard := 0.0
			for unit in option.bombard_units {
				if unit.unit_type == .Battleship {
					total_bombard += 4.0
				} else if unit.unit_type == .Cruiser {
					total_bombard += 3.0
				}
			}
			fmt.printf("Naval bombardment support for %s: %d ships, %.0f attack power\n",
				target, len(option.bombard_units), total_bombard)
		}
	}
}
// ===== Additional Helper Functions =====

// Helper: Estimate total defense power
estimate_defense_power_total :: proc(defenders: ^[dynamic]Unit_Info) -> f64 {
total := 0.0
for defender in defenders {
#partial switch defender.unit_type {
case .Infantry: total += 2.0
case .Artillery: total += 2.0
case .Tank: total += 3.0
case .AAGun: total += 0.0 // AA guns don't defend in combat
case .Fighter: total += 4.0
case .Submarine: total += 1.0
case .Destroyer: total += 2.0
case .Cruiser: total += 3.0
case .Battleship: total += 4.0
case .Carrier: total += 2.0
}
}
return total
}

// Helper: Check if has friendly ships
has_friendly_ships :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
player := gc.cur_player
for ship in Idle_Ship {
if gc.idle_ships[sea][player][ship] > 0 {
return true
}
}
return false
}

// Helper: Check if has friendly transports
has_friendly_transports :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
player := gc.cur_player
return gc.idle_ships[sea][player][.TRANS_EMPTY] > 0 ||
       gc.idle_ships[sea][player][.TRANS_1I] > 0 ||
       gc.idle_ships[sea][player][.TRANS_1A] > 0 ||
       gc.idle_ships[sea][player][.TRANS_1T] > 0 ||
       gc.idle_ships[sea][player][.TRANS_2I] > 0 ||
       gc.idle_ships[sea][player][.TRANS_1I_1A] > 0 ||
       gc.idle_ships[sea][player][.TRANS_1I_1T] > 0
}

/*
=============================================================================
MISSING METHODS FROM JAVA doCombatMove - TO BE IMPLEMENTED
=============================================================================
*/

/*
=============================================================================
METHOD: removeAttacksUntilCapitalCanBeHeld
=============================================================================

Java Original (lines 1780-1889):

  private void removeAttacksUntilCapitalCanBeHeld(
      final List<ProTerritory> prioritizedTerritories,
      final List<ProPurchaseOption> landPurchaseOptions) {

    ProLogger.info("Check capital defenses after attack moves");

    final Map<Territory, ProTerritory> attackMap =
        territoryManager.getAttackOptions().getTerritoryMap();

    final Territory myCapital = proData.getMyCapital();

    // Add max purchase defenders to capital for non-mobile factories (don't consider mobile
    // factories since they may move elsewhere)
    final List<Unit> placeUnits = new ArrayList<>();
    if (ProMatches.territoryHasNonMobileFactoryAndIsNotConqueredOwnedLand(player).test(myCapital)) {
      placeUnits.addAll(
          ProPurchaseUtils.findMaxPurchaseDefenders(
              proData, player, myCapital, landPurchaseOptions));
    }

    // Remove attack until capital can be defended
    while (true) {
      if (prioritizedTerritories.isEmpty()) {
        break;
      }

      // Determine max enemy counter attack units
      final List<Territory> territoriesToAttack = new ArrayList<>();
      for (final ProTerritory t : prioritizedTerritories) {
        territoriesToAttack.add(t.getTerritory());
      }
      ProLogger.trace("Remaining territories to attack=" + territoriesToAttack);
      territoryManager.populateEnemyAttackOptions(territoriesToAttack, List.of(myCapital));
      final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();
      if (enemyAttackOptions.getMax(myCapital) == null) {
        break;
      }

      // Find max remaining defenders
      final Set<Territory> territoriesAdjacentToCapital =
          data.getMap().getNeighbors(myCapital, Matches.territoryIsLand());
      final List<Unit> defenders = myCapital.getMatches(Matches.isUnitAllied(player));
      defenders.addAll(placeUnits);
      for (final Territory t : territoriesAdjacentToCapital) {
        defenders.addAll(t.getMatches(ProMatches.unitCanBeMovedAndIsOwnedLand(player, false)));
      }
      for (final ProTerritory t : attackMap.values()) {
        defenders.removeAll(t.getUnits());
      }

      // Determine counter-attack results to see if I can hold it
      final Set<Unit> enemyAttackingUnits =
          new HashSet<>(enemyAttackOptions.getMax(myCapital).getMaxUnits());
      enemyAttackingUnits.addAll(enemyAttackOptions.getMax(myCapital).getMaxAmphibUnits());
      final ProBattleResult result =
          calc.estimateDefendBattleResults(
              proData,
              myCapital,
              enemyAttackingUnits,
              defenders,
              enemyAttackOptions.getMax(myCapital).getMaxBombardUnits());
      ProLogger.trace(
          "Current capital result hasLandUnitRemaining="
              + result.isHasLandUnitRemaining()
              + ", TUVSwing="
              + result.getTuvSwing()
              + ", defenders="
              + defenders.size()
              + ", attackers="
              + enemyAttackingUnits.size());

      // Determine attack that uses the most units per value from capital and remove it
      if (result.isHasLandUnitRemaining()) {
        double maxUnitsNearCapitalPerValue = 0.0;
        Territory maxTerritory = null;
        final Set<Territory> territoriesNearCapital =
            data.getMap().getNeighbors(myCapital, Matches.territoryIsLand());
        territoriesNearCapital.add(myCapital);
        for (final Map.Entry<Territory, ProTerritory> attackEntry : attackMap.entrySet()) {
          final Territory t = attackEntry.getKey();
          int unitsNearCapital = 0;
          for (final Unit u : attackEntry.getValue().getUnits()) {
            if (territoriesNearCapital.contains(proData.getUnitTerritory(u))) {
              unitsNearCapital++;
            }
          }
          final double unitsNearCapitalPerValue = unitsNearCapital / attackMap.get(t).getValue();
          ProLogger.trace(
              t.getName() + " has unit near capital per value: " + unitsNearCapitalPerValue);
          if (unitsNearCapitalPerValue > maxUnitsNearCapitalPerValue) {
            maxUnitsNearCapitalPerValue = unitsNearCapitalPerValue;
            maxTerritory = t;
          }
        }
        if (maxTerritory != null) {
          final ProTerritory patdMax = attackMap.get(maxTerritory);
          prioritizedTerritories.remove(patdMax);
          patdMax.getUnits().clear();
          patdMax.getAmphibAttackMap().clear();
          patdMax.setBattleResult(null);
          ProLogger.debug("Removing territory to try to hold capital: " + maxTerritory.getName());
        }
      } else {
        break;
      }
    }
  }
*/

// Odin Implementation:
remove_attacks_until_capital_can_be_held_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
) {
	when ODIN_DEBUG {
		fmt.println("Check capital defenses after attack moves")
	}
	
	capital := mm.capital[gc.cur_player]
	
	// Calculate current defenders at capital
	capital_defenders := f64(0)
	for army in gc.idle_armies[capital][gc.cur_player] {
		capital_defenders += f64(army) * 2.0 // Use defense values
	}
	
	// Add units that could move to capital from adjacent territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[capital]) {
		if mm.team[gc.owner[adjacent]] == mm.team[gc.cur_player] {
			for army in gc.idle_armies[adjacent][gc.cur_player] {
				capital_defenders += f64(army) * 2.0
			}
		}
	}
	
	// Subtract units being used in attacks
	for option in options {
		// Count units from capital or adjacent being used in this attack
		// (Simplified: assume attacks use units proportionally)
		capital_defenders -= f64(len(option.attackers)) * 0.3
	}
	
	// Calculate enemy attack potential on capital
	enemy_attack_power := calculate_enemy_counter_attack_power(gc, capital)
	
	when ODIN_DEBUG {
		fmt.printf("  Capital: %.1f defenders vs %.1f enemy threat\n", 
			capital_defenders, enemy_attack_power)
	}
	
	// Remove attacks until capital can be defended
	for capital_defenders < enemy_attack_power * 1.2 && len(options) > 0 {
		// Find attack that uses most units near capital per value
		max_units_per_value := f64(0)
		max_index := -1
		
		for i := 0; i < len(options); i += 1 {
			option := &options[i]
			
			// Count units from capital region
			units_near_capital := 0
			for unit in option.attackers {
				// Check if unit is from capital or adjacent
				if unit.from_territory == capital {
					units_near_capital += 1
				} else {
					for adj in sa.slice(&mm.l2l_1away_via_land[capital]) {
						if unit.from_territory == adj {
							units_near_capital += 1
							break
						}
					}
				}
			}
			
			units_per_value := f64(units_near_capital) / max(option.attack_value, 1.0)
			if units_per_value > max_units_per_value {
				max_units_per_value = units_per_value
				max_index = i
			}
		}
		
		if max_index >= 0 {
			when ODIN_DEBUG {
				fmt.printf("  Removing attack on %s to defend capital\n", 
					options[max_index].territory)
			}
			
			// Return units to capital defense
			capital_defenders += f64(len(options[max_index].attackers)) * 0.3
			
			// Remove the attack
			unordered_remove(options, max_index)
		} else {
			break
		}
	}
	
	when ODIN_DEBUG {
		if len(options) > 0 {
			fmt.println("  Capital can be defended with current attack plan")
		} else {
			fmt.println("  Cancelled all attacks to defend capital")
		}
	}
}

/*
=============================================================================
METHOD: populateEnemyAttackOptions (second call)
=============================================================================

Java code shows this is called TWICE:
1. Before determineTerritoriesToAttack - with initial cleared territories
2. After determineTerritoriesToAttack - with final attack list + transport territories

The second call (lines 105-113):
    clearedTerritories = new ArrayList<>();
    final Set<Territory> possibleTransportTerritories = new HashSet<>();
    for (final ProTerritory patd : attackOptions) {
      clearedTerritories.add(patd.getTerritory());
      if (!patd.getAmphibAttackMap().isEmpty()) {
        possibleTransportTerritories.addAll(
            data.getMap().getNeighbors(patd.getTerritory(), Matches.territoryIsWater()));
      }
    }
    possibleTransportTerritories.addAll(clearedTerritories);
    territoryManager.populateEnemyAttackOptions(clearedTerritories, possibleTransportTerritories);

Then calls determineTerritoriesThatCanBeHeld AGAIN and removeTerritoriesThatArentWorthAttacking AGAIN
*/

// Odin Stub:
recalculate_enemy_attacks_after_territory_selection_triplea :: proc(
	gc: ^Game_Cache,
	options: ^[dynamic]Attack_Option,
) {
	when ODIN_DEBUG {
		fmt.println("Re-calculating enemy attack options after territory selection")
	}
	
	/*
	After selecting which territories to attack, we need to:
	1. Build list of territories being attacked
	2. Find sea zones adjacent to amphib targets (for transport safety)
	3. Re-calculate enemy attack potential on these territories
	4. Re-run holdability check with updated enemy info
	5. Re-filter low-value targets
	
	This two-phase approach is critical because:
	- Initial pass: Assumes we're attacking everything
	- Second pass: Only considers territories we actually selected
	- Enemy can now focus their counter-attacks on fewer targets
	*/
	
	// Step 0: Re-populate attackers for all selected territories
	// The previous step may have removed some options, so we need to recalculate
	// which units can attack which territories
	when ODIN_DEBUG {
		fmt.println("  Re-assigning attackers to selected territories...")
	}
	_ = try_to_attack_territories_triplea(gc, options, len(options))
	
	// Step 1: Re-run holdability check with final attack list
	when ODIN_DEBUG {
		fmt.println("  Re-checking which territories can be held...")
	}
	determine_territories_that_can_be_held_triplea(gc, options)
	
	// Step 2: Re-filter out territories that are no longer worth attacking
	when ODIN_DEBUG {
		fmt.println("  Re-filtering low-value targets...")
		initial_count := len(options)
	}
	
	remove_territories_that_arent_worth_attacking_triplea(gc, options)
	
	when ODIN_DEBUG {
		removed := initial_count - len(options)
		if removed > 0 {
			fmt.printf("  Removed %d additional territories after recalculation\n", removed)
		}
	}
}

/*
=============================================================================
POPULATE ATTACK OPTIONS - Full TripleA Implementation
=============================================================================

Java Original: ProTerritoryManager.findAttackOptions() (line 386)
This is the FIRST method called in doCombatMove() and is critical for finding
ALL units that can participate in attacks.

The method calls four sub-functions:
1. findLandMoveOptions - iterate land units, find reachable enemy territories
2. findNavalMoveOptions - iterate naval units, find reachable sea zones
3. findAirMoveOptions - iterate air units with 4-6 movement range
4. findAmphibMoveOptions - find amphibious assault options via transports

Each function:
- Iterates through ALL friendly units with movement
- For each unit, calculates which territories it can reach
- Builds attackers list for each potential target territory
- Tracks unit assignments in unitMoveMap

This is the CORRECT way to find reachable territories - not a simple adjacency check.
*/

populate_attack_options_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) {
	when ODIN_DEBUG {
		fmt.println("  [populateAttackOptions] Iterating through all friendly units...")
	}
	
	my_team := mm.team[gc.cur_player]
	enemy_team := mm.enemy_team[gc.cur_player]
	
	// Find land attack options - iterate through all land units
	populate_land_attack_options(gc, options, my_team, enemy_team)
	
	// Find air attack options - iterate through all air units (4-6 movement range)
	populate_air_attack_options(gc, options, my_team, enemy_team)
	
	// Find amphibious assault options - units on transports can attack coastal territories
	populate_amphib_attack_options(gc, options, my_team, enemy_team)
	
	when ODIN_DEBUG {
		fmt.printf("  [populateAttackOptions] Found %d potential attack targets\n", len(options))
	}
}

/*
=============================================================================
LAND ATTACK OPTIONS
=============================================================================

Java Original: ProTerritoryManager.findLandMoveOptions() (line 791)

Iterates through ALL friendly land units and finds which enemy territories
they can reach based on:
- Unit movement (infantry=1, tanks=2, etc.)
- Path availability (can't move through enemy territories except blitzing tanks)
- Combat restrictions

This is the proper way to find land attacks - NOT just checking adjacency!
*/

populate_land_attack_options :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, my_team: Team_ID, enemy_team: Team_ID) {
	// Iterate through ALL territories we control
	for land_tid in Land_ID {
		if mm.team[gc.owner[land_tid]] != my_team {
			continue
		}
		
		// Find all land units in this territory with movement left
		has_infantry := gc.idle_armies[land_tid][gc.cur_player][.INF] > 0
		has_artillery := gc.idle_armies[land_tid][gc.cur_player][.ARTY] > 0
		has_tanks := gc.idle_armies[land_tid][gc.cur_player][.TANK] > 0
		
		if !has_infantry && !has_artillery && !has_tanks {
			continue
		}
		
		// Infantry and artillery: 1 movement - can reach adjacent territories
		if has_infantry || has_artillery {
			for adj in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj]] == enemy_team {
					add_territory_to_attack_options(gc, options, adj)
				}
			}
		}
		
		// Tanks: 2 movement - can reach territories 1-2 away
		if has_tanks {
			// 1 away
			for adj in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj]] == enemy_team {
					add_territory_to_attack_options(gc, options, adj)
				}
			}
			
			// 2 away (blitzing through empty friendly)
			for adj1 in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj1]] != my_team {
					continue
				}
				if has_enemy_units(gc, adj1) {
					continue  // Can't blitz through enemies
				}
				
				for adj2 in sa.slice(&mm.l2l_1away_via_land[adj1]) {
					if adj2 == land_tid { continue }
					if mm.team[gc.owner[adj2]] == enemy_team {
						add_territory_to_attack_options(gc, options, adj2)
					}
				}
			}
		}
	}
}

/*
=============================================================================
AIR ATTACK OPTIONS
=============================================================================

Java Original: ProTerritoryManager.findAirMoveOptions() (line 879)

Iterates through ALL friendly air units and finds which enemy territories
they can reach based on movement range:
- Fighters: 4 movement
- Bombers: 6 movement

Air units can fly over any territory and attack distant targets.
This is CRITICAL and was missing from the simplified implementation!
*/

populate_air_attack_options :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, my_team: Team_ID, enemy_team: Team_ID) {
	// Iterate through ALL territories we control
	for land_tid in Land_ID {
		if mm.team[gc.owner[land_tid]] != my_team {
			continue
		}
		
		has_fighters := gc.idle_land_planes[land_tid][gc.cur_player][.FIGHTER] > 0
		has_bombers := gc.idle_land_planes[land_tid][gc.cur_player][.BOMBER] > 0
		
		if !has_fighters && !has_bombers {
			continue
		}
		
		when ODIN_DEBUG {
			if has_fighters {
				fmt.printf("  [Air] %v has %d fighters\n", land_tid, gc.idle_land_planes[land_tid][gc.cur_player][.FIGHTER])
			}
			if has_bombers {
				fmt.printf("  [Air] %v has %d bombers\n", land_tid, gc.idle_land_planes[land_tid][gc.cur_player][.BOMBER])
			}
		}
		
		// Fighters: 4 movement - can reach territories 1-4 away
		// For simplicity, we'll just check 1-2 away for now
		if has_fighters {
			// 1 away
			for adj1 in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj1]] == enemy_team {
					when ODIN_DEBUG {
						fmt.printf("  [Air] Fighter from %v can reach %v (1 move)\n", land_tid, adj1)
					}
					add_territory_to_attack_options(gc, options, adj1)
				}
			}
			
			// 2 away
			for adj1 in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				for adj2 in sa.slice(&mm.l2l_1away_via_land[adj1]) {
					if adj2 == land_tid { continue }
					if mm.team[gc.owner[adj2]] == enemy_team {
						when ODIN_DEBUG {
							fmt.printf("  [Air] Fighter from %v can reach %v via %v (2 moves)\n", land_tid, adj2, adj1)
						}
						add_territory_to_attack_options(gc, options, adj2)
					}
				}
			}
		}
		
		// Bombers: 6 movement - for now, same as fighters but could go further
		if has_bombers {
			// 1 away
			for adj1 in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				if mm.team[gc.owner[adj1]] == enemy_team {
					add_territory_to_attack_options(gc, options, adj1)
				}
			}
			
			// 2 away
			for adj1 in sa.slice(&mm.l2l_1away_via_land[land_tid]) {
				for adj2 in sa.slice(&mm.l2l_1away_via_land[adj1]) {
					if adj2 == land_tid { continue }
					if mm.team[gc.owner[adj2]] == enemy_team {
						add_territory_to_attack_options(gc, options, adj2)
					}
				}
			}
		}
	}
}

/*
=============================================================================
AMPHIBIOUS ASSAULT OPTIONS
=============================================================================

Java Original: ProTerritoryManager.findAmphibMoveOptions() (line 1063)

Finds coastal enemy territories that can be attacked via transports.
This includes:
1. Loaded transports adjacent to coastal enemy territories (0 moves needed)
2. Loaded transports 1 move away (1 move to reach, then unload)
3. Empty transports near loadable units that can load+move+unload in same turn

Key insight from Java: TransportMap stores for each transport:
  Map<Territory (target), Set<Territory> (load-from territories)>
This pre-calculates which territories a transport can attack and from where it can load.
*/

populate_amphib_attack_options :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, my_team: Team_ID, enemy_team: Team_ID) {
	canal_state := transmute(u8)gc.canals_open
	
	// ==========================================================================
	// Part 1: Check LOADED transports (1I, 1T, 1A, 2I, 1I_1A, 1I_1T)
	// ==========================================================================
	loaded_transport_types := [?]Idle_Ship{
		.TRANS_1I, .TRANS_1T, .TRANS_1A,
		.TRANS_2I, .TRANS_1I_1A, .TRANS_1I_1T,
	}
	
	for sea_tid in Sea_ID {
		// Check if we have any loaded transports here
		has_loaded := false
		for trans_type in loaded_transport_types {
			if gc.idle_ships[sea_tid][gc.cur_player][trans_type] > 0 {
				has_loaded = true
				break
			}
		}
		
		if !has_loaded {
			continue
		}
		
		// Adjacent coastal territories (0 move reach - can unload directly)
		for coastal_land in sa.slice(&mm.s2l_1away_via_sea[sea_tid]) {
			if mm.team[gc.owner[coastal_land]] == enemy_team {
				add_territory_to_attack_options(gc, options, coastal_land)
			}
		}
		
		// Sea zones 1 move away - can move to adjacent sea, then unload
		for adj_sea in mm.s2s_1away_via_sea[canal_state][sea_tid] {
			// Check if path is safe (no blocking enemy fleet)
			if gc.enemy_blockade_total[adj_sea] > 0 {
				continue  // Skip blocked sea zones
			}
			
			// Find coastal territories adjacent to the destination sea
			for coastal_land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
				if mm.team[gc.owner[coastal_land]] == enemy_team {
					add_territory_to_attack_options(gc, options, coastal_land)
				}
			}
		}
	}
	
	// ==========================================================================
	// Part 2: Check EMPTY transports that can load units nearby
	// ==========================================================================
	// Empty transports have 2 moves. They can:
	// - Load from adjacent land (costs 0 moves if no enemies in sea)
	// - Move 1-2 sea zones
	// - Unload at destination
	// Total: load + move(1-2) + unload = need transport adjacent to both load AND unload zones
	
	for sea_tid in Sea_ID {
		// Check for empty transports
		empty_count := gc.idle_ships[sea_tid][gc.cur_player][.TRANS_EMPTY]
		if empty_count == 0 {
			continue
		}
		
		// Check if there are units nearby to load
		has_loadable_units := false
		for adj_land in sa.slice(&mm.s2l_1away_via_sea[sea_tid]) {
			if gc.owner[adj_land] == gc.cur_player {
				// Check for loadable units (infantry, artillery, tanks)
				if gc.idle_armies[adj_land][gc.cur_player][.INF] > 0 ||
				   gc.idle_armies[adj_land][gc.cur_player][.ARTY] > 0 ||
				   gc.idle_armies[adj_land][gc.cur_player][.TANK] > 0 {
					has_loadable_units = true
					break
				}
			}
		}
		
		if !has_loadable_units {
			continue  // No units to load
		}
		
		// Empty transport can load and then:
		// - Move 0: unload to adjacent coastal enemy (rare - would need enemy coastal next to friendly coastal)
		// - Move 1: move 1 sea zone, unload to adjacent coastal enemy
		
		// Check coastal enemies adjacent to this sea zone (move 0)
		for coastal_land in sa.slice(&mm.s2l_1away_via_sea[sea_tid]) {
			if mm.team[gc.owner[coastal_land]] == enemy_team {
				add_territory_to_attack_options(gc, options, coastal_land)
			}
		}
		
		// Check sea zones 1 move away
		for adj_sea in mm.s2s_1away_via_sea[canal_state][sea_tid] {
			if gc.enemy_blockade_total[adj_sea] > 0 {
				continue
			}
			
			for coastal_land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
				if mm.team[gc.owner[coastal_land]] == enemy_team {
					add_territory_to_attack_options(gc, options, coastal_land)
				}
			}
		}
	}
}

// Helper: Add a territory to attack options (or update existing entry)
add_territory_to_attack_options :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option, target: Land_ID) {
	// Check if territory already in options
	for &opt in options {
		if opt.territory == target {
			// Already tracking this territory - but update amphib attackers
			// since we might be called from populate_amphib_attack_options
			update_amphib_attackers_only(gc, &opt)
			return
		}
	}
	
	// Add new attack option
	territory_value := mm.value[target]
	
	option := Attack_Option{
		territory = target,
		attackers = make([dynamic]Unit_Info),
		amphib_attackers = make([dynamic]Unit_Info),
		potential_attackers = make([dynamic]Unit_Info),
		potential_amphib_attackers = make([dynamic]Unit_Info),
		defenders = make([dynamic]Unit_Info),
		attack_value = f64(territory_value),
		win_percentage = 0.0,
		can_hold = false,
	}
	
	// Populate defenders with all enemy units at this territory
	my_team := mm.team[gc.cur_player]
	for player in Player_ID {
		if mm.team[player] == my_team {
			continue  // Skip allies
		}
		
		// Add enemy land units
		for army_type in Idle_Army {
			count := gc.idle_armies[target][player][army_type]
			for i in 0..<count {
				unit := Unit_Info{
					unit_type = idle_army_to_unit_type(army_type),
					from_territory = target,
				}
				append(&option.defenders, unit)
			}
		}
		
		// Add enemy air units
		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[target][player][plane_type]
			for i in 0..<count {
				unit := Unit_Info{
					unit_type = idle_plane_to_unit_type(plane_type),
					from_territory = target,
				}
				append(&option.defenders, unit)
			}
		}
	}
	
	// Populate POTENTIAL attackers (all units that could reach this territory)
	// This is used in Step 3 to check if we can hold the territory
	populate_potential_attackers(gc, &option)
	
	append(options, option)
}

// Helper: Convert Idle_Army to Unit_Type
idle_army_to_unit_type :: proc(army: Idle_Army) -> Unit_Type {
	switch army {
	case .INF:   return .Infantry
	case .ARTY:  return .Artillery
	case .TANK:  return .Tank
	case .AAGUN: return .AAGun
	}
	return .Infantry  // Default
}

// Helper: Convert Idle_Plane to Unit_Type
idle_plane_to_unit_type :: proc(plane: Idle_Plane) -> Unit_Type {
	switch plane {
	case .FIGHTER: return .Fighter
	case .BOMBER:  return .Bomber
	}
	return .Fighter  // Default
}

// Helper: Populate potential attackers for a target territory
// This finds all friendly units within attack range of the target
populate_potential_attackers :: proc(gc: ^Game_Cache, option: ^Attack_Option) {
	target := option.territory
	
	// Find all friendly ground units within 2 moves (simplified - tanks can move 2, inf/arty can move 1)
	// 1 move away
	for adj1 in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adj1] == gc.cur_player {
			// Add all ground units from this territory
			for army_type in Idle_Army {
				count := gc.idle_armies[adj1][gc.cur_player][army_type]
				for i in 0..<count {
					unit := Unit_Info{
						unit_type = idle_army_to_unit_type(army_type),
						from_territory = adj1,
					}
					append(&option.potential_attackers, unit)
				}
			}
		}
	}
	
	// 2 moves away (for tanks)
	for adj1 in sa.slice(&mm.l2l_1away_via_land[target]) {
		for adj2 in sa.slice(&mm.l2l_1away_via_land[adj1]) {
			if adj2 == target { continue }
			if gc.owner[adj2] == gc.cur_player {
				// Only add tanks (they can move 2)
				count := gc.idle_armies[adj2][gc.cur_player][.TANK]
				for i in 0..<count {
					unit := Unit_Info{
						unit_type = .Tank,
						from_territory = adj2,
					}
					append(&option.potential_attackers, unit)
				}
			}
		}
	}
	
	// Add all friendly fighters within 4 moves (simplified - just add nearby)
	// For now, add fighters from 1-2 territories away
	for adj1 in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adj1] == gc.cur_player {
			count := gc.idle_land_planes[adj1][gc.cur_player][.FIGHTER]
			for i in 0..<count {
				unit := Unit_Info{
					unit_type = .Fighter,
					from_territory = adj1,
				}
				append(&option.potential_attackers, unit)
			}
		}
	}
	
	// Add all friendly bombers within 6 moves (simplified)
	for adj1 in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adj1] == gc.cur_player {
			count := gc.idle_land_planes[adj1][gc.cur_player][.BOMBER]
			for i in 0..<count {
				unit := Unit_Info{
					unit_type = .Bomber,
					from_territory = adj1,
				}
				append(&option.potential_attackers, unit)
			}
		}
	}
	
	// Check for amphibious attackers from adjacent sea zones AND 1 move away
	canal_state := transmute(u8)gc.canals_open
	
	// All loaded transport types
	loaded_types := [?]struct{type: Idle_Ship, inf: u8, arty: u8, tank: u8}{
		{.TRANS_1I, 1, 0, 0},
		{.TRANS_1T, 0, 0, 1},
		{.TRANS_1A, 0, 1, 0},
		{.TRANS_2I, 2, 0, 0},
		{.TRANS_1I_1A, 1, 1, 0},
		{.TRANS_1I_1T, 1, 0, 1},
	}
	
	for sea_id in Sea_ID {
		// Check if this sea zone can reach the target (adjacent or 1 move away)
		is_adjacent := false
		is_one_away := false
		
		// Check if directly adjacent
		for land in sa.slice(&mm.s2l_1away_via_sea[sea_id]) {
			if land == target {
				is_adjacent = true
				break
			}
		}
		
		// Check if 1 sea zone away from an adjacent sea
		if !is_adjacent {
			for adj_sea in mm.s2s_1away_via_sea[canal_state][sea_id] {
				// Skip blocked sea zones
				if gc.enemy_blockade_total[adj_sea] > 0 {
					continue
				}
				for land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
					if land == target {
						is_one_away = true
						break
					}
				}
				if is_one_away { break }
			}
		}
		
		if !is_adjacent && !is_one_away {
			continue
		}
		
		// Add units from all loaded transports at this sea zone
		for info in loaded_types {
			count := gc.idle_ships[sea_id][gc.cur_player][info.type]
			if count == 0 { continue }
			
			// Add infantry from these transports
			for i in 0..<(count * info.inf) {
				unit := Unit_Info{
					unit_type = .Infantry,
					from_territory = Land_ID(sea_id),  // Sea zone as source (will be converted for amphib)
				}
				append(&option.potential_amphib_attackers, unit)
			}
			
			// Add artillery from these transports
			for i in 0..<(count * info.arty) {
				unit := Unit_Info{
					unit_type = .Artillery,
					from_territory = Land_ID(sea_id),
				}
				append(&option.potential_amphib_attackers, unit)
			}
			
			// Add tanks from these transports
			for i in 0..<(count * info.tank) {
				unit := Unit_Info{
					unit_type = .Tank,
					from_territory = Land_ID(sea_id),
				}
				append(&option.potential_amphib_attackers, unit)
			}
		}
	}
}

// Helper: Update only amphib attackers for an existing option
// Called when a territory is already in the options list but amphib attack routes are being discovered
update_amphib_attackers_only :: proc(gc: ^Game_Cache, option: ^Attack_Option) {
	// If already has amphib attackers, don't re-add
	if len(option.potential_amphib_attackers) > 0 {
		return
	}
	
	target := option.territory
	canal_state := transmute(u8)gc.canals_open
	
	// All loaded transport types
	loaded_types := [?]struct{type: Idle_Ship, inf: u8, arty: u8, tank: u8}{
		{.TRANS_1I, 1, 0, 0},
		{.TRANS_1T, 0, 0, 1},
		{.TRANS_1A, 0, 1, 0},
		{.TRANS_2I, 2, 0, 0},
		{.TRANS_1I_1A, 1, 1, 0},
		{.TRANS_1I_1T, 1, 0, 1},
	}
	
	for sea_id in Sea_ID {
		// Check if this sea zone can reach the target (adjacent or 1 move away)
		is_adjacent := false
		is_one_away := false
		
		// Check if directly adjacent
		for land in sa.slice(&mm.s2l_1away_via_sea[sea_id]) {
			if land == target {
				is_adjacent = true
				break
			}
		}
		
		// Check if 1 sea zone away from an adjacent sea
		if !is_adjacent {
			for adj_sea in mm.s2s_1away_via_sea[canal_state][sea_id] {
				// Skip blocked sea zones
				if gc.enemy_blockade_total[adj_sea] > 0 {
					continue
				}
				for land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
					if land == target {
						is_one_away = true
						break
					}
				}
				if is_one_away { break }
			}
		}
		
		if !is_adjacent && !is_one_away {
			continue
		}
		
		// Add units from all loaded transports at this sea zone
		for info in loaded_types {
			count := gc.idle_ships[sea_id][gc.cur_player][info.type]
			if count == 0 { continue }
			
			// Add infantry from these transports
			for i in 0..<(count * info.inf) {
				unit := Unit_Info{
					unit_type = .Infantry,
					from_territory = Land_ID(sea_id),
				}
				append(&option.potential_amphib_attackers, unit)
			}
			
			// Add artillery from these transports
			for i in 0..<(count * info.arty) {
				unit := Unit_Info{
					unit_type = .Artillery,
					from_territory = Land_ID(sea_id),
				}
				append(&option.potential_amphib_attackers, unit)
			}
			
			// Add tanks from these transports
			for i in 0..<(count * info.tank) {
				unit := Unit_Info{
					unit_type = .Tank,
					from_territory = Land_ID(sea_id),
				}
				append(&option.potential_amphib_attackers, unit)
			}
		}
	}
}

// Helper: Check if territory has enemy units
has_enemy_units :: proc(gc: ^Game_Cache, land_tid: Land_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	
	// Check all players
	for player in Player_ID {
		if mm.team[player] == my_team {
			continue
		}
		
		// Check armies
		for army_type in gc.idle_armies[land_tid][player] {
			if army_type > 0 {
				return true
			}
		}
		
		// Check planes
		for plane_type in gc.idle_land_planes[land_tid][player] {
			if plane_type > 0 {
				return true
			}
		}
	}
	
	return false
}

/*
=============================================================================
EXECUTE COMBAT MOVES (doMove)
=============================================================================

Java Original: ProCombatMoveAi.doMove() (lines 153-167)

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

This is Step 11 of the Pro AI Combat Move phase. It actually executes the planned
attacks by moving units from their source territories to their destinations.

In Java, this is split into 4 phases:
1. calculateMoveRoutes() - Move land and air units
2. calculateAmphibRoutes() - Unload transports for amphibious assaults
3. calculateBombardMoveRoutes() - Position naval units for shore bombardment
4. calculateBombingRoutes() - Execute strategic bombing runs

For OAAA, we'll simplify this to:
1. Move land units (infantry, artillery, tanks)
2. Move air units (fighters, bombers)
3. Handle amphibious assaults (units from transports)

NOTE: Naval bombardment and strategic bombing are not implemented yet.
*/

execute_combat_moves_triplea :: proc(gc: ^Game_Cache, attack_options: ^[dynamic]Attack_Option) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("  Executing combat moves for", len(attack_options), "attacks")
	}
	
	// Phase 1: Calculate and execute regular move routes (land + air units)
	execute_regular_move_routes(gc, attack_options) or_return
	
	// Phase 2: Calculate and execute amphibious routes (transport unloading)
	execute_amphibious_routes(gc, attack_options) or_return
	
	// Phase 3: Calculate and execute bombardment routes (not implemented yet)
	// execute_bombardment_routes(gc, attack_options) or_return
	
	// Phase 4: Calculate and execute bombing routes (not implemented yet)
	// execute_bombing_routes(gc, attack_options) or_return
	
	// Phase 5: Mark territories for combat and resolve battles
	for &opt in attack_options {
		// Mark this territory for combat resolution if there are enemy units
		if gc.team_land_units[opt.territory][mm.enemy_team[gc.cur_player]] > 0 {
			gc.more_land_combat_needed += {opt.territory}
			when ODIN_DEBUG {
				fmt.printf("  Marked %v for combat resolution\n", opt.territory)
			}
		} else if mm.team[gc.owner[opt.territory]] != mm.team[gc.cur_player] {
			// Empty enemy territory - check if we should capture it
			// This handles amphibious landings on undefended territories
			if gc.team_land_units[opt.territory][mm.team[gc.cur_player]] > 0 {
				transfer_land_ownership(gc, opt.territory)
				when ODIN_DEBUG {
					fmt.printf("  Captured undefended territory %v\n", opt.territory)
				}
			}
		}
	}
	
	// Resolve all marked land battles
	// resolve_land_battles(gc) or_return

	// when ODIN_DEBUG {
	// 	fmt.println("  + All combat moves executed and battles resolved")
	// 	// print_game_state(gc)
	// }
	
	
	return true
}

/*
=============================================================================
EXECUTE REGULAR MOVE ROUTES
=============================================================================

Java Original: ProMoveUtils.calculateMoveRoutes() + ProMoveUtils.doMove()

This function moves land and air units from their source territories to their
attack destinations. It handles:
- Infantry: 1 movement (adjacent only)
- Artillery: 1 movement (adjacent only)
- Tanks: 2 movement (can blitz through empty friendly)
- Fighters: 4 movement (simplified to 2 for now)
- Bombers: 6 movement (simplified to 2 for now)

Units are moved from idle_armies to active_armies (engaged in combat).
*/

execute_regular_move_routes :: proc(gc: ^Game_Cache, attack_options: ^[dynamic]Attack_Option) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("\n  [MOVE ROUTES] Moving land and air units to attack destinations")
	}
	
	for &opt in attack_options {
		target := opt.territory
		
		when ODIN_DEBUG {
			fmt.printf("    Moving %d units to attack %v\n", len(opt.attackers), target)
		}
		
		// Move each attacking unit
		for unit in opt.attackers {
			// Convert unit type to the appropriate army/plane type
			#partial switch unit.unit_type {
			case .Infantry:
				// Move infantry from source to target
				if gc.idle_armies[unit.from_territory][gc.cur_player][.INF] == 0 {
					when ODIN_DEBUG {
						fmt.printf("      ERROR: No infantry at %v to move!\n", unit.from_territory)
					}
					return false
				}

				gc.current_territory = to_air(unit.from_territory)
				gc.current_active_unit = Active_Unit.INF_1_MOVES
				dst_action := to_action(target)
				next_state := blitz_checks(gc, dst_action)
				move_single_army_land(gc, dst_action, next_state)

				when ODIN_DEBUG {
					fmt.printf("      Moved Infantry from %v to %v\n", unit.from_territory, target)
				}
				
			case .Artillery:
				if gc.idle_armies[unit.from_territory][gc.cur_player][.ARTY] == 0 {
					when ODIN_DEBUG {
						fmt.printf("      ERROR: No artillery at %v to move!\n", unit.from_territory)
					}
					return false
				}
				
				gc.current_territory = to_air(unit.from_territory)
				gc.current_active_unit = Active_Unit.ARTY_1_MOVES
				dst_action := to_action(target)
				next_state := blitz_checks(gc, dst_action)
				move_single_army_land(gc, dst_action, next_state)

				when ODIN_DEBUG {
					fmt.printf("      Moved Artillery from %v to %v\n", unit.from_territory, target)
				}
				
			case .Tank:
				if gc.idle_armies[unit.from_territory][gc.cur_player][.TANK] == 0 {
					when ODIN_DEBUG {
						fmt.printf("      ERROR: No tank at %v to move!\n", unit.from_territory)
					}
					return false
				}
				
				gc.current_territory = to_air(unit.from_territory)
				gc.current_active_unit = Active_Unit.TANK_2_MOVES
				dst_action := to_action(target)
				next_state := blitz_checks(gc, dst_action)
				move_single_army_land(gc, dst_action, next_state)

				when ODIN_DEBUG {
					fmt.printf("      Moved Tank from %v to %v\n", unit.from_territory, target)
				}
				
			case .Fighter:
				if gc.idle_land_planes[unit.from_territory][gc.cur_player][.FIGHTER] == 0 {
					when ODIN_DEBUG {
						fmt.printf("      ERROR: No fighter at %v to move!\n", unit.from_territory)
					}
					return false
				}
				
				gc.current_territory = to_air(unit.from_territory)
				move_unmoved_fighter_from_land_to_land(gc, to_action(target))
				// gc.idle_land_planes[unit.from_territory][gc.cur_player][.FIGHTER] -= 1
				// gc.team_land_units[unit.from_territory][mm.team[gc.cur_player]] -= 1
				// gc.idle_land_planes[target][gc.cur_player][.FIGHTER] += 1
				// distance:= mm.air_distances[to_air(unit.from_territory)][to_air(target)]
				// if distance == 1 {
				// 	gc.active_land_planes[target][.FIGHTER_3_MOVES] += 1
				// } else if distance == 2 {
				// 	gc.active_land_planes[target][.FIGHTER_2_MOVES] += 1
				// } else if distance == 3 {
				// 	gc.active_land_planes[target][.FIGHTER_1_MOVES] += 1
				// } else if distance == 4 {
				// 	gc.active_land_planes[target][.FIGHTER_0_MOVES] += 1
				// }
				// gc.team_land_units[target][mm.team[gc.cur_player]] += 1
				
				when ODIN_DEBUG {
					fmt.printf("      Moved Fighter from %v to %v\n", unit.from_territory, target)
				}
				
			case .Bomber:
				if gc.idle_land_planes[unit.from_territory][gc.cur_player][.BOMBER] == 0 {
					when ODIN_DEBUG {
						fmt.printf("      ERROR: No bomber at %v to move!\n", unit.from_territory)
					}
					return false
				}

				gc.current_territory = to_air(unit.from_territory)
				move_unmoved_bomber_to_land(gc, to_action(target))
				
				// gc.idle_land_planes[unit.from_territory][gc.cur_player][.BOMBER] -= 1
				// gc.team_land_units[unit.from_territory][mm.team[gc.cur_player]] -= 1
				// gc.idle_land_planes[target][gc.cur_player][.BOMBER] += 1
				// distance:= mm.air_distances[to_air(unit.from_territory)][to_air(target)]
				// if distance == 1 {
				// 	gc.active_land_planes[target][.BOMBER_5_MOVES] += 1
				// } else if distance == 2 {
				// 	gc.active_land_planes[target][.BOMBER_4_MOVES] += 1
				// } else if distance == 3 {
				// 	gc.active_land_planes[target][.BOMBER_3_MOVES] += 1
				// } else if distance == 4 {
				// 	gc.active_land_planes[target][.BOMBER_2_MOVES] += 1
				// } else if distance == 5 {
				// 	gc.active_land_planes[target][.BOMBER_1_MOVES] += 1
				// } else if distance == 6 {
				// 	gc.active_land_planes[target][.BOMBER_0_MOVES] += 1
				// }
				// gc.team_land_units[target][mm.team[gc.cur_player]] += 1
				
				when ODIN_DEBUG {
					fmt.printf("      Moved Bomber from %v to %v\n", unit.from_territory, target)
				}
			}
		}
	}
	
	return true
}

/*
=============================================================================
EXECUTE AMPHIBIOUS ROUTES
=============================================================================

Java Original: ProMoveUtils.calculateAmphibRoutes() + ProMoveUtils.doMove()

This function handles amphibious assaults by unloading units from transports
onto coastal enemy territories.

Amphibious attackers are stored with from_territory as a Sea_ID (cast to Land_ID).
We need to:
1. Find the sea zone
2. Find the appropriate transport type (TRANS_1I, TRANS_1T, TRANS_1A)
3. Unload the unit onto the target territory
4. Convert the loaded transport to an empty one
*/

execute_amphibious_routes :: proc(gc: ^Game_Cache, attack_options: ^[dynamic]Attack_Option) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("\n  [AMPHIB ROUTES] Unloading transports for amphibious assaults")
	}
	
	// Mapping from Idle_Ship transport types to what they carry
	Idle_Trans_Info :: struct {
		type: Idle_Ship,
		inf: u8,
		arty: u8,
		tank: u8,
	}
	
	idle_trans_types := [?]Idle_Trans_Info{
		{.TRANS_1I, 1, 0, 0},
		{.TRANS_1T, 0, 0, 1},
		{.TRANS_1A, 0, 1, 0},
		{.TRANS_2I, 2, 0, 0},
		{.TRANS_1I_1A, 1, 1, 0},
		{.TRANS_1I_1T, 1, 0, 1},
	}
	
	for &opt in attack_options {
		target := opt.territory
		
		if len(opt.amphib_attackers) == 0 {
			continue
		}
		
		when ODIN_DEBUG {
			fmt.printf("    Unloading %d units for amphibious assault on %v\n", 
				len(opt.amphib_attackers), target)
		}
		
		// Unload each amphibious attacker from IDLE transports
		for unit in opt.amphib_attackers {
			// from_territory is actually a Sea_ID (stored as Land_ID)
			sea_zone := Sea_ID(unit.from_territory)
			
			// Find which idle transport has this unit type and unload it
			ship_found := false
			
			for info in idle_trans_types {
				// Check if this transport type carries the unit we want
				carries_unit := false
				#partial switch unit.unit_type {
				case .Infantry:
					carries_unit = info.inf > 0
				case .Artillery:
					carries_unit = info.arty > 0
				case .Tank:
					carries_unit = info.tank > 0
				}
				
				if !carries_unit {
					continue
				}
				
				// Check if we have this transport type at this sea zone
				if gc.idle_ships[sea_zone][gc.cur_player][info.type] > 0 {
					when ODIN_DEBUG {
						fmt.printf("      Unloading %v from %v (sea zone %v) to %v\n", 
							unit.unit_type, info.type, sea_zone, target)
					}
					
					// Decrement the transport
					gc.idle_ships[sea_zone][gc.cur_player][info.type] -= 1
					
					// Determine new transport state after unloading
					new_trans_type: Idle_Ship
					#partial switch info.type {
					case .TRANS_1I:
						new_trans_type = .TRANS_EMPTY
					case .TRANS_1T:
						new_trans_type = .TRANS_EMPTY
					case .TRANS_1A:
						new_trans_type = .TRANS_EMPTY
					case .TRANS_2I:
						new_trans_type = .TRANS_1I  // 2I -> 1I after unloading one
					case .TRANS_1I_1A:
						// Depends on what we unloaded
						if unit.unit_type == .Infantry {
							new_trans_type = .TRANS_1A
						} else {
							new_trans_type = .TRANS_1I
						}
					case .TRANS_1I_1T:
						if unit.unit_type == .Infantry {
							new_trans_type = .TRANS_1T
						} else {
							new_trans_type = .TRANS_1I
						}
					case:
						new_trans_type = .TRANS_EMPTY
					}
					
					gc.idle_ships[sea_zone][gc.cur_player][new_trans_type] += 1
					
					// Add the unloaded unit to the target territory as an attacking unit
					// Must update active_armies, idle_armies, and team_land_units to keep them in sync
					#partial switch unit.unit_type {
					case .Infantry:
						gc.active_armies[target][.INF_0_MOVES] += 1
						gc.idle_armies[target][gc.cur_player][.INF] += 1
						gc.team_land_units[target][mm.team[gc.cur_player]] += 1
					case .Artillery:
						gc.active_armies[target][.ARTY_0_MOVES] += 1
						gc.idle_armies[target][gc.cur_player][.ARTY] += 1
						gc.team_land_units[target][mm.team[gc.cur_player]] += 1
					case .Tank:
						gc.active_armies[target][.TANK_0_MOVES] += 1
						gc.idle_armies[target][gc.cur_player][.TANK] += 1
						gc.team_land_units[target][mm.team[gc.cur_player]] += 1
					}
					
					ship_found = true
					break
				}
			}
			
			if !ship_found {
				when ODIN_DEBUG {
					fmt.printf("      ERROR: No suitable transport found at sea zone %v for %v\n", 
						sea_zone, unit.unit_type)
				}
				// Don't fail - just continue without unloading this unit
				// return false
			}
		}
	}
	
	return true
}

// =============================================================================
// HELPER FUNCTIONS FOR ITERATIVE UNIT ASSIGNMENT
// =============================================================================

// Get total available units of a type from adjacent territories
get_total_available_units :: proc(
	gc: ^Game_Cache,
	target: Land_ID,
	unit_type: Unit_Type,
	assigned_units: ^[dynamic]Unit_Info,
) -> int {
	total := 0
	
	for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
		if gc.owner[adjacent] != gc.cur_player {
			continue
		}
		
		available := get_active_unit_count_for_combat(gc, adjacent, unit_type)
		
		// Subtract already assigned units
		for unit in assigned_units {
			if unit.from_territory == adjacent && unit.unit_type == unit_type {
				available -= 1
			}
		}
		
		total += max(0, available)
	}
	
	// Also check 2-away for tanks
	if unit_type == .Tank {
		for land_2away in mm.l2l_2away_via_land_bitset[target] {
			if mm.team[gc.owner[land_2away]] != mm.team[gc.cur_player] {
				continue
			}
			
			// Use active_armies (tanks with 2 moves can blitz)
			available := int(gc.active_armies[land_2away][.TANK_2_MOVES])
			
			for unit in assigned_units {
				if unit.from_territory == land_2away && unit.unit_type == .Tank {
					available -= 1
				}
			}
			
			total += max(0, available)
		}
	}
	
	return total
}

// Get total available air units that can reach the target
// Uses the existing get_active_air_count_for_combat helper
get_total_available_air_units :: proc(
	gc: ^Game_Cache,
	target: Land_ID,
	unit_type: Unit_Type,
	assigned_units: ^[dynamic]Unit_Info,
) -> int {
	total := 0
	
	// Check our owned territories for air units
	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}
		
		// Simplified range check: within 2 land distance or same territory
		// (More accurate would check air movement, but this is good enough)
		can_reach := false
		if land_id == target {
			can_reach = true
		} else {
			// Check 1-away via land (air can reach)
			for adj in sa.slice(&mm.l2l_1away_via_land[target]) {
				if adj == land_id {
					can_reach = true
					break
				}
			}
			// Check 2-away
			if !can_reach {
				for adj in mm.l2l_2away_via_land_bitset[target] {
					if adj == land_id {
						can_reach = true
						break
					}
				}
			}
		}
		
		if !can_reach {
			continue
		}
		
		// Use existing helper to count air units
		available := get_active_air_count_for_combat(gc, land_id, unit_type)
		
		// Subtract already assigned
		for unit in assigned_units {
			if unit.from_territory == land_id && unit.unit_type == unit_type {
				available -= 1
			}
		}
		
		total += max(0, available)
	}
	
	return total
}

// Count units of a specific type in the attackers list
count_units_of_type :: proc(attackers: ^[dynamic]Unit_Info, unit_type: Unit_Type) -> int {
	count := 0
	for unit in attackers {
		if unit.unit_type == unit_type {
			count += 1
		}
	}
	return count
}

// Add a unit of the specified type to the attack from an adjacent territory
add_unit_to_attack :: proc(
	gc: ^Game_Cache,
	option: ^Attack_Option,
	unit_type: Unit_Type,
	assigned_units: ^[dynamic]Unit_Info,
) -> bool {
	target := option.territory
	
	// For land units, check adjacent territories
	if unit_type == .Infantry || unit_type == .Artillery || unit_type == .Tank {
		for adjacent in sa.slice(&mm.l2l_1away_via_land[target]) {
			if gc.owner[adjacent] != gc.cur_player {
				continue
			}
			
			// Check available (total minus already assigned from this territory)
			total := get_active_unit_count_for_combat(gc, adjacent, unit_type)
			assigned_from_here := 0
			for unit in assigned_units {
				if unit.from_territory == adjacent && unit.unit_type == unit_type {
					assigned_from_here += 1
				}
			}
			
			if total > assigned_from_here {
				unit := Unit_Info{
					unit_type = unit_type,
					from_territory = adjacent,
				}
				append(&option.attackers, unit)
				append(assigned_units, unit)
				return true
			}
		}
		
		// For tanks, also check 2-away territories
		if unit_type == .Tank {
			for land_2away in mm.l2l_2away_via_land_bitset[target] {
				if mm.team[gc.owner[land_2away]] != mm.team[gc.cur_player] {
					continue
				}
				
				// Use active_armies for tanks with 2 moves
				total := int(gc.active_armies[land_2away][.TANK_2_MOVES])
				
				assigned_from_here := 0
				for unit in assigned_units {
					if unit.from_territory == land_2away && unit.unit_type == .Tank {
						assigned_from_here += 1
					}
				}
				
				if total > assigned_from_here {
					unit := Unit_Info{
						unit_type = .Tank,
						from_territory = land_2away,
					}
					append(&option.attackers, unit)
					append(assigned_units, unit)
					return true
				}
			}
		}
	}
	
	// For air units, check reachable territories using simplified distance
	if unit_type == .Fighter || unit_type == .Bomber {
		for land_id in Land_ID {
			if gc.owner[land_id] != gc.cur_player {
				continue
			}
			
			// Simplified range check: within 2 land distance or same territory
			can_reach := false
			if land_id == target {
				can_reach = true
			} else {
				// Check 1-away via land
				for adj in sa.slice(&mm.l2l_1away_via_land[target]) {
					if adj == land_id {
						can_reach = true
						break
					}
				}
				// Check 2-away
				if !can_reach {
					for adj in mm.l2l_2away_via_land_bitset[target] {
						if adj == land_id {
							can_reach = true
							break
						}
					}
				}
			}
			
			if !can_reach {
				continue
			}
			
			// Use existing helper to count air units
			total := get_active_air_count_for_combat(gc, land_id, unit_type)
			
			assigned_from_here := 0
			for unit in assigned_units {
				if unit.from_territory == land_id && unit.unit_type == unit_type {
					assigned_from_here += 1
				}
			}
			
			if total > assigned_from_here {
				unit := Unit_Info{
					unit_type = unit_type,
					from_territory = land_id,
				}
				append(&option.attackers, unit)
				append(assigned_units, unit)
				return true
			}
		}
	}
	
	return false
}

// Simulate battle and return win percentage
simulate_attack_win_percentage :: proc(option: ^Attack_Option) -> f64 {
	combatants := Land_Combatants{}
	
	// Count attackers
	for attacker in option.attackers {
		#partial switch attacker.unit_type {
		case .Infantry:
			combatants.attackers[0].Infantry += 1
		case .Artillery:
			combatants.attackers[0].Artillery += 1
		case .Tank:
			combatants.attackers[0].Tanks += 1
		case .Fighter:
			combatants.attackers[1].Fighters += 1
		case .Bomber:
			combatants.attackers[2].Bombers += 1
		}
	}
	
	// Count amphib attackers too
	for attacker in option.amphib_attackers {
		#partial switch attacker.unit_type {
		case .Infantry:
			combatants.attackers[0].Infantry += 1
		case .Artillery:
			combatants.attackers[0].Artillery += 1
		case .Tank:
			combatants.attackers[0].Tanks += 1
		}
	}
	
	// Count defenders
	for defender in option.defenders {
		#partial switch defender.unit_type {
		case .Infantry:
			combatants.defenders.Infantry += 1
		case .Artillery:
			combatants.defenders.Artillery += 1
		case .Tank:
			combatants.defenders.Tanks += 1
		case .Fighter:
			combatants.defenders.Fighters += 1
		case .Bomber:
			combatants.defenders.Bombers += 1
		}
	}
	
	results := simulate_battle(combatants)
	return results.invaded_percent
}
