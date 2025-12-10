package oaaa

/*
Pro AI Non-Combat Move Phase Implementation

This file implements non-combat movement logic following TripleA's ProNonCombatMoveAi.java.
The Pro AI moves units to defensive positions, lands planes safely, and repositions forces
for future attacks.

=============================================================================
JAVA ProNonCombatMoveAi.java NESTED LOOP STRUCTURE (2,541 lines)
=============================================================================

MAIN ENTRY: doNonCombatMove() lines 76-198
├── territoryManager.populateDefenseOptions()
├── findUnitsThatCantMove() - [MISSING] lines 200-255
├── findInfraUnitsThatCanMove() - [MISSING] lines 257-275
├── moveOneDefenderToLandTerritoriesBorderingEnemy() - [PARTIAL]
│   └── LOOP: for each empty border territory
│       └── Find cheapest unit from adjacent owned territories
├── territoryManager.populateEnemyAttackOptions()
├── determineIfMoveTerritoriesCanBeHeld() - [PARTIAL]
│   └── LOOP: for each defense territory
│       └── calculateBattleResults(), set canHold flag
├── prioritizeDefendOptions() - [PARTIAL]
│   └── LOOP: for each territory, calculate defense priority
│
├── [CRITICAL] CAPITAL DEFENSE LOOP lines 130-165 - [MISSING]
│   while (true) {
│   │   └── LOOP: for each defend territory
│   │       └── Adjust value based on distance to capital
│   │   moveUnitsToBestTerritories()
│   │   └── Check capital local superiority
│   │   └── If no superiority: reset territoryManager, increase defenseRange, repeat
│   └── Break when capital is safe
│   }
│
├── moveUnitsToDefendTerritories() lines 630-960 - [PARTIAL]
│   └── OUTER LOOP: Try decreasing number of territories to defend
│       ├── LOOP: for each territory to defend
│       │   └── INNER LOOP: for each unit with move options
│       │       └── Add unit if improves defense
│       ├── [MISSING] LOOP: Check for amphib defense options
│       │   └── LOOP: for each transport in transportMapList
│       │       └── Find units to load, calculate safest unload zone
│       └── Check if all defenses successful; if not, reduce territory count
│
├── moveUnitsToBestTerritories() lines 962-1840 - [PARTIAL ~45%]
│   ├── [MISSING] Block 1: Transport amphib to best land (lines 985-1100)
│   │   └── LOOP: for proTransportData in transportMapList
│   │       └── LOOP: for transport in transportMap
│   │           ├── Find best land territory by value
│   │           ├── LOOP: Find units to load from adjacent territories
│   │           └── LOOP: Find safest unload sea zone
│   │
│   ├── [MISSING] Block 2: Transport amphib to best sea (lines 1100-1180)
│   │   └── Similar structure but for sea destinations
│   │
│   ├── [MISSING] Block 3: Empty transports to loading position (lines 1185-1280)
│   │   └── LOOP: for each empty transport
│   │       ├── Calculate load territory priorities
│   │       └── Move towards factory-adjacent sea zones
│   │
│   ├── [MISSING] Block 4: Remaining transports to safety (lines 1285-1400)
│   │   └── LOOP: for remaining unmoved transports
│   │       └── Find safest sea zone, try to unload if carrying units
│   │
│   ├── [IMPLEMENTED] Block 5: Sea units defend transports (lines 1500-1560)
│   │   └── LOOP: for each sea unit
│   │       └── Check if transport needs escort, add to escort duty
│   │
│   ├── [IMPLEMENTED] Block 6: Air units defend transports (lines 1560-1600)
│   │   └── LOOP: for fighters
│   │       └── Add to carriers providing transport defense
│   │
│   ├── [PARTIAL] Block 7: Sea units to best location (lines 1600-1730)
│   │   └── LOOP: for remaining sea units
│   │       └── Calculate sea value + transport presence, move to best
│   │
│   ├── [IMPLEMENTED] Block 8: Land units to high value (lines 1842-1904)
│   ├── [IMPLEMENTED] Block 9: Land units to coastal factories (lines 1910-1944)
│   ├── [IMPLEMENTED] Block 10: Land units to safest (lines 1950-1989)
│   ├── [IMPLEMENTED] Block 11: Air to safe with attack options (lines 2000-2110)
│   └── [IMPLEMENTED] Block 12: Air to safest (lines 2115-2160)
│
├── [MISSING] moveCarrierFighters() lines 2165-2175
│   └── LOOP: for fighters on carriers
│       └── Move carrier with fighters if carrier needs to move
│
├── [MISSING] moveInfraUnits() lines 2177-2475
│   ├── moveInfrastructure() - Move AA guns
│   │   └── LOOP: for each AA gun
│   │       └── Find best factory to protect
│   ├── moveFactoriesIfMobile() - Move mobile factories
│   │   └── LOOP: for each mobile factory
│   │       └── Move to highest production territory
│   ├── checkNeedToConsumeUnits() - Consume units for production
│   └── findBestPathToTerritoryUsingLandRoutes() - BFS multi-turn pathing
│       └── BFS LOOP with distance tracking
│
└── doMove() - Execute all moves

=============================================================================
*/

import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"


move_map : [Land_ID][Idle_Army]u8
unit_move_map : [Land_ID][Idle_Army]u8

// do_non_combat_move :: proc(gc: ^Game_Cache,
//       initialFactoryMoveMap: map[Territory]ProTerritory,
//       purchaseTerritories: map[Territory]ProPurchaseTerritory,
//       moveDel: IMoveDelegate) -> map[Territory]ProTerritory
//     {

//     ProLogger.info("Starting non-combat move phase");

//     // Current data at the start of non-combat move
//     // data = proData.getData();
//     // player = proData.getPlayer();
//     // unitTerritoryMap = proData.getUnitTerritoryMap();
//     // territoryManager = new ProTerritoryManager(calc, proData);
// 	move_map = {}
// 	unit_move_map = {}

//     // Find the max number of units that can move to each allied territory
//     // territoryManager.populateDefenseOptions(new ArrayList<>());
// 	findNavalMoveOptions(
//         proData,
//         player,
//         myUnitTerritories,
//         moveMap,
//         unitMoveMap,
//         transportMoveMap,
//         ProMatches.territoryHasNoEnemyUnitsOrCleared(player, clearedTerritories),
//         clearedTerritories,
//         false,
//         isCheckingEnemyAttacks);
//     findLandMoveOptions(
//         proData,
//         player,
//         myUnitTerritories,
//         moveMap,
//         unitMoveMap,
//         landRoutesMap,
//         Matches.isTerritoryAllied(player),
//         new ArrayList<>(),
//         clearedTerritories,
//         false,
//         isCheckingEnemyAttacks,
//         false);
//     findAirMoveOptions(
//         proData,
//         player,
//         myUnitTerritories,
//         moveMap,
//         unitMoveMap,
//         ProMatches.territoryCanLandAirUnits(player, false, new ArrayList<>(), new ArrayList<>()),
//         new ArrayList<>(),
//         new ArrayList<>(),
//         false,
//         isCheckingEnemyAttacks,
//         false);
//     findAmphibMoveOptions(
//         proData,
//         player,
//         myUnitTerritories,
//         moveMap,
//         transportMapList,
//         landRoutesMap,
//         Matches.isTerritoryAllied(player),
//         false,
//         isCheckingEnemyAttacks,
//         false);

//     // Note: On maps that have a single move phase, this function may be called with this true.
//     // boolean isCombatMove = GameStepPropertiesHelper.isCombatMove(data);

//     // Find number of units in each move territory that can't move and all infra units
//     findUnitsThatCantMove(purchaseTerritories, proData.getPurchaseOptions().getLandOptions())
//     // final Map<Unit, Set<Territory>> infraUnitMoveMap = findInfraUnitsThatCanMove();

//     // Try to have one land unit in each territory that is bordering an enemy territory
//     moved_one_defender_to_territories: Land_Bitset = move_one_defender_to_land_territories_bordering_enemy(gc)

//     // Determine max enemy attack units and if territories can be held
//     territoryManager.populateEnemyAttackOptions(
//         moved_one_defender_to_territories, territoryManager.getDefendTerritories());
//     determineIfMoveTerritoriesCanBeHeld();

//     // Prioritize territories to defend
//     Map<Territory, ProTerritory> factoryMoveMap = initialFactoryMoveMap;
//     final List<ProTerritory> prioritizedTerritories = prioritizeDefendOptions(factoryMoveMap);

//     // Determine which territories to defend and how many units each one needs
//     final Territory myCapital = proData.getMyCapital();
//     int enemyDistanceToMyCapital = Integer.MAX_VALUE;
//     if (myCapital != null) {
//       enemyDistanceToMyCapital =
//           ProUtils.getClosestEnemyLandTerritoryDistance(data, player, myCapital);
//       moveUnitsToDefendTerritories(isCombatMove, prioritizedTerritories, enemyDistanceToMyCapital);
//     }

//     // Copy data in case capital defense needs increased
//     final ProTerritoryManager territoryManagerCopy =
//         new ProTerritoryManager(calc, proData, territoryManager);

//     // Get list of territories that can't be held and find move value for each territory
//     final List<Territory> territoriesThatCantBeHeld = territoryManager.getCantHoldTerritories();
//     final Map<Territory, Double> territoryValueMap =
//         ProTerritoryValueUtils.findTerritoryValues(
//             proData,
//             player,
//             territoriesThatCantBeHeld,
//             List.of(),
//             new HashSet<>(territoryManager.getDefendTerritories()));
//     final Map<Territory, Double> seaTerritoryValueMap =
//         ProTerritoryValueUtils.findSeaTerritoryValues(
//             player, territoriesThatCantBeHeld, territoryManager.getDefendTerritories());
//     Map<Territory, ProTerritory> moveMap = territoryManager.getDefendOptions().getTerritoryMap();

//     // Use loop to ensure capital is protected after moves
//     if (myCapital != null) {
//       int defenseRange = -1;
//       while (true) {
//         // Add value to territories near capital if necessary
//         Predicate<Territory> canMove = ProMatches.territoryCanMoveLandUnits(player, isCombatMove);
//         for (final Territory t : territoryManager.getDefendTerritories()) {
//           double value = territoryValueMap.get(t);
//           final int distance = data.getMap().getDistance(myCapital, t, canMove);
//           if (distance >= 0 && distance <= defenseRange) {
//             value *= 10;
//           }
//           moveMap.get(t).setValue(value);
//           if (t.isWater()) {
//             moveMap.get(t).setSeaValue(seaTerritoryValueMap.get(t));
//           }
//         }
//         String a = String.valueOf(moveMap.get(myCapital).getValue());
//         ProLogger.info("Capital value: " + a);
//         moveUnitsToBestTerritories(isCombatMove);

//         // Check if capital has local land superiority
//         ProLogger.info(
//             "Checking if capital has local land superiority with enemyDistanceToMyCapital="
//                 + enemyDistanceToMyCapital);
//         if (enemyDistanceToMyCapital >= 2
//             && enemyDistanceToMyCapital <= 3
//             && defenseRange == -1
//             && !ProBattleUtils.territoryHasLocalLandSuperiorityAfterMoves(
//                 proData, myCapital, enemyDistanceToMyCapital, player, moveMap)) {
//           defenseRange = enemyDistanceToMyCapital - 1;
//           territoryManager = territoryManagerCopy;
//           ProLogger.debug(
//               "Capital doesn't have local land superiority so setting defensive stance");
//         } else {
//           break;
//         }
//       }
//     } else {
//       moveUnitsToBestTerritories(isCombatMove);
//     }

//     // Determine where to move infra units
//     factoryMoveMap = moveInfraUnits(isCombatMove, factoryMoveMap, infraUnitMoveMap);

//     // Log a warning if any units not assigned to a territory (skip infrastructure for now)
//     for (final Unit u : territoryManager.getDefendOptions().getUnitMoveMap().keySet()) {
//       if (Matches.unitIsInfrastructure().negate().test(u)) {
//         ProLogger.warn(
//             player
//                 + ": "
//                 + unitTerritoryMap.get(u)
//                 + " has unmoved unit: "
//                 + u
//                 + " with options: "
//                 + territoryManager.getDefendOptions().getUnitMoveMap().get(u));
//       }
//     }

//     // Calculate move routes and perform moves
//     doMove(isCombatMove, moveMap, moveDel, data, player);

//     // Log results
//     ProLogger.info("Logging results");
//     logAttackMoves(prioritizedTerritories);

//     territoryManager = null;
//     return factoryMoveMap;
//   }



// // Main non-combat move phase entry point

move_one_defender_to_land_territories_bordering_enemy :: proc(gc: ^Game_Cache) -> Land_Bitset {
	when ODIN_DEBUG {
		fmt.println("Determine which territories to defend with one land unit")
	}
	// Find land territories with no can't move units and adjacent to enemy land units
	territories_to_defend_with_one_unit : Land_Bitset={}
	// final Predicate<Unit> alliedAndNotInfra = ProMatches.unitIsAlliedLandAndNotInfra(player);
	for land in gc.friendly_owner {
		enemy_neighbors := mm.l2l_1away_via_land_bitset[land] & gc.has_enemy_armies
		if enemy_neighbors == {} do continue
		if gc.team_land_units[land][mm.team[gc.cur_player]] > 0 do continue
		territories_to_defend_with_one_unit += {land}
	}

	// Sort units by number of defend options and cost
	sorted_unit_move_options : map[Idle_Army]Land_Bitset ={}
	// sort_unit_move_options(sorted_unit_move_options, proData, unitMoveMap)

	// Set unit with the fewest move options in each territory
	for idle_army in Idle_Army {
		// if (Matches.unitIsLand().test(unit)) {
		for t in sorted_unit_move_options[idle_army] {
			unitValue := COST_IDLE_ARMY[idle_army]
			production := mm.value[t]

			// Only defend territories that either already have units (avoid abandoning territories)
			// or where unit value is less than production + 3 (avoid sacrificing expensive units to
			// block)
			player := gc.cur_player
			if (t in territories_to_defend_with_one_unit && (unitValue <= (production + 3) ||
					gc.idle_armies[t][player][.INF] > 0 || 
					gc.idle_armies[t][player][.ARTY] > 0 || 
					gc.idle_armies[t][player][.TANK] > 0 || 
					gc.idle_armies[t][player][.AAGUN] > 0 || 
					gc.idle_land_planes[t][player][.FIGHTER] > 0 || 
					gc.idle_land_planes[t][player][.BOMBER] > 0)) {
				// moveMap.get(t).addUnit(unit);
				move_map[t][idle_army] += 1
				// unitMoveMap.remove(unit);
				unit_move_map[t][idle_army] -= 1

				territories_to_defend_with_one_unit -= {t};
				when ODIN_DEBUG {
					fmt.printf("%v, added one land unit: %v\n", t, idle_army);
				}
				break;
			}
		}
		if (territories_to_defend_with_one_unit == {}) {
			break;
		}
	}
	// Only return territories that received a defender
	return territories_to_defend_with_one_unit;
}








proai_noncombat_move_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Starting non-combat move phase")
	}

	pro_data := pro_data_init(gc)

	// Step 1: Find territories that need defense
	defense_targets := find_noncombat_defense_targets(gc, &pro_data)
	defer pro_noncombat_move_cleanup(&defense_targets)

	when ODIN_DEBUG {
		if len(defense_targets) == 0 {
			fmt.println("[PRO-AI] No territories need defense")
		} else {
			fmt.printf("[PRO-AI] Found %d territories needing defense:\n", len(defense_targets))
			for target in defense_targets {
				fmt.printf(
					"  - %s: defense=%.1f vs threat=%.1f (gap=%.1f, factory=%v, capital=%v)\n",
					target.territory,
					target.current_defense,
					target.enemy_threat,
					target.defense_needed,
					target.has_factory,
					target.is_capital,
				)
			}
		}
	}

	// Step 2: Prioritize defense targets by strategic value
	prioritize_defense_targets(&defense_targets, gc, &pro_data)
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized defense targets:")
		for target in defense_targets {
			fmt.printf("  - %s: priority=%.1f, defense_needed=%.1f\n",
				target.territory, target.priority, target.defense_needed)
		}
	}

	// Step 3: Move units to defend priority territories
	move_units_to_defense(&defense_targets, gc, &pro_data)

	// Step 4: Land fighters in safe territories
	land_fighters_noncombat(gc, &pro_data)

	// Step 5: Land bombers in safe territories
	land_bombers_noncombat(gc, &pro_data)

	// Step 6: Load transports with units for positioning (BEFORE land movement!)
	// This is critical: we need to load units BEFORE they walk away
	// Java does: move amphib units -> move empty transports -> move sea -> move land
	load_transports_noncombat(gc, &pro_data)

	// Step 6b: Stage and unload loaded transports to high-value destinations
	// This implements the missing NCM-030 to NCM-045 blocks from Java
	stage_and_unload_transports_noncombat(gc, &pro_data)

	// Step 6c: Move empty transports toward best loading territories
	// This implements NCM-038 to NCM-041 (Block 3 from Java moveUnitsToBestTerritories)
	move_empty_transports_to_loading(gc, &pro_data)

	// Step 7: Move remaining sea units to safe positions
	move_sea_units_noncombat(gc, &pro_data)

	// #region NCM-014 Capital Defense Loop
	// Step 8: Move land units with capital defense check
	// Java loops to ensure capital has local land superiority
	// If not, increases defenseRange and repeats unit movement
	capital := mm.capital[gc.cur_player]
	enemy_distance_to_capital := get_closest_enemy_land_distance(gc, capital)
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Capital %v, enemy distance: %d\n", capital, enemy_distance_to_capital)
	}
	
	// Capital defense loop - ensures capital has local superiority
	// Java: defenseRange starts at -1, only set if capital lacks superiority AFTER first move attempt
	defense_range := -1
	max_iterations := 3  // Prevent infinite loop
	
	for iteration := 0; iteration < max_iterations; iteration += 1 {
		// If defense_range > 0, boost values of territories near capital
		if defense_range > 0 {
			boost_territory_values_near_capital(gc, &pro_data, capital, defense_range)
			when ODIN_DEBUG {
				fmt.printf("[PRO-AI] Iteration %d: Boosted territory values within %d of capital\n",
					iteration, defense_range)
			}
		}
		
		// Move land units to consolidate
		move_land_units_noncombat(gc, &pro_data)
		
		// Check if capital has local land superiority AFTER moves
		// Java: if (enemyDistanceToMyCapital >= 2 && enemyDistanceToMyCapital <= 3 
		//           && defenseRange == -1 && !territoryHasLocalLandSuperiorityAfterMoves(...))
		if enemy_distance_to_capital >= 2 && enemy_distance_to_capital <= 3 && defense_range == -1 {
			has_superiority := territory_has_local_land_superiority(
				gc, capital, enemy_distance_to_capital, gc.cur_player)
			
			when ODIN_DEBUG {
				fmt.printf("[PRO-AI] Post-move capital superiority check: %v\n", has_superiority)
			}
			
			if !has_superiority {
				// Capital doesn't have superiority - set defense range and retry
				defense_range = enemy_distance_to_capital - 1
				when ODIN_DEBUG {
					fmt.println("[PRO-AI] Capital doesn't have local land superiority - entering defensive stance")
				}
				continue
			}
		}
		
		// Capital is safe or already tried with boost - exit loop
		break
	}
	// #endregion
	
	// #region NCM-066 to NCM-069: Move AA guns to protect valuable factories
	move_aa_guns_noncombat(gc, &pro_data)
	// #endregion
	
	debug_checks(gc)
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Completed non-combat move phase")
	}

	return true
}

// Boost territory values near capital to prioritize capital defense
// Java: ProNonCombatMoveAi.java - multiplies territoryValue by 10 for territories within range
boost_territory_values_near_capital :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, capital: Land_ID, defense_range: int) {
	// Use BFS to find all territories within defense_range of capital
	visited: Land_Bitset = {capital}
	current_frontier: Land_Bitset = {capital}
	
	// Set capital to a very high value (1000) to ensure units consolidate there
	// Using a fixed high value instead of multiplying (which would fail if value is 0)
	pro_data.land_territories[capital].value = 1000.0
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Boosted capital %v value to 1000.0\n", capital)
	}
	
	// BFS outward from capital
	for dist := 1; dist <= defense_range; dist += 1 {
		next_frontier: Land_Bitset = {}
		
		// For each territory in current frontier
		for land_id in current_frontier {
			// Check adjacent land territories
			adjacent := mm.l2l_1away_via_land_bitset[land_id] - visited
			for adj_land in adjacent {
				visited += {adj_land}
				next_frontier += {adj_land}
				
				// Set adjacent territory to high value (decreasing by distance)
				// Distance 1 = 500, Distance 2 = 250, etc.
				boost_value := 1000.0 / math.pow(2.0, f64(dist))
				pro_data.land_territories[adj_land].value = boost_value
				
				when ODIN_DEBUG {
					fmt.printf("[PRO-AI] Boosted territory %v value to %.1f (dist %d from capital)\n",
						adj_land, boost_value, dist)
				}
			}
		}
		
		current_frontier = next_frontier
	}
}

// Defense_Target represents a territory that needs defensive units
Defense_Target :: struct {
	territory:       Land_ID,
	enemy_threat:    f64, // Enemy attack strength
	current_defense: f64, // Current defensive strength
	defense_needed:  f64, // Additional defense needed
	strategic_value: f64, // Strategic importance (factory, capital, etc)
	priority:        f64, // Overall priority for defense
	is_capital:      bool,
	has_factory:     bool,
}

// Find territories that need defensive reinforcement
find_noncombat_defense_targets :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) -> [dynamic]Defense_Target {
	targets := make([dynamic]Defense_Target)
	my_team := mm.team[gc.cur_player]

	when ODIN_DEBUG {
		fmt.println("  [NONCOMBAT] Scanning all ALLIED territories for defense needs...")
	}

	// Check all ALLIED territories (not just player-owned)
	// Java: findLandMoveOptions uses Matches.isTerritoryAllied(player)
	for land_id in Land_ID {
		// Check if territory is allied (same team)
		if mm.team[gc.owner[land_id]] != my_team {
			continue
		}

		// Calculate enemy threat
		enemy_threat := calculate_enemy_threat(gc, to_air(land_id), pro_data)

		// Calculate current defense
		current_defense := calculate_current_defense(gc, to_air(land_id))

		// Calculate strategic value
		territory_value := calculate_territory_value(gc, land_id)
		// Check if this is the CURRENT player's capital (for 11x boost)
		is_my_capital := is_player_capital(gc, land_id, gc.cur_player)
		// Check if this is ANY capital (for 5x boost) - matches Java's getProductionAndIsCapital
		is_any_capital := is_any_players_capital_land(land_id)
		has_factory := gc.factory_prod[land_id] > 0

		strategic_value := territory_value
		// Apply Java's multipliers: (1 + 10*isMyCapital) * (1 + 4*isAnyCapital)
		strategic_value *= (1.0 + 10.0 * (is_my_capital ? 1.0 : 0.0))
		strategic_value *= (1.0 + 4.0 * is_any_capital)
		if has_factory {
			strategic_value *= 3.0
		}

		// Check if this territory needs defense:
		// 1. Has enemy threat AND insufficient defense
		// 2. OR is strategically important (factory/capital) with no units
		needs_defense := false
		defense_gap := 0.0

		if enemy_threat > 0 {
			// Under threat - check if we have enough defense
			if current_defense < enemy_threat * 1.2 {
				needs_defense = true
				defense_gap = enemy_threat * 1.2 - current_defense
			}
		}

		// CRITICAL FIX: Also defend strategically important empty territories
		// This handles the case where all units moved out during combat phase
		if current_defense < 4.0 && (has_factory || is_any_capital > 0 || territory_value >= 3) {
			// Weak or empty strategic territory - check if enemy could attack next turn
			if has_enemy_neighbors(gc, land_id) {
				needs_defense = true
				// Assume minimum threat for weak strategic territories
				defense_gap = max(8.0 - current_defense, enemy_threat * 1.2 - current_defense)

				when ODIN_DEBUG {
					fmt.printf(
						"    [DEFENSE] %v is WEAK (cur_def=%.1f) with strategic value (factory=%v, capital=%v, value=%.1f, has_enemy_neighbors=true)\n",
						land_id,
						current_defense,
						has_factory,
						is_any_capital > 0,
						territory_value,
					)
				}
			}
		}

		if !needs_defense {
			continue
		}

		target := Defense_Target {
			territory       = land_id,
			enemy_threat    = max(enemy_threat, 4.0), // Minimum assumed threat
			current_defense = current_defense,
			defense_needed  = defense_gap,
			strategic_value = strategic_value,
			is_capital      = is_any_capital > 0,  // True if ANY player's capital
			has_factory     = has_factory,
		}

		append(&targets, target)
	}

	return targets
}

// Note: has_enemy_neighbors moved to pro_matches.odin (MATCH-021)

// Calculate enemy threat to a territory
calculate_enemy_threat :: proc(gc: ^Game_Cache, air_id: Air_ID, pro_data: ^Pro_Data) -> f64 {
	threat := 0.0
	if (is_air_land(air_id)) {
		territory := to_land(air_id)
		// Count enemy units in adjacent territories
		// Simplified - would use map graph for proper adjacency
		for player in Player_ID {
			if player == gc.cur_player {
				continue
			}
			if mm.team[player] == mm.team[gc.cur_player] {
				continue
			}

			// Check for enemy land units
			for army_type in Idle_Army {
				count := gc.idle_armies[territory][player][army_type]
				threat += f64(count) * get_army_threat_value(army_type)
			}

			// Check for enemy air units
			for plane_type in Idle_Plane {
				count := gc.idle_land_planes[territory][player][plane_type]
				threat += f64(count) * get_plane_threat_value(plane_type)
			}
		}
	} else {
		// NCM-044: Sea zone enemy threat calculation
		sea := to_sea(air_id)
		canal_state := transmute(u8)gc.canals_open
		
		// Count enemy units in this zone and adjacent zones
		for player in Player_ID {
			if player == gc.cur_player do continue
			if mm.team[player] == mm.team[gc.cur_player] do continue
			
			// Direct threat in this sea zone
			threat += f64(gc.idle_ships[sea][player][.DESTROYER]) * 2.0
			threat += f64(gc.idle_ships[sea][player][.CRUISER]) * 3.0
			threat += f64(gc.idle_ships[sea][player][.BATTLESHIP]) * 4.0
			threat += f64(gc.idle_ships[sea][player][.BS_DAMAGED]) * 4.0
			threat += f64(gc.idle_ships[sea][player][.SUB]) * 2.0
			threat += f64(gc.idle_sea_planes[sea][player][.FIGHTER]) * 3.0
			threat += f64(gc.idle_sea_planes[sea][player][.BOMBER]) * 4.0
			
			// Threat from adjacent sea zones (can attack in 1 move)
			for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
				threat += f64(gc.idle_ships[adj_sea][player][.DESTROYER]) * 1.0  // Half threat (needs to move)
				threat += f64(gc.idle_ships[adj_sea][player][.CRUISER]) * 1.5
				threat += f64(gc.idle_ships[adj_sea][player][.BATTLESHIP]) * 2.0
				threat += f64(gc.idle_ships[adj_sea][player][.SUB]) * 1.0
			}
		}
	}

	return threat
}

// Get threat value for army types
get_army_threat_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF:
		return 1.0
	case .ARTY:
		return 2.0
	case .TANK:
		return 3.0
	case .AAGUN:
		return 0.5
	case:
		return 1.0
	}
}

// Get threat value for plane types
get_plane_threat_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER:
		return 3.0
	case .BOMBER:
		return 4.0
	case:
		return 2.0
	}
}

// Calculate current defensive strength
calculate_current_defense :: proc(gc: ^Game_Cache, air_id: Air_ID) -> f64 {
	defense := 0.0
	if (is_air_land(air_id)) {
		territory := to_land(air_id)
		// Count friendly units
		for army_type in Idle_Army {
			count := gc.idle_armies[territory][gc.cur_player][army_type]
			defense += f64(count) * get_army_defense_value(army_type)
		}

		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[territory][gc.cur_player][plane_type]
			defense += f64(count) * get_plane_defense_value(plane_type)
		}
	} else {
		// NCM-044: Sea zone defense calculation
		sea := to_sea(air_id)
		player := gc.cur_player
		
		// Count friendly ships
		defense += f64(gc.idle_ships[sea][player][.DESTROYER]) * 2.0
		defense += f64(gc.idle_ships[sea][player][.CRUISER]) * 3.0
		defense += f64(gc.idle_ships[sea][player][.BATTLESHIP]) * 4.0
		defense += f64(gc.idle_ships[sea][player][.BS_DAMAGED]) * 4.0
		defense += f64(gc.idle_ships[sea][player][.CARRIER]) * 2.0
		defense += f64(gc.idle_ships[sea][player][.SUB]) * 1.0
		
		// Count allied ships
		for ally in Player_ID {
			if ally == player do continue
			if mm.team[ally] != mm.team[player] do continue
			
			defense += f64(gc.idle_ships[sea][ally][.DESTROYER]) * 2.0
			defense += f64(gc.idle_ships[sea][ally][.CRUISER]) * 3.0
			defense += f64(gc.idle_ships[sea][ally][.BATTLESHIP]) * 4.0
			defense += f64(gc.idle_ships[sea][ally][.CARRIER]) * 2.0
		}
		
		// Count sea-based planes
		defense += f64(gc.idle_sea_planes[sea][player][.FIGHTER]) * 3.0
		defense += f64(gc.idle_sea_planes[sea][player][.BOMBER]) * 4.0
	}
	return defense
}

// NCM-044: Find safest sea zone for air unit landing
// Evaluates sea zones by enemy threat to find safest destination
find_safest_sea_zone :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, from_land: Land_ID, movement_range: u8) -> Maybe(Sea_ID) {
	/*
	From ProNonCombatMoveAi.java lines 1305-1350:
	Evaluates sea zones by enemy threat to find safest destination
	*/
	
	best_sea: Maybe(Sea_ID) = nil
	min_threat: f64 = math.F64_MAX
	canal_state := transmute(u8)gc.canals_open
	
	// Check all sea zones in range
	for sea in Sea_ID {
		// Check if in range
		distance := get_land_to_sea_distance(gc, from_land, sea, movement_range)
		if distance == 0 || distance > movement_range do continue
		
		// Must have carrier capacity
		if !has_carrier_capacity(gc, sea) do continue
		
		// Calculate threat
		threat := calculate_enemy_threat(gc, to_air(sea), pro_data)
		defense := calculate_current_defense(gc, to_air(sea))
		
		// Calculate safety score (lower is safer)
		// Account for our defense when evaluating
		strength_diff := threat - defense
		
		// Prefer sea zones with some defense
		if defense > 0 {
			strength_diff -= 5.0  // Bonus for having friendly forces
		}
		
		if strength_diff < min_threat {
			min_threat = strength_diff
			best_sea = sea
		}
	}
	
	return best_sea
}

// NCM-044 Helper: Find safest sea zone from sea zone start
find_safest_sea_zone_from_sea :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, from_sea: Sea_ID, movement_range: u8) -> Maybe(Sea_ID) {
	best_sea: Maybe(Sea_ID) = nil
	min_threat: f64 = math.F64_MAX
	
	// Check all sea zones in range
	for sea in Sea_ID {
		// Check if in range
		distance := get_sea_distance(gc, from_sea, sea, movement_range)
		if distance == 0 || distance > movement_range do continue
		
		// Must have carrier capacity
		if !has_carrier_capacity(gc, sea) do continue
		
		// Calculate threat
		threat := calculate_enemy_threat(gc, to_air(sea), pro_data)
		defense := calculate_current_defense(gc, to_air(sea))
		
		// Calculate safety score (lower is safer)
		strength_diff := threat - defense
		
		// Prefer sea zones with some defense
		if defense > 0 {
			strength_diff -= 5.0
		}
		
		if strength_diff < min_threat {
			min_threat = strength_diff
			best_sea = sea
		}
	}
	
	return best_sea
}

// Get defense value for army types
get_army_defense_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF:
		return INFANTRY_DEFENSE
	case .ARTY:
		return ARTILLERY_DEFENSE
	case .TANK:
		return TANK_DEFENSE
	case .AAGUN:
		return 0.5
	case:
		return 1.0
	}
}

// Get defense value for plane types
get_plane_defense_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER:
		return 4.0
	case .BOMBER:
		return 1.0
	case:
		return 2.0
	}
}

// Check if territory is a player's capital
is_player_capital :: proc(gc: ^Game_Cache, territory: Land_ID, player: Player_ID) -> bool {
	capital_maybe := get_capital_territory(player)
	if capital_maybe == nil {
		return false
	}
	return capital_maybe.? == territory
}

// Check if territory is ANY player's capital (returns 1.0 or 0.0 for multiplier use)
// Matches Java's TerritoryAttachment.isCapital() check in getProductionAndIsCapital
is_any_players_capital_land :: proc(land: Land_ID) -> f64 {
	for player in Player_ID {
		if mm.capital[player] == land {
			return 1.0
		}
	}
	return 0.0
}

// Prioritize defense targets by strategic importance
prioritize_defense_targets :: proc(
	targets: ^[dynamic]Defense_Target,
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) {
	/*
	From ProNonCombatMoveAi.java prioritizeDefendOptions (lines 520-645):
	
	Calculates territory value using:
	territoryValue = unitOwnerMultiplier * 
	                 (2.0 * production + 10.0 * isFactory + 0.5 * cantMoveUnitValue + 0.5 * neighborValue) *
	                 (1 + 10.0 * isMyCapital) *
	                 (1 + 4.0 * isEnemyCapital)
	
	Then FILTERS territories removing those with:
	- isNotFactoryAndHasNoEnemyNeighbors (THIS IS KEY!)
	- Other conditions (can't hold, should hold, etc.)
	*/
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritizing defense targets...")
	}

	
	my_team := mm.team[gc.cur_player]
	
	// Calculate priority for each target using TripleA's formula
	for &target in targets {
		when ODIN_DEBUG {
			fmt.printf("  [DEFENSE] Evaluating %v\n", target.territory)
		}
		land_id := target.territory
		
		// Determine production value
		production := f64(gc.factory_prod[land_id])
		
		// Determine if it has a factory
		is_factory := target.has_factory ? 1.0 : 0.0
		
		// Determine if it is my capital
		is_my_capital := target.is_capital ? 1.0 : 0.0
		
		// Determine if it is ANY capital (enemy OR allied) - matches Java's getProductionAndIsCapital
		// Java uses ta.isCapital() which is true for ALL capitals regardless of owner
		is_any_capital := is_any_players_capital_land(land_id)
		
		// Calculate neighbor value (sum of adjacent territory production)
		neighbor_value := 0.0
		for neighbor in sa.slice(&mm.l2l_1away_via_land[land_id]) {
			neighbor_production := f64(gc.factory_prod[neighbor])
			if mm.team[gc.owner[neighbor]] == my_team {
				// Allied territories count at 10%
				neighbor_value += neighbor_production * 0.1
			} else {
				// Enemy/neutral territories count at 100%
				neighbor_value += neighbor_production
			}
		}
		
		// Determine defending unit value (cant move units)
		cant_move_unit_value := target.current_defense
		
		// Calculate territory value using TripleA formula
		territory_value := (2.0 * production + 
			10.0 * is_factory + 
			0.5 * cant_move_unit_value + 
			0.5 * neighbor_value) *
			(1.0 + 10.0 * is_my_capital) *
			(1.0 + 4.0 * is_any_capital)  // Fixed: Use is_any_capital (not just enemy) per Java
		
		target.priority = territory_value
		target.strategic_value = territory_value
	}

	// CRITICAL: Filter out territories that shouldn't be defended
	// This is what makes Germany (capital) get removed, allowing Poland to be chosen!
	filtered := make([dynamic]Defense_Target, 0, len(targets))
	defer delete(filtered)
	
	for target in targets {
		land_id := target.territory
		has_factory := target.has_factory
		has_enemy_neighbors := has_enemy_neighbors(gc, land_id)
		is_capital := target.is_capital
		
		// Remove if: not a factory AND no enemy neighbors (matches isNotFactoryAndHasNoEnemyNeighbors)
		is_not_factory_and_has_no_enemy_neighbors := !has_enemy_neighbors //&& !has_factory
		
		when ODIN_DEBUG {
			fmt.printf(
				"  [FILTER] Considering %v (value=%.2f): factory=%v, enemyNeighbors=%v, capital=%v\n",
				land_id, target.priority, has_factory, has_enemy_neighbors, is_capital,
			)
		}

		if is_not_factory_and_has_no_enemy_neighbors { //&& !is_capital {
			when ODIN_DEBUG {
				fmt.printf(
					"  [FILTER] Removing %v (value=%.2f): no enemy neighbors\n",
					land_id, target.priority,
				)
			}
			continue
		}
		
		append(&filtered, target)
	}

	// fmt.println("---[PRO-AI] Prioritized defense targets:")
	// for target in filtered {
	// 	fmt.printf("  - %s: priority=%.1f, defense_needed=%.1f\n",
	// 		target.territory, target.priority, target.defense_needed)
	// }

	// targets^ = filtered

	//clear targets and reappend from filtered list
	clear(targets)
	for target in filtered {
		append(targets, target)
	}

	// Sort by priority (highest first)
	slice.sort_by(targets[:], proc(a, b: Defense_Target) -> bool {
		return a.priority > b.priority
	})

	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized defense targets (after filtering):")
		for target, i in targets {
			if i >= 10 {break} 	// Show top 10
			fmt.printf(
				"  %d. %v: value=%.1f, factory=%v, capital=%v, enemyNeighbors=%v\n",
				i + 1,
				target.territory,
				target.priority,
				target.has_factory,
				target.is_capital,
				has_enemy_neighbors(gc, target.territory),
			)
		}
	}
}

// Move units to defend priority territories
move_units_to_defense :: proc(
	targets: ^[dynamic]Defense_Target,
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) {
	/*
	Move units to defensive positions:
	1. Initialize moved units tracker
	2. For each high-priority target needing defense
	3. Find nearby units that can reach
	4. Move units until defense requirement met
	5. NCM-025: For coastal territories, also consider amphib defense
	*/

	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)

	// For each high priority target, find nearby units that can move there
	for &target in targets {
		if target.defense_needed <= 0 {
			continue
		}

		// Find land units that can reach this territory
		units_moved := move_nearby_units_to_defense(
			gc,
			target.territory,
			target.defense_needed,
			&moved,
		)
		
		// Track remaining defense needed after land reinforcement
		remaining_defense := target.defense_needed - f64(units_moved) * 2.0  // Approximate

		// NCM-025: If still need defense and territory is coastal, try amphib defense
		if remaining_defense > 0 && is_land_adjacent_to_sea(target.territory) {
			amphib_units := move_amphib_defenders_to_territory(
				gc,
				target.territory,
				remaining_defense,
				&moved,
				pro_data,
			)
			units_moved += amphib_units
		}

		when ODIN_DEBUG {
			if units_moved > 0 {
				fmt.printf(
					"[PRO-AI] Moved %d units to defend territory %v\n",
					units_moved,
					target.territory,
				)
			}
		}
	}
}

// Move nearby units to defend a territory
move_nearby_units_to_defense :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	defense_needed: f64,
	moved: ^Moved_Units,
) -> int {
	/*
	Find and move units to defend a territory:
	1. Check adjacent territories for friendly units
	2. Prioritize: Infantry < Artillery < Tanks
	3. Move units until defense requirement met
	4. Use map graph for adjacency checking
	*/

	units_moved := 0
	defense_provided := f64(0)

	// Check all adjacent land territories
	for adjacent in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if gc.owner[adjacent] != gc.cur_player do continue
		if adjacent == territory do continue

		// Try to move infantry first (most expendable)
		// inf_available := get_available_unit_count(gc, adjacent, .INF, moved)
		inf_available := gc.active_armies[adjacent][.INF_1_MOVES]
		if inf_available > 0 && defense_provided < defense_needed {
			inf_to_move := min(inf_available, u8((defense_needed - defense_provided) / 2) + 1)

			success := execute_land_move(gc, adjacent, territory, .INF_1_MOVES, inf_to_move, moved)
			if success {
				units_moved += int(inf_to_move)
				defense_provided += f64(inf_to_move) * 2.0 // Infantry has 2 defense
			}
		}

		// Try artillery if still need defense
		if defense_provided < defense_needed {
			// arty_available := get_available_unit_count(gc, adjacent, .ARTY, moved)
			arty_available := gc.active_armies[adjacent][.ARTY_1_MOVES]
			if arty_available > 0 {
				arty_to_move := min(
					arty_available,
					u8((defense_needed - defense_provided) / 2) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .ARTY_1_MOVES, arty_to_move, moved)
				if success {
					units_moved += int(arty_to_move)
					defense_provided += f64(arty_to_move) * 2.0 // Artillery has 2 defense
				}
			}
		}

		// Try tanks if still need defense
		if defense_provided < defense_needed {
			// tank_available := get_available_unit_count(gc, adjacent, .TANK, moved)
			tank_available := gc.active_armies[adjacent][.TANK_1_MOVES]
			if tank_available > 0 {
				tank_to_move := min(
					tank_available,
					u8((defense_needed - defense_provided) / 3) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .TANK_1_MOVES, tank_to_move, moved)
				if success {
					units_moved += int(tank_to_move)
					defense_provided += f64(tank_to_move) * 3.0 // Tanks have 3 defense
				}
			}
			tank_available = gc.active_armies[adjacent][.TANK_2_MOVES]
			if tank_available > 0 {
				tank_to_move := min(
					tank_available,
					u8((defense_needed - defense_provided) / 3) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .TANK_2_MOVES, tank_to_move, moved)
				if success {
					units_moved += int(tank_to_move)
					defense_provided += f64(tank_to_move) * 3.0 // Tanks have 3 defense
				}
			}
		}

		// Stop if we've met defense requirement
		if defense_provided >= defense_needed {
			break
		}
	}

	// Check territories 2 moves away (tanks only - they have 2 movement)
	if defense_provided < defense_needed {
		for land_2_away in mm.l2l_2away_via_land_bitset[territory] {
			for midland in mm.l2l_2away_via_midland_bitset[territory][land_2_away] {
				if mm.team[gc.owner[midland]] != mm.team[gc.cur_player] do continue

				// Only tanks can move 2 spaces
				tank_available := get_available_unit_count(gc, land_2_away, .TANK, moved)
				if tank_available > 0 {
					tank_to_move := min(
						tank_available,
						u8((defense_needed - defense_provided) / 3) + 1,
					)

					// Note: Direct 2-move not supported by execute_land_move yet
					// Would need intermediate territory calculation
					// For now, skip 2-move tank movements

					success := execute_land_move(
						gc,
						land_2_away,
						territory,
						.TANK_2_MOVES,
						tank_to_move,
						moved,
					)
					if success {
						units_moved += int(tank_to_move)
						defense_provided += f64(tank_to_move) * 3.0
					}

					// if defense_provided >= defense_needed {
					// 	break
					// }
				}
			}

		}
	}

	return units_moved
}

// ============================================================================
// NCM-025 to NCM-028: AMPHIBIOUS DEFENSE
// ============================================================================

// NCM-025: Consider using transports to bring defenders via amphibious movement
// Called after land unit defense to consider transport-based reinforcement
move_amphib_defenders_to_territory :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	defense_needed: f64,
	moved: ^Moved_Units,
	pro_data: ^Pro_Data,
) -> int {
	/*
	NCM-025: Amphibious Defense Options
	From Java ProNonCombatMoveAi.java lines 860-950:
	
	1. Find transports that can reach sea zones adjacent to territory
	2. For each transport, find units that could be loaded
	3. Check if amphib landing would improve defense
	4. Execute amphib defense if beneficial
	
	This is used to reinforce threatened territories via sea when
	land reinforcement isn't sufficient.
	*/
	
	units_moved := 0
	defense_provided := f64(0)
	
	// Get sea zones adjacent to the territory (where transports can unload)
	adjacent_seas := sa.slice(&mm.l2s_1away_via_land[territory])
	if len(adjacent_seas) == 0 {
		return 0  // Not coastal, can't amphib defend
	}
	
	when ODIN_DEBUG {
		fmt.printf("  [AMPHIB-DEFENSE] Checking amphib defense for %v (need %.1f defense)\n",
			territory, defense_needed)
	}
	
	// NCM-026: Loop through sea zones and find transports
	for unload_sea in adjacent_seas {
		// Check if we control this sea zone (or can safely unload)
		if !is_sea_zone_safe_for_unload(gc, unload_sea) {
			continue
		}
		
		// Find loaded transports that can reach this sea zone
		for source_sea in Sea_ID {
			// Check if transport can reach unload_sea this turn
			can_reach := (source_sea == unload_sea) ||
				(unload_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][source_sea])
			
			if !can_reach {
				continue
			}
			
			// NCM-027: Find loaded transports at source_sea
			for trans_type in Idle_Transports {
				// Skip empty transports - they can't deliver defenders
				if trans_type == .TRANS_EMPTY {
					continue
				}
				
				count := gc.idle_ships[source_sea][gc.cur_player][trans_type]
				if count == 0 {
					continue
				}
				
				// This transport has units loaded - check if we should unload for defense
				defense_value := get_transport_defense_value(trans_type)
				
				if defense_value > 0 && defense_provided < defense_needed {
					// NCM-028: Execute amphib defense move
					// Move transport to unload_sea and unload at territory
					success := execute_amphib_defense_unload(
						gc, source_sea, unload_sea, territory, trans_type, moved)
					
					if success {
						units_moved += get_transport_unit_count(trans_type)
						defense_provided += defense_value
						
						when ODIN_DEBUG {
							fmt.printf("    [AMPHIB-DEFENSE] Moved transport %v from %v to unload at %v (defense: %.1f)\n",
								trans_type, source_sea, territory, defense_value)
						}
						
						if defense_provided >= defense_needed {
							return units_moved
						}
					}
				}
			}
		}
	}
	
	return units_moved
}

// NCM-028 Helper: Check if sea zone is safe for unloading defenders
is_sea_zone_safe_for_unload :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	// Check if there are enemy combat ships that would block unloading
	for enemy in Player_ID {
		if mm.team[enemy] == mm.team[gc.cur_player] {
			continue
		}
		
		// Check for enemy combat ships (subs can't block unloads)
		for ship in Idle_Ship {
			if ship == .SUB {
				continue  // Subs don't block
			}
			if gc.idle_ships[sea][enemy][ship] > 0 {
				return false  // Enemy combat ship present
			}
		}
	}
	return true
}

// NCM-027 Helper: Get defense value of units on a transport
get_transport_defense_value :: proc(trans_type: Idle_Ship) -> f64 {
	#partial switch trans_type {
	case .TRANS_1I:
		return 2.0  // 1 infantry = 2 defense
	case .TRANS_1A:
		return 2.0  // 1 artillery = 2 defense
	case .TRANS_1T:
		return 3.0  // 1 tank = 3 defense
	case .TRANS_2I:
		return 4.0  // 2 infantry = 4 defense
	case .TRANS_1I_1A:
		return 4.0  // 1 infantry + 1 artillery = 4 defense
	case .TRANS_1I_1T:
		return 5.0  // 1 infantry + 1 tank = 5 defense
	case:
		return 0.0  // Empty or unknown
	}
}

// NCM-027 Helper: Get number of units on a transport
get_transport_unit_count :: proc(trans_type: Idle_Ship) -> int {
	#partial switch trans_type {
	case .TRANS_1I, .TRANS_1A, .TRANS_1T:
		return 1
	case .TRANS_2I, .TRANS_1I_1A, .TRANS_1I_1T:
		return 2
	case:
		return 0
	}
}

// NCM-028 Helper: Execute an amphibious defense unload
execute_amphib_defense_unload :: proc(
	gc: ^Game_Cache,
	source_sea: Sea_ID,
	unload_sea: Sea_ID,
	target_land: Land_ID,
	trans_type: Idle_Ship,
	moved: ^Moved_Units,
) -> bool {
	/*
	Execute the amphib defense:
	1. Move transport from source_sea to unload_sea (if different)
	2. Unload units at target_land
	3. Convert transport to empty state
	*/
	
	// Validate we have the transport
	if gc.idle_ships[source_sea][gc.cur_player][trans_type] == 0 {
		return false
	}
	
	// Validate target land is friendly
	if mm.team[gc.owner[target_land]] != mm.team[gc.cur_player] {
		return false
	}
	
	// Decrement transport at source
	gc.idle_ships[source_sea][gc.cur_player][trans_type] -= 1
	
	// Determine what units are on transport and add them to target
	#partial switch trans_type {
	case .TRANS_1I:
		gc.idle_armies[target_land][gc.cur_player][.INF] += 1
	case .TRANS_1A:
		gc.idle_armies[target_land][gc.cur_player][.ARTY] += 1
	case .TRANS_1T:
		gc.idle_armies[target_land][gc.cur_player][.TANK] += 1
	case .TRANS_2I:
		gc.idle_armies[target_land][gc.cur_player][.INF] += 2
	case .TRANS_1I_1A:
		gc.idle_armies[target_land][gc.cur_player][.INF] += 1
		gc.idle_armies[target_land][gc.cur_player][.ARTY] += 1
	case .TRANS_1I_1T:
		gc.idle_armies[target_land][gc.cur_player][.INF] += 1
		gc.idle_armies[target_land][gc.cur_player][.TANK] += 1
	case:
		// Not a loaded transport
		gc.idle_ships[source_sea][gc.cur_player][trans_type] += 1  // Rollback
		return false
	}
	
	// Add empty transport to destination sea zone
	gc.idle_ships[unload_sea][gc.cur_player][.TRANS_EMPTY] += 1
	
	return true
}

// ============================================================================
// AIR UNIT LANDING LOGIC
// ============================================================================

// Air_Landing_Option represents a potential landing location for an air unit
Air_Landing_Option :: struct {
	territory:                Air_ID, // Where the plane could land
	is_water:                 bool, // Is this a carrier landing?
	carrier_id:               Maybe(u32), // Which carrier (if water landing)
	air_value:                f64, // Strategic value of landing here
	safety_score:             f64, // How safe is this location
	can_hold:                 bool, // Can territory be held
	has_factory:              bool, // Territory has factory
	is_capital:               bool, // Territory is capital
	is_allied:                bool, // Territory is allied (not owned)

	// Attack potential from this location
	num_sea_attack_options:   int,
	num_land_attack_options:  int,
	num_enemy_attack_options: int,
	num_nearby_enemies:       int,

	// Safety metrics
	enemy_threat:             f64,
	current_defense:          f64,
	win_percentage:           f64,
	tuv_swing:                f64,
	cant_hold_without_allies: bool,
}

// Air_Unit_To_Land represents a plane that needs to find a landing spot
Air_Unit_To_Land :: struct {
	plane_type:        Idle_Plane, // FIGHTER or BOMBER
	active_plane_type: Active_Plane,
	current_location:  Land_ID, // Where it is now
	movement_range:    int, // How far it can move
	options:           [dynamic]Air_Landing_Option, // Possible landing spots
}

// NCM-060: Block 11 - Land air units at safe territories with attack options
land_fighters_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing fighters in safe territories")
	}

	// From ProNonCombatMoveAi.java moveUnitsToBestTerritories() - Air units section
	land_air_units_noncombat(gc, pro_data, .FIGHTER)
}

// NCM-062: Block 12 - Land bombers at safest available territory
land_bombers_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing bombers in safe territories")
	}

	// From ProNonCombatMoveAi.java moveUnitsToBestTerritories() - Air units section
	land_air_units_noncombat(gc, pro_data, .BOMBER)
}

// Main air unit landing logic (handles both fighters and bombers)
land_air_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, plane_type: Idle_Plane) {
	/*
	From ProNonCombatMoveAi.java - moveUnitsToBestTerritories():
	
	ProLogger.info("Move air units");
	
	// Get list of territories that can't be held
	final List<Territory> territoriesThatCantBeHeld =
		moveMap.entrySet().stream()
			.filter(e -> !e.getValue().isCanHold())
			.map(Map.Entry::getKey)
			.collect(Collectors.toList());
	
	// Move air units to safe territory with most attack options
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		...
	}
	
	// Move air units to safest territory
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		...
	}
	*/

	// Step 1: Find all air units of this type that need landing
	when ODIN_DEBUG {
		fmt.printf("  [AIR] Find all air units of this type that need landing...\n")
	}
	air_units := find_air_units_needing_landing(gc, pro_data, plane_type)
	defer delete(air_units)

	if len(air_units) == 0 {
		return
	}

	when ODIN_DEBUG {
		fmt.printf("  [AIR] Found %d %v units needing landing\n", len(air_units), plane_type)
	}

	// Step 2: Find territories that can't be held (for attack value calculation)
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	defer delete(territories_cant_hold)

	// Step 3: For each air unit, find all valid landing options
	for &air_unit in air_units {
		find_air_landing_options(gc, pro_data, &air_unit, territories_cant_hold)
	}

	// Step 4: First pass - land in safe territories with most attack options
	land_air_units_to_best_attack_positions(gc, pro_data, &air_units)

	// Step 5: Second pass - land remaining units in safest available territory
	land_air_units_to_safest_territories(gc, pro_data, &air_units)

	// Step 6: Cleanup
	for air_unit in air_units {
		delete(air_unit.options)
	}
}

// Find all air units of a type that need landing
find_air_units_needing_landing :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	plane_type: Idle_Plane,
) -> [dynamic]Air_Unit_To_Land {
	units := make([dynamic]Air_Unit_To_Land)

	// Use the correct unlanded plane states based on plane type
	unlanded_planes: []Active_Plane
	movement_range: int
	if plane_type == .BOMBER {
		unlanded_planes = Unlanded_Bombers[:]
		movement_range = 6 // Bombers have 6 movement
	} else {
		unlanded_planes = Unlanded_Fighters[:]
		movement_range = 4 // Fighters have 4 movement
	}

	for plane in unlanded_planes {

		// Check all territories for idle planes
		for land_id in Land_ID {
			count := gc.active_land_planes[land_id][plane]
			if count == 0 {
				continue
			}

			// Create entries for each plane at this location
			for i in 0 ..< count {
				air_unit := Air_Unit_To_Land {
					plane_type        = plane_type,
					active_plane_type = plane,
					current_location  = land_id,
					movement_range    = movement_range,
					options           = make([dynamic]Air_Landing_Option),
				}
				append(&units, air_unit)
			}
		}
	}

	return units
}

// Find territories that can't be held
find_territories_that_cant_be_held :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) -> [dynamic]Land_ID {
	/*
	From ProNonCombatMoveAi.java:
	
	// Get list of territories that can't be held
	final List<Territory> territoriesThatCantBeHeld =
		moveMap.entrySet().stream()
			.filter(e -> !e.getValue().isCanHold())
			.map(Map.Entry::getKey)
			.collect(Collectors.toList());
	*/

	cant_hold := make([dynamic]Land_ID)

	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}

		// Calculate if we can hold this territory
		enemy_threat := calculate_enemy_threat(gc, to_air(land_id), pro_data)
		current_defense := calculate_current_defense(gc, to_air(land_id))

		// Can't hold if enemy threat exceeds defense by significant margin
		if enemy_threat > current_defense * 1.5 {
			append(&cant_hold, land_id)
		}
	}

	return cant_hold
}


// Calculate if territory can be held with the air unit
calculate_can_hold_with_air_unit :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	territory: Air_ID,
	plane_type: Idle_Plane,
) -> bool {
	enemy_threat := calculate_enemy_threat(gc, territory, pro_data)
	current_defense := calculate_current_defense(gc, territory)

	// Add air unit defense value
	air_defense := get_plane_defense_value(plane_type)
	total_defense := current_defense + air_defense

	// Can hold if defense meets threshold
	return total_defense >= enemy_threat * 1.2
}

// Calculate battle results for air unit landing
calculate_air_landing_battle_results :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	option: ^Air_Landing_Option,
	plane_type: Idle_Plane,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Check to see if the territory is safe
	final Collection<Unit> defendingUnits = proTerritory.getAllDefenders();
	defendingUnits.add(u);
	proTerritory.setBattleResultIfNull(
		() -> calc.calculateBattleResults(proData, proTerritory, defendingUnits));
	final ProBattleResult result = proTerritory.getBattleResult();
	...
	if (result.getWinPercentage() >= proData.getMinWinPercentage()
		|| result.getTuvSwing() > 0) {
		proTerritory.setCanHold(false);
		continue;
	}
	
	// Determine if territory can be held with owned units
	final List<Unit> myDefenders =
		CollectionUtils.getMatches(defendingUnits, Matches.unitIsOwnedBy(player));
	final ProBattleResult result2 =
		calc.calculateBattleResults(proData, proTerritory, myDefenders);
	int cantHoldWithoutAllies = 0;
	if (result2.getWinPercentage() >= proData.getMinWinPercentage()
		|| result2.getTuvSwing() > 0) {
		cantHoldWithoutAllies = 1;
	}
	*/

	// Simplified battle calculation
	air_defense := get_plane_defense_value(plane_type)
	total_defense := option.current_defense + air_defense

	// Estimate win percentage based on defense vs threat ratio
	if option.enemy_threat == 0 {
		option.win_percentage = 100.0
		option.tuv_swing = 0.0
	} else {
		ratio := total_defense / option.enemy_threat
		option.win_percentage = min(100.0, ratio * 50.0)
		option.tuv_swing = total_defense - option.enemy_threat
	}

	// Check if can hold without allies
	my_defense := calculate_current_defense(gc, option.territory)
	my_defense_with_air := my_defense + air_defense

	if option.enemy_threat > 0 {
		my_ratio := my_defense_with_air / option.enemy_threat
		my_win_pct := min(100.0, my_ratio * 50.0)

		// Can't hold without allies if win % is too low
		if my_win_pct < 70.0 || my_defense_with_air < option.enemy_threat {
			option.cant_hold_without_allies = true
		}
	}
}

// Calculate attack potential from landing location
calculate_air_attack_potential :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	option: ^Air_Landing_Option,
	air_unit: ^Air_Unit_To_Land,
	territories_cant_hold: [dynamic]Land_ID,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Find number of potential attack options next turn
	final int range = u.getMaxMovementAllowed();
	final Predicate<Territory> canMoveAirUnits =
		ProMatches.territoryCanMoveAirUnits(data, player, true);
	final Set<Territory> possibleAttackTerritories =
		data.getMap().getNeighbors(t, range / 2, canMoveAirUnits);
	final int numEnemyAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			ProMatches.territoryIsEnemyNotPassiveNeutralLand(player));
	final int numLandAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			ProMatches.territoryIsEnemyOrCantBeHeldAndIsAdjacentToMyLandUnits(
				player, territoriesThatCantBeHeld));
	final int numSeaAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			Matches.territoryHasEnemySeaUnits(player)
				.and(
					Matches.territoryHasUnitsThatMatch(
						Matches.unitHasSubBattleAbilities().negate())));
	final Set<Territory> possibleMoveTerritories =
		data.getMap()
			.getNeighbors(t, range, ProMatches.territoryCanMoveAirUnits(data, player, true));
	final int numNearbyEnemyTerritories =
		CollectionUtils.countMatches(
			possibleMoveTerritories, ProMatches.territoryIsEnemyNotPassiveNeutralLand(player));
	*/

	// Calculate attack range (half of movement for next turn planning)
	attack_range := air_unit.movement_range / 2
	full_range := air_unit.movement_range

	my_team := mm.team[gc.cur_player]

	// Count enemy territories within attack range
	// TODO: Use proper map graph for neighbor calculation
	// For now, use simplified adjacency

	num_enemy := 0
	num_land_attack := 0
	num_sea_attack := 0
	num_nearby := 0

	for land_id in Land_ID {
		owner := gc.owner[land_id]

		// Check if enemy territory
		if mm.team[owner] != mm.team[gc.cur_player] {
			// TODO: Calculate actual distance with map graph
			// For now, count all enemy territories
			num_enemy += 1

			// Check if it's a land attack target
			// (enemy or can't be held and adjacent to our units)
			is_cant_hold := false
			for cant_hold in territories_cant_hold {
				if cant_hold == land_id {
					is_cant_hold = true
					break
				}
			}

			if is_cant_hold {
				num_land_attack += 1
			}
		}
	}

	// Count sea attack options
	// TODO: Check sea zones for enemy ships

	option.num_enemy_attack_options = num_enemy
	option.num_land_attack_options = num_land_attack
	option.num_sea_attack_options = num_sea_attack
	option.num_nearby_enemies = num_nearby
}

// Calculate overall air value for landing location
calculate_air_value :: proc(option: ^Air_Landing_Option) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Check if number of attack territories and value are max
	final int isntFactory = ProMatches.territoryHasInfraFactoryAndIsLand().test(t) ? 0 : 1;
	final int hasOwnedCarrier =
		proTerritory.getAllDefenders().stream().anyMatch(ProMatches.unitIsOwnedCarrier(player))
			? 1
			: 0;
	final double airValue =
		(200.0 * numSeaAttackTerritories
				+ 100.0 * numLandAttackTerritories
				+ 10.0 * numEnemyAttackTerritories
				+ numNearbyEnemyTerritories)
			/ (1 + cantHoldWithoutAllies)
			/ (1 + (double) cantHoldWithoutAllies * isntFactory)
			* (1 + hasOwnedCarrier);
	*/

	isnt_factory := option.has_factory ? 0.0 : 1.0
	has_owned_carrier := 0.0 // TODO: Detect carriers
	cant_hold_allies := option.cant_hold_without_allies ? 1.0 : 0.0

	option.air_value =
		(200.0 * f64(option.num_sea_attack_options) +
			100.0 * f64(option.num_land_attack_options) +
			10.0 * f64(option.num_enemy_attack_options) +
			f64(option.num_nearby_enemies)) /
		(1.0 + cant_hold_allies) /
		(1.0 + cant_hold_allies * isnt_factory) *
		(1.0 + has_owned_carrier)

	// Calculate safety score
	if option.enemy_threat > 0 {
		option.safety_score = option.current_defense / option.enemy_threat
	} else {
		option.safety_score = 100.0
	}
}

// NCM-061: for (Unit air) loop - land units to best attack positions (first pass)
land_air_units_to_best_attack_positions :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	air_units: ^[dynamic]Air_Unit_To_Land,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Move air units to safe territory with most attack options
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		double maxAirValue = 0;
		Territory maxTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			...
			if (airValue > maxAirValue) {
				maxAirValue = airValue;
				maxTerritory = t;
			}
		}
		if (maxTerritory != null) {
			...
			moveMap.get(maxTerritory).addUnit(u);
			...
			it.remove();
		}
	}
	*/

	moved := make([dynamic]int)
	defer delete(moved)

	// #region NCM-061: for (Unit air) loop - find best attack position for each air unit
	for air_unit, idx in air_units {
		max_air_value := 0.0
		best_option_idx := -1

		// Find option with highest air value that can be held
		for option, i in air_unit.options {
			if !option.can_hold {
				continue
			}

			if option.air_value > max_air_value {
				max_air_value = option.air_value
				best_option_idx = i
			}
		}

		if best_option_idx >= 0 {
			best := air_unit.options[best_option_idx]

			when ODIN_DEBUG {
				fmt.printf(
					"  [AIR] %v landing at %v (airValue=%.1f, seaAttacks=%d, landAttacks=%d)\n",
					air_unit.plane_type,
					best.territory,
					best.air_value,
					best.num_sea_attack_options,
					best.num_land_attack_options,
				)
			}
			gc.current_territory = to_air(air_unit.current_location)
			gc.current_active_unit = to_unit(air_unit.active_plane_type)
			// Use correct move function based on plane type
			if air_unit.plane_type == .BOMBER {
				move_bomber_from_land_to_land(gc, to_action(best.territory))
			} else {
				move_fighter_from_land_to_land(gc, to_action(best.territory))
			}
			append(&moved, idx)
		}
	}
	// #endregion NCM-061

	// Remove moved units (in reverse to preserve indices)
	for i := len(moved) - 1; i >= 0; i -= 1 {
		idx := moved[i]
		ordered_remove(air_units, idx)
	}
}

// NCM-063: for (Unit air) loop - land units to safest territories (fallback pass)
land_air_units_to_safest_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	air_units: ^[dynamic]Air_Unit_To_Land,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Move air units to safest territory
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		double minStrengthDifference = Double.POSITIVE_INFINITY;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			...
			final double strengthDifference =
				ProBattleUtils.estimateStrengthDifference(t, attackers, defenders);
			...
			if (strengthDifference < minStrengthDifference) {
				minStrengthDifference = strengthDifference;
				minTerritory = t;
			}
		}
		if (minTerritory != null) {
			...
			moveMap.get(minTerritory).addUnit(u);
			it.remove();
		}
	}
	*/

	// #region NCM-063: for (Unit air) loop - find safest landing for each remaining air unit
	for air_unit in air_units {
		min_strength_diff := math.F64_MAX
		best_option_idx := -1

		// Find safest option (best strength difference)
		for option, i in air_unit.options {
			// Calculate strength difference
			strength_diff :=
				option.enemy_threat -
				(option.current_defense + get_plane_defense_value(air_unit.plane_type))

			if strength_diff < min_strength_diff {
				min_strength_diff = strength_diff
				best_option_idx = i
			}
		}

		if best_option_idx >= 0 {
			best := air_unit.options[best_option_idx]

			when ODIN_DEBUG {
				fmt.printf(
					"  [AIR] %v landing at SAFE %v (strengthDiff=%.1f)\n",
					air_unit.plane_type,
					best.territory,
					min_strength_diff,
				)
			}

			gc.current_territory = to_air(air_unit.current_location)
			gc.current_active_unit = to_unit(air_unit.active_plane_type)
			// Use correct move function based on plane type
			if air_unit.plane_type == .BOMBER {
				move_bomber_from_land_to_land(gc, to_action(best.territory))
			} else {
				move_fighter_from_land_to_land(gc, to_action(best.territory))
			}
		}
	}
	// #endregion NCM-063
}

// NCM-051 to NCM-053: Block 7 - Sea units to best location (strategic positioning)
// NCM-046 to NCM-050: Move sea units to defend transports and best locations
// From ProNonCombatMoveAi.java lines 1628-1720
move_sea_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving sea units (transport defense)")
	}
	
	player := gc.cur_player
	my_team := mm.team[player]
	
	// #region NCM-046: Build sea zones that need transport defense
	// Find all sea zones with transports that can be held
	transport_zones: Sea_Bitset = {}
	for sea in Sea_ID {
		if has_transports_at_sea(gc, sea, player) {
			// Check if this zone can potentially be held (not overwhelming enemy force)
			if can_hold_sea_zone_simple(gc, pro_data, sea) {
				transport_zones += {sea}
			}
		}
	}
	
	when ODIN_DEBUG {
		transport_count := card(transport_zones)
		fmt.printf("[PRO-AI] Found %d sea zones with transports needing defense\n", transport_count)
	}
	// #endregion NCM-046
	
	// #region NCM-047: Move sea combat units to defend transports
	// For each combat ship with moves, check if it can defend a transport zone
	Combat_Ships := [?]Active_Ship{
		.DESTROYER_2_MOVES, .CRUISER_2_MOVES, .BATTLESHIP_2_MOVES, .BS_DAMAGED_2_MOVES, .CARRIER_2_MOVES,
	}
	
	sea_units_moved := 0
	for ship_type in Combat_Ships {
		for src_sea in Sea_ID {
			// Process each ship of this type at this location
			for gc.active_ships[src_sea][ship_type] > 0 {
				// Find best transport zone this ship can reach
				best_sea: Maybe(Sea_ID) = nil
				best_defense_value: f64 = 0.0
				
				// Check if already at a transport zone
				if src_sea in transport_zones {
					if check_transport_defense(gc, pro_data, src_sea) {
						// Already defending transports here - mark as used
						move_combat_ship_0_moves(gc, src_sea, ship_type)
						sea_units_moved += 1
						continue
					}
				}
				
				// Check adjacent zones (1-2 moves away)
				for dst_sea in Sea_ID {
					if dst_sea not_in transport_zones {
						continue
					}
					
					distance := get_sea_distance(gc, src_sea, dst_sea, 2)
					if distance == 0 || distance > 2 {
						continue
					}
					
					// Check if moving here would help defense
					if check_transport_defense_with_unit(gc, pro_data, dst_sea, ship_type) {
						transport_count := count_transports_at_sea(gc, dst_sea, player)
						sea_value := get_sea_zone_value(gc, pro_data, dst_sea)
						defense_value := f64(transport_count) * 10.0 + sea_value
						
						if defense_value > best_defense_value {
							best_defense_value = defense_value
							best_sea = dst_sea
						}
					}
				}
				
				// Move to best defending position if found
				if best, ok := best_sea.?; ok {
					move_combat_ship_to_sea(gc, src_sea, best, ship_type)
					sea_units_moved += 1
					when ODIN_DEBUG {
						fmt.printf("  Sea unit %v moved from %v to defend transports at %v\n", 
						           ship_type, src_sea, best)
					}
				} else {
					// Can't find transport to defend - mark as 0 moves for Block 7
					move_combat_ship_0_moves(gc, src_sea, ship_type)
				}
			}
		}
	}
	// #endregion NCM-047
	
	// #region NCM-049: Move air units (fighters) to carriers defending transports
	// For each unmoved fighter on land/sea, check if it can land on a carrier in transport zone
	air_units_moved := 0
	
	// Check land-based fighters
	for src_land in Land_ID {
		for gc.active_land_planes[src_land][.FIGHTER_2_MOVES] > 0 {
			// Find best carrier in transport zone within range (4 moves)
			best_sea: Maybe(Sea_ID) = nil
			best_defense_value: f64 = 0.0
			
			for dst_sea in Sea_ID {
				if dst_sea not_in transport_zones {
					continue
				}
				
				// Check if in range (fighters have 4 movement)
				distance := get_land_to_sea_distance(gc, src_land, dst_sea, 4)
				if distance == 0 || distance > 4 {
					continue
				}
				
				// Check carrier capacity
				if !has_carrier_capacity(gc, dst_sea) {
					continue
				}
				
				// Check if adding fighter helps defense
				if check_transport_defense_with_fighter(gc, pro_data, dst_sea) {
					transport_count := count_transports_at_sea(gc, dst_sea, player)
					sea_value := get_sea_zone_value(gc, pro_data, dst_sea)
					defense_value := f64(transport_count) * 10.0 + sea_value
					
					if defense_value > best_defense_value {
						best_defense_value = defense_value
						best_sea = dst_sea
					}
				}
			}
			
			// Move fighter to carrier if found
			if best, ok := best_sea.?; ok {
				move_fighter_to_sea_defense(gc, src_land, best)
				air_units_moved += 1
				when ODIN_DEBUG {
					fmt.printf("  Fighter moved from %v to carrier at %v for transport defense\n", 
					           src_land, best)
				}
			} else {
				// Can't find carrier to land on - leave for land-based air moves
				break
			}
		}
	}
	
	// Check sea-based fighters (on carriers that may move)
	for src_sea in Sea_ID {
		for gc.active_sea_planes[src_sea][.FIGHTER_2_MOVES] > 0 {
			// Find best carrier in transport zone within range
			best_sea: Maybe(Sea_ID) = nil
			best_defense_value: f64 = 0.0
			
			// Already at transport zone with carrier
			if src_sea in transport_zones && has_carrier_capacity(gc, src_sea) {
				gc.active_sea_planes[src_sea][.FIGHTER_2_MOVES] -= 1
				gc.active_sea_planes[src_sea][.FIGHTER_0_MOVES] += 1
				air_units_moved += 1
				continue
			}
			
			for dst_sea in Sea_ID {
				if dst_sea not_in transport_zones {
					continue
				}
				
				// Check if in range (fighters have 4 movement)
				distance := get_sea_distance(gc, src_sea, dst_sea, 4)
				if distance == 0 || distance > 4 {
					continue
				}
				
				if !has_carrier_capacity(gc, dst_sea) {
					continue
				}
				
				if check_transport_defense_with_fighter(gc, pro_data, dst_sea) {
					transport_count := count_transports_at_sea(gc, dst_sea, player)
					sea_value := get_sea_zone_value(gc, pro_data, dst_sea)
					defense_value := f64(transport_count) * 10.0 + sea_value
					
					if defense_value > best_defense_value {
						best_defense_value = defense_value
						best_sea = dst_sea
					}
				}
			}
			
			if best, ok := best_sea.?; ok {
				move_fighter_sea_to_sea_defense(gc, src_sea, best)
				air_units_moved += 1
				when ODIN_DEBUG {
					fmt.printf("  Fighter moved from %v to %v for transport defense\n", src_sea, best)
				}
			} else {
				// Leave for other air movement
				break
			}
		}
	}
	// #endregion NCM-049
	
	// #region NCM-048/NCM-050: Move remaining sea units to best location
	// Block 7: Move remaining sea units to highest value location or safest
	Remaining_Combat_Ships := [?]Active_Ship{
		.DESTROYER_0_MOVES, .CRUISER_0_MOVES, .CRUISER_BOMBARDED,
		.BATTLESHIP_0_MOVES, .BATTLESHIP_BOMBARDED, 
		.BS_DAMAGED_0_MOVES, .BS_DAMAGED_BOMBARDED,
		.CARRIER_0_MOVES, .SUB_0_MOVES,
	}
	
	for ship_type in Remaining_Combat_Ships {
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship_type] == 0 {
				continue
			}
			
			// Already at good position - no movement needed for 0_MOVES ships
			// They stay in place
		}
	}
	// #endregion NCM-048/NCM-050
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Transport defense: %d sea units, %d air units moved\n", 
		           sea_units_moved, air_units_moved)
	}
}

// NCM-066 to NCM-069: Move AA guns to protect valuable factories
// From ProNonCombatMoveAi.java moveInfraUnits() lines 2195-2250
move_aa_guns_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving AA guns to protect factories")
	}
	
	player := gc.cur_player
	aa_moved := 0
	
	// #region NCM-067: Find AA guns that should move
	// Java: Only move AA from territories that can't be held and don't have factories
	for src_land in Land_ID {
		// Check if we have AA guns with moves here
		for gc.active_armies[src_land][.AAGUN_1_MOVES] > 0 {
			// Check if this territory can be held
			can_hold := can_territory_be_held(gc, pro_data, src_land)
			has_factory := gc.factory_prod[src_land] > 0 && gc.owner[src_land] == player
			
			// Only move AA from territories that can't be held and don't have factories
			// If territory has factory, AA should stay to protect it
			if can_hold || has_factory {
				// Skip this AA - territory is defensible or has factory
				gc.active_armies[src_land][.AAGUN_1_MOVES] -= 1
				gc.active_armies[src_land][.AAGUN_0_MOVES] += 1
				continue
			}
			
			// #region NCM-068: Find best factory to protect
			best_dest: Maybe(Land_ID) = nil
			best_value: f64 = 0.0
			
			// Check all territories within 1 move (AA has 1 movement)
			for dst_land in mm.l2l_1away_via_land_bitset[src_land] {
				// Must be owned by us
				if gc.owner[dst_land] != player {
					continue
				}
				
				// Check if destination can be held
				if !can_territory_be_held(gc, pro_data, dst_land) {
					continue
				}
				
				// Calculate value - prioritize factories without AA
				dst_has_factory := gc.factory_prod[dst_land] > 0
				dst_has_aa := gc.idle_armies[dst_land][player][.AAGUN] > 0
				
				value: f64 = f64(mm.value[dst_land])
				
				// Strong bonus for factories
				if dst_has_factory {
					value += 50.0
				}
				
				// Penalty if already has AA (want to spread out AA coverage)
				if dst_has_aa {
					value *= 0.01
				}
				
				// Check if this is better than current best
				if value > best_value {
					best_value = value
					best_dest = dst_land
				}
			}
			// #endregion NCM-068
			
			// #region NCM-069: Execute AA movement
			if dest, ok := best_dest.?; ok {
				// Move AA to destination
				move_aa_to_land(gc, src_land, dest)
				aa_moved += 1
				
				when ODIN_DEBUG {
					fmt.printf("  AA gun moved from %v to %v (value=%.1f)\n", src_land, dest, best_value)
				}
			} else {
				// No good destination - skip to 0 moves
				gc.active_armies[src_land][.AAGUN_1_MOVES] -= 1
				gc.active_armies[src_land][.AAGUN_0_MOVES] += 1
			}
			// #endregion NCM-069
		}
	}
	// #endregion NCM-067
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Moved %d AA guns\n", aa_moved)
	}
}

// NCM-067 Helper: Check if territory can be held
can_territory_be_held :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, land: Land_ID) -> bool {
	// Simple check: territory is owned by us and not overwhelmingly threatened
	player := gc.cur_player
	
	if gc.owner[land] != player {
		return false
	}
	
	my_team := mm.team[player]
	enemy_team := mm.enemy_team[player]
	
	// Count our units
	my_units: u8 = 0
	for army in gc.idle_armies[land][player] {
		my_units += army
	}
	for plane in gc.idle_land_planes[land][player] {
		my_units += plane
	}
	
	// Count enemy threat from adjacent
	enemy_threat: u8 = 0
	for adj_land in mm.l2l_1away_via_land_bitset[land] {
		enemy_threat += gc.team_land_units[adj_land][enemy_team]
	}
	
	// Can hold if we have defenders or minimal threat
	return my_units > 0 || enemy_threat < 5
}

// NCM-067 Helper: Move AA gun from source to destination
move_aa_to_land :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) {
	player := gc.cur_player
	
	// Remove from source
	gc.active_armies[src_land][.AAGUN_1_MOVES] -= 1
	gc.idle_armies[src_land][player][.AAGUN] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	// Add to destination  
	gc.active_armies[dst_land][.AAGUN_0_MOVES] += 1
	gc.idle_armies[dst_land][player][.AAGUN] += 1
	gc.team_land_units[dst_land][mm.team[player]] += 1
}

// NCM-046 Helper: Check if sea zone has transports
has_transports_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	// Check idle transports of any cargo state
	Transport_Types := [?]Idle_Ship{
		.TRANS_EMPTY, .TRANS_1I, .TRANS_1A, .TRANS_1T,
		.TRANS_2I, .TRANS_1I_1A, .TRANS_1I_1T,
	}
	for trans_type in Transport_Types {
		if gc.idle_ships[sea][player][trans_type] > 0 {
			return true
		}
	}
	return false
}

// NCM-046 Helper: Count transports at sea
count_transports_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	count := 0
	Transport_Types := [?]Idle_Ship{
		.TRANS_EMPTY, .TRANS_1I, .TRANS_1A, .TRANS_1T,
		.TRANS_2I, .TRANS_1I_1A, .TRANS_1I_1T,
	}
	for trans_type in Transport_Types {
		count += int(gc.idle_ships[sea][player][trans_type])
	}
	return count
}

// NCM-046 Helper: Check if sea zone can be held (not overwhelming enemy force)
can_hold_sea_zone_simple :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, sea: Sea_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	enemy_team := mm.enemy_team[gc.cur_player]
	canal_state := transmute(u8)gc.canals_open
	
	// Simple check: we have more defenders than enemies nearby
	my_combat_ships := gc.team_sea_units[sea][my_team]
	
	// Check adjacent enemy forces
	enemy_forces: u8 = 0
	for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
		enemy_forces += gc.team_sea_units[adj_sea][enemy_team]
	}
	
	// Can hold if we have defenders and not overwhelming enemy
	return my_combat_ships > 0 || enemy_forces < 5
}

// NCM-047 Helper: Check if transport defense is adequate
check_transport_defense :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, sea: Sea_ID) -> bool {
	// Simplified check: we have combat ships to defend transports
	player := gc.cur_player
	canal_state := transmute(u8)gc.canals_open
	
	// Count combat power
	combat_power: f64 = 0.0
	combat_power += f64(gc.idle_ships[sea][player][.DESTROYER]) * 2.0
	combat_power += f64(gc.idle_ships[sea][player][.CRUISER]) * 3.0
	combat_power += f64(gc.idle_ships[sea][player][.BATTLESHIP]) * 4.0
	combat_power += f64(gc.idle_ships[sea][player][.BS_DAMAGED]) * 4.0
	combat_power += f64(gc.idle_ships[sea][player][.CARRIER]) * 2.0
	
	// Also count fighters on carriers
	combat_power += f64(gc.idle_sea_planes[sea][player][.FIGHTER]) * 3.0
	
	// Count enemy threat from adjacent
	enemy_threat: f64 = 0.0
	for enemy in sa.slice(&mm.enemies[player]) {
		for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
			enemy_threat += f64(gc.idle_ships[adj_sea][enemy][.DESTROYER]) * 2.0
			enemy_threat += f64(gc.idle_ships[adj_sea][enemy][.CRUISER]) * 3.0
			enemy_threat += f64(gc.idle_ships[adj_sea][enemy][.BATTLESHIP]) * 4.0
			enemy_threat += f64(gc.idle_ships[adj_sea][enemy][.SUB]) * 2.0
		}
	}
	
	// Defense is adequate if combat power >= 50% of threat
	return combat_power >= enemy_threat * 0.5
}

// NCM-047 Helper: Check if adding unit would help transport defense
check_transport_defense_with_unit :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, sea: Sea_ID, ship_type: Active_Ship) -> bool {
	// Adding this ship improves defense
	// Simple check: return true if transport zone has transports to defend
	return has_transports_at_sea(gc, sea, gc.cur_player)
}

// NCM-049 Helper: Check if adding fighter would help transport defense
check_transport_defense_with_fighter :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, sea: Sea_ID) -> bool {
	// Adding fighter improves defense if there are carriers
	return has_transports_at_sea(gc, sea, gc.cur_player) && has_carrier_capacity(gc, sea)
}

// NCM-047 Helper: Get sea zone strategic value
// VAL-007 to VAL-011: Implements findSeaValue() from Java ProTerritoryValueUtils
get_sea_zone_value :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, sea: Sea_ID) -> f64 {
	/*
	Sea zone value calculation based on Java findSeaValue():
	VAL-007: Main entry
	VAL-008: Loop through sea zones
	VAL-009: Adjacent land value sum
	VAL-010: Transport route value
	VAL-011: Naval choke point bonus
	*/
	
	value: f64 = 0.0
	
	// VAL-009: Add value from adjacent land territories
	adjacent_lands := sa.slice(&mm.s2l_1away_via_sea[sea])
	for adj_land in adjacent_lands {
		land_value := f64(mm.value[adj_land])
		
		// Bonus for adjacent enemy territories (offensive value)
		if mm.team[gc.owner[adj_land]] != mm.team[gc.cur_player] {
			land_value *= 1.5  // Enemy territory is worth more
		}
		
		// Bonus for adjacent factories
		if gc.factory_prod[adj_land] > 0 {
			land_value += f64(gc.factory_prod[adj_land]) * 2.0
		}
		
		value += land_value
	}
	
	// VAL-010: Transport route value - bonus for being near friendly factories
	// Sea zones adjacent to factory territories are valuable for loading units
	for adj_land in adjacent_lands {
		if gc.owner[adj_land] == gc.cur_player && gc.factory_prod[adj_land] > 0 {
			value += f64(gc.factory_prod[adj_land]) * 3.0  // Strong bonus for factory-adjacent
		}
	}
	
	// VAL-011: Naval choke point bonus
	// Narrow passages (fewer connections) are more strategically valuable
	num_connections := card(mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][sea])
	if num_connections <= 2 {
		value *= 1.3  // 30% bonus for narrow passages
	} else if num_connections <= 3 {
		value *= 1.15  // 15% bonus for moderately restricted zones
	}
	
	// Bonus for canal-adjacent zones (strategic importance)
	// TODO: Check if this sea is adjacent to a canal
	
	return value
}

// NCM-047 Helper: Check if sea has carrier capacity for additional fighter
has_carrier_capacity :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	player := gc.cur_player
	
	// Count carriers (each has 2 capacity)
	carrier_capacity: int = 0
	carrier_capacity += int(gc.idle_ships[sea][player][.CARRIER]) * 2

	
	// Count allied carriers
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		carrier_capacity += int(gc.idle_ships[sea][ally][.CARRIER]) * 2
	}
	
	// Count fighters already on carriers
	fighter_count: int = 0
	fighter_count += int(gc.idle_sea_planes[sea][player][.FIGHTER])
	
	// Also count allied fighters
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		fighter_count += int(gc.idle_sea_planes[sea][ally][.FIGHTER])
	}
	
	return carrier_capacity > fighter_count
}

// TRN-001: Get unused carrier capacity in a sea zone
// Returns: number of additional fighters that can land (can be negative if overcrowded)
// From ProTransportUtils.java getUnusedCarrierCapacity() lines 363-377
get_unused_carrier_capacity :: proc(gc: ^Game_Cache, sea: Sea_ID) -> int {
	player := gc.cur_player
	
	// #region TRN-002: Count carriers (each has 2 capacity)
	carrier_capacity: int = 0
	carrier_capacity += int(gc.idle_ships[sea][player][.CARRIER]) * 2
	
	// Count allied carriers
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		carrier_capacity += int(gc.idle_ships[sea][ally][.CARRIER]) * 2
	}
	
	// Count fighters already on carriers
	fighter_count: int = 0
	fighter_count += int(gc.idle_sea_planes[sea][player][.FIGHTER])
	
	// Also count allied fighters
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		fighter_count += int(gc.idle_sea_planes[sea][ally][.FIGHTER])
	}
	// #endregion TRN-002
	
	return carrier_capacity - fighter_count
}

// TRN-003: Get unused carrier capacity within 2 sea zones
// Useful for checking if fighters can find a carrier to land on
// From ProTransportUtils.java getUnusedLocalCarrierCapacity() lines 327-360
get_unused_local_carrier_capacity :: proc(gc: ^Game_Cache, sea: Sea_ID) -> int {
	player := gc.cur_player
	canal_state := transmute(u8)gc.canals_open
	
	total_capacity: int = 0
	total_fighters: int = 0
	
	// #region TRN-004: Check current sea zone and 2-away neighbors
	// Current sea zone
	total_capacity += get_carrier_capacity_at_sea(gc, sea, player)
	total_fighters += get_fighter_count_at_sea(gc, sea, player)
	
	// 1-away sea zones
	for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
		total_capacity += get_carrier_capacity_at_sea(gc, adj_sea, player)
		total_fighters += get_fighter_count_at_sea(gc, adj_sea, player)
	}
	
	// 2-away sea zones
	for mid_sea in mm.s2s_1away_via_sea[canal_state][sea] {
		for far_sea in mm.s2s_1away_via_sea[canal_state][mid_sea] {
			if far_sea == sea {
				continue  // Already counted
			}
			// Check if already counted as 1-away
			already_counted := false
			for adj_sea in mm.s2s_1away_via_sea[canal_state][sea] {
				if far_sea == adj_sea {
					already_counted = true
					break
				}
			}
			if !already_counted {
				total_capacity += get_carrier_capacity_at_sea(gc, far_sea, player)
				total_fighters += get_fighter_count_at_sea(gc, far_sea, player)
			}
		}
	}
	// #endregion TRN-004
	
	return total_capacity - total_fighters
}

// TRN-003/004 Helper: Get carrier capacity at a specific sea zone
get_carrier_capacity_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	capacity: int = 0
	capacity += int(gc.idle_ships[sea][player][.CARRIER]) * 2
	
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		capacity += int(gc.idle_ships[sea][ally][.CARRIER]) * 2
	}
	
	return capacity
}

// TRN-003/004 Helper: Get fighter count at a specific sea zone
get_fighter_count_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	count: int = 0
	count += int(gc.idle_sea_planes[sea][player][.FIGHTER])
	
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player {
			continue
		}
		count += int(gc.idle_sea_planes[sea][ally][.FIGHTER])
	}
	
	return count
}

// TRN-017: Validate if carrier has capacity for additional fighter
// Returns true if there's room for one more fighter
// From ProTransportUtils.java validateCarrierCapacity() lines 304-321
validate_carrier_capacity :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	return get_unused_carrier_capacity(gc, sea) > 0
}

// TRN-017/018: Validate if carrier at sea zone can receive N more fighters
validate_carrier_capacity_for_count :: proc(gc: ^Game_Cache, sea: Sea_ID, additional_fighters: int) -> bool {
	return get_unused_carrier_capacity(gc, sea) >= additional_fighters
}

// TRN-021: Get count of allied fighters that can't land on carriers in a sea zone
// From ProTransportUtils.java getAirThatCantLandOnCarrier() lines 280-300
// Returns the number of excess fighters that have no carrier space
get_air_that_cant_land_on_carrier :: proc(gc: ^Game_Cache, sea: Sea_ID) -> int {
	unused_capacity := get_unused_carrier_capacity(gc, sea)
	if unused_capacity >= 0 {
		return 0  // All fighters can land
	}
	return -unused_capacity  // Return the overflow count
}

// TRN-022: Check if a specific number of fighters can find carrier space
// Includes checking adjacent sea zones for carriers that could pick them up
can_fighters_find_carrier_space :: proc(gc: ^Game_Cache, sea: Sea_ID, fighter_count: int) -> bool {
	local_capacity := get_unused_local_carrier_capacity(gc, sea)
	return local_capacity >= fighter_count
}

// NCM-047 Helper: Get distance between sea zones (BFS limited by max_distance)
get_sea_distance :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID, max_distance: u8) -> u8 {
	if src_sea == dst_sea {
		return 0
	}
	
	canal_state := transmute(u8)gc.canals_open
	
	// Check 1-away
	if dst_sea in mm.s2s_1away_via_sea[canal_state][src_sea] {
		return 1
	}
	
	if max_distance < 2 {
		return 0  // Not reachable
	}
	
	// Check 2-away
	for mid in mm.s2s_1away_via_sea[canal_state][src_sea] {
		if dst_sea in mm.s2s_1away_via_sea[canal_state][mid] {
			return 2
		}
	}
	
	return 0  // Not reachable within max_distance
}

// NCM-049 Helper: Get distance from land to sea (for fighter range)
get_land_to_sea_distance :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID, max_distance: u8) -> u8 {
	canal_state := transmute(u8)gc.canals_open
	
	// Check 1-away (land adjacent to sea)
	for adj_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		if adj_sea == dst_sea {
			return 1
		}
	}
	
	if max_distance < 2 {
		return 0
	}
	
	// Check 2-away through sea
	for mid_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		if dst_sea in mm.s2s_1away_via_sea[canal_state][mid_sea] {
			return 2
		}
	}
	
	if max_distance < 3 {
		return 0
	}
	
	// Check 3-away
	for mid_sea1 in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		for mid_sea2 in mm.s2s_1away_via_sea[canal_state][mid_sea1] {
			if dst_sea in mm.s2s_1away_via_sea[canal_state][mid_sea2] {
				return 3
			}
		}
	}
	
	if max_distance < 4 {
		return 0
	}
	
	// Check 4-away
	for mid_sea1 in sa.slice(&mm.l2s_1away_via_land[src_land]) {
		for mid_sea2 in mm.s2s_1away_via_sea[canal_state][mid_sea1] {
			for mid_sea3 in mm.s2s_1away_via_sea[canal_state][mid_sea2] {
				if dst_sea in mm.s2s_1away_via_sea[canal_state][mid_sea3] {
					return 4
				}
			}
		}
	}
	
	return 0
}

// NCM-047 Helper: Move combat ship to destination (uses all moves)
move_combat_ship_to_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID, ship_type: Active_Ship) {
	player := gc.cur_player
	
	// Get the idle type and 0_MOVES state
	idle_type := Active_Ship_To_Idle[ship_type]
	moved_type := Ships_Moved[ship_type]
	
	// Remove from source
	gc.active_ships[src_sea][ship_type] -= 1
	gc.idle_ships[src_sea][player][idle_type] -= 1
	gc.team_sea_units[src_sea][mm.team[player]] -= 1
	
	// Add to destination
	gc.active_ships[dst_sea][moved_type] += 1
	gc.idle_ships[dst_sea][player][idle_type] += 1
	gc.team_sea_units[dst_sea][mm.team[player]] += 1
	
	// #region NCM-064/065: If this is a carrier, move fighters with it
	// From ProNonCombatMoveAi.java moveAlliedCarriedFighters() lines 2161-2171
	// When a carrier moves, any fighters that would be stranded must move too
	if ship_type == .CARRIER_2_MOVES {
		move_carrier_fighters(gc, src_sea, dst_sea)
	}
	// #endregion NCM-064/065
}

// NCM-064/065: Move fighters that are on a carrier when the carrier moves
// Ensures fighters don't get stranded when their carrier moves away
// From ProNonCombatMoveAi.java moveAlliedCarriedFighters() lines 2161-2171
move_carrier_fighters :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	my_team := mm.team[player]
	
	// Calculate carrier capacity REMAINING at source after this carrier left
	// (carrier has already been removed from idle_ships[src_sea] at this point)
	remaining_capacity := 0
	for p in Player_ID {
		if mm.team[p] != my_team do continue
		remaining_capacity += int(gc.idle_ships[src_sea][p][.CARRIER]) * 2
	}
	
	// Count ALL fighters at source (across all active states and all allied players)
	// Fighters can be in any state: UNMOVED, 4_MOVES, 3_MOVES, 2_MOVES, 1_MOVES, 0_MOVES
	Fighter_States := [?]Active_Plane{
		.FIGHTER_UNMOVED, .FIGHTER_4_MOVES, .FIGHTER_3_MOVES,
		.FIGHTER_2_MOVES, .FIGHTER_1_MOVES, .FIGHTER_0_MOVES,
	}
	
	total_fighters := 0
	for p in Player_ID {
		if mm.team[p] != my_team do continue
		total_fighters += int(gc.idle_sea_planes[src_sea][p][.FIGHTER])
	}
	
	// Calculate excess fighters that need to move with carrier
	excess_fighters := total_fighters - remaining_capacity
	if excess_fighters <= 0 {
		return  // All fighters can stay on remaining carriers
	}
	
	// Move our fighters first, starting from lowest movement states
	// (0_MOVES fighters are most "committed" to staying, so move them last)
	// Actually, we should move fighters that have already used moves first
	Move_Priority := [?]Active_Plane{
		.FIGHTER_0_MOVES, .FIGHTER_1_MOVES, .FIGHTER_2_MOVES,
		.FIGHTER_3_MOVES, .FIGHTER_4_MOVES, .FIGHTER_UNMOVED,
	}
	
	fighters_moved := 0
	for state in Move_Priority {
		if fighters_moved >= excess_fighters do break
		
		fighters_in_state := int(gc.active_sea_planes[src_sea][state])
		fighters_to_move := min(fighters_in_state, excess_fighters - fighters_moved)
		
		if fighters_to_move > 0 {
			// Move these fighters from src to dst
			// They all become 0_MOVES since they moved with the carrier
			gc.active_sea_planes[src_sea][state] -= u8(fighters_to_move)
			gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += u8(fighters_to_move)
			
			gc.idle_sea_planes[src_sea][player][.FIGHTER] -= u8(fighters_to_move)
			gc.idle_sea_planes[dst_sea][player][.FIGHTER] += u8(fighters_to_move)
			
			gc.team_sea_units[src_sea][my_team] -= u8(fighters_to_move)
			gc.team_sea_units[dst_sea][my_team] += u8(fighters_to_move)
			
			fighters_moved += fighters_to_move
			
			when ODIN_DEBUG {
				fmt.printf("  [NCM-064] %d fighters (%v) moved with carrier from Sea_%d to Sea_%d\n",
				           fighters_to_move, state, int(src_sea), int(dst_sea))
			}
		}
	}
}

// NCM-047 Helper: Convert combat ship to 0_MOVES (stayed in place)
move_combat_ship_0_moves :: proc(gc: ^Game_Cache, sea: Sea_ID, ship_type: Active_Ship) {
	moved_type := Ships_Moved[ship_type]
	gc.active_ships[sea][ship_type] -= 1
	gc.active_ships[sea][moved_type] += 1
}

// NCM-049 Helper: Move fighter from land to sea for carrier defense
move_fighter_to_sea_defense :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove from land
	gc.active_land_planes[src_land][.FIGHTER_2_MOVES] -= 1
	gc.idle_land_planes[src_land][player][.FIGHTER] -= 1
	gc.team_land_units[src_land][mm.team[player]] -= 1
	
	// Add to sea
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	gc.idle_sea_planes[dst_sea][player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[player]] += 1
}

// NCM-049 Helper: Move fighter from sea to sea for carrier defense
move_fighter_sea_to_sea_defense :: proc(gc: ^Game_Cache, src_sea: Sea_ID, dst_sea: Sea_ID) {
	player := gc.cur_player
	
	// Remove from source sea
	gc.active_sea_planes[src_sea][.FIGHTER_2_MOVES] -= 1
	gc.idle_sea_planes[src_sea][player][.FIGHTER] -= 1
	gc.team_sea_units[src_sea][mm.team[player]] -= 1
	
	// Add to destination sea
	gc.active_sea_planes[dst_sea][.FIGHTER_0_MOVES] += 1
	gc.idle_sea_planes[dst_sea][player][.FIGHTER] += 1
	gc.team_sea_units[dst_sea][mm.team[player]] += 1
}

// NCM-038 to NCM-041: Block 3 - Move empty transports toward best loading territory
// From ProNonCombatMoveAi.java lines 1397-1510
move_empty_transports_to_loading :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	Java Algorithm (moveUnitsToBestTerritories, Block 3):
	
	For each empty transport that hasn't moved:
	1. Skip if already carrying units or has no moves left
	2. Calculate loadValue for each land territory with:
	   - Has a sea neighbor (coastal)
	   - Has transportable units OR has a factory
	   - Is reachable from current position
	   loadValue = territoryValue + 0.5*numTurnsAway - 0.1*numUnitsToLoad - 0.1*factoryProduction
	   Lower loadValue = better destination (factories and units reduce value)
	3. Sort territories by loadValue (ascending)
	4. Move transport toward territory with lowest loadValue if route is safe
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving empty transports toward loading positions")
	}
	
	player := gc.cur_player
	my_team := mm.team[player]
	transports_moved := 0
	
	// Build territory value map for loadValue calculation
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	territories_cant_hold_bitset: Land_Bitset = {}
	for land in territories_cant_hold[:] {
		territories_cant_hold_bitset += {land}
	}
	delete(territories_cant_hold)
	
	territory_value_map := find_territory_values_triplea(
		gc,
		gc.cur_player,
		territories_cant_hold_bitset,
		{},
		gc.friendly_owner,
	)
	defer delete(territory_value_map)
	
	// Process empty transports with moves remaining
	// TRANS_EMPTY_UNMOVED (2 moves) and TRANS_EMPTY_2_MOVES (loaded then unloaded)
	Empty_Trans_Types := [?]Active_Ship{.TRANS_EMPTY_UNMOVED, .TRANS_EMPTY_2_MOVES}
	
	for trans_type in Empty_Trans_Types {
		for src_sea in Sea_ID {
			// Process each empty transport at this location
			for gc.active_ships[src_sea][trans_type] > 0 {
				moved := move_one_empty_transport_to_loading(
					gc, pro_data, src_sea, trans_type, &territory_value_map, territories_cant_hold_bitset)
				
				if moved {
					transports_moved += 1
				} else {
					// Can't move this transport to any loading position
					// Skip it to 0 moves so we don't process forever
					gc.active_ships[src_sea][trans_type] -= 1
					gc.active_ships[src_sea][.TRANS_EMPTY_0_MOVES] += 1
				}
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("[PRO-AI] Moved %d empty transports toward loading positions\n", transports_moved)
	}
}

// Calculate loadValue for a territory (lower = better for loading)
calculate_load_value :: proc(
	gc: ^Game_Cache,
	land: Land_ID,
	src_sea: Sea_ID,
	distance: u8,
	territory_value_map: ^map[Land_ID]f64,
) -> f64 {
	player := gc.cur_player
	
	// Base territory value (from enemy-focused calculation)
	territory_value := territory_value_map[land] or_else 0.0
	
	// Calculate number of turns away (2 movement per turn for transports)
	max_moves_per_turn: u8 = 2
	num_turns_away: f64 = 0
	if distance > max_moves_per_turn {
		num_turns_away = f64((distance - 1) / max_moves_per_turn)
	}
	
	// Count transportable units at this territory (inf, arty, tanks)
	num_units_to_load: u8 = 0
	num_units_to_load += gc.idle_armies[land][player][.INF]
	num_units_to_load += gc.idle_armies[land][player][.ARTY]
	num_units_to_load += gc.idle_armies[land][player][.TANK]
	
	// Get factory production (if we own it and it wasn't conquered this turn)
	factory_production: u8 = 0
	if gc.owner[land] == player {
		factory_production = gc.factory_prod[land]
	}
	
	// Java formula: value = territoryValue + 0.5*numTurnsAway - 0.1*numUnitsToLoad - 0.1*factoryProduction
	// Lower value = better destination (factories and units make it more attractive)
	load_value := territory_value + 
		0.5 * num_turns_away - 
		0.1 * f64(num_units_to_load) - 
		0.1 * f64(factory_production)
	
	return load_value
}

// Move one empty transport toward the best loading territory
move_one_empty_transport_to_loading :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	src_sea: Sea_ID,
	trans_type: Active_Ship,
	territory_value_map: ^map[Land_ID]f64,
	territories_cant_hold: Land_Bitset,
) -> bool {
	player := gc.cur_player
	my_team := mm.team[player]
	
	// Structure to hold candidate loading territories
	Load_Candidate :: struct {
		land: Land_ID,
		sea_neighbor: Sea_ID, // Sea adjacent to this land
		load_value: f64,
		distance: u8, // Sea distance from src_sea
	}
	
	candidates: [dynamic]Load_Candidate
	defer delete(candidates)
	
	// Find all valid loading territories (friendly lands with sea access)
	for land in Land_ID {
		// Must be friendly
		if mm.team[gc.owner[land]] != my_team {
			continue
		}
		
		// Must have sea neighbor (coastal territory)
		if sa.len(mm.l2s_1away_via_land[land]) == 0 {
			continue
		}
		
		// Check if territory has units to load OR has a factory
		has_units := gc.idle_armies[land][player][.INF] > 0 ||
		             gc.idle_armies[land][player][.ARTY] > 0 ||
		             gc.idle_armies[land][player][.TANK] > 0
		has_factory := gc.factory_prod[land] > 0
		
		// Skip if no units and no factory (nothing to load now or in future)
		if !has_units && !has_factory {
			continue
		}
		
		// Find the closest sea neighbor we can reach
		best_sea_neighbor: Maybe(Sea_ID) = nil
		best_distance: u8 = 255
		
		for adj_sea in sa.slice(&mm.l2s_1away_via_land[land]) {
			// Calculate distance from src_sea to this adjacent sea
			distance := mm.sea_distances[transmute(u8)gc.canals_open][src_sea][adj_sea]
			
			// Skip if unreachable or if we're already there with units to load
			// (Java: distance > 0 && !(distance == 1 && hasUnits && !hasFactory))
			if distance == 255 {
				continue // Unreachable
			}
			if distance == 0 && has_units && !has_factory {
				continue // Already adjacent with units but no factory
			}
			
			if distance < best_distance {
				best_distance = distance
				best_sea_neighbor = adj_sea
			}
		}
		
		// If we found a reachable sea neighbor
		if sea_n, ok := best_sea_neighbor.?; ok {
			load_value := calculate_load_value(gc, land, src_sea, best_distance, territory_value_map)
			append(&candidates, Load_Candidate{
				land = land,
				sea_neighbor = sea_n,
				load_value = load_value,
				distance = best_distance,
			})
		}
	}
	
	if len(candidates) == 0 {
		return false
	}
	
	// Sort by load_value (ascending - lower is better)
	slice.sort_by(candidates[:], proc(a, b: Load_Candidate) -> bool {
		return a.load_value < b.load_value
	})
	
	// Try to move toward best loading territory
	for candidate in candidates {
		// Find path from src_sea to candidate.sea_neighbor
		target_sea := candidate.sea_neighbor
		
		if target_sea == src_sea {
			// Already at destination, no need to move
			// Just mark as 0 moves
			gc.active_ships[src_sea][trans_type] -= 1
			gc.active_ships[src_sea][.TRANS_EMPTY_0_MOVES] += 1
			return true
		}
		
		// Find next step toward target (up to 2 moves)
		// Check if we can reach in 1 move
		move_dst: Maybe(Sea_ID) = nil
		
		// 1 move away?
		if target_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
			// Check safety (no enemy blockade without escort)
			if is_sea_safe_for_transport(gc, target_sea) {
				move_dst = target_sea
			}
		} else {
			// Check 2 moves away - need intermediate step
			for mid_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
				if target_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][mid_sea] {
					// Can reach target via mid_sea - check if mid is safe
					if is_sea_safe_for_transport(gc, mid_sea) {
						// Move to mid_sea (1 step toward target)
						move_dst = mid_sea
						break
					}
				}
			}
			
			// If no path via mid, just try moving 1 step closer
			if move_dst == nil {
				for mid_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
					mid_dist := mm.sea_distances[transmute(u8)gc.canals_open][mid_sea][target_sea]
					src_dist := mm.sea_distances[transmute(u8)gc.canals_open][src_sea][target_sea]
					if mid_dist < src_dist && is_sea_safe_for_transport(gc, mid_sea) {
						move_dst = mid_sea
						break
					}
				}
			}
		}
		
		// Execute movement if we found a destination
		if dst, ok := move_dst.?; ok {
			// Safety check - make sure we actually have this transport
			if gc.active_ships[src_sea][trans_type] == 0 {
				return false
			}
			if gc.idle_ships[src_sea][player][.TRANS_EMPTY] == 0 {
				return false
			}
			
			// Move transport from src_sea to dst
			// Update active state
			gc.active_ships[src_sea][trans_type] -= 1
			gc.active_ships[dst][.TRANS_EMPTY_0_MOVES] += 1  // Used all moves
			
			// Update idle tracking
			gc.idle_ships[src_sea][player][.TRANS_EMPTY] -= 1
			gc.idle_ships[dst][player][.TRANS_EMPTY] += 1
			
			// Update team totals
			gc.team_sea_units[src_sea][mm.team[player]] -= 1
			gc.team_sea_units[dst][mm.team[player]] += 1
			
			when ODIN_DEBUG {
				fmt.printf("  Empty transport moved from %v to %v (toward %v for loading)\n",
					src_sea, dst, candidate.land)
			}
			
			return true
		}
	}
	
	return false
}

// Check if a sea zone is safe for transport movement (no enemy without escort)
is_sea_safe_for_transport :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	player := gc.cur_player
	my_team := mm.team[player]
	enemy_team := mm.enemy_team[player]
	
	// If no enemy presence, it's safe
	if gc.team_sea_units[sea][enemy_team] == 0 {
		return true
	}
	
	// If we have allied combat ships, it's safe (escorted)
	if gc.allied_sea_combatants_total[sea] > 0 {
		return true
	}
	
	// Enemy presence without escort - not safe
	return false
}

// Move land units to consolidate positions
move_land_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	From ProNonCombatMoveAi.java (lines 1842-1989):
	
	Three-pass algorithm:
	1. Move land units to territory with highest value and highest transport capacity
	2. Move land units towards nearest factory that is adjacent to the sea
	3. Move any remaining land units to safest territory (fallback)
	
	Territory values are calculated using find_territory_values_triplea() which computes
	value based on distance to ENEMY capitals/factories (not our own), matching Java's
	ProTerritoryValueUtils.findTerritoryValues().
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving land units to consolidate")
	}

	// Build territory value map based on distance to enemy capitals/factories
	// This matches Java: ProTerritoryValueUtils.findTerritoryValues(proData, player, 
	//   territoriesThatCantBeHeld, List.of(), territoriesToCheck)
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	territories_cant_hold_bitset: Land_Bitset = {}
	for land in territories_cant_hold[:] {
		territories_cant_hold_bitset += {land}
	}
	delete(territories_cant_hold)
	
	// All friendly territories are candidates for movement
	territories_to_check := gc.friendly_owner
	
	// Build the value map using enemy-focused calculation
	territory_value_map := find_territory_values_triplea(
		gc,
		gc.cur_player,
		territories_cant_hold_bitset,
		{}, // territories_to_attack is empty in non-combat
		territories_to_check,
	)
	defer delete(territory_value_map)
	
	// Apply capital defense boost if territories are marked as boosted in pro_data
	// This handles the capital defense loop's value boosting (matches Java lines 150-157)
	// Java: if (distance >= 0 && distance <= defenseRange) { value *= 10; }
	capital := mm.capital[gc.cur_player]
	for land in territories_to_check {
		boosted_value := pro_data.land_territories[land].value
		base_value := territory_value_map[land] or_else 0.0
		// If the pro_data has a high boost value set (from capital defense), use it
		// The boost sets values to 1000, 500, 250 etc. which are much higher than normal
		if boosted_value >= 100.0 {
			territory_value_map[land] = boosted_value
			when ODIN_DEBUG {
				fmt.printf("  [LAND] Applied capital defense boost to %v: %.1f -> %.1f\n",
					land, base_value, boosted_value)
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.println("  [LAND] Territory values (based on enemy targets):")
		for land, value in territory_value_map {
			if value > 0 {
				fmt.printf("    %v: %.1f\n", land, value)
			}
		}
	}

	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)

	// PASS 1: Move to high-value territories with transport capacity
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 1: Move to high-value territories near transports")
	}
	
	move_land_to_high_value_territories(gc, pro_data, &moved, &territory_value_map)
	debug_checks(gc)

	// PASS 2: Move towards coastal factories
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 2: Move towards coastal factories")
	}
	
	move_land_towards_coastal_factories(gc, pro_data, &moved)

	// PASS 3: Move remaining units to safest territory
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 3: Move remaining units to safety")
	}
	
	move_land_to_safest_territories(gc, pro_data, &moved)
}

// NCM-054: Block 8 - Move land units to high-value territories with transport capacity
move_land_to_high_value_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
	territory_value_map: ^map[Land_ID]f64,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1842-1904):
	
	// Move land units to territory with highest value and highest transport capacity
	// TODO: consider if territory ends up being safe
	final Predicate<Territory> canMoveSeaUnits = ProMatches.territoryCanMoveSeaUnits(player, true);
	final List<Unit> addedUnits = new ArrayList<>();
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		Territory maxValueTerritory = null;
		double maxValue = 0;
		int maxNeedAmphibUnitValue = Integer.MIN_VALUE;
		for (final Territory t : unitMoveMap.get(u)) {
			final ProTerritory proTerritory = moveMap.get(t);
			if (proTerritory.isCanHold() && proTerritory.getValue() >= maxValue) {
				// Find transport capacity of neighboring (distance 1) transports
				final Set<Territory> seaNeighbors = data.getMap().getNeighbors(t, canMoveSeaUnits);
				int transportCapacity1 = 0;
				for (Unit tr : ProTransportUtils.getTransports(player, moveMap, seaNeighbors)) {
					transportCapacity1 += tr.getUnitAttachment().getTransportCapacity();
				}
				
				// Find transport capacity of nearby (distance 2) transports
				final Set<Territory> nearbySeaTerritories =
					data.getMap().getNeighbors(t, 2, canMoveSeaUnits);
				nearbySeaTerritories.removeAll(seaNeighbors);
				int transportCapacity2 = 0;
				for (Unit tr : ProTransportUtils.getTransports(player, moveMap, nearbySeaTerritories)) {
					transportCapacity2 += tr.getUnitAttachment().getTransportCapacity();
				}
				final List<Unit> unitsToTransport =
					CollectionUtils.getMatches(
						proTerritory.getAllDefenders(), ProMatches.unitIsOwnedTransportableUnit(player));
				
				// Find transport cost of potential amphib units
				int transportCost = 0;
				for (final Unit unit : unitsToTransport) {
					transportCost += unit.getUnitAttachment().getTransportCost();
				}
				
				// Find territory that needs amphib units the most
				int hasFactory = 0;
				if (ProMatches.territoryHasInfraFactoryAndIsOwnedLandAdjacentToSea(player).test(t)) {
					hasFactory = 1;
				}
				final int neededNeighborTransportValue = Math.max(0, transportCapacity1 - transportCost);
				final int neededNearbyTransportValue =
					Math.max(0, transportCapacity1 + transportCapacity2 - transportCost);
				final int needAmphibUnitValue =
					1000 * neededNeighborTransportValue
						+ 100 * neededNearbyTransportValue
						+ (1 + 10 * hasFactory) * data.getMap().getNeighbors(t, canMoveSeaUnits).size();
				if (proTerritory.getValue() > maxValue || needAmphibUnitValue > maxNeedAmphibUnitValue) {
					maxValue = proTerritory.getValue();
					maxNeedAmphibUnitValue = needAmphibUnitValue;
					maxValueTerritory = t;
				}
			}
		}
		if (maxValueTerritory != null) {
			ProLogger.trace(
				String.format(
					"%s moved to %s with value=%s, needAmphibUnitValue=%s",
					u, maxValueTerritory, maxValue, maxNeedAmphibUnitValue));
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(maxValueTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	my_team := mm.team[gc.cur_player]
	
	// #region NCM-055: for (Unit land) loop - iterate land units to find optimal destinations
	for army in Unmoved_Armies {
		for src_land in Land_ID {
			// if gc.owner[src_land] != gc.cur_player {
			// 	continue
			// }

			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			
			// Get source territory value
			src_value := territory_value_map[src_land] or_else 0.0
			
			when ODIN_DEBUG {
				fmt.printf("    [PASS 1] Checking %d x %v at %v (src_value=%.1f)\n", 
					available, army, src_land, src_value)
			}
			
			// Find best destination considering value and transport capacity
			// Initialize with current position as default (stay in place if no better option)
			// This matches Java's approach of including current territory in move options
			best_territory := src_land
			best_value := src_value  // Start with source value, not 0
			best_amphib_value := calculate_amphib_value(gc, src_land)  // Include current amphib value
			destinations_checked := 0
			destinations_rejected := 0
			
			// Check all territories this unit can reach
			//if army == .TANK_2_MOVES do add_valid_army_moves_2(gc)

			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				destinations_checked += 1
				if !can_hold_destination(gc, pro_data, dst_land) {					
					destinations_rejected += 1
					when ODIN_DEBUG {
						fmt.printf("      -> %v: Cannot hold\n", dst_land)
					}
					continue
				}
				// Calculate transport capacity (amphib potential)
				amphib_value := calculate_amphib_value(gc, dst_land)
				
				// Get destination territory value from map
				dst_value := territory_value_map[dst_land] or_else 0.0
				
				when ODIN_DEBUG {
					fmt.printf("      -> %v: value=%.1f, amphib=%.1f\n", 
						dst_land, dst_value, amphib_value)
				}
				
				// Choose if better than current best
				// Only move if destination value is at least as good as source
				// This prevents moving from high-value to low-value territories
				// Amphib value is a tiebreaker when territory values are equal
				if dst_value > best_value || (dst_value == best_value && amphib_value > best_amphib_value) {
					best_value = dst_value
					best_amphib_value = amphib_value
					best_territory = dst_land
				}
			}
			
			when ODIN_DEBUG {
				fmt.printf("      Checked %d destinations, rejected %d, best=%v (value=%.1f)\n",
					destinations_checked, destinations_rejected, best_territory, best_value)
			}

			//TODO add tanks with 2 moves


			//todo game_cache bitset for is_boat_available large, small
			// for dst_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
			// 	idle_ships := &gc.idle_ships[dst_sea][gc.cur_player]
			// 	transport_available := false
			// 	for transport in Trans_Allowed_By_Army_Size[Army_Size[army]] {
			// 		if idle_ships[transport] > 0 {
			// 			transport_available = true
			// 			break
			// 		}
			// 	}
			// 	if !transport_available {
			// 		continue
			// 	}
			// }
			
			// Move unit to best destination
			if best_value > 0 {
				if best_territory != src_land {
					// success := execute_land_move(gc, src_land, best_land, army_type, 1, moved)
					gc.current_territory = to_air(src_land)
					gc.current_active_unit = to_unit(army)
					dst_action := to_action(best_territory)
					debug_checks(gc)
					next_state := blitz_checks(gc, dst_action)
					for _ in 0..<available {
						move_single_army_land(gc, dst_action, next_state)
						when ODIN_DEBUG {
							fmt.printf(
								"    [PASS 1] Moved %v from %v to %v (value: %.1f, amphib: %.1f)\n",
								army, src_land, best_territory, best_value, best_amphib_value,
							)
						}
					}
					debug_checks(gc)
				}
			}
		}
	}
	// #endregion NCM-055
}

// NCM-056: Block 9 - Move land units towards coastal factories
move_land_towards_coastal_factories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1910-1944):
	
	// Move land units towards nearest factory that is adjacent to the sea
	final Collection<Territory> myFactoriesAdjacentToSea =
		CollectionUtils.getMatches(
			data.getMap().getTerritories(),
			ProMatches.territoryHasInfraFactoryAndIsOwnedLandAdjacentToSea(player));
	final Predicate<Territory> canMoveLandUnits =
		ProMatches.territoryCanMoveLandUnits(player, true);
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		int minDistance = Integer.MAX_VALUE;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			if (!moveMap.get(t).isCanHold()) {
				continue;
			}
			for (final Territory factory : myFactoriesAdjacentToSea) {
				int distance = data.getMap().getDistance(t, factory, canMoveLandUnits);
				if (distance < 0) {
					distance = 10 * data.getMap().getDistance(t, factory);
				}
				if (distance >= 0 && distance < minDistance) {
					minDistance = distance;
					minTerritory = t;
				}
			}
		}
		if (minTerritory != null) {
			ProLogger.trace(
				u.getType().getName()
					+ " moved towards closest factory adjacent to sea at "
					+ minTerritory.getName());
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(minTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	// Find all our coastal factories
	coastal_factories := make([dynamic]Land_ID)
	defer delete(coastal_factories)
	
	for land_id in sa.slice(&gc.factory_locations[gc.cur_player]) {
		// Adjacent to sea?
		if is_land_adjacent_to_sea(land_id) {
			append(&coastal_factories, land_id)
		}
	}
	
	if len(coastal_factories) == 0 {
		return
	}
	
	when ODIN_DEBUG {
		fmt.printf("    Found %d coastal factories\n", len(coastal_factories))
	}
	
	// #region NCM-057: for (Unit land) loop - move units towards coastal factories
	for army in Unmoved_Armies {
		for src_land in Land_ID {
			// if gc.owner[src_land] != gc.cur_player {
			// 	continue
			// }
			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			// Find nearest coastal factory
			min_distance := max(u8)
			best_territory:= src_land
			
			// First calculate distance from current position to nearest factory
			src_to_factory_distance := max(u8)
			for factory in coastal_factories {
				dist := mm.air_distances[to_air(src_land)][to_air(factory)]
				if dist < src_to_factory_distance {
					src_to_factory_distance = dist
				}
			}
			
			// Check all reachable territories

			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				
				// Skip if can't hold
				if !can_hold_destination(gc, pro_data, dst_land) {
					continue
				}
				
				// Calculate distance from DESTINATION to nearest coastal factory
				for factory in coastal_factories {
					distance := mm.air_distances[to_air(dst_land)][to_air(factory)]
					
					// Only move if destination is closer to factory than current position
					if distance < min_distance && distance < src_to_factory_distance {
						min_distance = distance
						best_territory = dst_land
					}
				}
			}

			//TODO add tanks with 2 moves
			
			// Move towards coastal factory

			if best_territory != src_land {
				// success := execute_land_move(gc, src_land, best_land, army_type, 1, moved)
				gc.current_territory = to_air(src_land)
				gc.current_active_unit = to_unit(army)
				dst_action := to_action(best_territory)
				debug_checks(gc)
				next_state := blitz_checks(gc, dst_action)
				for _ in 0..<available {
					move_single_army_land(gc, dst_action, next_state)
					when ODIN_DEBUG {
						fmt.printf(
							"    [PASS 2] Moved %v from %v to %v (distance to factory: %d)\n",
							army, src_land, best_territory, min_distance,
						)
					}
				}
				debug_checks(gc)
			}
			// if best_territory != src_land {
			// 	success := execute_land_move(gc, src_land, best_territory, army, 1, moved)
			// 	when ODIN_DEBUG {
			// 		if success {
			// 			fmt.printf(
			// 				"    Moved %v from %v to %v (distance to factory: %d)\n",
			// 				army, src_land, best_territory, min_distance,
			// 			)
			// 		}
			// 	}
			// }
		}
	}
	// #endregion NCM-057
}

// NCM-058: Block 10 - Move land units to safest territories (fallback)
move_land_to_safest_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1950-1989):
	
	// Move any remaining land units to safest territory (this is rarely used)
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		
		// Get all units that have already moved
		final List<Unit> alreadyMovedUnits =
			moveMap.values().stream()
				.map(ProTerritory::getUnits)
				.flatMap(Collection::stream)
				.collect(Collectors.toList());
		
		// Find safest territory
		double minStrengthDifference = Double.POSITIVE_INFINITY;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			final ProTerritory proTerritory = moveMap.get(t);
			final List<Unit> attackers = proTerritory.getMaxEnemyUnits();
			final List<Unit> defenders = proTerritory.getMaxDefenders();
			defenders.removeAll(alreadyMovedUnits);
			defenders.addAll(proTerritory.getUnits());
			final double strengthDifference =
				ProBattleUtils.estimateStrengthDifference(t, attackers, defenders);
			if (strengthDifference < minStrengthDifference) {
				minStrengthDifference = strengthDifference;
				minTerritory = t;
			}
		}
		if (minTerritory != null) {
			ProLogger.debug(
				u.getType().getName()
					+ " moved to safest territory at "
					+ minTerritory.getName()
					+ " with strengthDifference="
					+ minStrengthDifference);
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(minTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	// #region NCM-059: for (Unit land) loop - move remaining units to safest territory
	for army in Unmoved_Armies {
		for src_land in Land_ID {
			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			// Find safest reachable territory
			min_strength_diff := math.F64_MAX
			best_territory:= src_land	
			
			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				// CRITICAL: Only consider FRIENDLY territories for non-combat move!
				if mm.team[gc.owner[dst_land]] != mm.team[gc.cur_player] {
					continue
				}
				
				// Calculate strength difference (attackers - defenders)
				enemy_threat := calculate_enemy_threat(gc, to_air(dst_land), pro_data)
				current_defense := calculate_current_defense(gc, to_air(dst_land))
				unit_defense := get_army_defense_value(Active_Army_To_Idle[army])
				
				strength_diff := enemy_threat - (current_defense + unit_defense)
				
				if strength_diff < min_strength_diff {
					min_strength_diff = strength_diff
					best_territory = dst_land
				}
			}
			
			// Don't move units AWAY from factory territories
			// Added factory check to prevent units leaving valuable factory locations
			if best_territory != src_land && gc.factory_prod[src_land] == 0 {
				gc.current_territory = to_air(src_land)
				gc.current_active_unit = to_unit(army)
				dst_action := to_action(best_territory)
				// debug_checks(gc)
				next_state := blitz_checks(gc, dst_action)
				for _ in 0..<available {
					move_single_army_land(gc, dst_action, next_state)
					when ODIN_DEBUG {
						fmt.printf(
							"    [PASS 3] Moved %v from %v to %v (strength diff: %.1f)\n",
							army, src_land, best_territory, min_strength_diff,
						)
					}
				}
				// debug_checks(gc)
			}

			// Move to safest territory
			// if best_territory != src_land {
			// 	success := execute_land_move(gc, src_land, best_territory, army, 1, moved)

			// 	when ODIN_DEBUG {
			// 		if success {
			// 			fmt.printf(
			// 				"    Moved %v from %v to %v (strength diff: %.1f)\n",
			// 				army, src_land, best_territory, min_strength_diff,
			// 			)
			// 		}
			// 	}
			// }
		}
	}
	// #endregion NCM-059
}

// ============================================================================
// HELPER FUNCTIONS FOR LAND MOVEMENT
// ============================================================================

// Calculate amphib value - how useful is this territory for amphibious assaults
calculate_amphib_value :: proc(gc: ^Game_Cache, land: Land_ID) -> f64 {
	/*
	From Java:
	final int needAmphibUnitValue =
		1000 * neededNeighborTransportValue
			+ 100 * neededNearbyTransportValue
			+ (1 + 10 * hasFactory) * data.getMap().getNeighbors(t, canMoveSeaUnits).size();
	*/
	
	// Check if has factory
	has_factory := gc.factory_prod[land] > 0
	factory_multiplier := has_factory ? 10.0 : 1.0
	
	// Simplified: Just count adjacent seas weighted by factory presence
	// Full implementation would count transport capacity at those seas
	amphib_value := factory_multiplier * f64(mm.l2s_1away_via_land[land].len)
	
	// TODO: Count actual transports in adjacent/nearby seas
	// For now, use simplified calculation
	
	return amphib_value
}

// Check if land territory is adjacent to sea
is_land_adjacent_to_sea :: proc(land: Land_ID) -> bool {
	return sa.len(mm.l2s_1away_via_land[land]) > 0
}

// Calculate distance between two land territories
// NCM-073: Uses precomputed BFS distances from mm.land_distances
calculate_land_distance :: proc(gc: ^Game_Cache, from: Land_ID, to: Land_ID) -> i32 {
	/*
	NCM-073/074: BFS pathfinding using precomputed distance matrix
	
	mm.land_distances is computed at map load time using Floyd-Warshall:
	- 0 = same territory
	- 1 = adjacent
	- 2+ = multi-hop distance
	- 127 = unreachable (different landmass)
	
	For ownership-aware pathfinding, we could add a secondary check,
	but for most AI purposes the raw distance is sufficient.
	*/
	
	LAND_INFINITY :: 127  // From land.odin
	dist := mm.land_distances[from][to]
	
	if dist == LAND_INFINITY {
		return 127  // Unreachable
	}
	
	return i32(dist)
}

// NCM-073: Find best path to territory using land routes (BFS)
// Returns the distance, or -1 if unreachable through friendly territory
find_best_path_to_territory :: proc(gc: ^Game_Cache, from: Land_ID, to: Land_ID) -> i32 {
	/*
	From Java ProAI.findBestPathToTerritoryUsingLandRoutes():
	
	NCM-074: BFS loop with distance tracking
	
	This version respects territory ownership - can only traverse
	territories owned by self or allies.
	
	Returns:
	- Distance if reachable through friendly territory
	- -1 if unreachable (blocked by enemy)
	*/
	
	LAND_INFINITY :: 127  // From land.odin
	
	if from == to {
		return 0
	}
	
	// Check if territories are on different landmasses
	if mm.land_distances[from][to] == LAND_INFINITY {
		return -1  // Different landmass - unreachable
	}
	
	// BFS to find shortest path through friendly territories
	visited: [len(Land_ID)]bool = {}
	distances: [len(Land_ID)]i32 = {}
	
	// Initialize distances to max
	for i in 0..<len(Land_ID) {
		distances[i] = 127
	}
	
	// Queue for BFS (use simple array as circular buffer)
	queue: [len(Land_ID)]Land_ID
	queue_head := 0
	queue_tail := 0
	
	// Start BFS from 'from'
	queue[queue_tail] = from
	queue_tail += 1
	visited[from] = true
	distances[from] = 0
	
	for queue_head != queue_tail {
		current := queue[queue_head]
		queue_head += 1
		
		// Check if we reached destination
		if current == to {
			return distances[current]
		}
		
		// Explore neighbors
		for adj in sa.slice(&mm.l2l_1away_via_land[current]) {
			if visited[adj] {
				continue
			}
			
			// Can only traverse friendly or allied territories
			// (or neutral territories we can pass through)
			owner := gc.owner[adj]
			if mm.team[owner] != mm.team[gc.cur_player] && adj != to {
				// Can't pass through enemy territory (except destination)
				continue
			}
			
			visited[adj] = true
			distances[adj] = distances[current] + 1
			queue[queue_tail] = adj
			queue_tail += 1
		}
	}
	
	// Couldn't reach destination through friendly territory
	return -1
}

// Check if destination can be held
can_hold_destination :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, land: Land_ID) -> bool {
	/*
	From Java:
	if (!moveMap.get(t).isCanHold()) {
		continue;
	}
	*/
	
	// Check if we own it or an ally owns it
	if mm.team[gc.owner[land]] != mm.team[gc.cur_player] {
		return false
	}
	
	// Calculate if we can hold it
	enemy_threat := calculate_enemy_threat(gc, to_air(land), pro_data)
	current_defense := calculate_current_defense(gc, to_air(land))
	
	// Can hold if defense is sufficient
	return current_defense >= enemy_threat * 0.8
}

// NCM-006/07: Move one unit to each territory bordering enemy
// From ProNonCombatMoveAi.java moveOneDefenderToLandTerritoriesBorderingEnemy() lines 330-390
move_one_defender_to_border_territories :: proc(gc: ^Game_Cache) -> int {
	/*
	Algorithm:
	1. Find friendly territories adjacent to enemy land units with no defenders
	2. Sort available units by cost (cheapest first - prefer infantry)
	3. For each territory needing defender, move cheapest unit that can reach
	4. Skip if unit value > territory production + 3 (avoid sacrificing expensive units)
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving one defender to each border territory")
	}
	
	player := gc.cur_player
	my_team := mm.team[player]
	defenders_moved := 0
	
	// NCM-007: Find territories that need a defender
	// Must be: friendly, adjacent to enemy with land units, currently undefended
	territories_needing_defender := make([dynamic]Land_ID, context.temp_allocator)
	
	for land in gc.friendly_owner {
		if gc.owner[land] != player do continue
		
		// Check if we already have defenders here
		has_defender := gc.team_land_units[land][my_team] > 0
		if has_defender do continue
		
		// Check if adjacent to enemy with land units
		has_enemy_neighbor_with_units := false
		for adj_land in sa.slice(&mm.l2l_1away_via_land[land]) {
			adj_owner := gc.owner[adj_land]
			if mm.team[adj_owner] != my_team {
				// Check if enemy has land units there
				if gc.team_land_units[adj_land][mm.team[adj_owner]] > 0 {
					has_enemy_neighbor_with_units = true
					break
				}
			}
		}
		
		if has_enemy_neighbor_with_units {
			append(&territories_needing_defender, land)
		}
	}
	
	when ODIN_DEBUG {
		if len(territories_needing_defender) > 0 {
			fmt.printf("  Found %d territories needing border defender\n", len(territories_needing_defender))
		}
	}
	
	// NCM-008: For each territory needing defender, find cheapest unit that can reach
	// Process in order: Infantry (3) < Artillery (4) < Tank (6)
	Unit_Move_Option :: struct {
		from_territory: Land_ID,
		unit_type:      Active_Army,
		cost:           int,
	}
	
	for target_land in territories_needing_defender {
		production := int(mm.value[target_land])
		
		// Find cheapest unit that can move here
		best_option: Maybe(Unit_Move_Option) = nil
		best_cost := 999
		
		// Check adjacent territories for units that can move
		for adj_land in sa.slice(&mm.l2l_1away_via_land[target_land]) {
			if gc.owner[adj_land] != player do continue
			
			// Check infantry first (cheapest, cost 3)
			if gc.active_armies[adj_land][.INF_1_MOVES] > 0 && 3 < best_cost {
				// Only move if unit value <= production + 3
				if 3 <= production + 3 {
					best_option = Unit_Move_Option{adj_land, .INF_1_MOVES, 3}
					best_cost = 3
				}
			}
			
			// Check artillery (cost 4)
			if gc.active_armies[adj_land][.ARTY_1_MOVES] > 0 && 4 < best_cost {
				if 4 <= production + 3 {
					best_option = Unit_Move_Option{adj_land, .ARTY_1_MOVES, 4}
					best_cost = 4
				}
			}
			
			// Check tanks (cost 6) - only if territory is valuable enough
			if gc.active_armies[adj_land][.TANK_1_MOVES] > 0 && 6 < best_cost {
				if 6 <= production + 3 {
					best_option = Unit_Move_Option{adj_land, .TANK_1_MOVES, 6}
					best_cost = 6
				}
			}
			// Tanks with 2 moves can also reach
			if gc.active_armies[adj_land][.TANK_2_MOVES] > 0 && 6 < best_cost {
				if 6 <= production + 3 {
					best_option = Unit_Move_Option{adj_land, .TANK_2_MOVES, 6}
					best_cost = 6
				}
			}
		}
		
		// Check 2-move distance for tanks
		for land_2_away in mm.l2l_2away_via_land_bitset[target_land] {
			if gc.owner[land_2_away] != player do continue
			
			// Only tanks can move 2 spaces
			if gc.active_armies[land_2_away][.TANK_2_MOVES] > 0 && 6 < best_cost {
				// Check if route is valid (mid-territory friendly)
				for midland in mm.l2l_2away_via_midland_bitset[target_land][land_2_away] {
					if mm.team[gc.owner[midland]] == my_team {
						if 6 <= production + 3 {
							best_option = Unit_Move_Option{land_2_away, .TANK_2_MOVES, 6}
							best_cost = 6
						}
						break
					}
				}
			}
		}
		
		// Execute move if found
		if opt, ok := best_option.?; ok {
			gc.active_armies[opt.from_territory][opt.unit_type] -= 1
			
			// Convert to 0-moves version at destination
			dest_type: Active_Army
			#partial switch opt.unit_type {
			case .INF_1_MOVES:
				dest_type = .INF_0_MOVES
			case .ARTY_1_MOVES:
				dest_type = .ARTY_0_MOVES
			case .TANK_1_MOVES, .TANK_2_MOVES:
				dest_type = .TANK_0_MOVES
			case:
				dest_type = .INF_0_MOVES
			}
			gc.active_armies[target_land][dest_type] += 1
			defenders_moved += 1
			
			when ODIN_DEBUG {
				fmt.printf("    Moved %v from %v to defend %v (cost %d, prod %d)\n",
					opt.unit_type, opt.from_territory, target_land, opt.cost, production)
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("  Moved %d defenders to border territories\n", defenders_moved)
	}
	
	return defenders_moved
}

// Helper: Check if territory can be held after reinforcement
can_hold_territory_after_reinforcement :: proc(
	gc: ^Game_Cache,
	territory: Air_ID,
	additional_defense: f64,
	pro_data: ^Pro_Data,
) -> bool {
	enemy_threat := calculate_enemy_threat(gc, territory, pro_data)
	current_defense := calculate_current_defense(gc, territory)
	total_defense := current_defense + additional_defense

	// Can hold if defense is 20% stronger than threat
	return total_defense >= enemy_threat * 1.2
}

// Helper: Find best territory to move a unit to
find_best_noncombat_move :: proc(
	gc: ^Game_Cache,
	from: Land_ID,
	unit_strength: f64,
) -> Maybe(Land_ID) {
	best_territory: Maybe(Land_ID) = nil
	best_value := 0.0

	// Check all territories unit can reach
	// Would use movement range and map graph
	// For now, simplified to adjacent territories

	// Evaluate each potential destination
	// Consider: strategic value, defensive need, safety

	return best_territory
}

// Cleanup
pro_noncombat_move_cleanup :: proc(targets: ^[dynamic]Defense_Target) {
	delete(targets^)
}

// NCM-030 to NCM-045: Transport positioning blocks (Block 1-4)
// Load transports during non-combat move phase
load_transports_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	From Java ProTerritoryManager.java (lines 1129-1139):
	
	// Remove any territories from transport map that I can move to on land and transports with no
	// amphib options
	for (final ProTransport proTransportData : transportMapList) {
	  final Map<Territory, Set<Territory>> transportMap = proTransportData.getTransportMap();
	  for (final Territory t : transportMap.keySet()) {
	    final Set<Territory> landMoveTerritories = landRoutesMap.get(t);
	    if (landMoveTerritories != null) {
	      transportMap.get(t).removeAll(landMoveTerritories);
	    }
	  }
	  transportMap.values().removeIf(Collection::isEmpty);
	}
	
	This removes loading sources that can be reached by land from the unload destination.
	Key insight: Don't load units from territories that can walk to the destination!
	
	For example: If unloading to India, and Sea_35 is adjacent to India only,
	we should NOT load from India since units there are already at the destination.
	*/
	
	when ODIN_DEBUG {
		fmt.println("  [NONCOMBAT] Loading transports for next turn positioning...")
	}
	
	// Find all sea zones with our transports
	player := gc.cur_player
	transports_loaded := 0
	
	// Pre-calculate territory values to determine best unload destinations
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	territories_cant_hold_bitset: Land_Bitset = {}
	for land in territories_cant_hold[:] {
		territories_cant_hold_bitset += {land}
	}
	delete(territories_cant_hold)
	
	territory_value_map := find_territory_values_triplea(
		gc,
		gc.cur_player,
		territories_cant_hold_bitset,
		{},
		gc.friendly_owner,
	)
	defer delete(territory_value_map)
	
	for sea in Sea_ID {
		// Count available transports at this sea zone
		empty_transports := gc.idle_ships[sea][player][.TRANS_EMPTY]
		partial_1i := gc.idle_ships[sea][player][.TRANS_1I]
		partial_1a := gc.idle_ships[sea][player][.TRANS_1A]
		partial_1t := gc.idle_ships[sea][player][.TRANS_1T]
		
		if empty_transports == 0 && partial_1i == 0 && partial_1a == 0 && partial_1t == 0 {
			continue
		}
		
		// Get adjacent lands
		adjacent_lands := &mm.s2l_1away_via_sea[sea]
		
		// Find the best unload destination for this sea zone
		// (highest value friendly land reachable from this sea)
		best_unload_dest: Maybe(Land_ID) = nil
		best_unload_value: f64 = -999.0
		
		// Check adjacent lands (1 sea move)
		for land in sa.slice(adjacent_lands) {
			if mm.team[gc.owner[land]] != mm.team[player] {
				continue
			}
			value := territory_value_map[land] or_else 0.0
			if value > best_unload_value {
				best_unload_value = value
				best_unload_dest = land
			}
		}
		
		// Check 2 sea moves away
		for sea_1 in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][sea] {
			for land in sa.slice(&mm.s2l_1away_via_sea[sea_1]) {
				if mm.team[gc.owner[land]] != mm.team[player] {
					continue
				}
				value := territory_value_map[land] or_else 0.0
				if value > best_unload_value {
					best_unload_value = value
					best_unload_dest = land
				}
			}
		}
		
		// Build set of territories that should NOT be loading sources
		// Only exclude the destination itself (to prevent loading from India to unload back to India)
		// Java's landRoutesMap is more sophisticated but for our case, just exclude the destination
		// BUT: Only exclude if the destination has positive strategic value - otherwise we're just
		// picking an arbitrary territory and should load freely (staging will pick a real destination)
		lands_that_can_walk_to_dest: Land_Bitset = {}
		if dest, ok := best_unload_dest.?; ok {
			// Only exclude if this is a strategically valuable destination
			// If value is near 0 or negative, we're far from the war and should load units freely
			// Use 0.1 threshold to avoid floating-point precision issues (e.g., 1e-36)
			if best_unload_value >= 0.1 {
				// Only exclude if dest is adjacent (lands that could actually load here)
				// Don't exclude if destination is 2 moves away - those units can't walk there
				for adj_land in sa.slice(adjacent_lands) {
					if adj_land == dest {
						lands_that_can_walk_to_dest += {dest}
						break
					}
				}
			}
		}
		
		// Check if any adjacent land has units we could load
		// But EXCLUDE lands that can walk to the unload destination (Java landRoutesMap filtering)
		has_loadable_units := false
		for land in sa.slice(adjacent_lands) {
			if mm.team[gc.owner[land]] != mm.team[player] {
				continue
			}
			
			// Skip this land if units there can walk to the destination
			if land in lands_that_can_walk_to_dest {
				continue
			}
			
			// Check idle armies (units that haven't moved this turn)
			if gc.idle_armies[land][player][.INF] > 0 ||
			   gc.idle_armies[land][player][.ARTY] > 0 ||
			   gc.idle_armies[land][player][.TANK] > 0 {
				has_loadable_units = true
				break
			}
			
			// Also check active armies (units that still have movement)
			// This is critical for island nations like UK where units can't walk away
			if gc.active_armies[land][.INF_1_MOVES] > 0 ||
			   gc.active_armies[land][.INF_0_MOVES] > 0 ||
			   gc.active_armies[land][.ARTY_1_MOVES] > 0 ||
			   gc.active_armies[land][.ARTY_0_MOVES] > 0 ||
			   gc.active_armies[land][.TANK_2_MOVES] > 0 ||
			   gc.active_armies[land][.TANK_1_MOVES] > 0 ||
			   gc.active_armies[land][.TANK_0_MOVES] > 0 {
				has_loadable_units = true
				break
			}
		}
		
		if !has_loadable_units {
			continue
		}
		
		// Load transports, but only from territories that can't walk to destination
		loaded := load_transports_at_sea_noncombat(gc, sea, lands_that_can_walk_to_dest)
		if loaded > 0 {
			transports_loaded += loaded
			
			when ODIN_DEBUG {
				fmt.printf("    Loaded %d units onto transports at sea %v\n", loaded, sea)
			}
		}
	}
	
	when ODIN_DEBUG {
		if transports_loaded > 0 {
			fmt.printf("  [NONCOMBAT] Total units loaded onto transports: %d\n", transports_loaded)
		} else {
			fmt.println("  [NONCOMBAT] No units loaded onto transports")
		}
	}
}

// Load transports at a specific sea zone during noncombat (uses idle armies)
// lands_to_exclude: territories where units can walk to the destination - don't load from these
load_transports_at_sea_noncombat :: proc(gc: ^Game_Cache, sea: Sea_ID, lands_to_exclude: Land_Bitset) -> int {
	/*
	During non-combat phase:
	- Units don't have "active" movement states - they're just idle
	- We load from idle_armies directly
	- The transport becomes loaded and ready for next turn
	
	From Java ProTerritoryManager.java (lines 1129-1139):
	Don't load from territories that can walk to the unload destination!
	*/
	
	player := gc.cur_player
	adjacent_lands := &mm.s2l_1away_via_sea[sea]
	units_loaded := 0
	
	// Load empty transports first (best capacity)
	for gc.idle_ships[sea][player][.TRANS_EMPTY] > 0 {
		loaded := load_noncombat_onto_empty_transport(gc, sea, adjacent_lands, lands_to_exclude)
		if !loaded {
			break
		}
		units_loaded += 1
	}
	
	// Fill 1I transports (can add tank, arty, or infantry)
	for gc.idle_ships[sea][player][.TRANS_1I] > 0 {
		loaded := load_noncombat_second_unit_onto_1i(gc, sea, adjacent_lands, lands_to_exclude)
		if !loaded {
			break
		}
		units_loaded += 1
	}
	
	// Fill 1A transports (can only add infantry)
	for gc.idle_ships[sea][player][.TRANS_1A] > 0 {
		loaded := load_noncombat_infantry_onto_partial(gc, sea, adjacent_lands, lands_to_exclude, .TRANS_1A)
		if !loaded {
			break
		}
		units_loaded += 1
	}
	
	// Fill 1T transports (can only add infantry)
	for gc.idle_ships[sea][player][.TRANS_1T] > 0 {
		loaded := load_noncombat_infantry_onto_partial(gc, sea, adjacent_lands, lands_to_exclude, .TRANS_1T)
		if !loaded {
			break
		}
		units_loaded += 1
	}
	
	return units_loaded
}

// Load best unit onto empty transport during noncombat
load_noncombat_onto_empty_transport :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
	lands_to_exclude: Land_Bitset,
) -> bool {
	player := gc.cur_player
	
	// Priority: Tank > Artillery > Infantry (for attack power)
	
	// Try tank first
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		// Don't load from territories that can walk to the destination (Java landRoutesMap)
		if land in lands_to_exclude {
			continue
		}
		
		if get_available_army_count(gc, land, .TANK) > 0 {
			// Load tank
			remove_army_for_transport(gc, land, .TANK)
			
			// Update transport
			gc.idle_ships[sea][player][.TRANS_EMPTY] -= 1
			gc.idle_ships[sea][player][.TRANS_1T] += 1
			gc.active_ships[sea][.TRANS_1T_UNMOVED] += 1
			
			// Try to add infantry too
			for inf_land in sa.slice(adjacent_lands) {
				if mm.team[gc.owner[inf_land]] != mm.team[player] {
					continue
				}
				if inf_land in lands_to_exclude {
					continue
				}
				if get_available_army_count(gc, inf_land, .INF) > 0 {
					remove_army_for_transport(gc, inf_land, .INF)
					
					// Transform 1T to 1I_1T
					gc.idle_ships[sea][player][.TRANS_1T] -= 1
					gc.idle_ships[sea][player][.TRANS_1I_1T] += 1
					gc.active_ships[sea][.TRANS_1T_UNMOVED] -= 1
					gc.active_ships[sea][.TRANS_1I_1T_2_MOVES] += 1
					break
				}
			}
			
			return true
		}
	}
	
	// Try artillery
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		if land in lands_to_exclude {
			continue
		}
		
		if get_available_army_count(gc, land, .ARTY) > 0 {
			remove_army_for_transport(gc, land, .ARTY)
			
			gc.idle_ships[sea][player][.TRANS_EMPTY] -= 1
			gc.idle_ships[sea][player][.TRANS_1A] += 1
			gc.active_ships[sea][.TRANS_1A_UNMOVED] += 1
			
			// Try to add infantry
			for inf_land in sa.slice(adjacent_lands) {
				if mm.team[gc.owner[inf_land]] != mm.team[player] {
					continue
				}
				if inf_land in lands_to_exclude {
					continue
				}
				if get_available_army_count(gc, inf_land, .INF) > 0 {
					remove_army_for_transport(gc, inf_land, .INF)
					
					gc.idle_ships[sea][player][.TRANS_1A] -= 1
					gc.idle_ships[sea][player][.TRANS_1I_1A] += 1
					gc.active_ships[sea][.TRANS_1A_UNMOVED] -= 1
					gc.active_ships[sea][.TRANS_1I_1A_2_MOVES] += 1
					break
				}
			}
			
			return true
		}
	}
	
	// Try 2 infantry
	infantry_loaded := 0
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		if land in lands_to_exclude {
			continue
		}
		
		for get_available_army_count(gc, land, .INF) > 0 && infantry_loaded < 2 {
			remove_army_for_transport(gc, land, .INF)
			
			if infantry_loaded == 0 {
				gc.idle_ships[sea][player][.TRANS_EMPTY] -= 1
				gc.idle_ships[sea][player][.TRANS_1I] += 1
				gc.active_ships[sea][.TRANS_1I_UNMOVED] += 1
			} else {
				gc.idle_ships[sea][player][.TRANS_1I] -= 1
				gc.idle_ships[sea][player][.TRANS_2I] += 1
				gc.active_ships[sea][.TRANS_1I_UNMOVED] -= 1
				gc.active_ships[sea][.TRANS_2I_2_MOVES] += 1
			}
			
			infantry_loaded += 1
		}
		
		if infantry_loaded >= 2 {
			break
		}
	}
	
	return infantry_loaded > 0
}

// Load second unit onto 1I transport during noncombat
load_noncombat_second_unit_onto_1i :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
	lands_to_exclude: Land_Bitset,
) -> bool {
	player := gc.cur_player
	
	// Prefer tank or artillery
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		if land in lands_to_exclude {
			continue
		}
		
		// Tank
		if get_available_army_count(gc, land, .TANK) > 0 {
			remove_army_for_transport(gc, land, .TANK)
			
			gc.idle_ships[sea][player][.TRANS_1I] -= 1
			gc.idle_ships[sea][player][.TRANS_1I_1T] += 1
			
			// Find and update active state
			if gc.active_ships[sea][.TRANS_1I_UNMOVED] > 0 {
				gc.active_ships[sea][.TRANS_1I_UNMOVED] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_2_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_2_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_1_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_1_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_0_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_0_MOVES] -= 1
			}
			gc.active_ships[sea][.TRANS_1I_1T_2_MOVES] += 1
			
			return true
		}
		
		// Artillery
		if get_available_army_count(gc, land, .ARTY) > 0 {
			remove_army_for_transport(gc, land, .ARTY)
			
			gc.idle_ships[sea][player][.TRANS_1I] -= 1
			gc.idle_ships[sea][player][.TRANS_1I_1A] += 1
			
			if gc.active_ships[sea][.TRANS_1I_UNMOVED] > 0 {
				gc.active_ships[sea][.TRANS_1I_UNMOVED] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_2_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_2_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_1_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_1_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_0_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_0_MOVES] -= 1
			}
			gc.active_ships[sea][.TRANS_1I_1A_2_MOVES] += 1
			
			return true
		}
	}
	
	// Fallback to infantry
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		
		if get_available_army_count(gc, land, .INF) > 0 {
			remove_army_for_transport(gc, land, .INF)
			
			gc.idle_ships[sea][player][.TRANS_1I] -= 1
			gc.idle_ships[sea][player][.TRANS_2I] += 1
			
			if gc.active_ships[sea][.TRANS_1I_UNMOVED] > 0 {
				gc.active_ships[sea][.TRANS_1I_UNMOVED] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_2_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_2_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_1_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_1_MOVES] -= 1
			} else if gc.active_ships[sea][.TRANS_1I_0_MOVES] > 0 {
				gc.active_ships[sea][.TRANS_1I_0_MOVES] -= 1
			}
			gc.active_ships[sea][.TRANS_2I_2_MOVES] += 1
			
			return true
		}
	}
	
	return false
}

// Load infantry onto partial transport (1A or 1T) during noncombat
load_noncombat_infantry_onto_partial :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	adjacent_lands: ^SA_S2L,
	lands_to_exclude: Land_Bitset,
	transport_type: Idle_Ship,
) -> bool {
	player := gc.cur_player
	
	for land in sa.slice(adjacent_lands) {
		if mm.team[gc.owner[land]] != mm.team[player] {
			continue
		}
		if land in lands_to_exclude {
			continue
		}
		
		if get_available_army_count(gc, land, .INF) > 0 {
			remove_army_for_transport(gc, land, .INF)
			
			if transport_type == .TRANS_1A {
				gc.idle_ships[sea][player][.TRANS_1A] -= 1
				gc.idle_ships[sea][player][.TRANS_1I_1A] += 1
				
				if gc.active_ships[sea][.TRANS_1A_UNMOVED] > 0 {
					gc.active_ships[sea][.TRANS_1A_UNMOVED] -= 1
				} else if gc.active_ships[sea][.TRANS_1A_2_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1A_2_MOVES] -= 1
				} else if gc.active_ships[sea][.TRANS_1A_1_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1A_1_MOVES] -= 1
				} else if gc.active_ships[sea][.TRANS_1A_0_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1A_0_MOVES] -= 1
				}
				gc.active_ships[sea][.TRANS_1I_1A_2_MOVES] += 1
			} else {  // TRANS_1T
				gc.idle_ships[sea][player][.TRANS_1T] -= 1
				gc.idle_ships[sea][player][.TRANS_1I_1T] += 1
				
				if gc.active_ships[sea][.TRANS_1T_UNMOVED] > 0 {
					gc.active_ships[sea][.TRANS_1T_UNMOVED] -= 1
				} else if gc.active_ships[sea][.TRANS_1T_2_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1T_2_MOVES] -= 1
				} else if gc.active_ships[sea][.TRANS_1T_1_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1T_1_MOVES] -= 1
				} else if gc.active_ships[sea][.TRANS_1T_0_MOVES] > 0 {
					gc.active_ships[sea][.TRANS_1T_0_MOVES] -= 1
				}
				gc.active_ships[sea][.TRANS_1I_1T_2_MOVES] += 1
			}
			
			return true
		}
	}
	
	return false
}

// Helper: Remove unit from active_armies (find the right move state)
// During noncombat, units might be in various move states - find and remove
remove_from_active_armies :: proc(gc: ^Game_Cache, land: Land_ID, unit_type: Idle_Army) {
	switch unit_type {
	case .INF:
		if gc.active_armies[land][.INF_1_MOVES] > 0 {
			gc.active_armies[land][.INF_1_MOVES] -= 1
		} else if gc.active_armies[land][.INF_0_MOVES] > 0 {
			gc.active_armies[land][.INF_0_MOVES] -= 1
		}
	case .ARTY:
		if gc.active_armies[land][.ARTY_1_MOVES] > 0 {
			gc.active_armies[land][.ARTY_1_MOVES] -= 1
		} else if gc.active_armies[land][.ARTY_0_MOVES] > 0 {
			gc.active_armies[land][.ARTY_0_MOVES] -= 1
		}
	case .TANK:
		if gc.active_armies[land][.TANK_2_MOVES] > 0 {
			gc.active_armies[land][.TANK_2_MOVES] -= 1
		} else if gc.active_armies[land][.TANK_1_MOVES] > 0 {
			gc.active_armies[land][.TANK_1_MOVES] -= 1
		} else if gc.active_armies[land][.TANK_0_MOVES] > 0 {
			gc.active_armies[land][.TANK_0_MOVES] -= 1
		}
	case .AAGUN:
		if gc.active_armies[land][.AAGUN_1_MOVES] > 0 {
			gc.active_armies[land][.AAGUN_1_MOVES] -= 1
		} else if gc.active_armies[land][.AAGUN_0_MOVES] > 0 {
			gc.active_armies[land][.AAGUN_0_MOVES] -= 1
		}
	}
}

// Helper: Get count of available units of a type (checks both idle and active)
// During noncombat, units might only exist in active_armies if idle_armies was already decremented
get_available_army_count :: proc(gc: ^Game_Cache, land: Land_ID, unit_type: Idle_Army) -> u8 {
	player := gc.cur_player
	// First check idle_armies (the authoritative count per player)
	idle_count := gc.idle_armies[land][player][unit_type]
	if idle_count > 0 {
		return idle_count
	}
	// If idle is 0, check active_armies in case of state mismatch
	// This handles edge cases where idle was decremented but active wasn't
	switch unit_type {
	case .INF:
		return gc.active_armies[land][.INF_1_MOVES] + gc.active_armies[land][.INF_0_MOVES]
	case .ARTY:
		return gc.active_armies[land][.ARTY_1_MOVES] + gc.active_armies[land][.ARTY_0_MOVES]
	case .TANK:
		return gc.active_armies[land][.TANK_2_MOVES] + gc.active_armies[land][.TANK_1_MOVES] + gc.active_armies[land][.TANK_0_MOVES]
	case .AAGUN:
		return gc.active_armies[land][.AAGUN_1_MOVES] + gc.active_armies[land][.AAGUN_0_MOVES]
	}
	return 0
}

// Helper: Remove one unit of a type from both idle_armies and active_armies
remove_army_for_transport :: proc(gc: ^Game_Cache, land: Land_ID, unit_type: Idle_Army) {
	player := gc.cur_player
	// Decrement idle_armies if available
	if gc.idle_armies[land][player][unit_type] > 0 {
		gc.idle_armies[land][player][unit_type] -= 1
	}
	// Always decrement from active_armies
	remove_from_active_armies(gc, land, unit_type)
	// Update team land units
	gc.team_land_units[land][mm.team[player]] -= 1
}

// ============================================================================
// NCM-030 to NCM-045: Transport Staging and Unloading During Non-Combat
// ============================================================================
/*
This implements the missing transport blocks from Java's moveUnitsToBestTerritories():

Block 1 (Java lines 985-1100): Transport amphib to best LAND territory
Block 2 (Java lines 1100-1180): Transport amphib to best SEA territory
Block 3 (Java lines 1185-1280): Empty transport to loading position
Block 4 (Java lines 1285-1400): Remaining transports to safety

The algorithm:
1. For each loaded transport, find the highest-value land territory it can reach
2. Move the transport to the adjacent sea zone
3. Unload the units to the land territory
4. Empty transports move towards factories for next turn loading
*/

// Stage and unload loaded transports during non-combat move
stage_and_unload_transports_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("  [NONCOMBAT] Staging and unloading loaded transports...")
	}
	
	player := gc.cur_player
	my_team := mm.team[player]
	
	// Get territory values for prioritizing unload destinations
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	territories_cant_hold_bitset: Land_Bitset = {}
	for land in territories_cant_hold[:] {
		territories_cant_hold_bitset += {land}
	}
	delete(territories_cant_hold)
	
	territory_value_map := find_territory_values_triplea(
		gc,
		gc.cur_player,
		territories_cant_hold_bitset,
		{},
		gc.friendly_owner,
	)
	defer delete(territory_value_map)
	
	transports_unloaded := 0
	
	// Process loaded transports in priority order
	// Include both 2_MOVES (newly loaded) and UNMOVED (from previous turns) transports
	Loaded_Transport_Priority := [?]Active_Ship{
		// Newly loaded transports with 2 moves
		.TRANS_1I_1T_2_MOVES,
		.TRANS_1I_1A_2_MOVES,
		.TRANS_2I_2_MOVES,
		.TRANS_1T_2_MOVES,
		.TRANS_1A_2_MOVES,
		.TRANS_1I_2_MOVES,
		// Also handle UNMOVED transports with cargo (from previous turns or start of game)
		.TRANS_1I_UNMOVED,
		.TRANS_1A_UNMOVED,
		.TRANS_1T_UNMOVED,
	}
	
	for transport_type in Loaded_Transport_Priority {
		for sea in Sea_ID {
			for gc.active_ships[sea][transport_type] > 0 {
				// Find best unload destination from this sea zone
				unloaded := stage_and_unload_one_transport(
					gc, pro_data, sea, transport_type, &territory_value_map)
				
				if unloaded {
					transports_unloaded += 1
				} else {
					// No valid unload destination, skip this transport
					// Move it to safer position instead
					skip_transport_to_0_moves(gc, sea, transport_type)
				}
			}
		}
	}
	
	when ODIN_DEBUG {
		fmt.printf("  [NONCOMBAT] Unloaded %d transports\n", transports_unloaded)
	}
}

// Stage and unload a single transport to the best destination
stage_and_unload_one_transport :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	src_sea: Sea_ID,
	transport_type: Active_Ship,
	territory_value_map: ^map[Land_ID]f64,
) -> bool {
	player := gc.cur_player
	my_team := mm.team[player]
	
	// Find all lands we can reach (within 2 sea moves, then adjacent land)
	best_land: Maybe(Land_ID) = nil
	best_value: f64 = -999.0
	best_sea: Sea_ID = src_sea
	best_distance: u8 = 0
	
	// Check lands adjacent to current sea (distance 0)
	for land in sa.slice(&mm.s2l_1away_via_sea[src_sea]) {
		if mm.team[gc.owner[land]] != my_team {
			continue // Can only unload to friendly territory in noncombat
		}
		
		value := territory_value_map[land] or_else 0.0
		if value > best_value {
			best_value = value
			best_land = land
			best_sea = src_sea
			best_distance = 0
		}
	}
	
	// Check lands reachable with 1 sea move
	for sea_1 in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		// Safety check - can we move there?
		if gc.team_sea_units[sea_1][mm.enemy_team[player]] > 0 &&
		   gc.allied_sea_combatants_total[sea_1] == 0 {
			continue // Can't move to hostile sea without escort
		}
		
		for land in sa.slice(&mm.s2l_1away_via_sea[sea_1]) {
			if mm.team[gc.owner[land]] != my_team {
				continue
			}
			
			value := territory_value_map[land] or_else 0.0
			if value > best_value {
				best_value = value
				best_land = land
				best_sea = sea_1
				best_distance = 1
			}
		}
	}
	
	// Check lands reachable with 2 sea moves
	for sea_2 in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		// Safety check
		if gc.team_sea_units[sea_2][mm.enemy_team[player]] > 0 &&
		   gc.allied_sea_combatants_total[sea_2] == 0 {
			continue
		}
		
		// Also check mid-sea safety
		path_blocked := true
		for mid_sea in sa.slice(&mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][src_sea][sea_2]) {
			if gc.enemy_blockade_total[mid_sea] == 0 {
				path_blocked = false
				break
			}
		}
		if path_blocked {
			continue
		}
		
		for land in sa.slice(&mm.s2l_1away_via_sea[sea_2]) {
			if mm.team[gc.owner[land]] != my_team {
				continue
			}
			
			value := territory_value_map[land] or_else 0.0
			if value > best_value {
				best_value = value
				best_land = land
				best_sea = sea_2
				best_distance = 2
			}
		}
	}
	
	// If no valid destination, return false
	if best_land == nil {
		return false
	}
	
	dst_land := best_land.?
	
	when ODIN_DEBUG {
		fmt.printf("    [TRANSPORT] Moving %v from sea %v to sea %v, unloading to %v (value=%.1f)\n",
			transport_type, src_sea, best_sea, dst_land, best_value)
	}
	
	// Move transport if needed
	if best_distance > 0 {
		move_transport_to_sea(gc, src_sea, best_sea, transport_type, best_distance)
	} else {
		// Just convert to 0_MOVES state since we're unloading here
		convert_transport_to_0_moves(gc, src_sea, transport_type)
	}
	
	// Unload all cargo to the destination land
	unload_transport_cargo_to_land(gc, best_sea, dst_land, transport_type)
	
	return true
}

// Skip a transport without unloading (set to 0 moves)
skip_transport_to_0_moves :: proc(gc: ^Game_Cache, sea: Sea_ID, transport_type: Active_Ship) {
	player := gc.cur_player
	
	// Map 2_MOVES to 0_MOVES state
	new_state: Active_Ship
	idle_state: Idle_Ship
	
	#partial switch transport_type {
	case .TRANS_1I_1T_2_MOVES:
		new_state = .TRANS_1I_1T_0_MOVES
		idle_state = .TRANS_1I_1T
	case .TRANS_1I_1A_2_MOVES:
		new_state = .TRANS_1I_1A_0_MOVES
		idle_state = .TRANS_1I_1A
	case .TRANS_2I_2_MOVES:
		new_state = .TRANS_2I_0_MOVES
		idle_state = .TRANS_2I
	case .TRANS_1T_2_MOVES, .TRANS_1T_UNMOVED:
		new_state = .TRANS_1T_0_MOVES
		idle_state = .TRANS_1T
	case .TRANS_1A_2_MOVES, .TRANS_1A_UNMOVED:
		new_state = .TRANS_1A_0_MOVES
		idle_state = .TRANS_1A
	case .TRANS_1I_2_MOVES, .TRANS_1I_UNMOVED:
		new_state = .TRANS_1I_0_MOVES
		idle_state = .TRANS_1I
	case:
		return // Unknown transport type
	}
	
	gc.active_ships[sea][transport_type] -= 1
	gc.active_ships[sea][new_state] += 1
	// idle_ships doesn't change (just the active state)
}

// Move transport from one sea to another
move_transport_to_sea :: proc(
	gc: ^Game_Cache,
	src_sea: Sea_ID,
	dst_sea: Sea_ID,
	transport_type: Active_Ship,
	distance: u8,
) {
	player := gc.cur_player
	
	// Get the 0_MOVES state after movement
	new_state: Active_Ship
	
	#partial switch transport_type {
	case .TRANS_1I_1T_2_MOVES:
		new_state = distance == 1 ? .TRANS_1I_1T_1_MOVES : .TRANS_1I_1T_0_MOVES
	case .TRANS_1I_1A_2_MOVES:
		new_state = distance == 1 ? .TRANS_1I_1A_1_MOVES : .TRANS_1I_1A_0_MOVES
	case .TRANS_2I_2_MOVES:
		new_state = distance == 1 ? .TRANS_2I_1_MOVES : .TRANS_2I_0_MOVES
	case .TRANS_1T_2_MOVES, .TRANS_1T_UNMOVED:
		new_state = distance == 1 ? .TRANS_1T_1_MOVES : .TRANS_1T_0_MOVES
	case .TRANS_1A_2_MOVES, .TRANS_1A_UNMOVED:
		new_state = distance == 1 ? .TRANS_1A_1_MOVES : .TRANS_1A_0_MOVES
	case .TRANS_1I_2_MOVES, .TRANS_1I_UNMOVED:
		new_state = distance == 1 ? .TRANS_1I_1_MOVES : .TRANS_1I_0_MOVES
	case:
		return
	}
	
	// Use 0_MOVES since we want to unload (can only unload when 0 moves)
	if distance == 1 {
		new_state = get_0_moves_state(transport_type)
	} else {
		new_state = get_0_moves_state(transport_type)
	}
	
	idle_state := Active_Ship_To_Idle[transport_type]
	
	// Remove from source
	gc.active_ships[src_sea][transport_type] -= 1
	gc.idle_ships[src_sea][player][idle_state] -= 1
	gc.team_sea_units[src_sea][mm.team[player]] -= 1
	
	// Add to destination
	gc.active_ships[dst_sea][new_state] += 1
	gc.idle_ships[dst_sea][player][idle_state] += 1
	gc.team_sea_units[dst_sea][mm.team[player]] += 1
}

// Get the 0_MOVES state for a transport type
get_0_moves_state :: proc(transport_type: Active_Ship) -> Active_Ship {
	#partial switch transport_type {
	case .TRANS_1I_1T_2_MOVES, .TRANS_1I_1T_1_MOVES:
		return .TRANS_1I_1T_0_MOVES
	case .TRANS_1I_1A_2_MOVES, .TRANS_1I_1A_1_MOVES:
		return .TRANS_1I_1A_0_MOVES
	case .TRANS_2I_2_MOVES, .TRANS_2I_1_MOVES:
		return .TRANS_2I_0_MOVES
	case .TRANS_1T_2_MOVES, .TRANS_1T_1_MOVES, .TRANS_1T_UNMOVED:
		return .TRANS_1T_0_MOVES
	case .TRANS_1A_2_MOVES, .TRANS_1A_1_MOVES, .TRANS_1A_UNMOVED:
		return .TRANS_1A_0_MOVES
	case .TRANS_1I_2_MOVES, .TRANS_1I_1_MOVES, .TRANS_1I_UNMOVED:
		return .TRANS_1I_0_MOVES
	case:
		return transport_type
	}
}

// Convert a transport to 0_MOVES state without moving
convert_transport_to_0_moves :: proc(gc: ^Game_Cache, sea: Sea_ID, transport_type: Active_Ship) {
	new_state := get_0_moves_state(transport_type)
	gc.active_ships[sea][transport_type] -= 1
	gc.active_ships[sea][new_state] += 1
}

// Unload transport cargo to land territory
unload_transport_cargo_to_land :: proc(
	gc: ^Game_Cache,
	sea: Sea_ID,
	land: Land_ID,
	transport_type: Active_Ship,
) {
	player := gc.cur_player
	my_team := mm.team[player]
	
	// Get 0_MOVES state for this transport
	transport_0_state := get_0_moves_state(transport_type)
	
	// Determine what cargo we have and unload it
	#partial switch transport_type {
	case .TRANS_1I_1T_2_MOVES:
		// Unload 1 Infantry
		gc.active_armies[land][.INF_0_MOVES] += 1
		gc.idle_armies[land][player][.INF] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to 1T
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_1I_1T] -= 1
		gc.active_ships[sea][.TRANS_1T_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_1T] += 1
		
	case .TRANS_1I_1A_2_MOVES:
		// Unload 1 Infantry
		gc.active_armies[land][.INF_0_MOVES] += 1
		gc.idle_armies[land][player][.INF] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to 1A
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_1I_1A] -= 1
		gc.active_ships[sea][.TRANS_1A_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_1A] += 1
		
	case .TRANS_2I_2_MOVES:
		// Unload 1 Infantry
		gc.active_armies[land][.INF_0_MOVES] += 1
		gc.idle_armies[land][player][.INF] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to 1I
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_2I] -= 1
		gc.active_ships[sea][.TRANS_1I_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_1I] += 1
		
	case .TRANS_1T_2_MOVES, .TRANS_1T_UNMOVED:
		// Unload 1 Tank
		gc.active_armies[land][.TANK_0_MOVES] += 1
		gc.idle_armies[land][player][.TANK] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to empty
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_1T] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
		
	case .TRANS_1A_2_MOVES, .TRANS_1A_UNMOVED:
		// Unload 1 Artillery
		gc.active_armies[land][.ARTY_0_MOVES] += 1
		gc.idle_armies[land][player][.ARTY] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to empty
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_1A] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
		
	case .TRANS_1I_2_MOVES, .TRANS_1I_UNMOVED:
		// Unload 1 Infantry
		gc.active_armies[land][.INF_0_MOVES] += 1
		gc.idle_armies[land][player][.INF] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update transport to empty
		gc.active_ships[sea][transport_0_state] -= 1
		gc.idle_ships[sea][player][.TRANS_1I] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
	}
	
	// Continue unloading remaining cargo if any
	// For 1I_1T and 1I_1A, we still have 1T or 1A left - try to unload those too
	#partial switch transport_type {
	case .TRANS_1I_1T_2_MOVES:
		// Still have tank on board (now in 1T state), unload it
		gc.active_armies[land][.TANK_0_MOVES] += 1
		gc.idle_armies[land][player][.TANK] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update to empty
		gc.active_ships[sea][.TRANS_1T_0_MOVES] -= 1
		gc.idle_ships[sea][player][.TRANS_1T] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
		
	case .TRANS_1I_1A_2_MOVES:
		// Still have artillery on board, unload it
		gc.active_armies[land][.ARTY_0_MOVES] += 1
		gc.idle_armies[land][player][.ARTY] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update to empty
		gc.active_ships[sea][.TRANS_1A_0_MOVES] -= 1
		gc.idle_ships[sea][player][.TRANS_1A] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
		
	case .TRANS_2I_2_MOVES:
		// Still have 1 infantry on board, unload it
		gc.active_armies[land][.INF_0_MOVES] += 1
		gc.idle_armies[land][player][.INF] += 1
		gc.team_land_units[land][my_team] += 1
		
		// Update to empty
		gc.active_ships[sea][.TRANS_1I_0_MOVES] -= 1
		gc.idle_ships[sea][player][.TRANS_1I] -= 1
		gc.active_ships[sea][.TRANS_EMPTY_0_MOVES] += 1
		gc.idle_ships[sea][player][.TRANS_EMPTY] += 1
	}
}
