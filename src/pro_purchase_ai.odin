package oaaa
import "core:fmt"

// Map<Territory, ProPurchaseTerritory> purchase(
//       final IPurchaseDelegate purchaseDelegate, final GameState startOfTurnData) {
purchase_triplea_full :: proc(gc: ^Game_Cache) -> map[Land_ID]Pro_Purchase_Territory {
	//     // Current data fields
	//     data = proData.getData();
	//     this.startOfTurnData = startOfTurnData;
	//     player = proData.getPlayer();
	player := gc.cur_player
	//     resourceTracker = new ProResourceTracker(player);
	//     territoryManager = new ProTerritoryManager(calc, proData);
	//     isBid = false;
	//     final ProPurchaseOptionMap purchaseOptions = proData.getPurchaseOptions();
	// (purchase options are implicit in our unit costs and factory production)

	//     ProLogger.info("Starting purchase phase with resources: " + resourceTracker);
	when ODIN_DEBUG {
		fmt.printf("Starting purchase phase with resources: %d PUs\n", gc.money[player])
	}
	//     if (!player.getUnits().isEmpty()) {
	//       ProLogger.info("Starting purchase phase with unplaced units=" + player.getUnits());
	//     }
	// (we don't track unplaced units separately in OAAA)

	//     // Find all purchase/place territories
	//     final Map<Territory, ProPurchaseTerritory> purchaseTerritories =
	//         ProPurchaseUtils.findPurchaseTerritories(proData, player);
	purchase_territories := find_purchase_territories_triplea(gc, player)
	//     final Set<Territory> placeTerritories =
	//         new HashSet<>(
	//             CollectionUtils.getMatches(
	//                 data.getMap().getTerritoriesOwnedBy(player), Matches.territoryIsLand()));
	place_territories: Land_Bitset = {}
	for land in Land_ID {
		if gc.owner[land] == player {
			place_territories += {land}
		}
	}
	//     for (final ProPurchaseTerritory t : purchaseTerritories.values()) {
	//       for (final ProPlaceTerritory ppt : t.getCanPlaceTerritories()) {
	//         placeTerritories.add(ppt.getTerritory());
	//       }
	//     }
	for _, purchase_terr in purchase_territories {
		place_territories += purchase_terr.can_place_territories
	}

	//     // Determine max enemy attack units and current allied defenders
	//     territoryManager.populateEnemyAttackOptions(List.of(), placeTerritories);
	territories_to_check: Land_Bitset = place_territories
	
	// Use the new per-enemy + aggregated enemy attack options
	all_enemies := all_enemy_attack_options_init()
	enemy_attack_options := pro_other_move_options_init()
	generate_all_enemy_attack_options(gc, &all_enemies, &enemy_attack_options)
	//     findDefendersInPlaceTerritories(purchaseTerritories);
	defenders_map := find_defenders_in_place_territories_triplea(gc)

	//     // Prioritize land territories that need defended and purchase additional defenders
	//     final List<ProPlaceTerritory> needToDefendLandTerritories =
	//         prioritizeTerritoriesToDefend(purchaseTerritories, true);
	need_to_defend_land_territories := prioritize_territories_to_defend_triplea(
		gc,
		true,
		&all_enemies,
		&enemy_attack_options,
	)
	//     purchaseDefenders(
	//         purchaseTerritories,
	//         needToDefendLandTerritories,
	//         purchaseOptions.getLandFodderOptions(),
	//         purchaseOptions.getLandZeroMoveOptions(),
	//         purchaseOptions.getAirOptions(),
	//         true);
	// Calculate naval budget reserve once for this player's turn
	naval_budget := calculate_naval_budget_reserve(gc)
	purchase_defenders_triplea(gc, need_to_defend_land_territories, true, naval_budget)

	//     // Find strategic value for each territory
	//     ProLogger.info("Find strategic value for place territories");
	when ODIN_DEBUG {
		fmt.println("Find strategic value for place territories")
	}
	//     final Set<Territory> territoriesToCheck = new HashSet<>();
	//     for (final Territory t : purchaseTerritories.keySet()) {
	//       for (final ProPlaceTerritory ppt : purchaseTerritories.get(t).getCanPlaceTerritories()) {
	//         territoriesToCheck.add(ppt.getTerritory());
	//       }
	//     }
	// territories_to_check: Land_Bitset = {}
	for _, purchase_terr in purchase_territories {
		territories_to_check += purchase_terr.can_place_territories
	}
	//     final Map<Territory, Double> territoryValueMap =
	//         ProTerritoryValueUtils.findTerritoryValues(
	//             proData, player, List.of(), List.of(), territoriesToCheck);
	territory_value_map := find_territory_values_triplea(gc, player, {}, {}, territories_to_check)
	//     for (final Territory t : purchaseTerritories.keySet()) {
	//       for (final ProPlaceTerritory ppt : purchaseTerritories.get(t).getCanPlaceTerritories()) {
	//         ppt.setStrategicValue(territoryValueMap.get(ppt.getTerritory()));
	//         ProLogger.debug(
	//             ppt.getTerritory() + ", strategicValue=" + territoryValueMap.get(ppt.getTerritory()));
	//       }
	//     }
	// (strategic values calculated per-territory in territory_value_map)
	when ODIN_DEBUG {
		for land in territories_to_check {
			fmt.printf("%v, strategicValue=%f\n", land, territory_value_map[land])
		}
	}

	//     // Prioritize land place options purchase AA then land units
	//     final List<ProPlaceTerritory> prioritizedLandTerritories =
	//         prioritizeLandTerritories(purchaseTerritories);
	prioritized_land_territories := prioritize_land_territories_triplea(gc)
	//     purchaseAaUnits(
	//         purchaseTerritories, prioritizedLandTerritories, purchaseOptions.getAaOptions());
	// Pass naval budget to prevent AA from spending money reserved for transports
	purchase_aa_units_triplea(gc, prioritized_land_territories, naval_budget)
	
	// MODIFIED: Move sea purchase BEFORE land units to ensure ships can be bought
	// In Java, land units spending all money prevents any sea purchases.
	// By doing sea first after land defense, we can buy ships when under sea threat.
	//     // Prioritize sea place options and purchase units
	prioritized_sea_territories := prioritize_sea_territories_triplea(gc)
	should_save_up_for_a_fleet := purchase_sea_and_amphib_units_triplea(
		gc,
		prioritized_sea_territories,
		&all_enemies,
		&enemy_attack_options,
	)
	
	//     purchaseLandUnits(purchaseTerritories, prioritizedLandTerritories, purchaseOptions);
	purchase_land_units_triplea(gc, prioritized_land_territories)

	//     // Prioritize sea territories that need defended and purchase additional defenders
	//     final List<ProPlaceTerritory> needToDefendSeaTerritories =
	//         prioritizeTerritoriesToDefend(purchaseTerritories, false);
	need_to_defend_sea_territories := prioritize_territories_to_defend_triplea(
		gc,
		false,
		&all_enemies,
		&enemy_attack_options,
	)
	//     purchaseDefenders(
	//         purchaseTerritories,
	//         needToDefendSeaTerritories,
	//         purchaseOptions.getSeaDefenseOptions(),
	//         List.of(),
	//         purchaseOptions.getAirOptions(),
	//         false);
	purchase_defenders_triplea(gc, need_to_defend_sea_territories, false, 0)

	//     // Determine whether to purchase new land factory
	//     final Map<Territory, ProPurchaseTerritory> factoryPurchaseTerritories = new HashMap<>();
	factory_purchase_territories := make(map[Land_ID]Pro_Purchase_Territory)
	//     purchaseFactory(
	//         factoryPurchaseTerritories,
	//         purchaseTerritories,
	//         prioritizedLandTerritories,
	//         purchaseOptions,
	//         false);
	purchase_factory_triplea(gc, false)

	//     // Try to use any remaining PUs on high value units, except if we need to save up for a fleet.
	//     if (!shouldSaveUpForAFleet) {
	if !should_save_up_for_a_fleet {
		//       purchaseUnitsWithRemainingProduction(
		//           purchaseTerritories, purchaseOptions.getLandOptions(), purchaseOptions.getAirOptions());
		purchase_units_with_remaining_production_triplea(gc, prioritized_land_territories)

		//       upgradeUnitsWithRemainingPUs(purchaseTerritories, purchaseOptions);
		upgrade_units_with_remaining_pus_triplea(gc, prioritized_land_territories)

		//       // Try to purchase land/sea factory with extra PUs
		//       purchaseFactory(
		//           factoryPurchaseTerritories,
		//           purchaseTerritories,
		//           prioritizedLandTerritories,
		//           purchaseOptions,
		//           true);
		purchase_factory_triplea(gc, true)
	}
	//     }

	//     // Add factory purchase territory to list
	//     purchaseTerritories.putAll(factoryPurchaseTerritories);
	for factory_land, factory_purchase_terr in factory_purchase_territories {
		purchase_territories[factory_land] = factory_purchase_terr
	}

	//     // Determine final count of each production rule
	//     final IntegerMap<ProductionRule> purchaseMap =
	//         populateProductionRuleMap(purchaseTerritories, purchaseOptions);
	populate_production_rule_map_triplea(gc)

	//     // Purchase units
	//     final String error = purchaseDelegate.purchase(purchaseMap);
	//     if (error != null) {
	//       ProLogger.warn("Purchase error: " + error);
	//     }
	// (units are purchased immediately in our simplified system via g_purchased_units)

	//     territoryManager = null;
	//     return purchaseTerritories;
	return purchase_territories
	//   }
}

// find_defenders_in_place_territories_triplea is implemented in pro_purchase.odin

find_territory_values_triplea :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	territories_that_cant_be_held: Land_Bitset,
	territories_to_attack: Land_Bitset,
	territories_to_check: Land_Bitset,
) -> map[Land_ID]f64 {
	enemy_capitals_and_factories_map := find_enemy_capitals_and_factories_value(
		gc,
		player,
		territories_that_cant_be_held,
		territories_to_attack,
	)

	territory_value_map := make(map[Land_ID]f64)
	for land in territories_to_check {
		// Use production value as strategic value
		territory_value_map[land] = find_land_value(
			gc,
			land,
			player,
			enemy_capitals_and_factories_map,
			territories_that_cant_be_held,
			territories_to_attack,
		)
	}
	return territory_value_map
}

// Note: Pro_Other_Move_Options has been moved to pro_data.odin
