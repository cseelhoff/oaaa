package oaaa

/*
=============================================================================
TRIPLEA ProPurchaseAi.java METHOD MAPPING
=============================================================================

This file implements methods from TripleA's ProPurchaseAi.java.
Each method includes the original Java code commented out for reference.

Implementation Status:
- [+] repair_factories_triplea - Repair damaged factories before purchasing
- [N/A] bid - Bidding logic (not applicable for MCTS rollouts)
- [+] purchase_triplea - Main purchase phase orchestration (all 11 steps)
- [+] should_save_up_for_fleet_triplea - Determine if should save PUs for future fleet
- [+] can_reach_enemy_by_land_triplea - Helper: Check if enemy reachable by land
- [+] find_defenders_in_place_territories_triplea - Find current defenders
- [+] prioritize_territories_to_defend_triplea - Sort territories by defense need
- [PARTIAL] purchase_defenders_triplea - Buy defenders (missing: carrier tracking, zero-move options)
- [+] prioritize_land_territories_triplea - Sort land territories by strategic value
- [PARTIAL] purchase_aa_units_triplea - Buy AA guns (missing: bomber threat check)
- [+] purchase_land_units_triplea - Buy land units for offense (fodder % algorithm)
- [+] purchase_factory_triplea - Decide whether to buy new factory
- [+] prioritize_sea_territories_triplea - Sort sea territories by value
- [PARTIAL] purchase_sea_and_amphib_units_triplea - CRITICAL: Missing amphib purchase loop (Java 1891-2091)
- [PARTIAL] purchase_units_with_remaining_production_triplea - Missing bomber preference, air multiplier
- [+] upgrade_units_with_remaining_pus_triplea - Upgrade to better units
- [+] find_upgrade_unit_efficiency_triplea - Calculate upgrade efficiency
- [+] populate_production_rule_map_triplea - Initialize purchase tracking
- [+] place_defenders_triplea - Place purchased units during place phase
- [+] place_units_triplea - Alias for place_defenders (places all units)
- [+] add_units_to_place_triplea - Track unit purchases (deferred placement)

CRITICAL ISSUE: purchase_sea_and_amphib_units_triplea is missing the main transport/amphib
purchase loop from Java lines 1891-2091. This causes UK infantry pileup - no transports
are being purchased for stranded units in low-value territories.

Total: 25 methods mapped from Java, 13 fully implemented, 4 partial, 4 architectural N/A
*/

import sa "core:container/small_array"
import "core:fmt"
import "core:math"

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
	debug_checks(gc)

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
=============================================================================
METHOD 1: repair
=============================================================================

Java Original (lines 74-139):

  void repair(
      final int initialPusRemaining,
      final IPurchaseDelegate purchaseDelegate,
      final GameData data,
      final GamePlayer player) {
    int pusRemaining = initialPusRemaining;
    ProLogger.info("Repairing factories with PUsRemaining=" + pusRemaining);

    // Current data at the start of combat move
    this.data = data;
    this.player = player;
    final Predicate<Unit> ourFactories =
        Matches.unitIsOwnedBy(player)
            .and(Matches.unitCanProduceUnits())
            .and(Matches.unitIsInfrastructure());
    final List<Territory> rfactories =
        CollectionUtils.getMatches(
            data.getMap().getTerritories(),
            ProMatches.territoryHasFactoryAndIsNotConqueredOwnedLand(player));
    if (player.getRepairFrontier() != null
        && Properties.getDamageFromBombingDoneToUnitsInsteadOfTerritories(data.getProperties())) {
      ProLogger.debug("Factories can be damaged");
      final Map<Unit, Territory> unitsThatCanProduceNeedingRepair = new HashMap<>();
      for (final Territory fixTerr : rfactories) {
        // Find damaged factories
        // [Lines 97-113 - Find units needing repair]
      }
      ProLogger.debug("Factories that need repaired: " + unitsThatCanProduceNeedingRepair);
      for (final var repairRule : player.getRepairFrontier().getRules()) {
        // Repair most damaged factories first
        // [Lines 116-137 - Repair logic]
      }
    }
  }
*/

// Odin Implementation:
repair_factories_triplea :: proc(gc: ^Game_Cache) {
	// Find all damaged factories owned by current player
	damaged_factories := make([dynamic]struct {
			unit_territory: Land_ID,
			damage:         u8,
			production:     u8,
		}, context.temp_allocator)

	// Collect damaged factories
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.owner[factory_loc] != gc.cur_player do continue

		damage := gc.factory_dmg[factory_loc]
		if damage > 0 {
			production := gc.factory_prod[factory_loc]
			append(&damaged_factories, struct {
				unit_territory: Land_ID,
				damage:         u8,
				production:     u8,
			}{factory_loc, damage, production})
		}
	}
	if len(damaged_factories) == 0 do return

	// Sort by damage amount (repair most damaged first)
	// This matches TripleA's prioritization
	for i := 0; i < len(damaged_factories) - 1; i += 1 {
		for j := i + 1; j < len(damaged_factories); j += 1 {
			if damaged_factories[j].damage > damaged_factories[i].damage {
				damaged_factories[i], damaged_factories[j] =
					damaged_factories[j], damaged_factories[i]
			}
		}
	}

	// Repair factories in priority order
	for factory in damaged_factories {
		if gc.money[gc.cur_player] == 0 do break

		// Repair as much as we can afford (1 IPC per damage point)
		repair_amount := min(factory.damage, gc.money[gc.cur_player])

		if repair_amount > 0 {
			gc.money[gc.cur_player] -= repair_amount
			gc.factory_dmg[factory.unit_territory] -= repair_amount
		}
	}
}

/*
=============================================================================
METHOD 2: bid (Not applicable for MCTS)
=============================================================================

Java Original (lines 141-256):

  Map<Territory, ProPurchaseTerritory> bid(
      final int pus, final IPurchaseDelegate purchaseDelegate, final GameState startOfTurnData) {
    // Current data fields
    data = proData.getData();
    this.startOfTurnData = startOfTurnData;
    player = proData.getPlayer();
    resourceTracker = new ProResourceTracker(pus, data);
    territoryManager = new ProTerritoryManager(calc, proData);
    isBid = true;
    final ProPurchaseOptionMap purchaseOptions = proData.getPurchaseOptions();

    // [Lines 154-241 - Bidding logic with limits]
    // Note: Bidding is for game setup, not relevant for MCTS rollouts
  }
*/

// Bidding not implemented - not needed for MCTS rollouts

/*
=============================================================================
METHOD 3: purchase (Main Entry Point)
=============================================================================

Java Original (lines 258-387):

  Map<Territory, ProPurchaseTerritory> purchase(
      final IPurchaseDelegate purchaseDelegate, final GameState startOfTurnData) {
    // Current data fields
    data = proData.getData();
    this.startOfTurnData = startOfTurnData;
    player = proData.getPlayer();
    resourceTracker = new ProResourceTracker(player);
    territoryManager = new ProTerritoryManager(calc, proData);
    isBid = false;
    final ProPurchaseOptionMap purchaseOptions = proData.getPurchaseOptions();

    ProLogger.info("Starting purchase phase with resources: " + resourceTracker);

    // Find all purchase/place territories
    final Map<Territory, ProPurchaseTerritory> purchaseTerritories =
        ProPurchaseUtils.findPurchaseTerritories(proData, player);

    // Determine max enemy attack units and current allied defenders
    territoryManager.populateEnemyAttackOptions(List.of(), placeTerritories);
    findDefendersInPlaceTerritories(purchaseTerritories);

    // Prioritize land territories that need defended and purchase additional defenders
    final List<ProPlaceTerritory> needToDefendLandTerritories =
        prioritizeTerritoriesToDefend(purchaseTerritories, true);
    purchaseDefenders(
        purchaseTerritories,
        needToDefendLandTerritories,
        purchaseOptions.getLandFodderOptions(),
        purchaseOptions.getLandZeroMoveOptions(),
        purchaseOptions.getAirOptions(),
        true);

    // Find strategic value for each territory
    // [Lines 305-320 - Calculate territory values]

    // Prioritize land place options purchase AA then land units
    final List<ProPlaceTerritory> prioritizedLandTerritories =
        prioritizeLandTerritories(purchaseTerritories);
    purchaseAaUnits(
        purchaseTerritories, prioritizedLandTerritories, purchaseOptions.getAaOptions());
    purchaseLandUnits(purchaseTerritories, prioritizedLandTerritories, purchaseOptions);

    // Prioritize sea territories that need defended and purchase additional defenders
    final List<ProPlaceTerritory> needToDefendSeaTerritories =
        prioritizeTerritoriesToDefend(purchaseTerritories, false);
    purchaseDefenders(
        purchaseTerritories,
        needToDefendSeaTerritories,
        purchaseOptions.getSeaDefenseOptions(),
        List.of(),
        purchaseOptions.getAirOptions(),
        false);

    // Determine whether to purchase new land factory
    final Map<Territory, ProPurchaseTerritory> factoryPurchaseTerritories = new HashMap<>();
    purchaseFactory(
        factoryPurchaseTerritories,
        purchaseTerritories,
        prioritizedLandTerritories,
        purchaseOptions,
        false);

    // Prioritize sea place options and purchase units
    final List<ProPlaceTerritory> prioritizedSeaTerritories =
        prioritizeSeaTerritories(purchaseTerritories);
    final boolean shouldSaveUpForAFleet =
        purchaseSeaAndAmphibUnits(purchaseTerritories, prioritizedSeaTerritories, purchaseOptions);

    // Try to use any remaining PUs on high value units
    if (!shouldSaveUpForAFleet) {
      purchaseUnitsWithRemainingProduction(
          purchaseTerritories, purchaseOptions.getLandOptions(), purchaseOptions.getAirOptions());
      upgradeUnitsWithRemainingPUs(purchaseTerritories, purchaseOptions);
      purchaseFactory(
          factoryPurchaseTerritories,
          purchaseTerritories,
          prioritizedLandTerritories,
          purchaseOptions,
          true);
    }

    // Purchase units
    final String error = purchaseDelegate.purchase(purchaseMap);
    return purchaseTerritories;
  }
*/

// PUR-001: purchase() main entry point - orchestrates all purchase logic
purchase_triplea :: proc(gc: ^Game_Cache) -> bool {
	/*
	Full TripleA purchase flow:
	1. Initialize purchase tracking
	2. Repair damaged factories
	3. Find territories needing defense, purchase defenders
	4. Purchase AA guns for high-value territories
	5. Purchase offensive land units
	6. Purchase factories if appropriate
	7. Purchase naval/amphibious units
	8. Use remaining PUs on high-value units
	9. Upgrade units if PUs remain
	*/

	if gc.money[gc.cur_player] == 0 {
		return true // No money to spend
	}

	// Step 1: Initialize purchase tracking (clear any previous purchases)
	// populate_production_rule_map_triplea(gc)

	// Step 2: Repair damaged factories FIRST (critical - affects production capacity)
	// repair_factories_triplea(gc)

	// if gc.money[gc.cur_player] == 0 {
	// 	return true // All money spent on repairs
	// }

	// Step 3: Find territories that need defense and purchase defenders
	// Prioritize land territories needing defense

	// Use the new per-enemy + aggregated structure
	all_enemies := all_enemy_attack_options_init()
	enemy_attack_options := pro_other_move_options_init()
	generate_all_enemy_attack_options(gc, &all_enemies, &enemy_attack_options)

	debug_checks(gc)

	// debug print each enemy's attack options (using per-enemy data)
	fmt.println("Enemy Attack Options (per-enemy):")
	for enemy in all_enemies.enemies_analyzed {
		fmt.println("Enemy:", enemy)
		enemy_data := &all_enemies.per_enemy[enemy]
		for land in Land_ID {
			threat := &enemy_data.land_threats[land]
			if threat.max_fighters > 0 {
				fmt.println("  Land:", land, "Fighters:", threat.max_fighters)
			}
			if threat.max_bombers > 0 {
				fmt.println("  Land:", land, "Bombers:", threat.max_bombers)
			}
			if threat.max_infantry > 0 {
				fmt.println("  Land:", land, "Infantry:", threat.max_infantry)
			}
			if threat.max_artillery > 0 {
				fmt.println("  Land:", land, "Artillery:", threat.max_artillery)
			}
			if threat.max_tanks > 0 {
				fmt.println("  Land:", land, "Tanks:", threat.max_tanks)
			}
		}
		for sea in Sea_ID {
			threat := &enemy_data.sea_threats[sea]
			if threat.max_fighters > 0 || threat.max_subs > 0 || threat.max_destroyers > 0 {
				fmt.println("  Sea:", sea, "Fighters:", threat.max_fighters, 
				           "Subs:", threat.max_subs, "Destroyers:", threat.max_destroyers)
			}
		}
	}
	
	// Print aggregated totals
	fmt.println("Enemy Attack Options (aggregated max):")
	for land in Land_ID {
		threat := &enemy_attack_options.land_max[land]
		if has_enemy_threat_land(&enemy_attack_options, land) {
			fmt.println("  Land:", land, 
			           "Inf:", threat.max_infantry,
			           "Art:", threat.max_artillery,
			           "Tank:", threat.max_tanks,
			           "Ftr:", threat.max_fighters,
			           "Bmb:", threat.max_bombers,
			           "Str:", threat.strength_estimate)
		}
	}

	need_to_defend_land := prioritize_territories_to_defend_triplea(
		gc,
		true,
		&all_enemies,
		&enemy_attack_options,
	)
	
	// Reserve budget for naval if we're a coastal power
	// This prevents spending ALL money on infantry when we need transports
	naval_budget := calculate_naval_budget_reserve(gc)
	if naval_budget > 0 {
		when ODIN_DEBUG {
			fmt.printf("  [BUDGET] Reserving %d IPCs for naval purchases\n", naval_budget)
		}
	}
	
	purchase_defenders_triplea(gc, need_to_defend_land, true, naval_budget)

	// Prioritize sea territories needing defense (if any)
	need_to_defend_sea := prioritize_territories_to_defend_triplea(
		gc,
		false,
		&all_enemies,
		&enemy_attack_options,
	)
	purchase_defenders_triplea(gc, need_to_defend_sea, false, 0) // No naval reserve for sea defense

	if gc.money[gc.cur_player] == 0 {
		return true // All money spent on defense
	}

	// Step 4: Prioritize land territories for offensive purchases
	prioritized_land := prioritize_land_territories_triplea(gc)

	// Step 5: Purchase AA guns for territories with factories
	// Pass naval budget to prevent AA from spending money reserved for transports
	purchase_aa_units_triplea(gc, prioritized_land, naval_budget)

	// Step 5.5: MOVED HERE - Prioritize sea territories and purchase naval units 
	// This is moved BEFORE offensive land purchases to ensure ships can be bought
	// when under sea threat. Otherwise, land units spend all money first.
	prioritized_sea := prioritize_sea_territories_triplea(gc)
	debug_checks(gc)
	should_save_for_fleet := purchase_sea_and_amphib_units_triplea(gc, prioritized_sea, &all_enemies, &enemy_attack_options)
	debug_checks(gc)

	// Step 6: Purchase offensive land units (infantry, tanks, artillery)
	purchase_land_units_triplea(gc, prioritized_land)

	if gc.money[gc.cur_player] == 0 {
		return true // All money spent
	}

	// Step 7: Consider factory purchase (if economically viable)
	purchase_factory_triplea(gc, false)

	if gc.money[gc.cur_player] == 0 {
		return true // All money spent on factory
	}
	debug_checks(gc)

	if should_save_for_fleet {
		// Saving up for a fleet - don't spend remaining money
		return true
	}

	if gc.money[gc.cur_player] == 0 {
		return true // All money spent
	}

	debug_checks(gc)
	// Step 9: Use remaining production capacity
	purchase_units_with_remaining_production_triplea(gc, prioritized_land)

	debug_checks(gc)
	// Step 10: Upgrade units with remaining PUs (if any)
	if gc.money[gc.cur_player] >= 3 {
		upgrade_units_with_remaining_pus_triplea(gc, prioritized_land)
	}
	debug_checks(gc)

	// Step 11: Try factory purchase again with remaining PUs (if we have extra)
	if gc.money[gc.cur_player] >= 15 {
		purchase_factory_triplea(gc, true)
	}

	return true
}

/*
=============================================================================
METHOD 4: shouldSaveUpForAFleet
=============================================================================

Java Original (lines 389-445):

  private boolean shouldSaveUpForAFleet(
      final ProPurchaseOptionMap purchaseOptions,
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories) {
    if (resourceTracker.isEmpty()
        || purchaseOptions.getSeaDefenseOptions().isEmpty()
        || purchaseOptions.getSeaTransportOptions().isEmpty()) {
      return false;
    }
    Optional<Territory> enemyTerritoryReachableByLand =
        territoryManager.findClosestTerritory(
            purchaseTerritories.keySet(),
            ProMatches.territoryCanPotentiallyMoveLandUnits(player),
            Matches.isTerritoryEnemy(player).and(Matches.territoryIsLand()));
    if (enemyTerritoryReachableByLand.isPresent()) {
      // An enemy territory is reachable by land, no need to save for a fleet.
      return false;
    }
    // See if we can reach the enemy by sea from a sea placement territory
    // [Lines 408-436 - Check if enemy only reachable by sea]
    
    // Don't save up more if we already have enough PUs to buy the biggest fleet we can
    IntegerMap<Resource> maxShipCost = new IntegerMap<>();
    for (ProPurchaseOption option : purchaseOptions.getSeaDefenseOptions()) {
      if (option.getCost() > maxShipCost.getInt(pus)) {
        maxShipCost.add(pus, option.getCost());
      }
    }
    maxShipCost.multiplyAllValuesBy(maxSeaUnitsThatCanBePlaced);
    if (resourceTracker.hasEnough(maxShipCost)) {
      return false;
    }
    ProLogger.info("Saving up for a fleet, since enemy territories are only reachable by sea");
    return true;
  }
*/

// Odin Implementation:
should_save_up_for_fleet_triplea :: proc(gc: ^Game_Cache) -> bool {
	// If no money, don't save
	if gc.money[gc.cur_player] == 0 do return false

	// Check if we can reach enemy by land
	enemy_reachable_by_land := can_reach_enemy_by_land_triplea(gc)
	if enemy_reachable_by_land {
		// Enemy reachable by land, no need to save for fleet
		return false
	}

	// Check if we already have enough PUs for a significant fleet
	// A "significant fleet" is destroyer (8) + transport (7) + cruiser (12) = 27 IPCs minimum
	max_ship_cost := u8(27)

	// Also consider carrier (14) + 2 fighters (20) = 34 for air cover
	max_fleet_cost := u8(50)

	if gc.money[gc.cur_player] >= max_fleet_cost {
		// We have enough, don't save more
		return false
	}

	// Enemy only reachable by sea and we don't have enough yet - save up
	return true
}

// Helper: Check if we can reach any enemy territory by land
can_reach_enemy_by_land_triplea :: proc(gc: ^Game_Cache) -> bool {
	/*
	Java Original (from ProPurchaseAi.java lines 397-407):
	
	Optional<Territory> enemyTerritoryReachableByLand =
		territoryManager.findClosestTerritory(
			purchaseTerritories.keySet(),
			ProMatches.territoryCanPotentiallyMoveLandUnits(player),
			Matches.isTerritoryEnemy(player).and(Matches.territoryIsLand()));
	if (enemyTerritoryReachableByLand.isPresent()) {
		return false;
	}
	*/

	// Check if any enemy land territory is adjacent to our territories
	for territory in Land_ID {
		if gc.owner[territory] == gc.cur_player {
			// Check adjacent territories
			for adj_id in sa.slice(&mm.l2l_1away_via_land[territory]) {
				adj := adj_id
				if gc.owner[adj] != gc.cur_player {
					// Check if this is an enemy (not an ally)
					is_ally := false
					for ally_id in sa.slice(&mm.allies[gc.cur_player]) {
						if gc.owner[adj] == ally_id {
							is_ally = true
							break
						}
					}
					if !is_ally {
						// Found enemy territory adjacent by land
						return true
					}
				}
			}
		}
	}

	return false
}

/*
=============================================================================
METHOD 5: findDefendersInPlaceTerritories
=============================================================================

Java Original (lines 578-588):

  private void findDefendersInPlaceTerritories(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories) {
    ProLogger.info("Find defenders in possible place territories");
    for (final ProPurchaseTerritory ppt : purchaseTerritories.values()) {
      for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
        placeTerritory.setDefendingUnits(
            placeTerritory
                .getTerritory()
                .getMatches(ProMatches.unitIsAlliedNotOwnedAir(player).negate()));
      }
    }
  }
*/

// Odin Implementation:
find_defenders_in_place_territories_triplea :: proc(
	gc: ^Game_Cache,
) -> map[Land_ID]Territory_Defenders {
	/*
	Java logic: For each place territory, find defending units
	Defenders = allied units EXCEPT air units we don't own
	(e.g., allied fighters on our territory count, but not if they belong to ally)
	*/

	defenders_map := make(map[Land_ID]Territory_Defenders)

	// Check all territories where we can place (have factories)
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.owner[factory_loc] != gc.cur_player do continue

		defenders := Territory_Defenders{}

		// Count our own units at this location
		defenders.inf = gc.idle_armies[factory_loc][gc.cur_player][.INF]
		defenders.arty = gc.idle_armies[factory_loc][gc.cur_player][.ARTY]
		defenders.tank = gc.idle_armies[factory_loc][gc.cur_player][.TANK]
		defenders.aa = gc.idle_armies[factory_loc][gc.cur_player][.AAGUN]
		defenders.fighter = gc.idle_land_planes[factory_loc][gc.cur_player][.FIGHTER]
		defenders.bomber = gc.idle_land_planes[factory_loc][gc.cur_player][.BOMBER]

		defenders_map[factory_loc] = defenders
	}

	return defenders_map
}

Territory_Defenders :: struct {
	inf:     u8,
	arty:    u8,
	tank:    u8,
	aa:      u8,
	fighter: u8,
	bomber:  u8,
}

// Purchase tracking structure (for purchase/place separation)
Purchased_Units :: struct {
	territory:  Land_ID, // Where to place these units
	inf:        u8,
	arty:       u8,
	tank:       u8,
	aa:         u8,
	fighter:    u8,
	bomber:     u8,
	// Naval units (for coastal factories)
	sub:        u8,
	destroyer:  u8,
	cruiser:    u8,
	carrier:    u8,
	battleship: u8,
	transport:  u8,
}

// Global purchase tracking (set during purchase phase, cleared during place phase)
g_purchased_units: [dynamic]Purchased_Units
g_purchased_factories: [dynamic]Land_ID // Territories where factories should be placed

/*
=============================================================================
METHOD 6: prioritizeTerritoriesToDefend
=============================================================================

Java Original (lines 590-713):

  private List<ProPlaceTerritory> prioritizeTerritoriesToDefend(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories, final boolean isLand) {

    ProLogger.info("Prioritize territories to defend with isLand=" + isLand);

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Determine which territories need defended
    final Set<ProPlaceTerritory> needToDefendTerritories = new HashSet<>();
    for (final ProPurchaseTerritory ppt : purchaseTerritories.values()) {
      for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
        final Territory t = placeTerritory.getTerritory();
        
        // Check if land/sea matches and if we own it
        // [Lines 604-612 - Filter checks]
        
        // Check if territory is attacked
        if (enemyAttackOptions.getMax(t) == null) { continue; }
        
        // Estimate current battle result
        // [Lines 619-652 - Battle simulation]
        
        // Add to list if can't hold
        if (!result.isHasLandUnitRemaining()
            && (Matches.territoryIsLand().test(t) || result.getTuvSwing() > minTuvSwing)) {
          needToDefendTerritories.add(placeTerritory);
        }
      }
    }

    // Calculate value of defending territory
    for (final ProPlaceTerritory placeTerritory : needToDefendTerritories) {
      final Territory t = placeTerritory.getTerritory();

      // Determine if it is my capital or adjacent to my capital
      int isMyCapital = 0;
      if (t.equals(proData.getMyCapital())) {
        isMyCapital = 1;
      }

      // Determine if it has a factory
      int isFactory = 0;
      if (ProMatches.territoryHasInfraFactoryAndIsOwnedLand(player).test(t)) {
        isFactory = 1;
      }

      // Determine production value
      int production = TerritoryAttachment.get(t).map(TerritoryAttachment::getProduction).orElse(0);

      // Determine defending unit value
      double defendingUnitValue =
          TuvUtils.getTuv(placeTerritory.getDefendingUnits(), proData.getUnitValueMap());

      // Calculate defense value for prioritization
      final double territoryValue =
          (2.0 * production + 4.0 * isFactory + 0.5 * defendingUnitValue)
              * (1 + isFactory)
              * (1 + 10.0 * isMyCapital);
      placeTerritory.setDefenseValue(territoryValue);
    }

    // Remove any territories with negative defense value
    needToDefendTerritories.removeIf(ppt -> ppt.getDefenseValue() <= 0);

    // Sort territories by value
    final List<ProPlaceTerritory> sortedTerritories = new ArrayList<>(needToDefendTerritories);
    sortedTerritories.sort(
        Comparator.comparingDouble(ProPlaceTerritory::getDefenseValue).reversed());
    return sortedTerritories;
  }
*/

Territory_Target :: struct {
	Infantry:    u8,
	Artillery:   u8,
	Tanks:       u8,
	Fighters:    u8,
	Bombers:     u8,
	Subs:        u8,
	Destroyers:  u8,
	Carriers:    u8,
	Cruisers:    u8,
	Battleships: u8,
	Bs_Damaged:  u8,
}

win_percentage_needed :: 0.95

// Sequential battle result - tracks cumulative results across multiple enemy attacks
Sequential_Battle_Result :: struct {
	total_tuv_swing: f64,           // Accumulated TUV swing across all battles
	final_invaded_percent: f64,     // Probability territory is taken after all attacks
	surviving_defenders: Land_Defenders,  // Remaining defenders after all battles
	num_battles: int,               // How many battles were simulated
}

// Simulate sequential battles where multiple enemies attack in turn order
// Each enemy attacks separately, survivors defend against next attacker
// Returns accumulated TUV swing and final invasion probability
simulate_sequential_enemy_attacks :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	initial_defenders: Land_Defenders,
	all_enemies: ^All_Enemy_Attack_Options,
) -> Sequential_Battle_Result {
	result := Sequential_Battle_Result{
		surviving_defenders = initial_defenders,
	}
	
	// Track probability that territory is still held after each battle
	// Start with 100% chance we hold it
	hold_probability: f64 = 1.0
	
	// Iterate through enemies in turn order (using enemies_analyzed which preserves order)
	for enemy in all_enemies.enemies_analyzed {
		threat := &all_enemies.per_enemy[enemy].land_threats[territory]
		
		// Skip enemies with no threat to this territory
		if threat.max_infantry == 0 && threat.max_artillery == 0 && 
		   threat.max_tanks == 0 && threat.max_fighters == 0 && 
		   threat.max_bombers == 0 {
			continue
		}
		
		// Set up battle combatants for this enemy's attack
		combatants := Land_Combatants{}
		combatants.attackers[0].Infantry = threat.max_infantry
		combatants.attackers[0].Artillery = threat.max_artillery
		combatants.attackers[0].Tanks = threat.max_tanks
		combatants.attackers[0].Fighters = threat.max_fighters
		combatants.attackers[0].Bombers = threat.max_bombers
		combatants.defenders = result.surviving_defenders
		
		// Simulate this battle
		battle_result := simulate_battle(combatants)
		result.num_battles += 1
		
		// Accumulate TUV swing
		result.total_tuv_swing += battle_result.avg_TUV_swing
		
		// Update hold probability: we only hold if we held before AND we hold this battle
		// invaded_percent is probability attacker wins, so (1 - invaded_percent) is hold probability
		hold_probability *= (1.0 - battle_result.invaded_percent)
		
		// Estimate surviving defenders for next battle
		// Use avg_survivor_def_power to estimate remaining units
		// This is simplified - we assume proportional losses
		if battle_result.avg_survivor_def_power > 0 && battle_result.invaded_percent < 1.0 {
			// Calculate what fraction of defense power survives
			initial_def_power := estimate_defense_power_triplea(result.surviving_defenders)
			if initial_def_power > 0 {
				survival_ratio := battle_result.avg_survivor_def_power / initial_def_power
				survival_ratio = min(1.0, max(0.0, survival_ratio))
				
				// Apply survival ratio to each unit type (simplified)
				result.surviving_defenders.Infantry = u8(f64(result.surviving_defenders.Infantry) * survival_ratio)
				result.surviving_defenders.Artillery = u8(f64(result.surviving_defenders.Artillery) * survival_ratio)
				result.surviving_defenders.Tanks = u8(f64(result.surviving_defenders.Tanks) * survival_ratio)
				result.surviving_defenders.Fighters = u8(f64(result.surviving_defenders.Fighters) * survival_ratio)
				result.surviving_defenders.Bombers = u8(f64(result.surviving_defenders.Bombers) * survival_ratio)
				result.surviving_defenders.AntiAir = u8(f64(result.surviving_defenders.AntiAir) * survival_ratio)
			}
		} else if battle_result.invaded_percent >= 1.0 {
			// Territory lost - no survivors
			result.surviving_defenders = {}
		}
	}
	
	// Final invaded percent is probability we DON'T hold after all battles
	result.final_invaded_percent = 1.0 - hold_probability
	
	return result
}

// PUR-006: prioritizeTerritoriesToDefend() - Sort territories by defense priority
prioritize_territories_to_defend_triplea :: proc(
	gc: ^Game_Cache,
	is_land: bool,
	all_enemies: ^All_Enemy_Attack_Options,
	enemy_attack_options: ^Pro_Other_Move_Options,  // Still used for quick "has threat" check
) -> [dynamic]Place_Territory_Defense {
	need_to_defend := make([dynamic]Place_Territory_Defense, context.temp_allocator)

	when ODIN_DEBUG {
		fmt.printf(
			"  [RATIONALE] Evaluating %s territories for defensive needs...\n",
			is_land ? "land" : "sea",
		)
	}

	// Sea territories - calculate defense needs based on TUV at risk
	if !is_land {
		when ODIN_DEBUG {
			fmt.println("    Evaluating sea zones for defensive needs...")
		}
		
		for sea in Sea_ID {
			// Check if we have any units in this sea zone
			our_units := count_our_ships(gc, sea)
			if our_units.total == 0 do continue
			
			// Check if there's enemy threat
			if !has_enemy_threat_sea(enemy_attack_options, sea) do continue
			
			// Get enemy threat
			threat := get_max_sea_threat(enemy_attack_options, sea)
			
			// Gather our defending ships
			defenders := gather_sea_defenders(gc, sea)
			
			// Calculate TUV at risk (value of our ships)
			tuv_at_risk := calculate_sea_tuv(our_units)
			hold_value := tuv_at_risk / 8.0  // Java uses unitValue / 8
			
			// Gather enemy attackers
			attackers := Sea_Attackers{
				Subs = threat.max_subs,
				Destroyers = threat.max_destroyers,
				Cruisers = threat.max_cruisers,
				Battleships = threat.max_battleships,
				Carriers = threat.max_carriers,
				Fighters = threat.max_fighters,
				Bombers = threat.max_bombers,
			}
			
			// Simulate battle
			combatants := Sea_Combatants{
				defenders = defenders,
				attackers = attackers,
			}
			result := get_sea_battle_results(combatants)
			
			when ODIN_DEBUG {
				fmt.printf("    Sea_%d: TUV=%.1f, holdValue=%.1f, TUV_swing=%.1f, win%%=%.1f%%\n",
					int(sea), tuv_at_risk, hold_value, result.avg_TUV_swing, result.win_percent)
			}
			
			// If TUV swing > hold value, we need defense
			// (TUV swing is negative when we lose, so check if loss > acceptable)
			if result.avg_TUV_swing <= hold_value {
				when ODIN_DEBUG {
					fmt.printf("      [SAFE] TUV swing %.1f <= hold value %.1f\n", 
						result.avg_TUV_swing, hold_value)
				}
				continue
			}
			
			// This sea zone needs defense - but we return Land_ID based structs
			// For now, find adjacent coastal factory to purchase from
			adjacent_factory := find_factory_for_sea_defense(gc, sea)
			if adjacent_factory == nil {
				when ODIN_DEBUG {
					fmt.printf("      [SKIP] No adjacent factory for Sea_%d\n", int(sea))
				}
				continue
			}
			
			factory_loc := adjacent_factory.?
			
			when ODIN_DEBUG {
				fmt.printf("      [THREATENED] Sea_%d needs defense, factory at %v\n", 
					int(sea), factory_loc)
			}
			
			// Create a Place_Territory_Defense using factory location as territory
			// This is a workaround - ideally we'd have a separate sea structure
			place_terr := Place_Territory_Defense{
				territory = factory_loc,
				defense_value = tuv_at_risk,  // Use TUV as priority
				defending_units = {},  // Empty for sea - not used
				is_capital = false,
				has_factory = true,
			}
			append(&need_to_defend, place_terr)
		}
		
		// Sort by defense value (highest TUV at risk first)
		for i := 0; i < len(need_to_defend) - 1; i += 1 {
			for j := i + 1; j < len(need_to_defend); j += 1 {
				if need_to_defend[j].defense_value > need_to_defend[i].defense_value {
					need_to_defend[i], need_to_defend[j] = need_to_defend[j], need_to_defend[i]
				}
			}
		}
		
		when ODIN_DEBUG {
			fmt.printf("    Found %d sea zones needing defense\n", len(need_to_defend))
		}
		
		return need_to_defend
	}

	// #region PUR-007: for (ProPlaceTerritory) loop - evaluate each territory for defense needs
	for land_territory in Land_ID {
		//check if units are placeable here
		// if gc.factory_prod[land_territory] == 0 do continue

		//check if we own it
		if gc.owner[land_territory] != gc.cur_player do continue
		
		// Check if there's any enemy threat to this territory
		if !has_enemy_threat_land(enemy_attack_options, land_territory) do continue

		
		// Calculate defense value using TripleA formula:
		// value = (2*production + 4*isFactory + 0.5*defenderValue) * (1+isFactory) * (1+10*isCapital)

		is_capital := mm.capital[gc.cur_player] == land_territory
		has_factory := gc.factory_prod[land_territory] > 0

		production := f64(mm.value[land_territory])
		is_factory_mult := has_factory ? 1.0 : 0.0
		is_capital_mult := is_capital ? 1.0 : 0.0

		// Gather current defenders
		initial_defenders: Land_Defenders = {}
		for player in sa.slice(&mm.allies[gc.cur_player]) {
			initial_defenders.Infantry += gc.idle_armies[land_territory][player][.INF]
			initial_defenders.Artillery += gc.idle_armies[land_territory][player][.ARTY]
			initial_defenders.AntiAir += gc.idle_armies[land_territory][player][.AAGUN]
			initial_defenders.Tanks += gc.idle_armies[land_territory][player][.TANK]
			initial_defenders.Fighters += gc.idle_land_planes[land_territory][player][.FIGHTER]
			initial_defenders.Bombers += gc.idle_land_planes[land_territory][player][.BOMBER]
		}
		// Calculate defending unit value (simplified TUV)
		defender_value := f64(
			initial_defenders.Infantry * Cost_Buy[.BUY_INF_ACTION] +
			initial_defenders.Artillery * Cost_Buy[.BUY_ARTY_ACTION] +
			initial_defenders.AntiAir * Cost_Buy[.BUY_AAGUN_ACTION] +
			initial_defenders.Tanks * Cost_Buy[.BUY_TANK_ACTION] +
			initial_defenders.Fighters * Cost_Buy[.BUY_FIGHTER_ACTION] +
			initial_defenders.Bombers * Cost_Buy[.BUY_BOMBER_ACTION],
		)

		defense_value :=
			(2.0 * production + 4.0 * is_factory_mult + 0.5 * defender_value) *
			(1.0 + is_factory_mult) *
			(1.0 + 10.0 * is_capital_mult)
		when ODIN_DEBUG {
			fmt.printf("    Possible Enemy Target Territory: %v defense_value: %.1f", land_territory, defense_value)
			if is_capital do fmt.printf(" [CAPITAL]")
			if has_factory do fmt.printf(" [FACTORY]")
			fmt.println()
		}

		if defense_value == 0 do continue
		
		// Simulate sequential battles - each enemy attacks in turn order
		// Survivors from one battle defend against the next attacker
		seq_result := simulate_sequential_enemy_attacks(gc, land_territory, initial_defenders, all_enemies)
		


		// Skip territories that are not sufficiently threatened
		if seq_result.final_invaded_percent < 1.0 - win_percentage_needed {
			fmt.printf("      [SAFE] Sequential Battle Results: TUV=%.2f, Invaded%%=%.1f%%, Battles=%d\n", 
		           seq_result.total_tuv_swing, seq_result.final_invaded_percent * 100, seq_result.num_battles)
			continue
		}
		when ODIN_DEBUG {
			fmt.printf(
				"      [THREATENED] Territory %v is not sufficiently protected (invaded%%=%.1f%% < needed=%.1f%%)\n",
				land_territory, seq_result.final_invaded_percent * 100, win_percentage_needed * 100,
			)
		}
		place_terr := Place_Territory_Defense {
			territory       = land_territory,
			defense_value   = defense_value,
			defending_units = initial_defenders,
			is_capital      = is_capital,
			has_factory     = has_factory,
		}
		append(&need_to_defend, place_terr)
	}
	// #endregion PUR-007

	// Sort by defense value (highest first)
	for i := 0; i < len(need_to_defend) - 1; i += 1 {
		for j := i + 1; j < len(need_to_defend); j += 1 {
			if need_to_defend[j].defense_value > need_to_defend[i].defense_value {
				need_to_defend[i], need_to_defend[j] = need_to_defend[j], need_to_defend[i]
			}
		}
	}

	result := make([dynamic]Place_Territory_Defense)
	for terr in need_to_defend {
		append(&result, terr)
	}

	when ODIN_DEBUG {
		fmt.printf(
			"  [RATIONALE] Found %d threatened territories (sorted by priority)\n",
			len(result),
		)
	}

	return result
}

Place_Territory_Defense :: struct {
	territory:       Land_ID,
	defense_value:   f64,
	defending_units: Land_Defenders,
	is_capital:      bool,
	has_factory:     bool,
}

// Sea territory defense structure
Place_Sea_Territory_Defense :: struct {
	sea_zone:        Sea_ID,
	defense_value:   f64,
	defending_units: Sea_Defenders,
	tuv_at_risk:     f64,  // Value of our ships that could be lost
}

/*
=============================================================================
METHOD 7: purchaseDefenders
=============================================================================

Java Original (lines 715-914):

  private void purchaseDefenders(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPlaceTerritory> needToDefendTerritories,
      final List<ProPurchaseOption> defensePurchaseOptions,
      final List<ProPurchaseOption> zeroMoveDefensePurchaseOptions,
      final List<ProPurchaseOption> airPurchaseOptions,
      final boolean isLand) {
    if (resourceTracker.isEmpty()) {
      return;
    }
    ProLogger.info("Purchase defenders with resources: " + resourceTracker + ", isLand=" + isLand);

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Loop through prioritized territories and purchase defenders
    for (final ProPlaceTerritory placeTerritory : needToDefendTerritories) {
      final Territory t = placeTerritory.getTerritory();
      
      // Find local owned units
      final List<Unit> ownedLocalUnits = t.getMatches(Matches.unitIsOwnedBy(player));
      int unusedCarrierCapacity = [...]
      
      // Determine if need destroyer (for enemy subs)
      boolean needDestroyer =
          enemyAttackOptions.getMax(t).getMaxUnits().stream()
                  .anyMatch(Matches.unitHasSubBattleAbilities())
              && ownedLocalUnits.stream().noneMatch(Matches.unitIsDestroyer());

      // Find all purchase territories for place territory
      final List<Unit> unitsToPlace = new ArrayList<>();
      ProBattleResult finalResult = new ProBattleResult();
      final List<ProPurchaseTerritory> selectedPurchaseTerritories =
          getPurchaseTerritories(placeTerritory, purchaseTerritories);
      for (final ProPurchaseTerritory purchaseTerritory : selectedPurchaseTerritories) {
        // [Lines 764-879 - Purchase defenders until can hold]
        // Key logic:
        // 1. Find best defensive unit (efficiency = defense/cost)
        // 2. Purchase until battle result is favorable
        // 3. Check if worth defending (has local superiority)
      }

      // Check to see if its worth trying to defend the territory
      final boolean hasLocalSuperiority =
          ProBattleUtils.territoryHasLocalLandSuperiority(
              proData, t, ProBattleUtils.SHORT_RANGE, player, purchaseTerritories);
      if (!finalResult.isHasLandUnitRemaining()
          || (finalResult.getTuvSwing() - resourceTracker.getTempPUs(data) / 2f)
              < placeTerritory.getMinBattleResult().getTuvSwing()
          || t.equals(proData.getMyCapital())
          || (!t.isWater() && hasLocalSuperiority)) {
        // Keep defenders
      } else {
        // Remove defenders and cancel purchase
      }
    }
  }
*/

// PUR-012: purchaseDefenders() - Buy defensive units for threatened territories
purchase_defenders_triplea :: proc(
	gc: ^Game_Cache,
	territories: [dynamic]Place_Territory_Defense,
	is_land: bool,
	naval_budget_reserve: u8, // Money to reserve for naval purchases
) {
	// TODO REVIEW: Java purchaseDefenders (lines 715-914) has additional logic:
	//
	// Missing Block 1 (lines 739-744): Carrier capacity tracking
	//   - carrierCapacity and carrierFightersToAdd for sea defense
	//   - Tracks fighters that can land on purchased carriers
	//
	// Missing Block 2 (lines 749-761): Zero-move defense options
	//   - Considers constructions like AA guns with different production limits
	//   - Multiple purchase territories for single place territory
	//
	// Missing Block 3 (lines 829-844): Sea defense efficiency
	//   - defenseEfficiency = defense / cost * 100 - 1
	//   - Different efficiency formula for sea vs land
	//
	// Missing Block 4 (lines 876-895): Temp purchase confirmation
	//   - confirmPlacementUnits() / clearTempPurchase() pattern
	//   - Tracks purchases tentatively before confirming
	//
	// Missing Block 5: Defense efficiency with existing units
	//   - Java calculates efficiency considering support bonuses
	//
	// Missing Block 6: Randomized purchase selection
	//   - Java uses random selection for variety
	//
	// Missing Block 7: Local superiority check
	//   - Java checks if we have local superiority already
	
	if gc.money[gc.cur_player] == 0 do return
	if len(territories) == 0 do return

	// Purchase defenders for each threatened territory (in priority order)
	when ODIN_DEBUG {
		fmt.println("  [RATIONALE] Analyzing territories needing defense:")
	}

	// #region PUR-013: for (ProPlaceTerritory) loop - purchase defenders for each threatened territory
	for place_terr in territories {
		// Find nearest factory that can produce for this territory
		factory := find_nearest_factory_triplea(gc, place_terr.territory)
		if factory == nil do continue

		factory_loc := factory.?

		// Gather enemy attackers from adjacent territories
		enemy_attackers := gather_enemy_attackers_from_adjacent(gc, place_terr.territory)

		// Use battle simulation for accurate defense assessment
		combatants := Land_Combatants {
			defenders = place_terr.defending_units,
			attackers = [3]Land_Attackers{enemy_attackers, {}, {}},
		}
		battle_result := get_battle_results(combatants)

		// Also keep simple power estimates for debug output
		// current_defense := estimate_defense_power_triplea(place_terr.defending_units)
		// enemy_threat := estimate_attack_power_triplea(enemy_attackers)

		when ODIN_DEBUG {
			fmt.printf("    Territory: %v\n", place_terr.territory)
			// fmt.printf("      Current defense power: %.1f\n", current_defense)
			// fmt.printf(
			// 	"      Enemy threat estimate: %.1f (from adjacent territories)\n",
			// 	enemy_threat,
			// )

			// Show breakdown of threats
			threat_details := make([dynamic]string)
			defer delete(threat_details)

			for adjacent in sa.slice(&mm.l2l_1away_via_land[place_terr.territory]) {
				adjacent_threat := f64(0)
				enemy_count := 0

				for player in Player_ID {
					if mm.team[player] != mm.team[gc.cur_player] {
						inf := gc.idle_armies[adjacent][player][.INF]
						arty := gc.idle_armies[adjacent][player][.ARTY]
						tank := gc.idle_armies[adjacent][player][.TANK]

						if inf > 0 || arty > 0 || tank > 0 {
							adjacent_threat += f64(inf) * 1.0 + f64(arty) * 2.0 + f64(tank) * 3.0
							enemy_count += int(inf) + int(arty) + int(tank)
						}
					}
				}

				if adjacent_threat > 0 {
					append(
						&threat_details,
						fmt.tprintf(
							"        %v: %.1f threat (%d units)",
							adjacent,
							adjacent_threat,
							enemy_count,
						),
					)
				}
			}

			if len(threat_details) > 0 {
				// fmt.println("      Threats from adjacent territories:")
				// for detail in threat_details {
				// 	fmt.println(detail)
				// }
			} else {
				fmt.println("      No adjacent enemy threats detected")
			}

			// fmt.printf("      Defense gap: %.1f\n", enemy_threat - current_defense)
			fmt.printf("      Nearest factory: %v\n", factory_loc)
			fmt.printf("      Battle simulation: %.1f%% chance of invasion, TUV swing: %.1f\n", 
				battle_result.invaded_percent * 100.0, battle_result.avg_TUV_swing)
		}

		// Use battle simulation: skip if less than 15% chance of being invaded
		// This is more accurate than simple power comparison
		INVASION_THRESHOLD :: 0.15
		if battle_result.invaded_percent < INVASION_THRESHOLD {
			when ODIN_DEBUG {
				fmt.printf("      Decision: Already adequately defended (%.1f%% invasion chance < %.0f%% threshold) - skipping\n",
					battle_result.invaded_percent * 100.0, INVASION_THRESHOLD * 100.0)
			}
			continue
		}

		// defense_gap := enemy_threat - current_defense

		// Purchase defenders until gap is closed or we run out of money
		// Use defensive efficiency: defense_power / cost
		// Infantry: defense 2, cost 3 -> efficiency 0.67
		// Artillery: defense 2, cost 4 -> efficiency 0.5
		// Tank: defense 3, cost 6 -> efficiency 0.5
		// Fighter: defense 4, cost 10 -> efficiency 0.4


		inf_count := u8(0)
		// Prefer infantry for defense (best efficiency)
		// Respect both money AND production capacity limits
		// Use battle simulation to determine when we've purchased enough
		current_defenders := place_terr.defending_units
		// #region PUR-015: while loop - buy fodder units until territory is defended
		// Check if we need to reserve money for naval purchases
		// Use max(0, money - reserve) to ensure we don't spend reserved money
		available_money: u8 = 0
		if gc.money[gc.cur_player] > naval_budget_reserve {
			available_money = gc.money[gc.cur_player] - naval_budget_reserve
		}
		
		// Also reserve 1 production capacity for transport if we have naval budget
		// This ensures we can actually BUILD a transport with the reserved money
		min_builds_remaining: u8 = 0
		if naval_budget_reserve >= 7 {
			min_builds_remaining = 1 // Reserve capacity for 1 transport
		}
		
		for available_money >= 3 && gc.builds_left[factory_loc] > min_builds_remaining {
			// Re-simulate battle with current defenders to check if we need more
			test_combatants := Land_Combatants {
				defenders = current_defenders,
				attackers = [3]Land_Attackers{enemy_attackers, {}, {}},
			}
			when ODIN_DEBUG {
				fmt.println("        Re-simulating battle:")
				fmt.printf("          Defenders: %s\n", format_land_defenders(current_defenders))
				fmt.printf("          Attackers: %s\n", format_land_attackers(enemy_attackers))
			}

			test_result := get_battle_results(test_combatants)

			when ODIN_DEBUG {
				fmt.printf(
					"        Re-simulated battle: invasion chance: %.1f%%, TUV swing: %.1f\n",
					test_result.invaded_percent * 100.0,
					test_result.avg_TUV_swing,
				)
			}
			
			// Stop purchasing if invasion chance is below threshold
			if test_result.invaded_percent < INVASION_THRESHOLD {
				break
			}
			
			when ODIN_DEBUG {
				fmt.printf(
					"      Purchasing infantry, Money: %d, factory: %v, capacity: %d\n",
					gc.money[gc.cur_player],
					factory_loc,
					gc.builds_left[factory_loc],
				)
			}
			// Buy infantry - store in g_purchased_units for placement phase
			gc.money[gc.cur_player] -= 3
			gc.builds_left[factory_loc] -= 1 // Decrement production capacity
			add_units_to_place_triplea(factory_loc, .Infantry, 1)
			inf_count += 1
			current_defenders.Infantry += 1  // Track added infantry for next simulation
			
			// Update available money for next iteration
			// Use max(0, money - reserve) to ensure we don't spend reserved money
			if gc.money[gc.cur_player] > naval_budget_reserve {
				available_money = gc.money[gc.cur_player] - naval_budget_reserve
			} else {
				available_money = 0
			}
		}
		// #endregion PUR-015
	}
	// #endregion PUR-013
}

// Helper: Find nearest factory to territory
find_nearest_factory_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> Maybe(Land_ID) {
	/*
	Java Original (from ProPurchaseUtils.java):
	
	final List<ProPurchaseTerritory> selectedPurchaseTerritories =
		getPurchaseTerritories(placeTerritory, purchaseTerritories);
	
	This finds factories that can reach the territory (considering movement)
	
	CRITICAL FIX: Only consider factories that can actually reinforce the territory:
	1. The territory itself (if it has a factory)
	2. Factories connected by land within infantry movement range
	
	Factories across the ocean (like Eastern_United_States for Szechwan) should NOT
	be considered for defensive purchases since units won't arrive this turn.
	*/

	// First check if the territory itself is a factory with capacity
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if factory_loc == territory {
			if gc.owner[factory_loc] == gc.cur_player && gc.builds_left[factory_loc] > 0 {
				return territory // Place at the territory's own factory
			}
			break
		}
	}

	// Find nearest factory that can actually reach this territory by land
	// Infantry moves 1, so we need factories within land distance 1
	// (placed units can move in NCM to reinforce adjacent territory)
	best_factory: Maybe(Land_ID) = nil
	best_distance: u8 = 255  // Use high value for "no path"
	
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.owner[factory_loc] != gc.cur_player do continue
		if gc.builds_left[factory_loc] == 0 do continue // Skip exhausted factories
		
		// Check land distance - units placed at factory can reinforce if adjacent
		land_dist := mm.land_distances[factory_loc][territory]
		
		// Only consider factories within reasonable land range (1-2 moves for infantry)
		// Distance 0 = same territory (handled above)
		// Distance 1 = adjacent, can reinforce in NCM
		// Distance 2+ = too far for immediate defense
		if land_dist == 0 || land_dist > 2 || land_dist == 127 { // 127 = no land path
			continue
		}
		
		// Prefer closer factories, or factories with more capacity if same distance
		if land_dist < best_distance || (land_dist == best_distance && (best_factory == nil || gc.builds_left[factory_loc] > gc.builds_left[best_factory.?])) {
			best_distance = land_dist
			best_factory = factory_loc
		}
	}

	return best_factory
}

// Calculate how much money to reserve for naval purchases
// Coastal powers (with factories adjacent to sea) should reserve money for transports/ships
calculate_naval_budget_reserve :: proc(gc: ^Game_Cache) -> u8 {
	player := gc.cur_player
	
	// Check if we have any coastal factories
	has_coastal_factory := false
	for factory_loc in sa.slice(&gc.factory_locations[player]) {
		if gc.owner[factory_loc] != player do continue
		if gc.builds_left[factory_loc] == 0 do continue
		
		// Check if factory is coastal (adjacent to sea)
		if len(sa.slice(&mm.l2s_1away_via_land[factory_loc])) > 0 {
			has_coastal_factory = true
			break
		}
	}
	
	if !has_coastal_factory {
		return 0 // Landlocked - no naval budget needed
	}
	
	// Reserve enough for 1 transport (7 IPC) + some combat ships
	// This ensures UK can buy transports even when threatened
	// Use 25% of total income as naval reserve, minimum 7 (transport cost)
	income := gc.money[player]
	reserve := max(u8(7), income / 4)
	
	// Cap at 50% to not over-reserve
	return min(reserve, income / 2)
}

// Helper: Estimate defense power of units
estimate_defense_power_triplea :: proc(units: Land_Defenders) -> f64 {
	// Defense values (from game rules):
	// Infantry: 2, Artillery: 2, Tank: 3, AA: 0 (special), Fighter: 4, Bomber: 1
	power := f64(0)
	power += f64(units.Infantry) * INFANTRY_DEFENSE
	power += f64(units.Artillery) * ARTILLERY_DEFENSE
	power += f64(units.Tanks) * TANK_DEFENSE
	power += f64(units.Fighters) * FIGHTER_DEFENSE
	power += f64(units.Bombers) * BOMBER_DEFENSE
	return power
}

// Helper: Estimate attack power of units (for debug output)
estimate_attack_power_triplea :: proc(units: Land_Attackers) -> f64 {
	power := f64(0)
	power += f64(units.Infantry) * INFANTRY_ATTACK
	// Artillery boosts paired infantry
	power += f64(min(units.Infantry, units.Artillery)) * INFANTRY_ATTACK
	power += f64(units.Artillery) * ARTILLERY_ATTACK
	power += f64(units.Tanks) * TANK_ATTACK
	power += f64(units.Fighters) * FIGHTER_ATTACK
	power += f64(units.Bombers) * BOMBER_ATTACK
	return power
}

// Helper: Gather enemy attackers from adjacent territories for battle simulation
gather_enemy_attackers_from_adjacent :: proc(gc: ^Game_Cache, t: Land_ID) -> Land_Attackers {
	attackers := Land_Attackers{}
	
	// Check adjacent territories for enemy units
	for adjacent in sa.slice(&mm.l2l_1away_via_land[t]) {
		// Count enemy units that could attack from this adjacent territory
		for player in Player_ID {
			if mm.team[player] != mm.team[gc.cur_player] {
				attackers.Infantry += gc.idle_armies[adjacent][player][.INF]
				attackers.Artillery += gc.idle_armies[adjacent][player][.ARTY]
				attackers.Tanks += gc.idle_armies[adjacent][player][.TANK]
			}
		}
	}
	
	// Also check for enemy fighters/bombers that could reach this territory
	// Fighters have range 4, bombers have range 6
	// For simplicity, check territories within fighter range (2 moves for attack)
	for adjacent in mm.l2l_2away_via_land_bitset[t] {
		for player in Player_ID {
			if mm.team[player] != mm.team[gc.cur_player] {
				attackers.Fighters += gc.idle_land_planes[adjacent][player][.FIGHTER]
				attackers.Bombers += gc.idle_land_planes[adjacent][player][.BOMBER]
			}
		}
	}
	
	return attackers
}

// =============================================================================
// SEA DEFENSE HELPER FUNCTIONS
// =============================================================================

// Ship count structure for quick totals
Ship_Counts :: struct {
	subs:        u8,
	destroyers:  u8,
	cruisers:    u8,
	carriers:    u8,
	battleships: u8,
	bs_damaged:  u8,
	transports:  u8,
	fighters:    u8,  // On carriers
	total:       u8,
}

// Count our ships in a sea zone
count_our_ships :: proc(gc: ^Game_Cache, sea: Sea_ID) -> Ship_Counts {
	counts := Ship_Counts{}
	
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		counts.subs += gc.idle_ships[sea][player][.SUB]
		counts.destroyers += gc.idle_ships[sea][player][.DESTROYER]
		counts.cruisers += gc.idle_ships[sea][player][.CRUISER]
		counts.carriers += gc.idle_ships[sea][player][.CARRIER]
		counts.battleships += gc.idle_ships[sea][player][.BATTLESHIP]
		counts.bs_damaged += gc.idle_ships[sea][player][.BS_DAMAGED]
		
		// Count transports
		counts.transports += gc.idle_ships[sea][player][.TRANS_EMPTY]
		counts.transports += gc.idle_ships[sea][player][.TRANS_1I]
		counts.transports += gc.idle_ships[sea][player][.TRANS_1A]
		counts.transports += gc.idle_ships[sea][player][.TRANS_1T]
		counts.transports += gc.idle_ships[sea][player][.TRANS_2I]
		counts.transports += gc.idle_ships[sea][player][.TRANS_1I_1A]
		counts.transports += gc.idle_ships[sea][player][.TRANS_1I_1T]
		
		// Fighters on carriers
		counts.fighters += gc.idle_sea_planes[sea][player][.FIGHTER]
	}
	
	counts.total = counts.subs + counts.destroyers + counts.cruisers + 
	               counts.carriers + counts.battleships + counts.bs_damaged + 
	               counts.transports + counts.fighters
	
	return counts
}

// Gather sea defenders from a sea zone
gather_sea_defenders :: proc(gc: ^Game_Cache, sea: Sea_ID) -> Sea_Defenders {
	defenders := Sea_Defenders{}
	
	for player in sa.slice(&mm.allies[gc.cur_player]) {
		defenders.Subs += gc.idle_ships[sea][player][.SUB]
		defenders.Destroyers += gc.idle_ships[sea][player][.DESTROYER]
		defenders.Cruisers += gc.idle_ships[sea][player][.CRUISER]
		defenders.Carriers += gc.idle_ships[sea][player][.CARRIER]
		defenders.Battleships += gc.idle_ships[sea][player][.BATTLESHIP]
		defenders.BS_Damaged += gc.idle_ships[sea][player][.BS_DAMAGED]
		defenders.Fighters += gc.idle_sea_planes[sea][player][.FIGHTER]
		
		// Count transports as fodder
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_EMPTY]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_1I]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_1A]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_1T]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_2I]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_1I_1A]
		defenders.Transports += gc.idle_ships[sea][player][.TRANS_1I_1T]
	}
	
	return defenders
}

// Calculate TUV (Total Unit Value) for ships
calculate_sea_tuv :: proc(ships: Ship_Counts) -> f64 {
	tuv := f64(0)
	tuv += f64(ships.subs) * 6.0       // Submarine cost
	tuv += f64(ships.destroyers) * 8.0  // Destroyer cost
	tuv += f64(ships.cruisers) * 12.0   // Cruiser cost
	tuv += f64(ships.carriers) * 14.0   // Carrier cost
	tuv += f64(ships.battleships) * 20.0 // Battleship cost
	tuv += f64(ships.bs_damaged) * 20.0  // Damaged BB still worth full
	tuv += f64(ships.transports) * 7.0   // Transport cost
	tuv += f64(ships.fighters) * 10.0    // Fighters on carriers
	return tuv
}

// Find a factory adjacent to a sea zone for naval purchases
find_factory_for_sea_defense :: proc(gc: ^Game_Cache, sea: Sea_ID) -> Maybe(Land_ID) {
	// Check all coastal territories adjacent to this sea zone
	for land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
		// Must be our territory with a factory
		if gc.owner[land] != gc.cur_player do continue
		if gc.factory_prod[land] == 0 do continue
		if gc.builds_left[land] == 0 do continue
		
		return land
	}
	
	return nil
}

// Helper: Format Land_Defenders for human-readable debug output (hides 0-count units)
format_land_defenders :: proc(units: Land_Defenders) -> string {
	parts := make([dynamic]string, context.temp_allocator)
	
	if units.Infantry > 0 do append(&parts, fmt.tprintf("%d Inf", units.Infantry))
	if units.Artillery > 0 do append(&parts, fmt.tprintf("%d Art", units.Artillery))
	if units.Tanks > 0 do append(&parts, fmt.tprintf("%d Tank", units.Tanks))
	if units.Fighters > 0 do append(&parts, fmt.tprintf("%d Ftr", units.Fighters))
	if units.Bombers > 0 do append(&parts, fmt.tprintf("%d Bmb", units.Bombers))
	if units.AntiAir > 0 do append(&parts, fmt.tprintf("%d AA", units.AntiAir))
	
	if len(parts) == 0 do return "(none)"
	
	// Join with ", "
	result := parts[0]
	for i in 1..<len(parts) {
		result = fmt.tprintf("%s, %s", result, parts[i])
	}
	return result
}

// Helper: Format Land_Attackers for human-readable debug output (hides 0-count units)
format_land_attackers :: proc(units: Land_Attackers) -> string {
	parts := make([dynamic]string, context.temp_allocator)
	
	if units.Infantry > 0 do append(&parts, fmt.tprintf("%d Inf", units.Infantry))
	if units.Artillery > 0 do append(&parts, fmt.tprintf("%d Art", units.Artillery))
	if units.Tanks > 0 do append(&parts, fmt.tprintf("%d Tank", units.Tanks))
	if units.Fighters > 0 do append(&parts, fmt.tprintf("%d Ftr", units.Fighters))
	if units.Bombers > 0 do append(&parts, fmt.tprintf("%d Bmb", units.Bombers))
	
	if len(parts) == 0 do return "(none)"
	
	// Join with ", "
	result := parts[0]
	for i in 1..<len(parts) {
		result = fmt.tprintf("%s, %s", result, parts[i])
	}
	return result
}

/*
=============================================================================
METHOD 8: prioritizeLandTerritories
=============================================================================

Java Original (lines 916-954):

  private List<ProPlaceTerritory> prioritizeLandTerritories(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories) {

    ProLogger.info("Prioritize land territories to place");

    // Get all land place territories
    final List<ProPlaceTerritory> prioritizedLandTerritories = new ArrayList<>();
    for (final ProPurchaseTerritory ppt : purchaseTerritories.values()) {
      for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
        final Territory t = placeTerritory.getTerritory();
        if (t.isWater()
            || !t.getOwner().equals(player)
            || placeTerritory.getStrategicValue() == Double.MIN_VALUE) {
          continue;
        }
        // [Lines 926-944 - Additional filters]
        prioritizedLandTerritories.add(placeTerritory);
      }
    }

    // Sort territories by value
    prioritizedLandTerritories.sort(
        Comparator.comparingDouble(ProPlaceTerritory::getStrategicValue).reversed());
    return prioritizedLandTerritories;
  }
*/

// Odin Implementation:
prioritize_land_territories_triplea :: proc(gc: ^Game_Cache) -> [dynamic]Place_Territory_Land {
	prioritized := make([dynamic]Place_Territory_Land, context.temp_allocator)

	// Get all land territories we own with factories
	for territory in Land_ID {
		if gc.owner[territory] != gc.cur_player do continue

		// Check if we have factory here (can place units)
		has_factory := gc.factory_prod[territory] > 0
		
		// For offensive purchases, only consider territories with factories
		if !has_factory do continue
		
		// Calculate strategic value based on:
		// 1. Factory production capacity
		// 2. Distance to enemy (closer = more strategic)
		// 3. Territory IPC value
		production := f64(gc.factory_prod[territory])
		territory_value := f64(mm.value[territory])
		
		// Get enemy distance - closer territories are more strategic for offense
		enemy_distance := get_closest_enemy_land_distance(gc, territory)
		distance_factor := 6.0 - f64(min(enemy_distance, 5)) // 5 at dist 1, 1 at dist 5
		
		// Strategic value combines production, territory value, and proximity
		strategic_value := (production + territory_value) * distance_factor

		place_terr := Place_Territory_Land {
			territory       = territory,
			strategic_value = strategic_value,
			has_factory     = has_factory,
		}
		append(&prioritized, place_terr)
	}

	// Sort by strategic value (highest first)
	for i := 0; i < len(prioritized) - 1; i += 1 {
		for j := i + 1; j < len(prioritized); j += 1 {
			if prioritized[j].strategic_value > prioritized[i].strategic_value {
				prioritized[i], prioritized[j] = prioritized[j], prioritized[i]
			}
		}
	}

	result := make([dynamic]Place_Territory_Land)
	for terr in prioritized {
		append(&result, terr)
	}
	return result
}

Place_Territory_Land :: struct {
	territory:       Land_ID,
	strategic_value: f64,
	has_factory:     bool,
}

/*
=============================================================================
METHOD 9: purchaseAaUnits
=============================================================================

Java Original (lines 956-1052):

  private void purchaseAaUnits(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPlaceTerritory> prioritizedLandTerritories,
      final List<ProPurchaseOption> specialPurchaseOptions) {

    if (resourceTracker.isEmpty()) {
      return;
    }
    ProLogger.info("Purchase AA units with resources: " + resourceTracker);

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Loop through prioritized territories and purchase AA units
    for (final ProPlaceTerritory placeTerritory : prioritizedLandTerritories) {
      final Territory t = placeTerritory.getTerritory();

      // Check if any enemy attackers
      if (enemyAttackOptions.getMax(t) == null) { continue; }

      // Check remaining production
      final int remainingUnitProduction = purchaseTerritories.get(t).getRemainingUnitProduction();
      if (remainingUnitProduction <= 0) { continue; }

      // Check if territory needs AA
      final boolean enemyCanBomb =
          enemyAttackOptions.getMax(t).getMaxUnits().stream()
              .anyMatch(Matches.unitIsStrategicBomber());
      final boolean territoryCanBeBombed =
          t.anyUnitsMatch(Matches.unitCanProduceUnitsAndCanBeDamaged());
      final boolean hasAaBombingDefense = t.anyUnitsMatch(Matches.unitIsAaForBombingThisUnitOnly());
      
      if (!enemyCanBomb || !territoryCanBeBombed || hasAaBombingDefense) {
        continue;
      }

      // Determine most cost efficient AA unit
      ProPurchaseOption bestAaOption = null;
      int minCost = Integer.MAX_VALUE;
      for (final ProPurchaseOption ppo : purchaseOptionsForTerritory) {
        if (ppo.getCost() < minCost) {
          minCost = ppo.getCost();
          bestAaOption = ppo;
        }
      }

      if (bestAaOption != null) {
        resourceTracker.purchase(bestAaOption);
        addUnitsToPlace(placeTerritory, bestAaOption.createTempUnits());
      }
    }
  }
*/

// Odin Implementation:
purchase_aa_units_triplea :: proc(
	gc: ^Game_Cache,
	prioritized_territories: [dynamic]Place_Territory_Land,
	naval_budget_reserve: u8 = 0, // Money to reserve for naval purchases
) {
	// TODO REVIEW: Java purchaseAaUnits (lines 956-1052) has additional logic:
	//
	// Missing Block 1 (lines 970-985): Enemy bomber threat check
	//   - Iterates enemy bomber range to check if territory can be bombed
	//   - enemyBombersInRange = findEnemyBombersInRange(...)
	//
	// Missing Block 2: Territory can be bombed check
	//   - ProMatches.territoryCanBeBombed()
	//
	// Missing Block 3: Best AA option selection by cost
	//   - Java selects cheapest AA option that fits budget
	//   - Currently hardcoded to check >= 5.0 strategic value
	
	if gc.money[gc.cur_player] == 0 do return

	// Calculate available money (respecting naval reserve)
	// Use max(0, money - reserve) to ensure we don't spend reserved money
	available_money: u8 = 0
	if gc.money[gc.cur_player] > naval_budget_reserve {
		available_money = gc.money[gc.cur_player] - naval_budget_reserve
	}

	// Purchase AA guns for territories that:
	// 1. Have factories (can be bombed)
	// 2. Don't already have AA
	// 3. Are threatened by enemy bombers

	for place_terr in prioritized_territories {
		if available_money < 5 do break // AA costs 5

		territory := place_terr.territory

		// Only buy AA for territories with factories
		if !place_terr.has_factory do continue

		// Check if already has AA
		has_aa := gc.idle_armies[territory][gc.cur_player][.AAGUN] > 0
		if has_aa do continue

		// Simplified: Check if territory has high strategic value (likely bomber target)
		if place_terr.strategic_value >= 5.0 {
			// Buy AA gun
			if try_buy_aa_triplea(gc, territory) {
				// Update available money after purchase
				if gc.money[gc.cur_player] > naval_budget_reserve {
					available_money = gc.money[gc.cur_player] - naval_budget_reserve
				} else {
					available_money = 0
				}
			}
		}
	}
}

// Helper: Try to buy AA gun for territory
try_buy_aa_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	if gc.money[gc.cur_player] < 5 do return false

	// Find factory for placement
	factory := find_nearest_factory_triplea(gc, territory)
	if factory_loc, ok := factory.?; ok {
		// Check production capacity
		if gc.builds_left[factory_loc] == 0 do return false
		
		when ODIN_DEBUG {
			fmt.printf("  [AA PURCHASE] Bought AA for %v at factory %v, Money: %d\n", 
			          territory, factory_loc, gc.money[gc.cur_player])
		}
		
		// Deduct money and production
		gc.money[gc.cur_player] -= 5
		gc.builds_left[factory_loc] -= 1
		
		// Add AA to placement tracking
		add_units_to_place_triplea(factory_loc, .AAGun, 1)
		return true
	}

	return false
}

/*
=============================================================================
METHOD 10: purchaseLandUnits
=============================================================================

Java Original (lines 1054-1221):

  private void purchaseLandUnits(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPlaceTerritory> prioritizedLandTerritories,
      final ProPurchaseOptionMap purchaseOptions) {

    final List<Unit> unplacedUnits = player.getMatches(Matches.unitIsNotSea());
    if (resourceTracker.isEmpty() && unplacedUnits.isEmpty()) {
      return;
    }
    ProLogger.info("Purchase land units with resources: " + resourceTracker);

    // Loop through prioritized territories and purchase land units
    for (final ProPlaceTerritory placeTerritory : prioritizedLandTerritories) {
      final Territory t = placeTerritory.getTerritory();

      // Check remaining production
      int remainingUnitProduction = purchaseTerritories.get(t).getRemainingUnitProduction();
      if (remainingUnitProduction <= 0) { continue; }

      // Determine most cost efficient units
      final List<ProPurchaseOption> landFodderOptions = [...]
      final List<ProPurchaseOption> landAttackOptions = [...]
      final List<ProPurchaseOption> landDefenseOptions = [...]

      // Determine enemy distance and locally owned units
      int enemyDistance =
          ProUtils.getClosestEnemyOrNeutralLandTerritoryDistance(
              data, player, t, territoryValueMap);
      final int fodderPercent = 80 - enemyDistance * 5;

      // Purchase as many units as possible
      int addedFodderUnits = 0;
      double attackAndDefenseDifference = 0;
      boolean selectFodderUnit = true;
      while (true) {
        // Select between fodder (infantry) and attack/defense units
        // [Lines 1138-1215 - Complex selection logic]
        // Key: Balance between cheap fodder and expensive attack units
        // based on distance to enemy and current unit composition
      }

      // Add units to place territory
      addUnitsToPlace(placeTerritory, unitsToPlace);
    }
  }
*/

// PUR-028: purchaseLandUnits() - Buy offensive land units with fodder % algorithm
purchase_land_units_triplea :: proc(
	gc: ^Game_Cache,
	prioritized_territories: [dynamic]Place_Territory_Land,
) {
	if gc.money[gc.cur_player] == 0 do return

	/*
	TripleA algorithm: fodderPercent = 80 - enemyDistance * 5
	- Close to enemy (distance 0-1): Buy more expensive attack units
	- Far from enemy (distance 10+): Buy mostly cheap infantry
	*/

	when ODIN_DEBUG {
		fmt.println("  [RATIONALE] Purchasing offensive land units...")
	}

	total_inf := 0
	total_arty := 0
	total_tank := 0
	starting_money := gc.money[gc.cur_player]

	// #region PUR-029: for (ProPlaceTerritory) loop - iterate prioritized territories for land purchases
	for place_terr in prioritized_territories {
		if gc.money[gc.cur_player] < 3 do break

		territory := place_terr.territory

		// Only buy at factory locations
		if !place_terr.has_factory do continue

		// Estimate enemy distance (simplified)
		enemy_distance := estimate_enemy_distance_triplea(gc, territory)

		// Calculate fodder percentage
		fodder_percent := 80 - enemy_distance * 5
		if fodder_percent < 20 do fodder_percent = 20
		if fodder_percent > 80 do fodder_percent = 80

		when ODIN_DEBUG {
			fmt.printf(
				"    %v: enemy distance=%d, fodder%%=%d\n",
				territory,
				enemy_distance,
				fodder_percent,
			)
		}

		// Purchase units using weighted deterministic selection
		// Instead of random, we use unit counts and distance factor to create variety
		//
		// Key insight from Java:
		// - Track attackAndDefenseDifference to balance purchases
		// - Use distance factor to weight high-movement units (tanks)
		// - Fodder % determines how many cheap units vs expensive units

		units_bought := 0
		attack_defense_diff: f64 = 0.0  // Positive = bought too much attack, need defense
		
		// Calculate distance factor for tanks (movement=2) vs infantry (movement=1)
		// At distance 5: tank_factor ≈ 2.0, infantry_factor = 1.0
		// At distance 10: tank_factor ≈ 4.0, infantry_factor = 1.0
		tank_distance_factor := calculate_land_distance_factor(2, enemy_distance)
		
		// Check remaining production capacity at this factory
		remaining_production := gc.builds_left[territory]
		
		// #region PUR-030: while loop - buy units until production/money exhausted
		for gc.money[gc.cur_player] >= 3 && units_bought < 10 && remaining_production > 0 {
			// Calculate current fodder ratio (what % of units bought so far are infantry)
			current_fodder_ratio := units_bought > 0 ? (total_inf * 100) / (total_inf + total_arty + total_tank) : 100
			
			// Decide fodder vs attack based on current ratio vs target fodder_percent
			buy_fodder := current_fodder_ratio < fodder_percent
			
			if buy_fodder {
				// Fodder mode: prefer infantry, but consider artillery for support
				// Buy artillery every 3rd infantry if we can afford it and have infantry to support
				// Artillery gives +1 attack to paired infantry, so optimal ratio is ~2:1 inf:arty
				should_buy_arty := (total_inf > 0) && 
				                   (total_arty * 3 < total_inf) &&  // Maintain ~3:1 ratio
				                   (gc.money[gc.cur_player] >= 4) &&
				                   (attack_defense_diff <= 0)  // Don't buy if already attack-heavy
				
				if should_buy_arty {
					gc.money[gc.cur_player] -= 4
					gc.builds_left[territory] -= 1
					remaining_production -= 1
					add_units_to_place_triplea(territory, .Artillery, 1)
					units_bought += 1
					total_arty += 1
					attack_defense_diff += 0.0  // Artillery: 2 attack, 2 defense = neutral
				} else if gc.money[gc.cur_player] >= 3 {
					gc.money[gc.cur_player] -= 3
					gc.builds_left[territory] -= 1
					remaining_production -= 1
					add_units_to_place_triplea(territory, .Infantry, 1)
					units_bought += 1
					total_inf += 1
					attack_defense_diff -= 1.0  // Infantry: 1 attack, 2 defense = defense-heavy
				}
			} else {
				// Attack mode: choose between tank and artillery based on distance factor
				// Tanks are better when far from enemy (high distance factor)
				// Artillery is better when close (supports infantry, cheaper)
				
				// Use distance factor to decide: if tank_factor > 1.5, prefer tanks
				// Also consider attack/defense balance
				prefer_tank := (tank_distance_factor > 1.5) || (attack_defense_diff < 0)
				
				if prefer_tank && gc.money[gc.cur_player] >= 6 {
					// Buy tank - high mobility, good at distance
					gc.money[gc.cur_player] -= 6
					gc.builds_left[territory] -= 1
					remaining_production -= 1
					add_units_to_place_triplea(territory, .Tank, 1)
					units_bought += 1
					total_tank += 1
					attack_defense_diff += 0.0  // Tank: 3 attack, 3 defense = neutral
				} else if gc.money[gc.cur_player] >= 4 {
					// Buy artillery - supports infantry
					gc.money[gc.cur_player] -= 4
					gc.builds_left[territory] -= 1
					remaining_production -= 1
					add_units_to_place_triplea(territory, .Artillery, 1)
					units_bought += 1
					total_arty += 1
					attack_defense_diff += 0.0  // Artillery: 2 attack, 2 defense = neutral
				} else if gc.money[gc.cur_player] >= 3 {
					// Fallback to infantry if can't afford attack units
					gc.money[gc.cur_player] -= 3
					gc.builds_left[territory] -= 1
					remaining_production -= 1
					add_units_to_place_triplea(territory, .Infantry, 1)
					units_bought += 1
					total_inf += 1
					attack_defense_diff -= 1.0
				} else {
					break
				}
			}
		}
		// #endregion PUR-030
	}
	// #endregion PUR-029

	when ODIN_DEBUG {
		if total_inf > 0 || total_arty > 0 || total_tank > 0 {
			money_spent := starting_money - gc.money[gc.cur_player]
			fmt.printf(
				"    Purchased: %d infantry, %d artillery, %d tanks (%d IPCs)\n",
				total_inf,
				total_arty,
				total_tank,
				money_spent,
			)
		} else {
			fmt.println("    No offensive units purchased")
		}
	}
}

// Helper: Get distance to nearest enemy or neutral land territory
// Uses O(1) bitset operations with precomputed distance data
// Returns 1-5 (or 5 if no enemy found within 4 moves)
get_closest_enemy_land_distance :: proc(gc: ^Game_Cache, territory: Land_ID) -> int {
	/*
	Java Original (from ProUtils.java):
	
	int enemyDistance = ProUtils.getClosestEnemyOrNeutralLandTerritoryDistance(
		data, player, t, territoryValueMap);
	if (enemyDistance <= 0) {
		enemyDistance = 10;  // No land path to enemy = isolated, treat as very far
	}
	
	Returns distance to closest enemy/neutral land territory via LAND path only.
	Returns 10 if no land path exists (island nations like UK, USA, Japan).
	
	CRITICAL: This uses land_distances matrix which only includes land connections,
	NOT air connections. The a2a_within_X_moves bitsets include air routes over water
	and should NOT be used here.
	*/
	
	// Find closest enemy using land_distances matrix
	closest_distance: u8 = 127
	
	for land in Land_ID {
		// Check if this is an enemy territory
		if land in gc.friendly_owner do continue  // Skip friendly territories
		
		dist := mm.land_distances[territory][land]
		if dist > 0 && dist < closest_distance {
			closest_distance = dist
		}
	}
	
	// If no land path found, return 10 (isolated like Java does)
	if closest_distance == 127 {
		return 10
	}
	
	// Cap at 10 like Java
	return min(int(closest_distance), 10)
}

// Alias for backward compatibility
estimate_enemy_distance_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> int {
	return get_closest_enemy_land_distance(gc, territory)
}

/*
=============================================================================
METHOD 11: purchaseFactory
=============================================================================

Java Original (lines 1223-1435):

  private void purchaseFactory(
      final Map<Territory, ProPurchaseTerritory> factoryPurchaseTerritories,
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPlaceTerritory> prioritizedLandTerritories,
      final ProPurchaseOptionMap purchaseOptions,
      final boolean hasExtraPUs) {

    if (resourceTracker.isEmpty()) {
      return;
    }

    // Only try to purchase a factory if all production was used
    // [Lines 1233-1245 - Check if production maxed out]

    // Find all owned land territories that could have a factory
    final List<Territory> possibleFactoryTerritories = [...]
    for (final Territory t : possibleFactoryTerritories) {
      // Only consider territories with production of at least 3
      final int production = TerritoryAttachment.get(t).getProduction();
      if ((production < 3 && !hasExtraPUs) || production < 2) {
        continue;
      }

      // Check if no enemy attackers or can hold after counter-attack
      // [Lines 1268-1313 - Safety checks]
    }

    // Remove territories without local land superiority
    if (!hasExtraPUs) {
      purchaseFactoryTerritories.removeIf(
          t -> !ProBattleUtils.territoryHasLocalLandSuperiority([...]));
    }

    // Find strategic value for each territory
    final Map<Territory, Double> territoryValueMap = [...]
    double maxValue = 0.0;
    Territory maxTerritory = null;
    for (final Territory t : purchaseFactoryTerritories) {
      final int production = TerritoryAttachment.get(t).getProduction();
      final double value = territoryValueMap.get(t) * production + 0.1 * production;
      final boolean isAdjacentToSea = [...]
      final int numNearbyEnemyTerritories = [...]
      
      if (value > maxValue
          && ((numNearbyEnemyTerritories >= 4 && territoryValueMap.get(t) >= 1)
              || (isAdjacentToSea && hasExtraPUs))) {
        maxValue = value;
        maxTerritory = t;
      }
    }

    // Determine whether to purchase factory
    if (maxTerritory != null) {
      // [Lines 1364-1433 - Purchase factory logic]
    }
  }
*/

// Odin Implementation:
purchase_factory_triplea :: proc(gc: ^Game_Cache, has_extra_pus: bool) -> bool {
	if gc.money[gc.cur_player] < 15 do return false // Factory costs 15

	when ODIN_DEBUG {
		if has_extra_pus {
			fmt.println("  [RATIONALE] Evaluating factory purchase with remaining funds...")
		} else {
			fmt.println("  [RATIONALE] Evaluating factory purchase...")
		}
	}

	/*
	TripleA logic:
	1. Only buy factory if all current production is being used
	2. Territory must have production >= 3 (or >= 2 with extra PUs)
	3. Must have local land superiority (safe from enemy)
	4. Calculate value = territoryValue * production
	5. Must be adjacent to sea OR have 4+ nearby enemy territories
	*/

	// Initialize tracking if needed
	if g_purchased_factories == nil {
		g_purchased_factories = make([dynamic]Land_ID)
	}

	// Check if all current production is being used
	// (Simplified: assume we want factories if we have money)

	// Find candidate territories for factory placement
	candidate_territories := make([dynamic]struct {
			territory: Land_ID,
			value:     f64,
		}, context.temp_allocator)

	for territory in Land_ID {
		if gc.owner[territory] != gc.cur_player do continue

		// Check if already has factory or is scheduled to get one
		if gc.factory_prod[territory] > 0 do continue
		already_purchased := false
		for purchased_factory in g_purchased_factories {
			if purchased_factory == territory {
				already_purchased = true
				break
			}
		}
		if already_purchased do continue

		// Check production value
		production := mm.value[territory]
		min_production := has_extra_pus ? u8(2) : u8(3)
		if production < min_production do continue

		// Calculate strategic value
		territory_value := calculate_territory_value(gc, territory)
		value := territory_value * f64(production) + 0.1 * f64(production)

		// Check if adjacent to sea (useful for naval production)
		is_adjacent_to_sea := len(mm.l2s_1away_via_land[territory].data) > 0

		// Count nearby enemy territories
		nearby_enemies := count_nearby_enemy_territories_triplea(gc, territory)

		// Decide if this is a good factory location
		if (nearby_enemies >= 4 && territory_value >= 1.0) ||
		   (is_adjacent_to_sea && has_extra_pus) {
			append(&candidate_territories, struct {
				territory: Land_ID,
				value:     f64,
			}{territory, value})
		}
	}

	if len(candidate_territories) == 0 do return false

	// Find best candidate (highest value)
	max_value := f64(0)
	max_territory := Land_ID(0)
	for candidate in candidate_territories {
		if candidate.value > max_value {
			max_value = candidate.value
			max_territory = candidate.territory
		}
	}

	if max_value > 0 {
		// Store factory purchase for later placement
		gc.money[gc.cur_player] -= 15
		append(&g_purchased_factories, max_territory)

		when ODIN_DEBUG {
			fmt.printf(
				"  [FACTORY] Purchased factory for %v (value: %.1f)\n",
				max_territory,
				max_value,
			)
		}

		return true
	}

	when ODIN_DEBUG {
		fmt.println("    No suitable location found for factory")
	}

	return false
}

// Helper: Count enemy territories within 2 moves
count_nearby_enemy_territories_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> int {
	/*
	Java Original (from ProPurchaseAi.java lines 348-352):
	
	final int numNearbyEnemyTerritories =
		ProMatches.territoryIsEnemyOrCantBeHeld(player, data, territoryValueMap)
			.countMatches(data.getMap().getNeighbors(t, 2));
	*/

	count := 0

	// Check adjacent territories
	for adj_id in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if is_enemy_territory_triplea(gc, adj_id) {
			count += 1
		}
	}

	// Check 2 away (simplified - just use bitset)
	for t2 in Land_ID {
		if t2 in mm.l2l_2away_via_land_bitset[territory] {
			if is_enemy_territory_triplea(gc, t2) {
				count += 1
			}
		}
	}

	return count
}

// Helper: Check if territory is enemy-owned
is_enemy_territory_triplea :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	if gc.owner[territory] == gc.cur_player do return false

	// Check if ally
	for ally_id in sa.slice(&mm.allies[gc.cur_player]) {
		if gc.owner[territory] == ally_id do return true
	}

	return true // Not us, not ally = enemy
}

/*
=============================================================================
METHOD 12: prioritizeSeaTerritories
=============================================================================

Java Original (lines 1437-1517):

  private List<ProPlaceTerritory> prioritizeSeaTerritories(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories) {

    ProLogger.info("Prioritize sea territories");

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();

    // Determine which sea territories can be placed in
    final Set<ProPlaceTerritory> seaPlaceTerritories = new HashSet<>();
    for (final ProPurchaseTerritory ppt : purchaseTerritories.values()) {
      for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
        if (!placeTerritory.getTerritory().isWater()) { continue; }
        seaPlaceTerritories.add(placeTerritory);
      }
    }

    // Calculate value of territory
    for (final ProPlaceTerritory placeTerritory : seaPlaceTerritories) {
      final Territory t = placeTerritory.getTerritory();

      // Find number of local naval units
      final List<Unit> units = new ArrayList<>(placeTerritory.getDefendingUnits());
      final int numMyTransports =
          CollectionUtils.countMatches(myUnits, Matches.unitIsSeaTransport());
      final int numSeaDefenders =
          CollectionUtils.countMatches(units, Matches.unitIsNotSeaTransport());

      // Determine needed defense strength
      int needDefenders = 0;
      if (enemyAttackOptions.getMax(t) != null) {
        // [Lines 1472-1478 - Calculate needed defenders]
      }
      final boolean hasLocalNavalSuperiority =
          ProBattleUtils.territoryHasLocalNavalSuperiority([...]);
      if (!hasLocalNavalSuperiority) {
        needDefenders++;
      }

      // Calculate sea value for prioritization
      final double territoryValue =
          placeTerritory.getStrategicValue()
              * (1 + numMyTransports + 0.1 * numSeaDefenders)
              / (1 + 3.0 * needDefenders);
      placeTerritory.setStrategicValue(territoryValue);
    }

    // Sort territories by value
    final List<ProPlaceTerritory> sortedTerritories = new ArrayList<>(seaPlaceTerritories);
    sortedTerritories.sort(
        Comparator.comparingDouble(ProPlaceTerritory::getStrategicValue).reversed());
    return sortedTerritories;
  }
*/

// Odin Implementation:
prioritize_sea_territories_triplea :: proc(gc: ^Game_Cache) -> [dynamic]Place_Territory_Sea {
	/*
	TripleA formula:
	value = strategicValue * (1 + transports + 0.1*defenders) / (1 + 3*needDefenders)
	*/

	sea_territories := make([dynamic]Place_Territory_Sea, context.temp_allocator)

	// Find all sea zones where we can place units (coastal factories)
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		// Check if factory is coastal (adjacent to sea)
		for sea_id in sa.slice(&mm.l2s_1away_via_land[factory_loc]) {
			// Calculate value for this sea zone
			strategic_value := calculate_sea_strategic_value_triplea(gc, sea_id)

			// Count our naval units
			num_transports := count_all_transports_triplea(gc, sea_id)
			num_defenders := count_sea_defenders_triplea(gc, sea_id)

			// Estimate need for defenders (simplified)
			need_defenders := 0
			if num_defenders < 2 {
				need_defenders = 2 - int(num_defenders)
			}

			// Calculate priority value
			value :=
				strategic_value *
				(1.0 + f64(num_transports) + 0.1 * f64(num_defenders)) /
				(1.0 + 3.0 * f64(need_defenders))

			place_sea := Place_Territory_Sea {
				sea_zone        = sea_id,
				strategic_value = value,
				num_transports  = num_transports,
				num_defenders   = num_defenders,
			}
			append(&sea_territories, place_sea)
		}
	}

	// Sort by strategic value (highest first)
	for i := 0; i < len(sea_territories) - 1; i += 1 {
		for j := i + 1; j < len(sea_territories); j += 1 {
			if sea_territories[j].strategic_value > sea_territories[i].strategic_value {
				sea_territories[i], sea_territories[j] = sea_territories[j], sea_territories[i]
			}
		}
	}

	result := make([dynamic]Place_Territory_Sea)
	for terr in sea_territories {
		append(&result, terr)
	}
	return result
}

Place_Territory_Sea :: struct {
	sea_zone:        Sea_ID,
	strategic_value: f64,
	num_transports:  u8,
	num_defenders:   u8,
}

// Helper: Calculate strategic value of sea zone
calculate_sea_strategic_value_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> f64 {
	// Base value from adjacent land territories
	value := f64(0)

	for land_id in sa.slice(&mm.s2l_1away_via_sea[sea_id]) {
		if gc.owner[land_id] == gc.cur_player {
			value += calculate_territory_value(gc, land_id) * 0.5
		}
	}

	return value
}

// Helper: Count sea defense units
count_sea_defenders_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> u8 {
	count := u8(0)
	count += gc.idle_ships[sea_id][gc.cur_player][.SUB]
	count += gc.idle_ships[sea_id][gc.cur_player][.DESTROYER]
	count += gc.idle_ships[sea_id][gc.cur_player][.CRUISER]
	count += gc.idle_ships[sea_id][gc.cur_player][.CARRIER]
	count += gc.idle_ships[sea_id][gc.cur_player][.BATTLESHIP]
	// Fighters on carriers
	count += gc.idle_sea_planes[sea_id][gc.cur_player][.FIGHTER]
	return count
}

// Helper: Count all transport types
count_all_transports_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> u8 {
	count := u8(0)
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_EMPTY]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_1I]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_1A]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_1T]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_2I]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_1I_1A]
	count += gc.idle_ships[sea_id][gc.cur_player][.TRANS_1I_1T]
	return count
}

// Count empty/partially loaded transports that need cargo
count_empty_transports_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> u8 {
	player := gc.cur_player
	count := u8(0)
	// Only count empty transports (they need units)
	count += gc.idle_ships[sea_id][player][.TRANS_EMPTY]
	// Partially loaded transports also need units
	count += gc.idle_ships[sea_id][player][.TRANS_1I]  // Has space for 3 more
	count += gc.idle_ships[sea_id][player][.TRANS_1A]  // Has space for 2 more
	count += gc.idle_ships[sea_id][player][.TRANS_1T]  // Has space for 2 more
	return count
}

// Count units stranded on low-value territories adjacent to a sea zone
// Java uses territoryValueMap.get(neighbor) <= 0.25 to identify these
// Key insight: UK and other islands have low value because they can't reach enemy by land
count_stranded_units_for_sea :: proc(gc: ^Game_Cache, sea_id: Sea_ID, player: Player_ID) -> u8 {
	count := u8(0)
	
	// Check all land territories adjacent to this sea zone
	for land_id in sa.slice(&mm.s2l_1away_via_sea[sea_id]) {
		// Only check our own territories
		if gc.owner[land_id] != player do continue
		
		// Calculate territory value
		// Low value = isolated from enemy / not strategically important
		territory_value := calculate_strategic_land_value_for_transport(gc, land_id, player)
		
		when ODIN_DEBUG {
			units_here := gc.idle_armies[land_id][player][.INF] + 
			              gc.idle_armies[land_id][player][.ARTY] + 
			              gc.idle_armies[land_id][player][.TANK]
			if units_here > 0 {
				fmt.printf("        [CHECK] %v owner=%v value=%.2f units=%d\n",
					land_id, gc.owner[land_id], territory_value, units_here)
			}
		}
		
		// Java threshold is 0.25 - below this, units should be evacuated
		if territory_value <= 0.25 {
			// Count transportable units (infantry, artillery, tanks)
			count += gc.idle_armies[land_id][player][.INF]
			count += gc.idle_armies[land_id][player][.ARTY]
			count += gc.idle_armies[land_id][player][.TANK]
			
			when ODIN_DEBUG {
				if count > 0 {
					fmt.printf("        [STRANDED] %v has value=%.2f, units=%d\n",
						land_id, territory_value, count)
				}
			}
		}
	}
	
	return count
}

// Calculate strategic value of a territory for transport decisions
// Returns low value (<=0.25) for isolated territories like UK
calculate_strategic_land_value_for_transport :: proc(gc: ^Game_Cache, land_id: Land_ID, player: Player_ID) -> f64 {
	/*
	Java (ProTerritoryValueUtils.findTerritoryValues):
	Territory value is based on:
	1. Distance to enemy capitals/factories
	2. Nearby enemy production
	3. Whether territory can reach enemy by land
	
	Key insight: UK has low value because it's an island - no land path to enemy!
	
	Important: We want to identify territories where units are "stranded" and should
	be transported out. This is DIFFERENT from the territory's strategic importance.
	
	A territory is "low value for transport purposes" if:
	1. It's an island with no land connection to any enemy
	2. It has no factory (factories always have value)
	
	Territories with land paths to enemy should have value > 0.25 so units stay put.
	
	UPDATE: For TRANSPORT purposes, we actually want to identify territories where
	units NEED transport to reach enemies - this includes island factories like UK!
	The original logic was wrong - factories on islands still need transports.
	*/
	
	// Check if this territory has a land path to any enemy territory
	// land_distances uses 127 (INFINITY) for unreachable territories
	LAND_INFINITY :: 127
	has_land_path_to_enemy := false
	for enemy in sa.slice(&mm.enemies[player]) {
		// Check if enemy has any territory we can reach by land
		for land in Land_ID {
			if gc.owner[land] != enemy do continue
			
			// Check land distance: > 0 means adjacent or reachable, < INFINITY means not infinite
			// Distance of 0 only happens for same territory (not applicable here)
			// Distance of INFINITY (127) means unreachable by land
			dist := mm.land_distances[land_id][land]
			if dist > 0 && dist < LAND_INFINITY {
				has_land_path_to_enemy = true
				break
			}
		}
		if has_land_path_to_enemy do break
	}
	
	// If there's a land path to enemy, units here aren't stranded - they can walk there
	if has_land_path_to_enemy {
		return 1.0 // High value - units should stay and advance by land
	}
	
	// No land path to enemy - this is an isolated territory
	// For TRANSPORT purposes, ALL isolated territories need transports, including factories
	// Return low value to indicate units need transport evacuation
	return 0.1 // Below 0.25 threshold - need transport to reach enemies
}

/*
=============================================================================
METHOD 13: purchaseSeaAndAmphibUnits
=============================================================================

Java Original (lines 1519-2096):

  private boolean purchaseSeaAndAmphibUnits(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPlaceTerritory> prioritizedSeaTerritories,
      final ProPurchaseOptionMap purchaseOptions) {
    if (resourceTracker.isEmpty()) {
      return false;
    }
    ProLogger.info("Purchase sea and amphib units with resources: " + resourceTracker);

    final ProOtherMoveOptions enemyAttackOptions = territoryManager.getEnemyAttackOptions();
    boolean boughtUnits = false;
    boolean wantedToBuyUnitsButCouldNotDefendThem = false;

    // Loop through prioritized territories and purchase sea units
    for (final ProPlaceTerritory placeTerritory : prioritizedSeaTerritories) {
      final Territory t = placeTerritory.getTerritory();

      // This is VERY complex - over 500 lines!
      // Key phases:
      // 1. Determine if need destroyer (for subs)
      // 2. Purchase sea defense units
      // 3. Purchase transports
      // 4. Purchase attack ships (carriers, battleships, etc)
      // 5. Check if can defend purchased units
      // 6. Load transports with units for amphibious assault
      // [Lines 1542-2091 - Complex naval purchase logic]
    }

    // If wanted to buy but couldn't defend, consider saving up
    return !boughtUnits
        && wantedToBuyUnitsButCouldNotDefendThem
        && shouldSaveUpForAFleet(purchaseOptions, purchaseTerritories);
  }
*/

// PUR-061: purchaseSeaAndAmphibUnits() - Buy naval and amphibious units (3 phases)
purchase_sea_and_amphib_units_triplea :: proc(
	gc: ^Game_Cache,
	prioritized_sea: [dynamic]Place_Territory_Sea,
	all_enemies: ^All_Enemy_Attack_Options,
	enemy_attack_options: ^Pro_Other_Move_Options,
) -> (
	should_save: bool,
) {
	if gc.money[gc.cur_player] == 0 do return false

	/*
	TripleA logic (577 lines):
	1. For each sea zone with enemy threats, run battle simulation
	2. Purchase defenders until TUV swing < -1 OR win% < 5%
	3. Then purchase for naval superiority
	4. Then purchase transports + amphib units
	5. If wanted to buy but couldn't defend, consider saving up
	*/

	bought_units := false
	wanted_to_buy_but_couldnt_defend := false
	debug_checks(gc)

	// region PUR-062: for (ProPlaceTerritory) loop - iterate prioritized sea zones for purchases
	for place_sea in prioritized_sea {
		if gc.money[gc.cur_player] < 6 do break // Cheapest ship is sub at 6

		sea_id := place_sea.sea_zone
		debug_checks(gc)
		
		// Find the coastal factory that can build to this sea zone
		factory_for_sea: Maybe(Land_ID) = nil
		for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
			if gc.owner[factory_loc] != gc.cur_player do continue
			if gc.builds_left[factory_loc] == 0 do continue
			// Check if factory is adjacent to this sea zone
			for adj_sea in sa.slice(&mm.l2s_1away_via_land[factory_loc]) {
				if adj_sea == sea_id {
					factory_for_sea = factory_loc
					break
				}
			}
			if factory_for_sea != nil do break
		}
		
		// Skip if no factory can build to this sea zone
		if factory_for_sea == nil do continue
		factory_loc := factory_for_sea.?

		// Get enemy threat to this sea zone
		threat := &enemy_attack_options.sea_max[sea_id]
		has_threat := threat.max_fighters > 0 || threat.max_bombers > 0 ||
		              threat.max_destroyers > 0 || threat.max_cruisers > 0 ||
		              threat.max_battleships > 0 || threat.max_subs > 0 || threat.max_carriers > 0

		when ODIN_DEBUG {
			fmt.println("    [SEA ZONE]", sea_id, "factory:", factory_loc, "has_threat:", has_threat,
			           "threat subs:", threat.max_subs, "destroyers:", threat.max_destroyers,
			           "cruisers:", threat.max_cruisers, "BS:", threat.max_battleships,
			           "fighters:", threat.max_fighters, "bombers:", threat.max_bombers)
		}

		// Check if need destroyer (for enemy subs)
		need_destroyer := check_need_destroyer_triplea(gc, sea_id) && threat.max_subs > 0

		// Phase 1: Purchase sea defenders if under threat
		// LIMIT: Reserve at least 7 IPCs for transport purchases (if we have enough)
		// Then spend up to 50% of remaining on sea defense
		transport_reserve: u8 = 0
		if gc.money[gc.cur_player] >= 14 { // Can afford both defense and transport
			transport_reserve = 7
		} else if gc.money[gc.cur_player] >= 10 { // Prioritize transport for coastal powers
			transport_reserve = 7 // Reserve for transport, less for defense
		}
		available_for_defense := gc.money[gc.cur_player]
		if available_for_defense > transport_reserve {
			available_for_defense = gc.money[gc.cur_player] - transport_reserve
		} else {
			available_for_defense = 0 // Not enough for defense after transport reserve
		}
		max_defense_spend := available_for_defense / 2 // 50% of what's available after transport reserve
		defense_spent: u8 = 0
		
		if has_threat {
			// Run battle simulation to see if we can hold
			result := simulate_sea_defense(gc, sea_id, threat, factory_loc)
			
			// Purchase defenders until we can hold (TUV swing < -1 OR win% < 5)
			// OR until we've spent our defense budget
			// region PUR-063: while loop - purchase defenders until TUV/win% threshold met
			purchase_loop: for gc.money[gc.cur_player] >= 6 && gc.builds_left[factory_loc] > 0 && defense_spent < max_defense_spend {
				// Check if we can already hold
				if result.avg_TUV_swing < -1.0 || result.win_percent < 5.0 {
					break
				}
				
				// Calculate remaining defense budget
				remaining_defense_budget := max_defense_spend
				if defense_spent < max_defense_spend {
					remaining_defense_budget = max_defense_spend - defense_spent
				} else {
					remaining_defense_budget = 0
				}
				
				// Select best unit to buy based on efficiency
				// Only consider units that fit within remaining defense budget
				best_unit: Maybe(Idle_Ship) = nil
				best_efficiency := f64(0)
				unused_carrier_cap := int(gc.idle_ships[sea_id][gc.cur_player][.CARRIER]) * 2 - 
				                      int(gc.idle_sea_planes[sea_id][gc.cur_player][.FIGHTER])
				
				ships_to_consider := [?]Idle_Ship{.DESTROYER, .CRUISER, .SUB, .CARRIER, .BATTLESHIP}
				for ship in ships_to_consider {
					cost := COST_IDLE_SHIP[ship]
					// Check both affordability AND budget limit
					if gc.money[gc.cur_player] < cost do continue
					if cost > remaining_defense_budget do continue // Don't exceed defense budget
					
					efficiency := get_sea_defense_efficiency(ship, need_destroyer, unused_carrier_cap)
					if efficiency > best_efficiency {
						best_efficiency = efficiency
						best_unit = ship
					}
				}
				
				if best_unit == nil do break
				ship := best_unit.?
				cost := COST_IDLE_SHIP[ship]
				
				// Buy the unit
				gc.money[gc.cur_player] -= cost
				gc.builds_left[factory_loc] -= 1
				defense_spent += cost
				add_naval_units_to_place_triplea(factory_loc, ship, 1)
				bought_units = true
				
				if ship == .DESTROYER {
					need_destroyer = false
				}
				
				// Re-simulate to check if we can hold now
				result = simulate_sea_defense(gc, sea_id, threat, factory_loc)
				
				when ODIN_DEBUG {
					fmt.println("  [SEA PURCHASE] Bought", ship, "for", sea_id, 
					           "TUV swing:", result.avg_TUV_swing, "Win%:", result.win_percent)
				}
			}
			// endregion PUR-063
			
			// Note: We no longer skip to next sea zone if we can't hold
			// Instead, we still try to buy transports (they're valuable for offense)
		}
		debug_checks(gc)

		// Phase 2: Purchase transports if strategic value is high
		// CHANGED: Buy transports even if we can't perfectly defend the sea zone
		// Having transports enables attacks; losing them is worth the strategic value
		if place_sea.strategic_value >= 3.0 && gc.money[gc.cur_player] >= 7 && gc.builds_left[factory_loc] > 0 {
			// Check if we have at least some defense (don't buy naked transports)
			defenders := count_sea_defenders_triplea(gc, sea_id)
			if defenders >= 1 {
				gc.money[gc.cur_player] -= 7
				gc.builds_left[factory_loc] -= 1
				add_naval_units_to_place_triplea(factory_loc, .TRANS_EMPTY, 1)
				bought_units = true
				
				when ODIN_DEBUG {
					fmt.println("  [SEA PURCHASE] Bought TRANSPORT for", sea_id)
				}
			} else {
				wanted_to_buy_but_couldnt_defend = true
			}
		}
		debug_checks(gc)

		// Phase 3: Purchase carriers if we have fighters that need landing spots
		unused_carrier_cap := int(gc.idle_ships[sea_id][gc.cur_player][.CARRIER]) * 2 - 
		                      int(gc.idle_sea_planes[sea_id][gc.cur_player][.FIGHTER])
		if unused_carrier_cap < 0 && gc.money[gc.cur_player] >= 14 && gc.builds_left[factory_loc] > 0 {
			// Check if we can defend a carrier
			defenders := count_sea_defenders_triplea(gc, sea_id)
			if defenders >= 2 {
				gc.money[gc.cur_player] -= 14
				gc.builds_left[factory_loc] -= 1
				add_naval_units_to_place_triplea(factory_loc, .CARRIER, 1)
				bought_units = true
				
				when ODIN_DEBUG {
					fmt.println("  [SEA PURCHASE] Bought CARRIER for", sea_id)
				}
			} else {
				wanted_to_buy_but_couldnt_defend = true
			}
		}
	}
	// endregion PUR-062
	debug_checks(gc)

	// =============================================================================
	// Phase 4: Transport/Amphib Purchase (Java lines 1891-2091)
	// KEY INSIGHT: Buy transports for units stranded on low-value islands (like UK)
	// =============================================================================
	
	// #region PUR-064: Transport/Amphib purchasing - buy transports and amphib units
	purchase_transports_and_amphib_units(gc, prioritized_sea, &bought_units)
	// #endregion PUR-064
	
	debug_checks(gc)

	// Return whether we should save up for fleet
	return !bought_units && wanted_to_buy_but_couldnt_defend
}

// =============================================================================
// PUR-064: Purchase transports and amphib units
// Identifies stranded units on low-value territories and buys transports to evacuate them
// =============================================================================
purchase_transports_and_amphib_units :: proc(
	gc: ^Game_Cache,
	prioritized_sea: [dynamic]Place_Territory_Sea,
	bought_units: ^bool,
) {
	if gc.money[gc.cur_player] < 3 do return // Need at least 3 for infantry
	
	player := gc.cur_player
	
	// Calculate territory values to find low-value territories (stranded units)
	// Java uses value <= 0.25 to identify territories where units should be evacuated
	LOW_VALUE_THRESHOLD :: 0.25
	
	when ODIN_DEBUG {
		fmt.println("\n  [PHASE 4] Transport/Amphib Purchase")
	}
	
	// For each prioritized sea zone, check for transport opportunities
	for place_sea in prioritized_sea {
		sea_id := place_sea.sea_zone
		
		// Find factory that can build to this sea zone
		factory_for_sea: Maybe(Land_ID) = nil
		for factory_loc in sa.slice(&gc.factory_locations[player]) {
			if gc.owner[factory_loc] != player do continue
			if gc.builds_left[factory_loc] == 0 do continue
			for adj_sea in sa.slice(&mm.l2s_1away_via_land[factory_loc]) {
				if adj_sea == sea_id {
					factory_for_sea = factory_loc
					break
				}
			}
			if factory_for_sea != nil do break
		}
		
		if factory_for_sea == nil do continue
		factory_loc := factory_for_sea.?
		
		// Count existing transports that need units (empty or partially loaded)
		transports_needing_units := count_empty_transports_triplea(gc, sea_id)
		
		// Count potential units to load from adjacent low-value territories
		potential_units_to_load := count_stranded_units_for_sea(gc, sea_id, player)
		
		when ODIN_DEBUG {
			fmt.printf("    [SEA %v] transports_needing_units=%d, potential_units_to_load=%d, factory=%v\n",
				sea_id, transports_needing_units, potential_units_to_load, factory_loc)
		}
		
		// Skip if no units need transport
		if potential_units_to_load == 0 do continue
		
		// #region PUR-065: while loop - purchase transports and amphib units
		amphib_loop: for gc.money[gc.cur_player] >= 3 && gc.builds_left[factory_loc] > 0 {
			
			// Branch A: Fill existing empty transports with purchased amphib units
			if transports_needing_units > 0 {
				// Transport capacity is 5 (2 infantry or 1 infantry + 1 tank/arty)
				transport_capacity := 5
				
				// CRITICAL FIX: First deduct capacity for existing stranded units
				// Java does this with selectUnitsToTransportFromList() - existing units
				// get priority to be loaded, and we only purchase for remaining capacity.
				//
				// Calculate how many stranded units can fill this transport:
				// Infantry costs 2 transport capacity, others cost 3
				stranded_to_load := min(int(potential_units_to_load), 2) // Max 2 units per transport
				if stranded_to_load > 0 {
					// Assume stranded units are mostly infantry (transport cost 2 each)
					// 2 infantry = 4 capacity, leaving 1 (but can't use 1 for anything)
					// 1 infantry = 2 capacity, could still fit 1 arty/tank (3)
					capacity_used_by_stranded := stranded_to_load * 2 // Assume infantry at 2 each
					transport_capacity -= capacity_used_by_stranded
					potential_units_to_load -= u8(stranded_to_load)
					
					when ODIN_DEBUG {
						fmt.printf("      [LOAD EXISTING] %d stranded units will fill %d capacity (remaining: %d)\n",
							stranded_to_load, capacity_used_by_stranded, transport_capacity)
					}
				} else {
					// No stranded units left to load - this transport would be empty after
					// loading existing units. Skip buying units just to fill empty transports
					// unless we have good amphibious assault opportunities.
					// For now, skip filling transports that have no cargo purpose.
					transports_needing_units -= 1
					continue
				}
				
				// Only purchase units if there's remaining capacity after loading stranded units
				// #region PUR-066: while loop - fill transport with amphib units
				fill_transport: for transport_capacity > 0 && gc.money[gc.cur_player] >= 3 && gc.builds_left[factory_loc] > 0 {
					// Calculate amphib efficiencies
					// Prefer tanks > artillery > infantry for offensive punch
					best_unit: Maybe(Unit_Type) = nil
					best_efficiency: f64 = 0
					
					// Tank: cost 6, transport cost 3, attack 3 -> efficiency 3/6 = 0.5 per PU
					if transport_capacity >= 3 && gc.money[gc.cur_player] >= 6 {
						efficiency := f64(3.0) / f64(6.0) // attack / cost
						if efficiency > best_efficiency {
							best_efficiency = efficiency
							best_unit = .Tank
						}
					}
					
					// Artillery: cost 4, transport cost 3, attack 2 -> efficiency 2/4 = 0.5 per PU
					// But artillery supports infantry, so slightly prefer
					if transport_capacity >= 3 && gc.money[gc.cur_player] >= 4 {
						efficiency := f64(2.2) / f64(4.0) // Slightly boosted for infantry support
						if efficiency > best_efficiency {
							best_efficiency = efficiency
							best_unit = .Artillery
						}
					}
					
					// Infantry: cost 3, transport cost 2, attack 1 -> efficiency 1/3 = 0.33 per PU
					if transport_capacity >= 2 && gc.money[gc.cur_player] >= 3 {
						efficiency := f64(1.0) / f64(3.0)
						if efficiency > best_efficiency {
							best_efficiency = efficiency
							best_unit = .Infantry
						}
					}
					
					if best_unit == nil do break fill_transport
					
					unit := best_unit.?
					cost: u8 = 0
					transport_cost: int = 0
					
					#partial switch unit {
					case .Infantry:
						cost = 3
						transport_cost = 2
					case .Artillery:
						cost = 4
						transport_cost = 3
					case .Tank:
						cost = 6
						transport_cost = 3
					case:
						break fill_transport
					}
					
					gc.money[gc.cur_player] -= cost
					gc.builds_left[factory_loc] -= 1
					transport_capacity -= transport_cost
					add_units_to_place_triplea(factory_loc, unit, 1)
					bought_units^ = true
					
					when ODIN_DEBUG {
						fmt.printf("      [AMPHIB] Bought %v for transport at %v (capacity left: %d)\n",
							unit, factory_loc, transport_capacity)
					}
				}
				// #endregion PUR-066
				
				transports_needing_units -= 1
				
			} else {
				// Branch B: Buy new transport if units need evacuation and we can defend it
				if potential_units_to_load > 0 && gc.money[gc.cur_player] >= 7 {
					// Check if we have enough defense for transport
					defenders := count_sea_defenders_triplea(gc, sea_id)
					if defenders >= 1 {
						gc.money[gc.cur_player] -= 7
						gc.builds_left[factory_loc] -= 1
						add_naval_units_to_place_triplea(factory_loc, .TRANS_EMPTY, 1)
						bought_units^ = true
						transports_needing_units += 1 // Will trigger Branch A next iteration
						
						when ODIN_DEBUG {
							fmt.printf("      [TRANSPORT] Bought transport at %v for stranded units\n", factory_loc)
						}
					} else {
						// Can't defend transport, stop trying
						break amphib_loop
					}
				} else {
					// No more units to load or can't afford transport
					break amphib_loop
				}
			}
		}
		// #endregion PUR-065
	}
	// #endregion PUR-064
}

// Helper: Check if we need destroyer for anti-sub warfare
check_need_destroyer_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> bool {
	/*
	Java Original (from ProPurchaseAi.java lines 559-562):
	
	boolean needDestroyer =
		enemyAttackOptions.getMax(t).getMaxUnits().stream()
			.anyMatch(Matches.unitHasSubBattleAbilities())
		&& ownedLocalUnits.stream().noneMatch(Matches.unitIsDestroyer());
	*/

	// Check if we already have destroyer
	if gc.idle_ships[sea_id][gc.cur_player][.DESTROYER] > 0 do return false

	// Simplified: assume moderate sub threat if we have no destroyer
	return true
}

// Helper: Check if we can defend a new transport
can_defend_new_transport_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> bool {
	// Need at least 1 combat ship to protect transport
	defenders := count_sea_defenders_triplea(gc, sea_id)
	return defenders >= 1
}

// Helper: Check if we can defend a new carrier
can_defend_new_carrier_triplea :: proc(gc: ^Game_Cache, sea_id: Sea_ID) -> bool {
	// Need at least 2 combat ships to protect carrier
	defenders := count_sea_defenders_triplea(gc, sea_id)
	return defenders >= 2
}

// =============================================================================
// SEA BATTLE HELPER FUNCTIONS FOR PURCHASE DECISIONS
// =============================================================================

// Build Sea_Attackers structure from Enemy_Territory_Threat
// Used to create battle simulation inputs from enemy attack analysis
get_enemy_sea_attackers_from_threat :: proc(threat: ^Enemy_Territory_Threat) -> Sea_Attackers {
	return Sea_Attackers{
		Subs        = threat.max_subs,
		Destroyers  = threat.max_destroyers,
		Cruisers    = threat.max_cruisers,
		Carriers    = threat.max_carriers,
		Battleships = threat.max_battleships,
		BS_Damaged  = 0,  // Threat analysis doesn't distinguish damaged
		Fighters    = threat.max_fighters,
		Bombers     = threat.max_bombers,
	}
}

// Build Sea_Defenders from our current units in a sea zone
// Includes both idle ships and pending purchases from the specified factory
get_my_sea_defenders :: proc(
	gc: ^Game_Cache, 
	sea_id: Sea_ID,
	factory_loc: Land_ID,  // Factory location to check for pending purchases
) -> Sea_Defenders {
	player := gc.cur_player
	
	def := Sea_Defenders{
		Subs        = gc.idle_ships[sea_id][player][.SUB],
		Destroyers  = gc.idle_ships[sea_id][player][.DESTROYER],
		Cruisers    = gc.idle_ships[sea_id][player][.CRUISER],
		Carriers    = gc.idle_ships[sea_id][player][.CARRIER],
		Battleships = gc.idle_ships[sea_id][player][.BATTLESHIP],
		BS_Damaged  = gc.idle_ships[sea_id][player][.BS_DAMAGED],
		Fighters    = gc.idle_sea_planes[sea_id][player][.FIGHTER],
		Transports  = count_all_transports_triplea(gc, sea_id),
	}
	
	// Add pending purchases from the factory that builds to this sea zone
	for &purchase in g_purchased_units {
		if purchase.territory == factory_loc {
			// Check if this factory can build to this sea zone
			for adj_sea in sa.slice(&mm.l2s_1away_via_land[factory_loc]) {
				if adj_sea == sea_id {
					def.Subs += purchase.sub
					def.Destroyers += purchase.destroyer
					def.Cruisers += purchase.cruiser
					def.Carriers += purchase.carrier
					def.Battleships += purchase.battleship
					def.Transports += purchase.transport
					break
				}
			}
		}
	}
	
	// Add allied ships
	for ally in sa.slice(&mm.allies[player]) {
		if ally == player do continue
		def.Subs += gc.idle_ships[sea_id][ally][.SUB]
		def.Destroyers += gc.idle_ships[sea_id][ally][.DESTROYER]
		def.Cruisers += gc.idle_ships[sea_id][ally][.CRUISER]
		def.Carriers += gc.idle_ships[sea_id][ally][.CARRIER]
		def.Battleships += gc.idle_ships[sea_id][ally][.BATTLESHIP]
		def.BS_Damaged += gc.idle_ships[sea_id][ally][.BS_DAMAGED]
		def.Fighters += gc.idle_sea_planes[sea_id][ally][.FIGHTER]
	}
	
	return def
}

// Simulate a sea battle and return results for purchase decision
// This is the main entry point for AI purchase decisions
simulate_sea_defense :: proc(
	gc: ^Game_Cache,
	sea_id: Sea_ID,
	threat: ^Enemy_Territory_Threat,
	factory_loc: Land_ID,
) -> Sea_Battle_Results {
	attackers := get_enemy_sea_attackers_from_threat(threat)
	defenders := get_my_sea_defenders(gc, sea_id, factory_loc)
	
	when ODIN_DEBUG {
		fmt.printf("    [SIM] %v: Def(subs=%d,DD=%d,CA=%d,CV=%d,BS=%d,ftr=%d) vs Att(subs=%d,DD=%d,CA=%d,CV=%d,BS=%d,ftr=%d,bmb=%d)\n",
			sea_id,
			defenders.Subs, defenders.Destroyers, defenders.Cruisers, defenders.Carriers, defenders.Battleships, defenders.Fighters,
			attackers.Subs, attackers.Destroyers, attackers.Cruisers, attackers.Carriers, attackers.Battleships, attackers.Fighters, attackers.Bombers)
	}
	
	combatants := Sea_Combatants{
		defenders = defenders,
		attackers = attackers,
	}
	
	return simulate_sea_battle(combatants)
}

// Check if we can hold a sea zone against enemy attacks
// Returns true if TUV swing is favorable OR win% is low enough
can_hold_sea_zone :: proc(
	gc: ^Game_Cache,
	sea_id: Sea_ID,
	threat: ^Enemy_Territory_Threat,
	factory_loc: Land_ID,
) -> bool {
	result := simulate_sea_defense(gc, sea_id, threat, factory_loc)
	
	// Java logic: (result.getTuvSwing() < -1 || result.getWinPercentage() < (100.0 - 95))
	// TUV swing < -1 means defender wins on TUV
	// Win% < 5 means attacker only wins 5% of time
	return result.avg_TUV_swing < -1.0 || result.win_percent < 5.0
}

// Calculate sea defense efficiency for a unit type
// Based on Java's ProPurchaseOption.getSeaDefenseEfficiency()
get_sea_defense_efficiency :: proc(
	ship_type: Idle_Ship,
	need_destroyer: bool,
	unused_carrier_capacity: int,
) -> f64 {
	/*
	Java logic (simplified):
	- Destroyer: bonus if need_destroyer for anti-sub
	- Carrier: bonus if we have fighters needing landing spots
	- Otherwise: defense power / cost
	*/
	
	cost := f64(COST_IDLE_SHIP[ship_type])
	if cost == 0 do return 0.0
	
	#partial switch ship_type {
	case .DESTROYER:
		base := f64(DESTROYER_DEFENSE) / cost
		if need_destroyer {
			return base * 2.0  // Double value if we need anti-sub
		}
		return base
	case .CRUISER:
		return f64(CRUISER_DEFENSE) / cost
	case .BATTLESHIP:
		// Battleships are expensive but take 2 hits
		return f64(BATTLESHIP_DEFENSE * 2) / cost
	case .CARRIER:
		base := f64(CARRIER_DEFENSE) / cost
		if unused_carrier_capacity < 0 {
			// We have fighters that need landing spots
			return base * 1.5
		}
		return base
	case .SUB:
		// Subs are cheap but can be ignored if enemy has no destroyer
		return f64(SUB_DEFENSE) / cost * 0.8
	case:
		return 0.0  // Transports have no defense
	}
}

/*
=============================================================================
METHOD 14: purchaseUnitsWithRemainingProduction
=============================================================================

Java Original (lines 2098-2250):

  private void purchaseUnitsWithRemainingProduction(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final List<ProPurchaseOption> landPurchaseOptions,
      final List<ProPurchaseOption> airPurchaseOptions) {

    if (resourceTracker.isEmpty()) { return; }

    // Get all safe/unsafe land place territories with remaining production
    final List<ProPlaceTerritory> prioritizedLandTerritories = new ArrayList<>();
    final List<ProPlaceTerritory> prioritizedCantHoldLandTerritories = new ArrayList<>();
    // [Lines 2116-2126 - Categorize territories]

    // Loop through territories and purchase long range attack units
    for (final ProPlaceTerritory placeTerritory : prioritizedLandTerritories) {
      // Purchase most cost efficient long range attack unit (bombers, fighters)
      // [Lines 2136-2188]
    }

    // Loop through can't hold territories and purchase defense units
    for (final ProPlaceTerritory placeTerritory : prioritizedCantHoldLandTerritories) {
      // Purchase defensive units even if can't hold
      // [Lines 2199-2247]
    }
  }
*/

// Odin Implementation:
purchase_units_with_remaining_production_triplea :: proc(
	gc: ^Game_Cache,
	prioritized_land: [dynamic]Place_Territory_Land,
) {
	// TODO REVIEW: Java purchaseUnitsWithRemainingProduction (lines 2098-2250) has additional logic:
	//
	// Missing Block 1 (line 2164): Attack efficiency with movement bonus
	//   - attackEfficiency = (attack * attack) * movement
	//   - Squares attack value to emphasize high-attack units
	//
	// Missing Block 2 (line 2166): Air unit 10x multiplier
	//   - if (ppo.isAir()) { attackEfficiency *= 10; }
	//   - This heavily prioritizes air units for safe territories
	//
	// Missing Block 3: Defense efficiency with cost squared
	//   - defenseEfficiency = (defense * defense) / cost
	//   - Java uses squared defense for efficiency
	//
	// Missing Block 4: Bomber purchasing
	//   - Java prefers bombers over fighters due to attack * movement
	//   - Current code only buys fighters
	//
	// Missing Block 5: Randomized selection
	//   - Java uses random() for variety in unit selection
	
	if gc.money[gc.cur_player] == 0 do return

	/*
	TripleA logic:
	1. For safe territories: Buy long-range attack units (fighters, bombers)
	2. For unsafe territories: Buy defensive units
	*/

	when ODIN_DEBUG {
		fmt.println("  [RATIONALE] Using remaining production capacity...")
	}

	starting_money := gc.money[gc.cur_player]
	fighters_bought := 0
	infantry_bought := 0

	// Split territories into safe and unsafe
	safe_territories := make([dynamic]Place_Territory_Land, context.temp_allocator)
	unsafe_territories := make([dynamic]Place_Territory_Land, context.temp_allocator)

	for place_terr in prioritized_land {
		// Check if territory has factory
		if !place_terr.has_factory do continue

		// Simplified safety check: high strategic value = safe
		if place_terr.strategic_value >= 5.0 {
			append(&safe_territories, place_terr)
		} else {
			append(&unsafe_territories, place_terr)
		}
	}

	// Buy long-range attackers for safe territories (fighters preferred)
	for place_terr in safe_territories {
		if gc.money[gc.cur_player] < 10 do break

		territory := place_terr.territory
		
		// Check remaining production capacity
		if gc.builds_left[territory] == 0 do continue

		// Buy fighter (versatile, good attack and defense)
		if gc.money[gc.cur_player] >= 10 {
			gc.money[gc.cur_player] -= 10
			gc.builds_left[territory] -= 1
			add_units_to_place_triplea(territory, .Fighter, 1)
			fighters_bought += 1
			when ODIN_DEBUG {
				fmt.printf("    Bought fighter at %v (safe territory)\n", territory)
			}
		}
	}

	// Buy defenders for unsafe territories
	for place_terr in unsafe_territories {
		if gc.money[gc.cur_player] < 3 do break

		territory := place_terr.territory
		
		// Check remaining production capacity
		if gc.builds_left[territory] == 0 do continue

		// Buy infantry (cheap defenders)
		for gc.money[gc.cur_player] >= 3 && gc.builds_left[territory] > 0 {
			gc.money[gc.cur_player] -= 3
			gc.builds_left[territory] -= 1
			add_units_to_place_triplea(territory, .Infantry, 1)
			infantry_bought += 1
		}
	}

	when ODIN_DEBUG {
		if fighters_bought > 0 || infantry_bought > 0 {
			money_spent := starting_money - gc.money[gc.cur_player]
			fmt.printf(
				"    Purchased: %d fighters, %d infantry (%d IPCs)\n",
				fighters_bought,
				infantry_bought,
				money_spent,
			)
		} else {
			fmt.println("    No units purchased with remaining production")
		}
	}
}

/*
=============================================================================
METHOD 15: upgradeUnitsWithRemainingPUs
=============================================================================

Java Original (lines 2252-2392):

  private void upgradeUnitsWithRemainingPUs(
      final Map<Territory, ProPurchaseTerritory> purchaseTerritories,
      final ProPurchaseOptionMap purchaseOptions) {

    if (resourceTracker.isEmpty()) { return; }

    // Get all safe land place territories
    final List<ProPlaceTerritory> prioritizedLandTerritories = new ArrayList<>();
    // [Lines 2262-2268 - Get territories]

    // Sort by ascending value (upgrade far territories first)
    prioritizedLandTerritories.sort(
        Comparator.comparingDouble(ProPlaceTerritory::getStrategicValue));

    // Loop through territories and upgrade units
    for (final ProPlaceTerritory placeTerritory : prioritizedLandTerritories) {
      // Try to upgrade units to better versions
      // Example: Infantry -> Artillery or Tank
      // [Lines 2277-2389 - Upgrade logic]
      // Key: Use findUpgradeUnitEfficiency to determine best upgrade
    }
  }
*/

// Odin Implementation:
upgrade_units_with_remaining_pus_triplea :: proc(
	gc: ^Game_Cache,
	prioritized_land: [dynamic]Place_Territory_Land,
) {
	if gc.money[gc.cur_player] < 1 do return

	/*
	TripleA logic:
	1. Upgrade PURCHASED units (not existing ones) in far territories first
	2. Replace cheap units with better units (e.g., Infantry -> Artillery/Tank)
	3. Use findUpgradeUnitEfficiency to determine best upgrade
	
	Important: We can only upgrade units we purchased THIS TURN, which are
	tracked in g_purchased_units. We refund the cheaper unit and buy the upgrade.
	*/

	when ODIN_DEBUG {
		fmt.println("  [RATIONALE] Upgrading units with remaining funds...")
	}

	starting_money := gc.money[gc.cur_player]
	upgrades := 0

	// Iterate through purchased units and try to upgrade them
	for &purchase in g_purchased_units {
		if gc.money[gc.cur_player] < 1 do break
		
		territory := purchase.territory
		
		// Get territory strategic value
		strategic_value: f64 = 0
		for place_terr in prioritized_land {
			if place_terr.territory == territory {
				strategic_value = place_terr.strategic_value
				break
			}
		}
		
		// Get enemy distance for this territory - key for movement factor calculation
		enemy_distance := get_closest_enemy_land_distance(gc, territory)

		// Try to upgrade purchased infantry to artillery
		// Cost difference: 4 - 3 = 1 IPC
		for purchase.inf > 0 && gc.money[gc.cur_player] >= 1 {
			efficiency := find_upgrade_unit_efficiency_triplea(
				4,
				2.0,
				2.0,
				1,
				strategic_value,
				enemy_distance,
			)

			if efficiency > 3.0 { // Worth upgrading
				purchase.inf -= 1
				purchase.arty += 1
				gc.money[gc.cur_player] -= 1 // Pay upgrade cost (4-3=1)
				upgrades += 1
				when ODIN_DEBUG {
					fmt.printf("    Upgraded infantry -> artillery at %v\n", territory)
				}
			} else {
				break // Not worth upgrading more infantry here
			}
		}

		// Try to upgrade purchased infantry to tank
		// Cost difference: 6 - 3 = 3 IPCs
		// Tanks benefit greatly from the exponential distance factor!
		for purchase.inf > 0 && gc.money[gc.cur_player] >= 3 {
			efficiency := find_upgrade_unit_efficiency_triplea(
				6,
				3.0,
				3.0,
				2, // movement 2 gives exponential boost at distance
				strategic_value,
				enemy_distance,
			)

			if efficiency > 5.0 { // Worth upgrading
				purchase.inf -= 1
				purchase.tank += 1
				gc.money[gc.cur_player] -= 3 // Pay upgrade cost (6-3=3)
				upgrades += 1
				when ODIN_DEBUG {
					fmt.printf("    Upgraded infantry -> tank at %v (dist=%d)\n", territory, enemy_distance)
				}
			} else {
				break // Not worth upgrading more infantry here
			}
		}
		
		// Try to upgrade purchased artillery to tank
		// Cost difference: 6 - 4 = 2 IPCs
		for purchase.arty > 0 && gc.money[gc.cur_player] >= 2 {
			efficiency := find_upgrade_unit_efficiency_triplea(
				6,
				3.0,
				3.0,
				2,
				strategic_value,
				enemy_distance,
			)
			
			// Only upgrade if tanks are significantly better (distance factor helps)
			if efficiency > 6.0 {
				purchase.arty -= 1
				purchase.tank += 1
				gc.money[gc.cur_player] -= 2 // Pay upgrade cost (6-4=2)
				upgrades += 1
				when ODIN_DEBUG {
					fmt.printf("    Upgraded artillery -> tank at %v (dist=%d)\n", territory, enemy_distance)
				}
			} else {
				break
			}
		}
	}

	when ODIN_DEBUG {
		if upgrades > 0 {
			money_spent := starting_money - gc.money[gc.cur_player]
			fmt.printf("    Completed %d unit upgrades (%d IPCs)\n", upgrades, money_spent)
		} else {
			fmt.println("    No upgrades performed")
		}
	}
}

/*
=============================================================================
METHOD 16: findUpgradeUnitEfficiency
=============================================================================

Java Original (lines 2394-2403):

  private static double findUpgradeUnitEfficiency(
      final ProPurchaseOption ppo, final double strategicValue) {
    final double multiplier =
        (strategicValue >= 1) ? ppo.getDefenseEfficiency() : ppo.getMovement();
    return ppo.getAttackEfficiency() * multiplier * ppo.getCost() / ppo.getQuantity();
  }
*/

// Helper: Calculate land distance factor with exponential movement bonus
// This is the key formula that makes tanks more valuable at greater distances
//
// Java Original (ProPurchaseOption.java lines 263-275):
//   private double calculateLandDistanceFactor(final int enemyDistance) {
//     if (movement <= 0) return 0.1;
//     final double distance = Math.max(0, enemyDistance - 1.5);
//     final int moveValue = isLandTransport ? (movement + 1) : movement;
//     final double moveFactor = 1.0 + 2.0 * (Math.pow(2, moveValue - 1.0) - 1.0) / Math.pow(2, moveValue - 1.0);
//     return Math.pow(moveFactor, distance / 5);
//   }
//
// Movement -> moveFactor mapping:
//   0 -> 0.1 (stationary units heavily penalized)
//   1 -> 1.0 (infantry baseline)
//   2 -> 2.0 (tanks get 2x factor)
//   3 -> 2.5, 4 -> 2.75, etc (diminishing returns)
//
// At distance 5:  tank factor = 2.0^1 = 2.0
// At distance 10: tank factor = 2.0^2 = 4.0
// At distance 15: tank factor = 2.0^3 = 8.0
calculate_land_distance_factor :: proc(movement: int, enemy_distance: int) -> f64 {
	if movement <= 0 {
		return 0.1  // Stationary units are 10x less efficient
	}
	
	// Adjusted distance: subtract 1.5 because nearby enemies don't need mobility
	distance := max(0.0, f64(enemy_distance) - 1.5)
	
	// Calculate move factor: 1, 2, 2.5, 2.75, etc.
	// Formula: 1.0 + 2.0 * (2^(move-1) - 1) / 2^(move-1)
	// Which simplifies to: 1.0 + 2.0 * (1 - 1/2^(move-1))
	move_value := f64(movement)
	power_term := math.pow(2.0, move_value - 1.0)
	move_factor := 1.0 + 2.0 * (power_term - 1.0) / power_term
	
	// Exponential boost based on distance: moveFactor^(distance/5)
	// This means at distance 5, you get moveFactor^1
	// At distance 10, you get moveFactor^2, etc.
	return math.pow(move_factor, distance / 5.0)
}

// Odin Implementation:
find_upgrade_unit_efficiency_triplea :: proc(
	unit_cost: int,
	attack: f64,
	defense: f64,
	movement: int,
	strategic_value: f64,
	enemy_distance: int = 5,  // Default to mid-range distance
) -> f64 {
	/*
	TripleA algorithm:
	- If territory has high strategic value (>= 1.0, near enemy): favor defense efficiency
	- If territory has low strategic value (< 1.0, far from enemy): favor movement * distance factor
	- The distance factor gives exponential boost to high-movement units at large distances
	
	This helps determine whether upgrading a unit is worthwhile:
	- Infantry (3 cost, 1 attack, 2 defense, 1 movement)
	- Artillery (4 cost, 2 attack, 2 defense, 1 movement)
	- Tank (6 cost, 3 attack, 3 defense, 2 movement)
	
	Example at enemy_distance = 10:
	- Infantry distance factor = 1.0^1 = 1.0
	- Tank distance factor = 2.0^1.7 ≈ 3.25
	
	So tanks become ~3.25x more efficient at distance 10 vs infantry!
	*/

	// Calculate the exponential distance factor based on movement
	distance_factor := calculate_land_distance_factor(movement, enemy_distance)
	
	// Multiplier: use defense near enemy, or distance_factor far from enemy
	multiplier := strategic_value >= 1.0 ? defense : distance_factor

	// Attack efficiency is attack power per cost
	attack_efficiency := attack / f64(unit_cost)

	// Final efficiency: combines attack, strategic multiplier, and total cost
	// Higher is better (more bang for buck)
	efficiency := attack_efficiency * multiplier * f64(unit_cost)

	return efficiency
}

/*
=============================================================================
HELPER METHODS
=============================================================================
*/

// populateProductionRuleMap - Convert purchases to production rules
populate_production_rule_map_triplea :: proc(gc: ^Game_Cache) {
	/*
	Java Original (from ProPurchaseAi.java lines 389-400):
	
	final IntegerMap<ProductionRule> purchaseMap = new IntegerMap<>();
	for (final ProPurchaseTerritory ppt : purchaseTerritories.values()) {
		for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
			for (final Unit unit : placeTerritory.getPlaceUnits()) {
				final ProductionRule rule = unit.getProductionRule();
				purchaseMap.add(rule, 1);
			}
		}
	}
	*/

	// Initialize purchase tracking if not already done
	if g_purchased_units == nil {
		g_purchased_units = make([dynamic]Purchased_Units)
	}

	// Clear any previous purchases
	clear(&g_purchased_units)

	// Note: This is called at start of purchase phase to prepare tracking
	// Individual purchase methods will append to g_purchased_units
}

// placeDefenders - Place purchased defenders during place phase
place_defenders_triplea :: proc(gc: ^Game_Cache) {
	/*
	Java Original (from ProPurchaseAi.java lines 585-655):
	
	ProLogger.info("Placing defenders with " + purchaseTerritories.size());
	for (final ProPurchaseTerritory ppt : prioritizedTerritories) {
		if (purchaseTerritory.isCanHold()) {
			for (final Unit defender : placeTerritory.getPlaceUnits()) {
				if (Matches.unitIsInfrastructure().negate().test(defender)) {
					placeUnits.add(defender);
				}
			}
			doPlace(purchaseTerritory.getTerritory(), placeUnits, placeDelegate);
		}
	}
	*/

	// Place all purchased units from tracking structure
	if g_purchased_units == nil || len(g_purchased_units) == 0 {
		when ODIN_DEBUG {
			fmt.println("  [PLACE] No units to place (g_purchased_units is empty)")
		}
		return
	}

	when ODIN_DEBUG {
		fmt.printf("  [PLACE] Placing units from %d territories\n", len(g_purchased_units))
	}

	for purchase in g_purchased_units {
		territory := purchase.territory
		units_placed := false

		// Place land units
		if purchase.inf > 0 {
			gc.active_armies[territory][.INF_0_MOVES] += purchase.inf
			gc.idle_armies[territory][gc.cur_player][.INF] += purchase.inf
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.inf
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d Infantry -> %v\n", purchase.inf, territory)
			}
			units_placed = true
		}
		if purchase.arty > 0 {
			gc.active_armies[territory][.ARTY_0_MOVES] += purchase.arty
			gc.idle_armies[territory][gc.cur_player][.ARTY] += purchase.arty
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.arty
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d Artillery -> %v\n", purchase.arty, territory)
			}
			units_placed = true
		}
		if purchase.tank > 0 {
			gc.active_armies[territory][.TANK_0_MOVES] += purchase.tank
			gc.idle_armies[territory][gc.cur_player][.TANK] += purchase.tank
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.tank
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d Tank -> %v\n", purchase.tank, territory)
			}
			units_placed = true
		}
		if purchase.aa > 0 {
			gc.active_armies[territory][.AAGUN_0_MOVES] += purchase.aa
			gc.idle_armies[territory][gc.cur_player][.AAGUN] += purchase.aa
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.aa
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d AA Gun -> %v\n", purchase.aa, territory)
			}
			units_placed = true
		}
		if purchase.fighter > 0 {
			gc.active_land_planes[territory][.FIGHTER_0_MOVES] += purchase.fighter
			gc.idle_land_planes[territory][gc.cur_player][.FIGHTER] += purchase.fighter
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.fighter
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d Fighter -> %v\n", purchase.fighter, territory)
			}
			units_placed = true
		}
		if purchase.bomber > 0 {
			gc.active_land_planes[territory][.BOMBER_0_MOVES] += purchase.bomber
			gc.idle_land_planes[territory][gc.cur_player][.BOMBER] += purchase.bomber
			gc.team_land_units[territory][mm.team[gc.cur_player]] += purchase.bomber
			when ODIN_DEBUG {
				fmt.printf("  [PLACE] %d Bomber -> %v\n", purchase.bomber, territory)
			}
			units_placed = true
		}

		// Place naval units (find adjacent sea zone)
		if purchase.sub > 0 ||
		   purchase.destroyer > 0 ||
		   purchase.cruiser > 0 ||
		   purchase.carrier > 0 ||
		   purchase.battleship > 0 ||
		   purchase.transport > 0 {
			// Find first adjacent sea zone
			for sea_id in sa.slice(&mm.l2s_1away_via_land[territory]) {
				if purchase.sub > 0 {
					gc.active_ships[sea_id][.SUB_0_MOVES] += purchase.sub
					gc.idle_ships[sea_id][gc.cur_player][.SUB] += purchase.sub
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.sub
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Submarine -> %v (from factory at %v)\n",
							purchase.sub,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				if purchase.destroyer > 0 {
					gc.active_ships[sea_id][.DESTROYER_0_MOVES] += purchase.destroyer
					gc.idle_ships[sea_id][gc.cur_player][.DESTROYER] += purchase.destroyer
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.destroyer
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Destroyer -> %v (from factory at %v)\n",
							purchase.destroyer,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				if purchase.cruiser > 0 {
					gc.active_ships[sea_id][.CRUISER_0_MOVES] += purchase.cruiser
					gc.idle_ships[sea_id][gc.cur_player][.CRUISER] += purchase.cruiser
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.cruiser
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Cruiser -> %v (from factory at %v)\n",
							purchase.cruiser,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				if purchase.carrier > 0 {
					gc.active_ships[sea_id][.CARRIER_0_MOVES] += purchase.carrier
					gc.idle_ships[sea_id][gc.cur_player][.CARRIER] += purchase.carrier
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.carrier
					gc.allied_carriers_total[sea_id] += purchase.carrier
					if gc.allied_carriers_total[sea_id] * 2 > gc.allied_fighters_total[sea_id] {
						gc.has_carrier_space += {sea_id}
						gc.is_fighter_cache_current = false
					}
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Carrier -> %v (from factory at %v)\n",
							purchase.carrier,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				if purchase.battleship > 0 {
					gc.active_ships[sea_id][.BATTLESHIP_0_MOVES] += purchase.battleship
					gc.idle_ships[sea_id][gc.cur_player][.BATTLESHIP] += purchase.battleship
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.battleship
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Battleship -> %v (from factory at %v)\n",
							purchase.battleship,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				if purchase.transport > 0 {
					gc.active_ships[sea_id][.TRANS_EMPTY_0_MOVES] += purchase.transport
					gc.idle_ships[sea_id][gc.cur_player][.TRANS_EMPTY] += purchase.transport
					gc.team_sea_units[sea_id][mm.team[gc.cur_player]] += purchase.transport
					when ODIN_DEBUG {
						fmt.printf(
							"  [PLACE] %d Transport -> %v (from factory at %v)\n",
							purchase.transport,
							sea_id,
							territory,
						)
					}
					units_placed = true
				}
				break // Only place in first adjacent sea zone
			}
		}
	}

	// Clear purchases after placing
	clear(&g_purchased_units)

	when ODIN_DEBUG {
		fmt.println("  + All purchased units placed")
	}
}

// place_factory_triplea - Place factories that were purchased during purchase phase
place_factory_triplea :: proc(gc: ^Game_Cache) {
	/*
	Place factories from g_purchased_factories tracking structure.
	This is called during the place phase after units are placed.
	*/

	if g_purchased_factories == nil || len(g_purchased_factories) == 0 {
		when ODIN_DEBUG {
			fmt.println("  [PLACE] No factories to place")
		}
		return
	}

	when ODIN_DEBUG {
		fmt.printf("  [PLACE] Placing %d factory/factories\n", len(g_purchased_factories))
	}

	for factory_territory in g_purchased_factories {
		// Set factory production
		gc.factory_prod[factory_territory] = mm.value[factory_territory]
		gc.factory_dmg[factory_territory] = 0

		// Add to factory locations
		sa.push(&gc.factory_locations[gc.cur_player], factory_territory)

		when ODIN_DEBUG {
			fmt.printf(
				"  [PLACE] Factory -> %v (production capacity: %d)\n",
				factory_territory,
				mm.value[factory_territory],
			)
		}
	}

	// Clear factory purchases after placing
	clear(&g_purchased_factories)

	when ODIN_DEBUG {
		fmt.println("  + All factories placed")
	}
}


// placeUnits - Place remaining units
place_units_triplea :: proc(gc: ^Game_Cache) {
	/*
	Java Original (from ProPurchaseAi.java lines 657-713):
	
	ProLogger.info("Placing remaining units");
	for (final ProPurchaseTerritory ppt : sortedTerritories) {
		final List<Unit> placeUnits = new ArrayList<>();
		for (final ProPlaceTerritory placeTerritory : ppt.getCanPlaceTerritories()) {
			placeUnits.addAll(placeTerritory.getPlaceUnits());
		}
		if (!placeUnits.isEmpty()) {
			doPlace(ppt.getTerritory(), placeUnits, placeDelegate);
		}
	}
	*/

	// This is an alias for place_defenders_triplea in OAAA
	// Both methods place units from the purchase tracking structure
	place_defenders_triplea(gc)
}

// addUnitsToPlace - Add units to place territory
add_units_to_place_triplea :: proc(territory: Land_ID, unit_type: Unit_Type, count: u8) {
	/*
	Java Original (from ProPurchaseUtils.java lines 234-245):
	
	private static void addUnitsToPlace(
		final ProPlaceTerritory placeTerritory, final List<Unit> unitsToPlace) {
		for (final Unit unit : unitsToPlace) {
			if (Matches.unitIsInfrastructure().test(unit)) {
				placeTerritory.getPlaceUnits().add(0, unit);
			} else {
				placeTerritory.getPlaceUnits().add(unit);
			}
		}
	}
	*/

	if count == 0 do return

	// Find or create purchase entry for this territory
	found := false
	for &purchase in g_purchased_units {
		if purchase.territory == territory {
			// Add to existing entry
			#partial switch unit_type {
			case .Infantry:
				purchase.inf += count
			case .Artillery:
				purchase.arty += count
			case .Tank:
				purchase.tank += count
			case .AAGun:
				purchase.aa += count
			case .Fighter:
				purchase.fighter += count
			case .Bomber:
				purchase.bomber += count
			}
			found = true
			break
		}
	}

	if !found {
		// Create new entry
		new_purchase := Purchased_Units {
			territory = territory,
		}
		#partial switch unit_type {
		case .Infantry:
			new_purchase.inf = count
		case .Artillery:
			new_purchase.arty = count
		case .Tank:
			new_purchase.tank = count
		case .AAGun:
			new_purchase.aa = count
		case .Fighter:
			new_purchase.fighter = count
		case .Bomber:
			new_purchase.bomber = count
		}
		append(&g_purchased_units, new_purchase)
	}
}

// Helper for naval units
add_naval_units_to_place_triplea :: proc(territory: Land_ID, unit_type: Idle_Ship, count: u8) {
	if count == 0 do return

	// Find or create purchase entry for this territory
	found := false
	for &purchase in g_purchased_units {
		if purchase.territory == territory {
			// Add to existing entry
			#partial switch unit_type {
			case .SUB:
				purchase.sub += count
			case .DESTROYER:
				purchase.destroyer += count
			case .CRUISER:
				purchase.cruiser += count
			case .CARRIER:
				purchase.carrier += count
			case .BATTLESHIP:
				purchase.battleship += count
			case .TRANS_EMPTY:
				purchase.transport += count
			}
			found = true
			break
		}
	}

	if !found {
		// Create new entry
		new_purchase := Purchased_Units {
			territory = territory,
		}
		#partial switch unit_type {
		case .SUB:
			new_purchase.sub = count
		case .DESTROYER:
			new_purchase.destroyer = count
		case .CRUISER:
			new_purchase.cruiser = count
		case .CARRIER:
			new_purchase.carrier = count
		case .BATTLESHIP:
			new_purchase.battleship = count
		case .TRANS_EMPTY:
			new_purchase.transport = count
		}
		append(&g_purchased_units, new_purchase)
	}
}
