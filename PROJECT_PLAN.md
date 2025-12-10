# OAAA Pro AI Conversion Project Plan

## Project Overview

This document provides a comprehensive project plan for completing the conversion of TripleA's Pro AI (Java) to Odin for the OAAA project. The focus is on data-oriented design, performance optimization for MCTS rollouts, and avoiding OOP patterns.

**Target**: Convert TripleA's `games.strategy.triplea.ai.pro.*` package to Odin's data-oriented architecture.

**Key Principles**:
1. Data-Oriented Design - Arrays indexed by enums, bitsets, no object instances
2. Performance First - Designed for fast MCTS rollouts
3. No OOP Patterns - Avoid predicates, interfaces, inheritance
4. Count-Based Units - No individual unit instances, only `[location][player][type]u8` counts

---

## Known Regressions

| Commit | Date | Issue | Suspected Cause | Status |
|--------|------|-------|-----------------|--------|
| `3e00286` | 2025-12-10 | Germany loses capital to Russia before round 60 | Naval superiority purchase loop (PUR-060) may be over-spending on naval units, weakening land defense | ✅ FIXED |
| `04b71c2` | 2025-12-10 | (same session) | territory_has_local_naval_superiority() implementation (PUR-056 to PUR-059) | ✅ FIXED |
| (uncommitted) | 2025-12-10 | Russia loses to Germany by round 21 | CMB-041 to CMB-043 excess attackers redistribution - may be stripping too many units from attacks | ✅ FIXED |

**Last known good commit**: `1e25982` (NCM-066-069 AA gun movement) - AI stable 60+ rounds as of 2025-12-10

---

## Navigation

To jump to a region ID in the codebase:
- **Workspace Search**: `Ctrl+Shift+F` → type `#region PUR-013` → click result
- **File Symbol Navigation**: Open the file, then `Ctrl+Shift+O` → type the region ID

Region IDs in the table below (e.g., `PUR-013`) are unique searchable anchors embedded in `// #region` comments.

---

## Master Loop/Method Tracking Table

This table tracks every loop and sub-loop in the Java Pro AI code, mapped to Odin equivalents.

### Legend
| Status | Meaning |
|--------|---------|
| ✅ DONE | Fully implemented and working |
| 🔶 PARTIAL | Implemented but missing some functionality |
| ❌ MISSING | Not implemented |
| ⏭️ SKIP | Intentionally omitted (N/A for A&A 1942 SE) |
| 🔄 STUB | Placeholder exists, needs implementation |

### Equivalency Score Guide
| Score | Meaning |
|-------|---------|
| 100% | Semantically identical - all logic paths match Java |
| 75-99% | Minor differences - core algorithm matches, small edge cases differ |
| 50-74% | Partial match - main concept implemented but significant logic missing |
| 25-49% | Basic structure only - entry point exists but internals differ substantially |
| 0-24% | Minimal/none - stub or completely different approach |

---

### AbstractProAi.java - Turn Orchestration (541 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| ABST-001 | `purchase()` main entry | 148-260 | Main purchase phase entry point. Orchestrates factory repair, pre-purchase simulation, and unit purchasing. | [`proai_purchase_phase()`](src/pro_purchase.odin) | ✅ DONE | 85% | Missing pre-purchase simulation |
| ABST-002 | └─ `for (GameStep step : gameSteps)` simulation loop | 203-252 | Simulates combat moves, battles, and non-combat moves BEFORE purchasing to predict board state at placement time. Critical for informed purchase decisions. | N/A | ⏭️ SKIP | 0% | Pre-purchase simulation omitted |
| ABST-003 | `move()` main entry | 109-142 | Main movement phase entry point. Dispatches to combat or non-combat move based on phase. Handles maps with only combat move phase. | [`proai_combat_move_phase()`](src/pro_turn.odin) / [`proai_noncombat_move_phase()`](src/pro_noncombat_move.odin) | ✅ DONE | 90% | |
| ABST-004 | `place()` main entry | 284-295 | Main placement phase entry point. Places units purchased during purchase phase at factories. | [`proai_place_units_phase()`](src/pro_place.odin) | ✅ DONE | 95% | |
| ABST-005 | `tech()` | 297-300 | Technology research phase. Decides whether to spend IPCs on tech dice. | [`proai_tech_phase()`](src/pro_turn.odin) | ⏭️ SKIP | N/A | N/A for A&A 1942 SE |
| ABST-006 | `retreatQuery()` | 302-348 | Called during battles to decide whether to retreat. Considers strength difference, strafing status, and battle type (land vs sea). | [`should_retreat_land()`](src/pro_matches.odin), [`should_retreat_sea()`](src/pro_matches.odin) | ✅ DONE | 80% | RETREAT-001 to RETREAT-006 |
| ABST-007 | `selectCasualties()` | 371-410 | Called during battles to choose which units die first. Optimizes casualty selection based on unit value and situation. | [`should_optimize_casualties()`](src/pro_matches.odin), [`get_unit_cost()`](src/pro_matches.odin) | 🔶 PARTIAL | 60% | CASUALTY-001 to CASUALTY-004 helpers added; static ordering already cost-optimized |
| ABST-008 | `getGameStepsForPlayer()` loop | 270-280 | Iterates through game sequence to find all steps belonging to current player. Used for simulation planning. | N/A | ⏭️ SKIP | N/A | Part of simulation |

---

### ProPurchaseAi.java - Purchase Logic (2,645 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| PUR-001 | `repair()` | 68-130 | Repairs damaged factories using available PUs. Prioritizes factories by damage amount and strategic value. | [`repair_factories_triplea()`](src/pro_purchase.odin) | ✅ DONE | 80% | |
| PUR-002 | └─ `for (RepairRule : rules)` | 104-127 | Iterates through available repair rules to find matching repair options for each damaged factory. | Inline in repair | ✅ DONE | 75% | |
| PUR-003 | └─ └─ `for (Unit fixUnit : needingRepair)` | 105-126 | For each factory needing repair, calculates repair cost and applies repair if affordable. | Inline | ✅ DONE | 75% | |
| PUR-004 | `bid()` | 138-175 | Handles bid placement at game start. Places bid units in territories where player started with units. | N/A | ⏭️ SKIP | N/A | Bidding not used |
| PUR-005 | └─ `while (true)` bid loop | 170-270 | Iteratively places bid units one at a time, prioritizing threatened territories and strategic value. | N/A | ⏭️ SKIP | N/A | |
| PUR-006 | `purchase()` main entry | 277-380 | Main purchase logic coordinator. Calls defenders, land units, AA, factories, sea/amphib, and remaining production purchases in sequence. | [`purchase_triplea()`](src/pro_purchase.odin) | ✅ DONE | 90% | |
| PUR-007 | └─ `shouldSaveUpForAFleet()` | 381-443 | Checks if player is landlocked and needs to save PUs for a fleet. Returns true if enemy is only reachable by sea and we can't afford ships yet. | [`should_save_up_for_fleet_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | BFS sea search |
| PUR-008 | `place()` | 445-575 | Places all purchased units at factories. Land units placed first (reduces failed placements), then sea units. Handles remaining unplaced units. | [`place_defenders_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | |
| PUR-009 | └─ `for (ProPurchaseTerritory t)` land placement | 461-480 | Iterates through purchase territories to place land units at each factory location. | [`place_units_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | |
| PUR-010 | └─ └─ `for (ProPlaceTerritory ppt)` | 462-479 | For each place territory under a purchase territory, collects units to place. | Inline | ✅ DONE | 85% | |
| PUR-011 | └─ └─ └─ `for (Unit placeUnit)` match loop | 466-474 | Matches purchased unit types with actual unit instances in player's unit collection. | Inline | ✅ DONE | 80% | Count-based vs instance |
| PUR-012 | └─ `for (ProPurchaseTerritory t)` sea placement | 482-502 | Same as land placement loop but for sea zones adjacent to coastal factories. | [`place_units_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | |
| PUR-013 | └─ └─ (same nested structure) | 483-501 | Nested loops for sea unit placement matching. | `#region PUR-013` | ✅ DONE | 85% | |
| PUR-014 | `findDefendersInPlaceTerritories()` | 577-588 | Counts current allied defenders in each place territory. Used to calculate how many additional defenders needed. | Inline | ✅ DONE | 90% | |
| PUR-015 | └─ `for (ProPurchaseTerritory ppt)` | 578-587 | Iterates through purchase territories and their place territories to count defenders. | Inline | ✅ DONE | 90% | |
| PUR-016 | `prioritizeTerritoriesToDefend()` | 590-700 | Identifies territories that can't be held against max enemy attack. Calculates defense priority based on production, capital status, and strategic value. | [`prioritize_territories_to_defend_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | |
| PUR-017 | └─ `for (ProPurchaseTerritory ppt)` find needy | 601-660 | Checks each territory to see if current defenders can hold against max enemy attack using battle simulation. | Inline | ✅ DONE | 85% | |
| PUR-018 | └─ └─ `for (ProPlaceTerritory place)` | 604-658 | For each place territory, simulates battle and marks as needing defense if TUV swing is negative. | Inline | ✅ DONE | 85% | |
| PUR-019 | └─ Sort + filter loop | 662-698 | Sorts territories by defense priority (capital first, then production value, then TUV swing). Filters out territories that can't be held. | `slice.sort_by` | ✅ DONE | 90% | |
| PUR-020 | `purchaseDefenders()` | 700-900 | Main defensive purchasing loop. Buys units until each threatened territory can be held or no more money/production. | [`purchase_defenders_triplea()`](src/pro_purchase.odin) | ✅ DONE | 75% | Infantry only, missing randomization |
| PUR-021 | └─ `for (ProPlaceTerritory place)` | 712-898 | Iterates through prioritized territories that need defense. | `#region PUR-021` | ✅ DONE | 75% | |
| PUR-022 | └─ └─ `while (true)` purchase until can hold | 750-870 | Inner loop that keeps buying defenders until battle simulation shows territory can be held (TUV swing ≤ 0). | `#region PUR-015` | ✅ DONE | 80% | |
| PUR-023 | └─ └─ └─ `removeInvalidPurchaseOptions()` | 760 | Filters out purchase options that exceed budget, production capacity, or max unit limits. | Inline checks | ✅ DONE | 70% | Simplified |
| PUR-024 | └─ └─ └─ `for (ppo)` calc defenseEfficiencies | 765-790 | Calculates defense efficiency (defense power / cost) for each purchasable unit type. Considers destroyer need and carrier capacity. | Inline | ✅ DONE | 60% | Infantry only |
| PUR-025 | └─ └─ └─ `randomizePurchaseOption()` | 795 | Selects purchase option with some randomization weighted by efficiency. Prevents always buying same unit. | [`randomize_land_purchase()`](src/pro_purchase_utils.odin) | ✅ DONE | 90% | Weighted random selection |
| PUR-026 | └─ └─ └─ `calculateBattleResults()` | 830 | Simulates battle with current defenders + pending purchases vs max enemy attackers. Returns win%, TUV swing. | [`simulate_sequential_enemy_attacks()`](src/pro_purchase.odin) | ✅ DONE | 95% | Improved |
| PUR-027 | `prioritizeLandTerritories()` | 902-960 | Ranks land territories for offensive unit placement. Considers enemy neighbors, strategic value, and local land superiority. | [`prioritize_land_territories_triplea()`](src/pro_purchase.odin) | ✅ DONE | 70% | Simplified formula |
| PUR-028 | └─ `for (ProPurchaseTerritory ppt)` | 908-935 | Iterates through purchase territories to find those needing offensive units. | Inline | ✅ DONE | 70% | |
| PUR-029 | └─ └─ `for (ProPlaceTerritory place)` | 909-934 | Checks each place territory for enemy neighbors and strategic value thresholds. | Inline | ✅ DONE | 70% | |
| PUR-030 | └─ Sort by strategic value | 938-945 | Sorts territories by strategic value descending. Higher value territories get offensive units first. | `slice.sort_by` | ✅ DONE | 90% | |
| PUR-031 | `purchaseAaUnits()` | 962-1080 | Purchases AA guns for territories with factories that can be strategically bombed by enemy bombers. | [`purchase_aa_units_triplea()`](src/pro_purchase.odin) | ✅ DONE | 90% | |
| PUR-032 | └─ `for (ProPlaceTerritory place)` | 972-1078 | Iterates through territories checking if they have bombable factories and lack AA defense. | Outer loop | ✅ DONE | 85% | |
| PUR-033 | └─ └─ `while (true)` AA purchase | 1020-1070 | Continues buying AA until factory is adequately protected or budget exhausted. Java can buy multiple AA. | Inner while loop | ✅ DONE | 85% | Multiple AA purchase based on bomber threat |
| PUR-034 | └─ └─ └─ efficiency calculation | 1025-1040 | Calculates AA purchase efficiency based on expected bombing damage reduction vs AA cost. | count_enemy_bombers_in_range | ✅ DONE | 75% | Uses bomber count for AA ratio |
| PUR-035 | `purchaseLandUnits()` | 1082-1350 | Main offensive land unit purchasing. Buys attack units (tanks, artillery) balanced with fodder (infantry) based on distance to enemy. | [`purchase_land_units_triplea()`](src/pro_purchase.odin) | ✅ DONE | 80% | |
| PUR-036 | └─ `for (ProPlaceTerritory place)` | 1095-1348 | Iterates through prioritized land territories that should receive offensive units. | `#region PUR-029` | ✅ DONE | 80% | |
| PUR-037 | └─ └─ `while (true)` land purchase | 1150-1340 | Keeps buying land units until production capacity or budget exhausted. Balances attack power vs fodder. | `#region PUR-030` | ✅ DONE | 75% | |
| PUR-038 | └─ └─ └─ `for (ppo)` calc attackEfficiency | 1180-1220 | Calculates attack efficiency (attack power / cost) for each unit. Weights infantry vs attack units based on enemy distance. | Fodder % calc | ✅ DONE | 85% | Different algorithm |
| PUR-039 | └─ └─ └─ `randomizePurchaseOption()` | 1225 | Weighted random selection of unit type to purchase. | [`randomize_land_purchase()`](src/pro_purchase_utils.odin) | ✅ DONE | 90% | Weighted random selection |
| PUR-040 | `purchaseFactory()` | 1352-1517 | Decides where to build new factories. Considers production value, enemy distance, defensibility, and existing factories. | [`purchase_factory_triplea()`](src/pro_purchase.odin) | ✅ DONE | 70% | |
| PUR-041 | └─ `for (Territory t)` find factory locations | 1365-1440 | Scans all owned territories without factories to find potential factory locations. | Loop | ✅ DONE | 70% | |
| PUR-042 | └─ └─ Factory value calculation | 1380-1430 | Calculates factory value based on territory production, neighbor production, and distance from enemy. | Inline | ✅ DONE | 65% | |
| PUR-043 | └─ Sort by factory value | 1445 | Sorts potential factory locations by value descending. | `slice.sort_by` | ✅ DONE | 90% | |
| PUR-044 | └─ `for (Territory t)` place factories | 1450-1515 | Purchases factories at best locations until budget or need exhausted. | Loop | ✅ DONE | 70% | |
| PUR-045 | `prioritizeSeaTerritories()` | 1519-1620 | Ranks sea zones for naval purchases. Prioritizes zones with existing fleet, near enemy, and with transport capacity. | [`prioritize_sea_territories_triplea()`](src/pro_purchase.odin) | ✅ DONE | 65% | |
| PUR-046 | └─ `for (ProPurchaseTerritory ppt)` | 1530-1580 | Iterates through purchase territories with coastal factories. | Outer loop | ✅ DONE | 65% | |
| PUR-047 | └─ └─ `for (ProPlaceTerritory place)` | 1535-1575 | For each sea zone adjacent to factory, calculates naval strategic value. | Inner loop | ✅ DONE | 65% | |
| PUR-048 | └─ Sort by strategic value | 1585-1610 | Sorts sea zones by strategic value for naval purchases. | `slice.sort_by` | ✅ DONE | 90% | |
| PUR-049 | **`purchaseSeaAndAmphibUnits()`** | 1622-2091 | **CRITICAL**: Main naval and amphibious unit purchasing. Three phases: sea defense, naval superiority, and transport/amphib units. | [`purchase_sea_and_amphib_units_triplea()`](src/pro_purchase.odin) | ✅ DONE | 90% | All 3 phases implemented |
| PUR-050 | └─ `for (ProPlaceTerritory place)` outer | 1640-2089 | Iterates through prioritized sea territories for naval purchases. | `#region PUR-062` | 🔶 PARTIAL | 60% | |
| PUR-051 | └─ └─ **Phase 1: Sea Defense** `while(true)` | 1680-1755 | Buys naval defenders until sea zone can be held against enemy naval attack. Similar to land defense purchasing. | `#region PUR-063` | ✅ DONE | 75% | |
| PUR-052 | └─ └─ └─ `removeInvalidPurchaseOptions()` | 1690 | Filters invalid naval purchase options by budget and production. | Inline | ✅ DONE | 70% | |
| PUR-053 | └─ └─ └─ `for (ppo)` defenseEfficiencies | 1695-1720 | Calculates naval defense efficiency. Considers destroyer need for sub defense and carrier capacity for fighters. | Inline | ✅ DONE | 65% | |
| PUR-054 | └─ └─ └─ `randomizePurchaseOption()` | 1725 | Weighted selection of naval unit to purchase. | [`randomize_ship_purchase()`](src/pro_purchase_utils.odin) | ✅ DONE | 90% | Weighted random selection |
| PUR-055 | └─ └─ └─ `calculateBattleResults()` | 1740 | Simulates naval battle with current + pending ships vs enemy fleet. | Battle sim | ✅ DONE | 90% | |
| PUR-056 | └─ └─ **Phase 2: Naval Superiority** `while(true)` | 1760-1885 | Buys ships until achieving local naval superiority considering enemy air from adjacent land territories. | [`territory_has_local_naval_superiority()`](src/pro_utils.odin) | ✅ DONE | 90% | Threshold=50 |
| PUR-057 | └─ └─ └─ Collect enemyUnitsInLandTerritories | 1770-1790 | Gathers enemy air units from land territories within striking distance of sea zone. Critical for accurate threat assessment. | [`calculate_enemy_air_threat_from_land()`](src/pro_utils.odin) | ✅ DONE | 90% | BFS to max_dist |
| PUR-058 | └─ └─ └─ Collect enemyUnitsInSeaTerritories | 1792-1810 | Gathers enemy naval units from nearby sea zones that could attack. | [`calculate_enemy_naval_strength()`](src/pro_utils.odin) | ✅ DONE | 90% | BFS to max_dist |
| PUR-059 | └─ └─ └─ `estimateBattleResults()` | 1820 | Estimates battle outcome with allied fleet vs combined enemy naval + air threat. | [`territory_has_local_naval_superiority()`](src/pro_utils.odin) | ✅ DONE | 90% | Strength comparison |
| PUR-060 | └─ └─ └─ `for (ppo)` superiority efficiencies | 1840-1870 | Calculates ship purchase efficiency for achieving naval superiority. | [`purchase_sea_units_triplea()`](src/pro_purchase.odin) PUR-060 loop | ✅ DONE | 85% | Uses `territory_has_local_naval_superiority()` |
| PUR-061 | └─ └─ **Phase 3: Transport/Amphib** `while(true)` | 1891-2085 | Buys transports and amphib units to evacuate stranded units from low-value territories. | `#region PUR-065` | 🔶 PARTIAL | 70% | Recently improved |
| PUR-062 | └─ └─ └─ Find transportsThatNeedUnits | 1900-1940 | Identifies existing transports that have capacity for more units. Tracks which transports need loading. | `count_empty_transports_triplea`, `find_transports_needing_units_near_factory` | ✅ DONE | 85% | Range 2 search |
| PUR-063 | └─ └─ └─ `for (Territory sea)` transports loop | 1905-1930 | Scans sea zones within transport range to find available transports. | `get_transport_capacity_at_sea_inline` | ✅ DONE | 85% | |
| PUR-064 | └─ └─ └─ └─ `for (Unit transport)` | 1910-1928 | For each transport, calculates remaining capacity and adds to transportsThatNeedUnits if has space. | Inline | 🔶 PARTIAL | 55% | |
| PUR-065 | └─ └─ └─ Find potentialUnitsToLoad (value<=0.25) | 1945-1980 | **KEY INSIGHT**: Finds land units in territories with strategic value ≤ 0.25 (isolated islands like UK). These units should be transported out. | `count_stranded_units` | ✅ DONE | 80% | Recently fixed |
| PUR-066 | └─ └─ └─ `for (Territory neighbor)` low-value | 1950-1975 | Iterates through land neighbors of sea zones to find units stranded on islands needing evacuation. | Inline | ✅ DONE | 75% | |
| PUR-067 | └─ └─ └─ **Branch A**: Fill existing transport | 1990-2040 | If transports need units, fills them with available amphib units before buying new transports. | `#region PUR-066` | ✅ DONE | 75% | Recently fixed |
| PUR-068 | └─ └─ └─ └─ `selectUnitsToTransportFromList()` | 1995 | Selects best units to load onto transport from available units (prefers tanks > artillery > infantry). | Inline | 🔶 PARTIAL | 60% | Simplified |
| PUR-069 | └─ └─ └─ └─ `while (transportCapacity > 0)` | 2000-2035 | Keeps loading/purchasing amphib units until transport is full. | Fill loop | ✅ DONE | 80% | |
| PUR-070 | └─ └─ └─ └─ └─ Calc amphibEfficiencies | 2005-2020 | Calculates efficiency of purchasing amphib units (attack power for amphib assault / cost). | Inline | 🔶 PARTIAL | 60% | |
| PUR-071 | └─ └─ └─ **Branch B**: Buy new transport | 2045-2080 | If no transports need units but potentialUnitsToLoad exists, buys new transport. | Branch B | ✅ DONE | 75% | |
| PUR-072 | └─ └─ └─ └─ Calc transportEfficiencies | 2050-2070 | Calculates transport purchase efficiency based on units waiting to be transported. | `get_transport_remaining_capacity_inline` | 🔶 PARTIAL | 75% | Capacity helpers |
| PUR-073 | `purchaseUnitsWithRemainingProduction()` | 2093-2250 | Uses remaining factory production capacity to buy additional units. Called after main purchase phases. | [`purchase_units_with_remaining_production_triplea()`](src/pro_purchase.odin) | ✅ DONE | 85% | Bomber preference, air 10x mult |
| PUR-074 | └─ `for (ProPurchaseTerritory ppt)` | 2105-2248 | Iterates through territories with remaining production. | Outer loop | ✅ DONE | 85% | |
| PUR-075 | └─ └─ `for (ProPlaceTerritory place)` | 2110-2245 | For each place territory, checks remaining production capacity. | Inner loop | ✅ DONE | 85% | |
| PUR-076 | └─ └─ └─ `while (true)` fill production | 2150-2240 | Continues purchasing until production capacity filled or budget exhausted. | While loop | ✅ DONE | 85% | Randomized defense |
| PUR-077 | └─ └─ └─ └─ `for (ppo)` efficiencies | 2160-2200 | Calculates general unit efficiency for filling remaining capacity. | Inline | ✅ DONE | 85% | Attack*move efficiency |
| PUR-078 | `upgradeUnitsWithRemainingPUs()` | 2252-2450 | Uses remaining PUs to upgrade placed infantry to artillery or tanks if efficient. | [`upgrade_units_with_remaining_pus_triplea()`](src/pro_purchase.odin) | ✅ DONE | 75% | |
| PUR-079 | └─ `for (ProPurchaseTerritory ppt)` | 2265-2448 | Iterates through territories where units were placed. | Outer loop | ✅ DONE | 75% | |
| PUR-080 | └─ └─ `for (ProPlaceTerritory place)` | 2270-2445 | For each place territory with placed units. | Inner loop | ✅ DONE | 75% | |
| PUR-081 | └─ └─ └─ `while (true)` upgrade loop | 2310-2440 | Keeps upgrading units while profitable and funds available. | While loop | ✅ DONE | 70% | |
| PUR-082 | └─ └─ └─ └─ `for (unit)` find upgradeable | 2315-2350 | Finds infantry that could be upgraded to artillery or tanks. | Inline | ✅ DONE | 70% | |
| PUR-083 | └─ └─ └─ └─ `findUpgradeUnitEfficiency()` | 2360 | Calculates efficiency of upgrading (attack gain / additional cost). | [`find_upgrade_unit_efficiency_triplea()`](src/pro_purchase.odin) | ✅ DONE | 80% | |
| PUR-084 | `findUpgradeUnitEfficiency()` | 2452-2520 | Helper function calculating upgrade value. Considers attack power increase vs cost difference. | [`find_upgrade_unit_efficiency_triplea()`](src/pro_purchase.odin) | ✅ DONE | 80% | |
| PUR-085 | `findFactoryDefenseValue()` | 2522-2570 | Calculates how valuable a factory is to defend. Higher for capitals and high-production territories. | `find_factory_defense_value_triplea()` | ✅ DONE | 90% | Full capital+prod logic |
| PUR-086 | `selectPurchaseTerritoriesWithRemainingProduction()` | 2572-2645 | Finds territories that still have unused production capacity for additional purchases. | Inline | 🔶 PARTIAL | 55% | |

---

### ProCombatMoveAi.java - Combat Move Logic (2,031 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| CMB-001 | `doCombatMove()` main entry | 76-175 | Main combat move phase entry point. Orchestrates attack option generation, prioritization, territory selection, and move execution. | [`proai_combat_move_phase()`](src/pro_turn.odin) | ✅ DONE | 90% | |
| CMB-002 | `determineTerritoriesThatCanBeBombed()` | 1780-1875 | Identifies enemy factories that can be strategically bombed. Calculates expected bombing damage vs risk of losing bombers. | `plan_strategic_bombing_raids()` | ✅ DONE | 85% | |
| CMB-003 | └─ `for (Unit bomber)` | 1790-1870 | For each bomber, finds all reachable enemy factories within range. | `#region CMB-003` | ✅ DONE | 85% | |
| CMB-004 | └─ └─ `for (Territory target)` | 1800-1865 | Calculates bombing value for each target (damage potential vs AA defense risk). | `#region CMB-004` | ✅ DONE | 85% | |
| CMB-005 | `prioritizeAttackOptions()` | 192-299 | Calculates attack priority value for each potential target. Considers production, capital status, defensibility, and strategic position. | [`prioritize_attack_options_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 85% | |
| CMB-006 | └─ `for (Iterator<ProTerritory> it)` | 200-295 | Iterates through all attack options, calculating value and removing invalid ones. | Loop | ✅ DONE | 85% | |
| CMB-007 | └─ └─ Attack value calculation | 210-280 | Complex formula considering: isLand, isNeutral, isCanHold, isAmphib, hasFactory, nearCapital, production value. | Inline | ✅ DONE | 80% | |
| CMB-008 | `determineTerritoriesThatCanBeHeld()` | 301-430 | For each attackable territory, determines if it can be held after conquest against enemy counter-attack. | [`determine_territories_that_can_be_held_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 85% | |
| CMB-009 | └─ `for (ProTerritory patd)` | 315-425 | Iterates through attack options to simulate post-conquest defense. | Loop | ✅ DONE | 85% | |
| CMB-010 | └─ └─ Battle simulation | 340-400 | Simulates enemy counter-attack against our remaining forces. Sets canHold flag based on win%. | [`calculate_battle_results()`](src/battle.odin) | ✅ DONE | 95% | |
| CMB-011 | `removeTerritoriesThatArentWorthAttacking()` | 432-490 | Filters out attack options with negative expected value (TUV loss exceeds strategic gain). | [`remove_territories_that_arent_worth_attacking_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 85% | |
| CMB-012 | └─ Filter loop | 445-485 | Removes territories where expected TUV swing is too negative or win% is too low. | Loop | ✅ DONE | 85% | |
| CMB-013 | `determineTerritoriesToAttack()` | 492-620 | Greedily selects which territories to actually attack from available options, avoiding overcommitment. | [`determine_territories_to_attack_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 80% | |
| CMB-014 | └─ `while (true)` selection loop | 510-615 | Iteratively selects highest-value attack, marks units as used, recalculates remaining options. | While loop | ✅ DONE | 80% | |
| CMB-015 | └─ └─ Find highest priority | 520-540 | Sorts remaining options by attack value and selects best one. | Sort + select | ✅ DONE | 85% | |
| CMB-016 | └─ └─ TUV swing check | 550-570 | Stops selecting attacks when expected TUV swing becomes too negative (diminishing returns). | Check | ✅ DONE | 80% | |
| CMB-017 | `moveOneDefenderToLandTerritoriesBorderingEnemy()` | 622-720 | Ensures empty friendly territories bordering enemies have at least one defender to prevent free captures. | [`move_one_defender_to_land_territories_bordering_enemy_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 85% | |
| CMB-018 | └─ `for (Territory t)` border territories | 635-715 | Finds empty friendly territories adjacent to enemy and moves cheapest available unit there. | Loop | ✅ DONE | 85% | |
| CMB-019 | └─ └─ Find cheapest defender | 650-700 | Searches adjacent friendly territories for cheapest unit (infantry preferred) to move. | Inline | ✅ DONE | 80% | |
| CMB-020 | `removeTerritoriesWhereTransportsAreExposed()` | 722-820 | Removes attack options that would leave transports undefended and vulnerable to enemy counter-attack. | [`remove_territories_where_transports_are_exposed_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 75% | |
| CMB-021 | └─ `for (Territory t)` | 735-815 | Checks each attack to see if committed units would leave nearby transports exposed. | Loop | ✅ DONE | 75% | |
| CMB-022 | `determineUnitsToAttackWith()` | 822-896 | Assigns specific units to each selected attack. Balances unit usage across multiple attacks. | [`determine_units_to_attack_with_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 80% | |
| CMB-023 | └─ `for (ProTerritory patd)` | 835-892 | For each territory to attack, assigns units from potential attackers pool. | Outer loop | ✅ DONE | 80% | |
| CMB-024 | └─ └─ Sort by attack options | 845-860 | Sorts units by number of attack options (units with fewer options assigned first). | Sort | ✅ DONE | 75% | |
| CMB-025 | └─ └─ `for (Unit unit)` assignment | 865-890 | Assigns each unit to the attack, tracking used units to avoid double-assignment. | Inner loop | ✅ DONE | 80% | |
| CMB-026 | `tryToAttackTerritories()` | 1245-1778 | Main attack execution logic with 6 phases: trivial wins, fill attacks, destroyers, limit units, excess attackers, validation. | [`try_to_attack_territories_triplea()`](src/pro_combat_move_triplea_methods.odin) | 🔶 PARTIAL | 65% | 4 phases vs 6 |
| CMB-027 | └─ **Phase 1: Trivial wins** | 1257-1320 | First pass: assigns minimum units needed for guaranteed wins (≥99% probability). Handles easy captures efficiently. | Phase 1 | ✅ DONE | 85% | |
| CMB-028 | └─ └─ `for (ProTerritory patd)` sorted by value | 1265-1315 | Iterates through territories sorted by attack value, handling easiest wins first. | `#region CMB-028` | ✅ DONE | 85% | |
| CMB-029 | └─ └─ └─ Find necessary units | 1275-1295 | Calculates minimum units needed to achieve 99%+ win probability. | Inline | ✅ DONE | 80% | |
| CMB-030 | └─ └─ └─ Check win ≥99% | 1300-1310 | Verifies attack is essentially guaranteed before committing units. | Check | ✅ DONE | 85% | |
| CMB-031 | └─ **Phase 2: Fill non-trivial** | 1322-1400 | Second pass: adds units to attacks that need more forces to reach acceptable win%. | Phase 2 | ✅ DONE | 80% | |
| CMB-032 | └─ └─ `for (ProTerritory patd)` remaining | 1330-1395 | Iterates through attacks still needing units. | `#region CMB-032` | ✅ DONE | 80% | |
| CMB-033 | └─ └─ └─ `for (Unit unit)` sorted by options | 1340-1385 | Adds units one at a time, preferring units with fewer alternative attack options. | Inner loop | ✅ DONE | 75% | |
| CMB-034 | └─ └─ └─ └─ Add if improves win% | 1350-1380 | Only adds unit if it meaningfully improves win probability without wasting value. | Check | ✅ DONE | 80% | |
| CMB-035 | └─ **Phase 3: Add destroyers for subs** | 1402-1478 | Ensures attacks against submarines include at least one destroyer to enable sub hits. | Phase 3 | ✅ DONE | 85% | |
| CMB-036 | └─ └─ `for (ProTerritory patd)` missing destroyers | 1410-1470 | Finds sea attacks with subs but no destroyer assigned. | Loop | ✅ DONE | 85% | |
| CMB-037 | └─ └─ └─ `for (Unit destroyer)` multi-options | 1420-1465 | Assigns destroyers from available pool, preferring ones with multiple attack options. | Inner loop | ✅ DONE | 80% | |
| CMB-038 | └─ **Phase 4: Limit if can't hold** | 1480-1512 | For territories that can't be held post-conquest, reduces attacking force to minimize losses. | Phase 4 | ✅ DONE | 80% | |
| CMB-039 | └─ └─ `for (ProTerritory patd)` !canHold | 1485-1508 | Iterates through attacks where we'll lose the territory after. | Loop | ✅ DONE | 80% | |
| CMB-040 | └─ └─ └─ Check 1 less unit still wins | 1490-1505 | Removes units one at a time while still maintaining victory, saving TUV. | Check | ✅ DONE | 80% | |
| CMB-041 | └─ **Phase 5: Use excess attackers** | 1514-1560 | Redistributes excess units (>150% needed) from over-committed attacks to under-committed ones. | [`try_to_attack_territories_triplea()`](src/pro_combat_move_triplea_methods.odin#L2320-L2430) | ✅ DONE | 85% | Phase 5 excess attacker redistribution loop |
| CMB-042 | └─ └─ `for (ProTerritory patd)` strafing | 1520-1555 | Finds attacks with significant excess force that could be used elsewhere. | Phase 5 strafing loop | ✅ DONE | 85% | Removes excess from strafing attacks |
| CMB-043 | └─ └─ └─ `for (Unit unit)` excess (>150%) | 1530-1550 | Moves excess units to attacks that need reinforcement. | Phase 5 redistribution | ✅ DONE | 80% | Redistributes to under-committed attacks |
| CMB-044 | └─ **Phase 6: Validate & Log** | 1562-1778 | Final validation of all attacks. Checks transport restrictions, sub retreat rules, and logs summary. | 🔶 PARTIAL | 🔶 PARTIAL | 50% | |
| CMB-045 | └─ └─ Transport casualty restriction check | 1580-1610 | Verifies attacks don't violate transport casualty restriction rules (some maps require transports to be taken as casualties last). | ✅ DONE | check_transport_casualty_restriction() | 100% | |
| CMB-046 | └─ └─ Sub retreat before battle calc | 1620-1650 | Calculates whether enemy subs should retreat before battle based on destroyer presence. | ✅ DONE | should_enemy_subs_retreat() | 100% | |
| CMB-047 | └─ └─ Log attack summary | 1700-1770 | Outputs detailed log of all planned attacks for debugging. | [`log_attack_moves()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 90% | |
| CMB-048 | `checkContestedSeaTerritories()` | 1875-1945 | Handles contested sea zones where both sides have units. May need to clear with subs or avoid. | [`check_contested_sea_territories_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 90% | Moves ships to safe adjacent sea zones |
| CMB-049 | └─ `for (Territory t)` contested sea | 1885-1940 | Iterates through sea zones with both friendly and enemy units. | Loop | ✅ DONE | 90% | |
| CMB-050 | `doMove()` execute moves | 176-190 | Executes all planned combat moves by calling move delegate. Handles move failures gracefully. | [`execute_combat_moves_triplea()`](src/pro_combat_move_triplea_methods.odin) | ✅ DONE | 90% | |

---

### ProNonCombatMoveAi.java - Non-Combat Move Logic (2,541 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| NCM-001 | `doNonCombatMove()` main entry | 76-198 | Main non-combat move phase entry point. Orchestrates defensive positioning, air landing, transport loading, and infrastructure movement. | [`proai_noncombat_move_phase()`](src/pro_noncombat_move.odin) | 🔶 PARTIAL | 55% | |
| NCM-002 | `findUnitsThatCantMove()` | 200-255 | Identifies units that cannot move this turn: consumed units, allied defenders, zero-movement units, newly placed units. | State-based (idle_armies vs active_armies) | ⏭️ SKIP | N/A | Implicit via state tracking |
| NCM-003 | └─ `for (Unit unit)` consumed units | 210-250 | Iterates through units being consumed for production or other purposes. | N/A | ⏭️ SKIP | N/A | No consumed units in 1942 SE |
| NCM-004 | `findInfraUnitsThatCanMove()` | 257-275 | Identifies infrastructure units (AA guns, mobile factories) that can be moved during non-combat. | `AAGUN_1_MOVES` state check | ⏭️ SKIP | N/A | Only AA guns, handled by state |
| NCM-005 | └─ `for (Territory t)` | 262-272 | Scans territories for moveable infrastructure. | Inline in `move_aa_guns_noncombat()` | ⏭️ SKIP | N/A | |
| NCM-006 | `moveOneDefenderToLandTerritoriesBorderingEnemy()` | 277-360 | Same as combat move version - ensures border territories have at least one defender. | [`move_one_defender_to_border_territories()`](src/pro_noncombat_move.odin#L3875) | ✅ DONE | 85% | Full implementation with 1-move and 2-move tank search |
| NCM-007 | └─ `for (Territory t)` empty borders | 290-355 | Finds empty territories adjacent to enemy and assigns defenders. | Loop | ✅ DONE | 85% | Checks enemy adjacency and no existing defenders |
| NCM-008 | └─ └─ Find cheapest adjacent unit | 305-340 | Searches for cheapest unit to move as defender. | Inline | ✅ DONE | 85% | Cost-ordered search: Infantry < Artillery < Tank |
| NCM-009 | `determineIfMoveTerritoriesCanBeHeld()` | 362-440 | Calculates whether each territory can be held against enemy attack with current + potential defenders. | [`determine_if_territories_can_be_held()`](src/pro_noncombat_move.odin) | 🔶 PARTIAL | 60% | |
| NCM-010 | └─ `for (ProTerritory t)` | 375-435 | Iterates through territories running battle simulations. | Loop | 🔶 PARTIAL | 60% | |
| NCM-011 | └─ └─ Battle simulation | 390-420 | Simulates enemy attack to determine if territory is defensible. | Sim | 🔶 PARTIAL | 70% | |
| NCM-012 | `prioritizeDefendOptions()` | 442-510 | Ranks territories by defense priority based on production, capital proximity, and strategic value. | [`prioritize_defend_options()`](src/pro_noncombat_move.odin) | 🔶 PARTIAL | 55% | |
| NCM-013 | └─ `for (ProTerritory t)` calc priority | 455-505 | Calculates defense priority score for each territory. | Loop | 🔶 PARTIAL | 55% | |
| NCM-014 | **Capital Defense Loop** | 130-165 | **CRITICAL**: Outer loop that repeatedly adjusts defense until capital has local superiority. May increase defense range multiple times. | [`proai_noncombat_move_phase()`](src/pro_noncombat_move.odin#L435-480) | ✅ DONE | 90% | Implemented with territoryHasLocalLandSuperiority |
| NCM-015 | └─ `while (true)` | 130-165 | Keeps iterating until capital is adequately defended or no more options. | `for iteration` loop | ✅ DONE | 90% | Max 3 iterations, breaks when capital is safe |
| NCM-016 | └─ └─ `for (ProTerritory t)` adjust values | 140-150 | Adjusts territory values based on distance to capital to prioritize capital defense. | [`boost_territory_values_near_capital()`](src/pro_noncombat_move.odin#L492-526) | ✅ DONE | 95% | BFS boost by 10x matching Java |
| NCM-017 | └─ └─ `moveUnitsToBestTerritories()` | 152 | Moves units to defensive positions. | `move_land_units_noncombat()` | 🔶 PARTIAL | 45% | |
| NCM-018 | └─ └─ Check capital local superiority | 155-160 | Checks if capital now has enough defenders. If not, increases defense range and repeats. | [`territory_has_local_land_superiority()`](src/pro_utils.odin#L271-365) | ✅ DONE | 95% | Uses BFS to check allied vs enemy strength |
| NCM-019 | └─ └─ Reset + increase defenseRange | 162-164 | Increases search range for defenders and resets move data for another pass. | `defense_range = enemy_distance - 1` | ✅ DONE | 85% | Increases defense_range and continues loop |
| NCM-020 | `moveUnitsToDefendTerritories()` | 630-960 | Assigns units to defend threatened territories. Uses greedy assignment with battle simulation validation. | [`move_units_to_defense()`](src/pro_noncombat_move.odin) | 🔶 PARTIAL | 75% | Full unit type loop |
| NCM-021 | └─ `while` decreasing territories loop | 650-955 | Outer loop that reduces number of defended territories if not enough units to defend all. | Outer while | 🔶 PARTIAL | 45% | |
| NCM-022 | └─ └─ `for (ProTerritory t)` to defend | 665-850 | Iterates through territories needing defense. | Loop | 🔶 PARTIAL | 75% | |
| NCM-023 | └─ └─ └─ `for (Unit unit)` with move options | 680-830 | For each unit that can reach, considers adding to defense. | Inner loop | 🔶 PARTIAL | 75% | Infantry->Arty->Tank order |
| NCM-024 | └─ └─ └─ └─ Add if improves defense | 700-810 | Adds unit if battle simulation shows improved defense without wasting TUV. | Check | 🔶 PARTIAL | 55% | |
| NCM-025 | └─ └─ **Amphib defense options** | 860-950 | Considers using transports to bring defenders via amphibious movement. | [`move_amphib_defenders_to_territory()`](src/pro_noncombat_move.odin) | ✅ DONE | 75% | Unloads loaded transports for defense |
| NCM-026 | └─ └─ └─ `for (transport)` in transportMapList | 870-940 | Iterates through available transports for amphibious reinforcement. | Loop in `move_amphib_defenders_to_territory()` | ✅ DONE | 75% | Iterates Idle_Transports |
| NCM-027 | └─ └─ └─ └─ Find units to load | 880-910 | Identifies units that could be loaded onto transport for defensive movement. | `get_transport_defense_value()` | ✅ DONE | 70% | Uses already-loaded transports |
| NCM-028 | └─ └─ └─ └─ Find safest unload zone | 915-935 | Finds safest sea zone to unload defenders at destination. | `is_sea_zone_safe_for_unload()` | ✅ DONE | 75% | Checks for enemy combat ships |
| NCM-029 | `moveUnitsToBestTerritories()` | 962-1840 | Large method with 12 blocks moving different unit types to optimal positions. Handles transports, sea units, land units, and air. | [`move_units_to_best_territories()`](src/pro_noncombat_move.odin) | 🔶 PARTIAL | 45% | ~45% |
| NCM-030 | └─ **Block 1: Transport amphib to land** | 985-1100 | Moves loaded transports to unload at high-value land territories. Key for offensive positioning. | [`stage_and_unload_transports_noncombat()`](src/pro_noncombat_move.odin) | ✅ DONE | 80% | Implemented with value-based destination selection |
| NCM-031 | └─ └─ `for (proTransportData)` transportMapList | 995-1095 | Iterates through transport movement data structures. | [`stage_and_unload_one_transport()`](src/pro_noncombat_move.odin) | ✅ DONE | 75% | Priority-based iteration through loaded transports |
| NCM-032 | └─ └─ └─ `for (transport)` in transportMap | 1000-1090 | For each transport, finds best destination. | Loop in `stage_and_unload_one_transport()` | ✅ DONE | 80% | |
| NCM-033 | └─ └─ └─ └─ Find best land by value | 1010-1040 | Evaluates reachable land territories by strategic value for unloading. | `find_territory_values_triplea()` + land value calc | ✅ DONE | 85% | Uses territory values from ProTerritoryValueUtils |
| NCM-034 | └─ └─ └─ └─ `for` find units to load | 1045-1065 | If transport not full, finds additional units to load from adjacent land. | ❌ SKIPPED | 🔶 PARTIAL | 0% | Not needed - transports already loaded during load phase |
| NCM-035 | └─ └─ └─ └─ `for` find safest unload sea | 1070-1085 | Selects safest sea zone for the unload operation. | Adjacent sea selection in `stage_and_unload_one_transport()` | ✅ DONE | 70% | Simplified - uses first valid adjacent sea |
| NCM-036 | └─ **Block 2: Transport amphib to sea** | 1100-1180 | Moves transports to strategic sea positions even if not unloading. For future turn positioning. | ❌ SKIPPED | 🔶 PARTIAL | 50% |  |
| NCM-037 | └─ └─ Similar structure | 1105-1175 | Same pattern as Block 1 but for sea-only destinations. | ❌ SKIPPED | 🔶 PARTIAL | 0% | |
| NCM-038 | └─ **Block 3: Empty transports to loading** | 1185-1280 | Moves empty transports towards territories with units waiting to be loaded (near factories). | [`move_empty_transports_to_loading()`](src/pro_noncombat_move.odin) | ✅ DONE | 85% | Uses Java loadValue formula |
| NCM-039 | └─ └─ `for (transport)` empty | 1195-1275 | Iterates through empty transports. | `for trans_type in Empty_Trans_Types` | ✅ DONE | 85% | Processes UNMOVED and 2_MOVES |
| NCM-040 | └─ └─ └─ Calc load territory priorities | 1205-1240 | Calculates which territories have units that should be transported. | [`calculate_load_value()`](src/pro_noncombat_move.odin) | ✅ DONE | 90% | territoryValue + 0.5*turns - 0.1*units - 0.1*production |
| NCM-041 | └─ └─ └─ Move to factory-adjacent sea | 1250-1270 | Moves transport to sea zone adjacent to factory for next-turn loading. | `move_one_empty_transport_to_loading()` | ✅ DONE | 80% | Includes safe path checking |
| NCM-042 | └─ **Block 4: Remaining transports to safety** | 1285-1400 | Moves transports that couldn't find good destinations to safest available sea zone. | [`skip_transport_to_0_moves()`](src/pro_noncombat_move.odin) | ✅ DONE | 65% | Transports without destinations skip to 0 moves |
| NCM-043 | └─ └─ `for (transport)` remaining | 1295-1395 | Iterates through transports not yet moved. | Fallback in `stage_and_unload_one_transport()` | ✅ DONE | 60% | |
| NCM-044 | └─ └─ └─ Find safest sea zone | 1305-1350 | Evaluates sea zones by enemy threat to find safest destination. | [`find_safest_sea_zone()`](src/pro_noncombat_move.odin) | ✅ DONE | 85% | Evaluates threat vs defense for sea zones |
| NCM-045 | └─ └─ └─ Try unload if carrying | 1355-1390 | If transport is carrying units, tries to unload at safe location rather than risk losing cargo. | [`unload_transport_cargo_to_land()`](src/pro_noncombat_move.odin) | ✅ DONE | 85% | Always unloads cargo to best destination |
| NCM-046 | └─ **Block 5: Sea units defend transports** | 1500-1560 | Moves warships to protect vulnerable transports from enemy attack. | [`move_sea_units_noncombat()`](src/pro_noncombat_move.odin) `#region NCM-046` | ✅ DONE | 85% | Moves destroyers/cruisers/battleships/carriers to escort |
| NCM-047 | └─ └─ `for (Unit sea)` | 1510-1555 | Iterates through available warships. | `Combat_Ships` loop | ✅ DONE | 85% | |
| NCM-048 | └─ └─ └─ Check transport needs escort | 1520-1545 | Identifies transports that lack adequate protection. | [`check_transport_defense()`](src/pro_noncombat_move.odin) | ✅ DONE | 80% | Simplified threat assessment |
| NCM-049 | └─ **Block 6: Air units defend transports** | 1560-1600 | Moves fighters to carriers to provide air cover for transport fleets. | `#region NCM-049` | ✅ DONE | 80% | Land and sea fighters to carriers |
| NCM-050 | └─ └─ `for (fighter)` | 1570-1595 | Iterates through fighters that could land on carriers. | Fighter loops | ✅ DONE | 80% | |
| NCM-051 | └─ **Block 7: Sea units to best location** | 1600-1730 | Moves remaining warships to strategically valuable sea zones. | [`move_sea_units_noncombat()`](src/pro_noncombat_move.odin) | ✅ DONE | 80% | Combat ship and fighter move |
| NCM-052 | └─ └─ `for (Unit sea)` remaining | 1610-1725 | Iterates through warships not assigned to escort duty. | Loop | ✅ DONE | 80% | |
| NCM-053 | └─ └─ └─ Calc sea value + transport presence | 1620-1700 | Calculates sea zone value considering strategic importance and transport presence. | `get_sea_zone_value()` | ✅ DONE | 80% | Transport count bonus |
| NCM-054 | └─ **Block 8: Land units to high value** | 1842-1904 | Moves land units towards high strategic value territories (production centers, enemy borders). | [`move_land_units_noncombat()`](src/pro_noncombat_move.odin) | ✅ DONE | 85% | |
| NCM-055 | └─ └─ `for (Unit land)` | 1850-1900 | Iterates through land units to find optimal destinations. | `#region NCM-055` | ✅ DONE | 85% | |
| NCM-056 | └─ **Block 9: Land to coastal factories** | 1910-1944 | Moves land units to coastal factories for potential transport loading next turn. | Inline | ✅ DONE | 80% | |
| NCM-057 | └─ └─ `for (Unit land)` | 1918-1940 | Moves units towards coasts for amphib operations. | `#region NCM-057` | ✅ DONE | 80% | |
| NCM-058 | └─ **Block 10: Land to safest** | 1950-1989 | Moves remaining land units to safest available territory (away from enemy threat). | Inline | ✅ DONE | 80% | |
| NCM-059 | └─ └─ `for (Unit land)` | 1958-1985 | Final pass for land units without good offensive destination. | `#region NCM-059` | ✅ DONE | 80% | |
| NCM-060 | └─ **Block 11: Air to safe with attack options** | 2000-2110 | Lands air units at territories that are safe AND provide good attack options for next turn. | [`land_fighters_noncombat()`](src/pro_noncombat_move.odin) | ✅ DONE | 85% | |
| NCM-061 | └─ └─ `for (Unit air)` | 2010-2105 | Iterates through air units needing landing locations. | `#region NCM-061` | ✅ DONE | 85% | |
| NCM-062 | └─ **Block 12: Air to safest** | 2115-2160 | Lands remaining air units at safest available territory (carriers or defended land). | Inline | ✅ DONE | 80% | |
| NCM-063 | └─ └─ `for (Unit air)` | 2125-2155 | Final pass ensuring all air units have legal landing spots. | `#region NCM-063` | ✅ DONE | 80% | |
| NCM-064 | `moveCarrierFighters()` | 2165-2175 | Special handling for fighters on carriers - ensures carrier moves with its fighters. | ❌ REVERTED | 🔶 PARTIAL | 10% | Bug in active state tracking |
| NCM-065 | └─ `for (fighter)` on carriers | 2168-2173 | Coordinates carrier and fighter movement. | ❌ REVERTED | 🔶 PARTIAL | 10% | Needs proper state handling |
| NCM-066 | `moveInfraUnits()` | 2177-2475 | Moves infrastructure units (AA guns, mobile factories) to optimal locations. | `move_aa_guns_noncombat()` | ✅ DONE | 85% | Infrastructure |
| NCM-067 | └─ `moveInfrastructure()` AA guns | 2185-2300 | Moves AA guns to protect valuable factories from strategic bombing. | `#region NCM-067` | ✅ DONE | 85% | |
| NCM-068 | └─ └─ `for (Unit aa)` | 2195-2295 | Iterates through AA guns to find best destinations. | `#region NCM-068` | ✅ DONE | 85% | |
| NCM-069 | └─ └─ └─ Find best factory to protect | 2210-2280 | Evaluates factories by bombing vulnerability and current AA coverage. | `#region NCM-069` | ✅ DONE | 85% | |
| NCM-070 | └─ `moveFactoriesIfMobile()` | 2305-2400 | For maps with mobile factories, moves them to optimal production locations. | ⏭️ SKIP | N/A for 1942 SE | N/A | Mobile factories N/A |
| NCM-071 | └─ └─ `for (Unit factory)` mobile | 2315-2395 | Iterates through mobile factories. | ⏭️ SKIP | N/A for 1942 SE | N/A | |
| NCM-072 | └─ `checkNeedToConsumeUnits()` | 2405-2440 | Checks if any units need to be consumed for production (some map mechanics). | ⏭️ SKIP | N/A for 1942 SE | N/A | N/A for 1942 SE |
| NCM-073 | └─ `findBestPathToTerritoryUsingLandRoutes()` BFS | 2445-2475 | Multi-turn pathfinding using BFS to find optimal route to distant territories. | ✅ DONE | find_best_path_to_territory() | 100% | |
| NCM-074 | └─ └─ BFS loop with distance tracking | 2450-2470 | Breadth-first search through land connections with movement cost tracking. | ✅ DONE | Uses visited/distances arrays | 100% | |
| NCM-075 | `doMove()` execute moves | 195-198 | Executes all planned non-combat moves via move delegate. | [`execute_noncombat_moves()`](src/pro_noncombat_move.odin) | ✅ DONE | 90% | |

---

### ProTerritoryManager.java - Territory Analysis (1,277 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| TM-001 | `populateAttackOptions()` | 50-85 | Entry point that calls findAttackOptions() to populate the attack map with all possible attack destinations and available attackers. | [`populate_attack_options()`](src/pro_territory_manager.odin) | ✅ DONE | 85% | |
| TM-002 | └─ `findAttackOptions()` | 600-900 | Core method that iterates through all friendly units and identifies which enemy territories each can reach and attack. | Called | ✅ DONE | 85% | |
| TM-003 | └─ └─ `for (Unit land)` with movement | 620-700 | For each land unit, finds all enemy territories within movement range and adds unit as potential attacker. | Loop | ✅ DONE | 90% | |
| TM-004 | └─ └─ `for (Unit air)` | 710-780 | For each air unit, finds all enemy territories within flight range (considering return path) and adds as attacker. | Loop | ✅ DONE | 85% | |
| TM-005 | └─ └─ `for (Unit transport)` amphib | 790-860 | For each loaded transport, finds coastal territories it can reach and adds cargo as potential amphibious attackers. | Loop | 🔶 PARTIAL | 70% | |
| TM-006 | └─ └─ `for (Unit naval)` | 870-900 | For each warship, identifies enemy sea zones it can attack plus bombardment opportunities for coastal territories. | Loop | 🔶 PARTIAL | 65% | |
| TM-007 | `populateDefendOptions()` | 86-120 | Entry point for defense analysis. Identifies which friendly units can reach each threatened territory as defenders. | [`populate_defend_options()`](src/pro_territory_manager.odin) | ✅ DONE | 80% | |
| TM-008 | └─ `findDefendOptions()` | 400-580 | Core defense method - finds all units that could potentially move to defend each territory. | Called | 🔶 PARTIAL | 65% | |
| TM-009 | └─ └─ `for (Unit land)` friendly | 420-480 | For each land unit, calculates which friendly territories it can reach to provide defense. | Loop | ✅ DONE | 80% | |
| TM-010 | └─ └─ `for (Unit air)` | 490-540 | For each fighter/bomber, identifies territories within range that could use air defense. | Loop | ✅ DONE | 80% | |
| TM-011 | └─ └─ `for (transport)` reinforcement | 550-575 | Identifies transports that could bring amphibious reinforcements to threatened coastal territories. | [`find_transport_defend_destinations()`](src/pro_territory_manager.odin) | ✅ DONE | 85% | BFS to 2 moves |
| TM-012 | `populateEnemyAttackOptions()` | 125-131 | Entry for enemy threat analysis. Generates attack options for each enemy player separately for accurate threat assessment. | [`generate_all_enemy_attack_options()`](src/pro_enemy_attacks.odin) | ✅ DONE | 90% | |
| TM-013 | └─ `findEnemyAttackOptions()` | 300-400 | Per-enemy version of findAttackOptions. Tracks what each enemy can attack independently. | [`generate_single_enemy_attack_options()`](src/pro_enemy_attacks.odin) | ✅ DONE | 90% | |
| TM-014 | └─ └─ `for (enemy player)` | 310-395 | Iterates through each enemy player to generate separate attack option sets. | `#region TM-014` | ✅ DONE | 90% | |
| TM-015 | └─ └─ └─ `for (Unit land)` | 320-350 | For each enemy land unit, calculates territories it threatens. | Loop | ✅ DONE | 90% | |
| TM-016 | └─ └─ └─ `for (Unit air)` | 355-380 | For each enemy air unit, calculates territories within strike range. | Loop | ✅ DONE | 90% | |
| TM-017 | └─ └─ └─ `for (Unit naval)` | 385-395 | For each enemy ship, identifies sea zones and bombardment targets it threatens. | Loop | ✅ DONE | 85% | |
| TM-018 | `populateEnemyDefenseOptions()` | 132-135 | Analyzes enemy defensive capabilities including scramble-capable airbases and reserve forces. | 🔶 PARTIAL | find_enemy_defend_options() | 50% | Scramble N/A for 1942 SE |
| TM-019 | └─ `findScrambleOptions()` | 500-580 | Identifies airbases that can scramble fighters to defend adjacent sea zones (map-specific rule). | ⏭️ SKIP | N/A for 1942 SE | N/A | Scramble N/A |
| TM-020 | └─ └─ `for (airbase)` | 510-575 | Checks each airbase for scramble capability and available fighters. | ⏭️ SKIP | N/A for 1942 SE | N/A | |
| TM-021 | └─ `findEnemyDefendOptions()` | 580-600 | Finds enemy units that could reinforce threatened territories on enemy's turn. | ✅ DONE | find_enemy_defend_options() | 100% | |
| TM-022 | `removeTerritoriesThatCantBeConquered()` | 140-300 | Filters attack options by running battle simulations and removing attacks that can't win. | 🔶 PARTIAL | 🔶 PARTIAL | 60% | |
| TM-023 | └─ `for (Territory t)` in attackMap | 155-295 | Iterates through each attack option and runs simulation to check win probability. | Loop | 🔶 PARTIAL | 60% | |
| TM-024 | └─ └─ Battle simulation | 170-200 | Runs Monte Carlo battle sim to determine attack success probability. | Sim | ✅ DONE | 95% | |
| TM-025 | └─ └─ Strafing check for allies | 210-280 | For allies, checks if strafing attack (attack and retreat) is worthwhile when conquest isn't possible. | ✅ DONE | check_strafing_attack_worthwhile() | 100% | |

---

### ProTransportUtils.java - Transport Utilities (521 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| TRN-001 | `getUnusedCarrierCapacity()` | 45-80 | Returns total available fighter slots across all carriers in a sea zone (2 per carrier minus loaded fighters). | `get_unused_carrier_capacity()` | ✅ DONE | 85% | |
| TRN-002 | └─ `for (Unit carrier)` | 55-75 | Iterates through carriers counting capacity and subtracting already-landed fighters. | `#region TRN-002` | ✅ DONE | 85% | |
| TRN-003 | `getUnusedLocalCarrierCapacity()` | 82-120 | Similar to above but only counts carriers that haven't moved yet (can still pick up fighters). | `get_unused_local_carrier_capacity()` | ✅ DONE | 85% | Checks 2-away |
| TRN-004 | └─ `for (Unit carrier)` local | 92-115 | Checks carrier movement status before counting capacity. | `#region TRN-004` | ✅ DONE | 85% | |
| TRN-005 | `getUnitsToTransportThatCantMoveToHigherValue()` | 122-200 | **KEY**: Finds units stranded on low-value territories (islands) that need transport evacuation. | `count_stranded_units` | 🔶 PARTIAL | 70% | Recently improved |
| TRN-006 | └─ `for (Territory neighbor)` | 135-195 | Checks if any adjacent land has higher strategic value - if not, units are "stranded". | Inline | 🔶 PARTIAL | 65% | Low-value check |
| TRN-007 | └─ └─ `for (Unit unit)` | 145-190 | Identifies specific units that should be transported out due to lack of land route to battle. | Inline | 🔶 PARTIAL | 60% | |
| TRN-008 | `getUnitsToTransportFromTerritories()` | 202-280 | Gets list of units to load from a set of territories, prioritizing attack units over infantry. | [`find_loadable_units_near_sea()`](src/pro_transport.odin) | ✅ DONE | 80% | |
| TRN-009 | └─ `for (Territory t)` | 215-275 | Iterates through source territories for loading. | `for land in adjacent_lands` | ✅ DONE | 80% | |
| TRN-010 | └─ └─ `for (Unit unit)` | 225-270 | Filters units suitable for transport loading (land units with sufficient movement). | `Unit_Load_Info` struct | ✅ DONE | 80% | Checks infantry/artillery/tanks |
| TRN-011 | `selectUnitsToTransportFromList()` | 282-340 | Given excess units, selects optimal subset to fill transport capacity (tanks first, then artillery, then infantry). | Inline loading | 🔶 PARTIAL | 55% | Simplified |
| TRN-012 | └─ `while (capacity > 0)` | 295-335 | Greedy loop filling transport capacity with highest-value units first. | Loop | 🔶 PARTIAL | 55% | |
| TRN-013 | └─ └─ `for (Unit unit)` best to load | 300-330 | Selects best available unit type to fill remaining capacity. | Inline | 🔶 PARTIAL | 50% | |
| TRN-014 | `interleaveUnitsCarriersAndPlanes()` | 342-455 | Complex movement ordering for carrier+fighter fleets. Ensures fighters don't move before their carrier, and carriers don't strand fighters. | N/A | ⏭️ SKIP | N/A | Java-specific for unit list ordering; Odin uses state-based tracking |
| TRN-015 | └─ `while (carriers.hasNext())` | 360-450 | Pairs carriers with fighters for coordinated movement. | N/A | ⏭️ SKIP | N/A | Not needed with state machine |
| TRN-016 | └─ └─ `for (fighter)` per carrier | 375-440 | Assigns fighters to specific carriers and orders movement appropriately. | N/A | ⏭️ SKIP | N/A | Fighter landing handled separately |
| TRN-017 | `validateCarrierCapacity()` | 457-490 | Validation check ensuring no carrier is overloaded (max 2 fighters per carrier). | `validate_carrier_capacity()` | ✅ DONE | 90% | |
| TRN-018 | └─ `for (Unit carrier)` | 465-485 | Checks each carrier's fighter count doesn't exceed capacity. | Inline | ✅ DONE | 90% | |
| TRN-019 | `getTransportsThatCanTransport()` | 492-521 | Filters transports to only those with available capacity and movement remaining. | `get_transports_with_capacity()` | ✅ DONE | 90% | Full filtering added |
| TRN-020 | └─ `for (Unit transport)` | 500-518 | Checks each transport for capacity and movement status. | `get_transports_at_sea_with_capacity()` | ✅ DONE | 90% | Transport_Info struct |
| TRN-021 | `getAirThatCantLandOnCarrier()` | 280-300 | Returns count of excess fighters that have no carrier space. | `get_air_that_cant_land_on_carrier()` | ✅ DONE | 90% | New helper |
| TRN-022 | `canFightersFindCarrierSpace()` | N/A | Checks if fighters can find carrier space including nearby sea zones. | `can_fighters_find_carrier_space()` | ✅ DONE | 85% | Uses local capacity |
| TRN-023 | `getTransportCost()` | 164-170 | Returns transport capacity cost for a single unit type (infantry=2, artillery/tank=3). | `get_unit_transport_cost()` | ✅ DONE | 95% | Simple lookup |
| TRN-024 | `findUnitsTransportCost()` | 177-182 | Sums transport capacity needed for all units in a territory. | `find_units_transport_cost()` | ✅ DONE | 90% | For evacuation planning |
| TRN-025 | `getTransportCapacity()` | N/A | Calculates remaining transport capacity at a sea zone. | `get_available_transport_capacity_at_sea()` | ✅ DONE | 90% | New helper for amphib planning |
| TRN-026 | Transport state helpers | N/A | Helper functions for transport state classification. | `is_transport_full()`, `is_transport_empty()`, `can_transport_load_infantry/heavy()` | ✅ DONE | 95% | Boolean predicates |

---

### ProTerritoryValueUtils.java - Territory Valuation (721 lines)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| VAL-001 | `findTerritoryValues()` | 40-180 | Main entry for strategic territory valuation. Combines production, position, and accessibility into single value score. | [`get_pro_value()`](src/pro_land_value.odin) | 🔶 PARTIAL | 55% | |
| VAL-002 | └─ `for (Territory t)` | 55-175 | Iterates all territories calculating composite strategic value. | Loop | 🔶 PARTIAL | 55% | |
| VAL-003 | └─ └─ Production value calc | 65-90 | Base value from IPC production (factories worth more in contested areas). | Inline | ✅ DONE | 85% | |
| VAL-004 | └─ └─ Neighbor bonus calc | 95-120 | Adds bonus based on adjacent territory values (positions near good territories are worth more). | Inline | ✅ DONE | 80% | |
| VAL-005 | └─ └─ Enemy factory/capital distance | 125-150 | Territories closer to enemy capitals/factories worth more for offensive staging. | [`find_enemy_capitals_and_factories_value()`](src/pro_land_value.odin) | ✅ DONE | 85% | Distance-based decay |
| VAL-006 | └─ └─ Sea zone accessibility | 155-170 | Coastal territories worth more for transport loading/unloading potential. | `l2s_1away` check in `find_land_value()` | ✅ DONE | 80% | 15% coastal bonus |
| VAL-007 | `findSeaValue()` | 182-280 | Calculates strategic value of sea zones for naval positioning decisions. | [`get_sea_zone_value()`](src/pro_noncombat_move.odin) | ✅ DONE | 80% | |
| VAL-008 | └─ `for (Sea zone)` | 195-275 | Iterates all sea zones calculating naval strategic value. | Loop in caller | ✅ DONE | 80% | |
| VAL-009 | └─ └─ Adjacent land value sum | 205-230 | Sea zones adjacent to valuable land are worth controlling. | `for adj_land in adjacent_lands` | ✅ DONE | 85% | Factory + enemy bonus |
| VAL-010 | └─ └─ Transport route value | 235-260 | Sea zones on key transport routes (factory to front line) are valuable. | Factory-adjacent bonus | ✅ DONE | 75% | 3x factory prod bonus |
| VAL-011 | └─ └─ Naval choke point | 265-275 | Narrow passages or canal-adjacent zones get bonus value. | `num_connections` check | ✅ DONE | 80% | 30% for ≤2 connections |
| VAL-012 | `findLandValue()` | 282-400 | Detailed land territory valuation using BFS from production centers. | 🔶 PARTIAL | 🔶 PARTIAL | 45% | |
| VAL-013 | └─ BFS from production centers | 295-395 | Breadth-first search radiating value outward from factories, decaying with distance. | [`find_land_value()`](src/pro_land_value.odin) | ✅ DONE | 85% | Uses sorted decay |
| VAL-014 | `findAttackValue()` | 402-520 | Evaluates territories from offensive perspective - how valuable to capture. | ✅ DONE | find_attack_value() in pro_land_value.odin | 100% | |
| VAL-015 | └─ `for (Territory t)` | 415-515 | Iterates enemy territories calculating attack priority. | ✅ DONE | Part of find_attack_value() | 100% | |
| VAL-016 | └─ └─ TUV swing calc | 430-480 | Expected TUV gain from successful attack (enemy losses minus our losses). | ✅ DONE | calculate_land_defense_strength() | 100% | |
| VAL-017 | └─ └─ Post-conquest defensibility | 485-510 | Can we hold territory after capture? Factors in enemy counter-attack potential. | ✅ DONE | estimate_enemy_counterattack_strength() | 100% | |
| VAL-018 | `findDefenseValue()` | 522-640 | Evaluates territories from defensive perspective - how important to hold. | ✅ DONE | find_defense_value() in pro_land_value.odin | 100% | |
| VAL-019 | └─ `for (Territory t)` | 535-635 | Iterates friendly territories calculating defense priority. | ✅ DONE | Part of find_defense_value() | 100% | |
| VAL-020 | └─ └─ Capital proximity | 550-580 | Territories closer to capital are more critical to defend. | ✅ DONE | Uses mm.land_distances to capital | 100% | |
| VAL-021 | └─ └─ Factory presence | 585-620 | Territories with factories are high defense priority. | ✅ DONE | Factory bonus in find_defense_value() | 100% | |
| VAL-022 | `findUnitValue()` | 642-721 | Returns combat efficiency value for each unit type (attack/defense power relative to cost). | [`get_army_unit_value()`](src/pro_utils.odin#L211) + family | ✅ DONE | 90% | Full lookup tables for army/ship/plane |
| VAL-023 | └─ `for (UnitType type)` | 655-715 | Iterates unit types calculating value ratios. | N/A | ✅ DONE | 90% | Uses COST_IDLE_ARMY/SHIP/PLANE arrays |

---

### ProMatches.java - Territory and Unit Predicates (Local Utilities)

| ID | Java Method/Loop | Lines | Description | Odin Equivalent | Status | Equiv | Notes |
|----|------------------|-------|-------------|-----------------|--------|-------|-------|
| MATCH-001 | `territoryIsIsland()` | N/A | Checks if land territory is coastal but has no land neighbors. | `is_island()` | ✅ DONE | 95% | For stranded unit detection |
| MATCH-002 | `territoryHasLandNeighbors()` | N/A | Checks if territory has adjacent land territories. | `has_land_neighbors()` | ✅ DONE | 95% | Map geometry helper |
| MATCH-003 | `getLandNeighborCount()` | N/A | Returns count of adjacent land territories. | `get_land_neighbor_count()` | ✅ DONE | 95% | Connectivity metric |
| MATCH-004 | `getSeaNeighborCount()` | N/A | Returns count of adjacent sea zones. | `get_sea_neighbor_count()` | ✅ DONE | 95% | Coastal access metric |
| MATCH-005 | Player relationship: enemies | N/A | Checks if two players are on opposing teams. | `are_enemies()` | ✅ DONE | 95% | Team comparison |
| MATCH-006 | Player relationship: allies | N/A | Checks if two players are on same team. | `are_allies()` | ✅ DONE | 95% | Team comparison |
| MATCH-007 | `isEnemyOfCurrent()` | N/A | Checks if player is enemy of current player. | `is_enemy_of_current()` | ✅ DONE | 95% | Loop helper |
| MATCH-008 | `isAllyOfCurrent()` | N/A | Checks if player is allied with current player. | `is_ally_of_current()` | ✅ DONE | 95% | Loop helper |
| MATCH-009 | Territory ownership: self | N/A | Checks if territory owned by current player. | `is_owned_by_current()` | ✅ DONE | 95% | Ownership check |
| MATCH-010 | Territory ownership: ally | N/A | Checks if territory owned by ally (not self). | `is_owned_by_ally()` | ✅ DONE | 95% | Reinforcement targets |
| MATCH-011 | Territory ownership: friendly | N/A | Checks if territory owned by self or ally. | `is_friendly_territory()` | ✅ DONE | 95% | Movement validation |
| MATCH-012 | `getAdjacentLandCount(sea)` | N/A | Returns count of land territories touching a sea zone. | `get_adjacent_land_count()` | ✅ DONE | 95% | Transport value |
| MATCH-013 | `getAdjacentSeaCount(sea)` | N/A | Returns count of sea zones connected to this one. | `get_adjacent_sea_count()` | ✅ DONE | 95% | Naval mobility |
| MATCH-014 | `isCanalSea(sea)` | N/A | Checks if sea zone's connectivity depends on canal status. | `is_canal_sea()` | ✅ DONE | 95% | Chokepoint detection |
| MATCH-015 | `isEnemyTerritory()` | N/A | Checks if territory is owned by enemy player. | `is_enemy_territory()` | ✅ DONE | 95% | Attack targets |
| MATCH-016 | `territoryHasFactory()` | N/A | Checks if territory has a factory. | `has_factory()` | ✅ DONE | 95% | Consolidated from combat_move |
| MATCH-017 | `territoryHasAaGun()` | N/A | Checks if territory has at least one AA gun. | `has_aa_gun()` | ✅ DONE | 95% | Consolidated from combat_move |
| MATCH-018 | `territoryIsCoastal()` | N/A | Checks if land territory borders any sea zone. | `is_coastal()` | ✅ DONE | 95% | Transport accessibility |
| MATCH-019 | `canProduceAt()` | N/A | Checks if player can produce at territory. | `can_produce_at()` | ✅ DONE | 95% | Factory + ownership check |
| MATCH-020 | `getProductionValue()` | N/A | Returns IPC value of territory. | `get_production_value()` | ✅ DONE | 95% | Base production lookup |
| MATCH-021 | `hasEnemyNeighbors()` | N/A | Checks if any adjacent land is enemy-owned. | `has_enemy_neighbors()` | ✅ DONE | 95% | Consolidated from noncombat_move |
| MATCH-022 | `hasAlliedNeighbors()` | N/A | Checks if any adjacent land is ally-owned. | `has_allied_neighbors()` | ✅ DONE | 95% | Reinforcement routes |
| MATCH-023 | `countEnemyUnitsAt()` | N/A | Returns total enemy army units at territory. | `count_enemy_units_at()` | ✅ DONE | 95% | Strength assessment |
| MATCH-024 | `countAlliedUnitsAt()` | N/A | Returns total allied army units at territory. | `count_allied_units_at()` | ✅ DONE | 95% | Defense counting |
| MATCH-025 | `isCapital()` | N/A | Checks if territory is any player's capital. | `is_capital()` | ✅ DONE | 95% | Victory condition check |
| MATCH-026 | `hasEnemyLandUnits()` | N/A | Checks if land has enemy ground forces. | `has_enemy_land_units()` | ✅ DONE | 95% | O(1) team lookup |
| MATCH-027 | `hasAlliedLandUnits()` | N/A | Checks if land has allied ground forces. | `has_allied_land_units()` | ✅ DONE | 95% | O(1) team lookup |
| MATCH-028 | `hasEnemySeaUnits()` | N/A | Checks if sea zone has enemy naval forces. | `has_enemy_sea_units()` | ✅ DONE | 95% | O(1) team lookup |
| MATCH-029 | `hasAlliedSeaUnits()` | N/A | Checks if sea zone has allied naval forces. | `has_allied_sea_units()` | ✅ DONE | 95% | O(1) team lookup |
| MATCH-030 | `isContestedSea()` | N/A | Checks if sea zone has both allied and enemy. | `is_contested_sea()` | ✅ DONE | 95% | Combat resolution |
| MATCH-031 | `getPlayerCapital()` | N/A | Returns capital territory for a player. | `get_player_capital()` | ✅ DONE | 95% | Map data lookup |
| MATCH-032 | `isOwnCapital()` | N/A | Checks if territory is current player's capital. | `is_own_capital()` | ✅ DONE | 95% | Capital defense |
| MATCH-033 | `ownsCapital()` | N/A | Checks if player owns their capital. | `owns_capital()` | ✅ DONE | 95% | Income/surrender |
| MATCH-034 | `getEnemyDistanceToLand()` | N/A | Min distance from any enemy land to target. | `get_enemy_distance_to_land()` | ✅ DONE | 90% | Threat assessment |
| MATCH-035 | `getLandDistance()` | N/A | BFS distance between two land territories. | `get_land_distance()` | ✅ DONE | 90% | Pathfinding helper |
| MATCH-036 | `isEnemyOrCanAttack()` | N/A | Checks if territory is enemy or player can attack from it. | `is_enemy_or_can_attack()` | ✅ DONE | 90% | Territory classification |
| MATCH-037 | `isEnemyNotAllied()` | N/A | Checks if territory is enemy to player. | `is_enemy_not_allied()` | ✅ DONE | 95% | Team-based check |
| MATCH-038 | `getFactoryCapacity()` | N/A | Returns production capacity of factory at territory. | `get_factory_capacity()` | ✅ DONE | 95% | Factory utility |
| MATCH-039 | `hasBombableFactory()` | N/A | Checks if territory has factory that can be bombed. | `has_bombable_factory()` | ✅ DONE | 95% | SBR planning |
| MATCH-040 | `isFactoryDamaged()` | N/A | Checks if factory has damage. | `is_factory_damaged()` | ✅ DONE | 95% | Repair logic |
| MATCH-041 | `canBuildUnits()` | N/A | Checks if player can build at factory. | `can_build_units()` | ✅ DONE | 95% | Placement logic |
| MATCH-042 | `isAdjacentToOwnedFactory()` | N/A | Checks if sea zone is next to owned factory. | `is_adjacent_to_owned_factory()` | ✅ DONE | 95% | Naval placement |
| MATCH-043 | `isAdjacentToAlliedFactory()` | N/A | Checks if sea zone is next to allied factory. | `is_adjacent_to_allied_factory()` | ✅ DONE | 95% | Naval support |
| MATCH-044 | `isAdjacentToEnemyFactory()` | N/A | Checks if sea zone is next to enemy factory. | `is_adjacent_to_enemy_factory()` | ✅ DONE | 95% | Attack targets |
| MATCH-045 | `hasFactory()` | N/A | Checks if territory has factory. | `has_factory()` | ✅ DONE | 95% | Factory utility |
| MATCH-046 | `isOwnedFactory()` | N/A | Checks if player owns factory at territory. | `is_owned_factory()` | ✅ DONE | 95% | Purchase logic |
| MATCH-047 | `countEmptyTransports()` | N/A | Returns empty transports at sea zone. | `count_empty_transports_at_sea()` | ✅ DONE | 95% | Transport tracking |
| MATCH-048 | `countLoadedTransports()` | N/A | Returns loaded transports at sea zone. | `count_loaded_transports_at_sea()` | ✅ DONE | 95% | Transport tracking |
| MATCH-049 | `countCombatShips()` | N/A | Returns warships (not transports) at sea. | `count_combat_ships_at_sea()` | ✅ DONE | 95% | Naval strength |
| MATCH-050 | `hasDestroyer()` | N/A | Checks if player has destroyer at sea zone. | `has_destroyer()` | ✅ DONE | 95% | Sub combat |
| MATCH-051 | `hasCarrier()` | N/A | Checks if player has carrier at sea zone. | `has_carrier()` | ✅ DONE | 95% | Fighter landing |
| MATCH-052 | `hasSubmarine()` | N/A | Checks if player has submarine at sea zone. | `has_submarine()` | ✅ DONE | 95% | Sub detection |
| MATCH-053 | `countCarriers()` | N/A | Returns carrier count at sea zone. | `count_carriers_at_sea()` | ✅ DONE | 95% | Capacity calc |
| MATCH-054 | `getCarrierCapacity()` | N/A | Returns total fighter capacity at sea. | `get_carrier_capacity()` | ✅ DONE | 95% | Fighter placement |
| MATCH-055 | `hasBombardShips()` | N/A | Checks if player has cruisers/battleships. | `has_bombard_ships()` | ✅ DONE | 95% | Amphib support |
| MATCH-056 | `countBombardShips()` | N/A | Returns bombardment-capable ships count. | `count_bombard_ships()` | ✅ DONE | 95% | Shore bombardment |
| MATCH-057 | `getBombardPower()` | N/A | Returns total bombardment attack power. | `get_bombard_power()` | ✅ DONE | 95% | Amphib assault |
| MATCH-058 | `countFightersAtLand()` | N/A | Returns fighters at land territory. | `count_fighters_at_land()` | ✅ DONE | 95% | Air unit tracking |
| MATCH-059 | `countBombersAtLand()` | N/A | Returns bombers at land territory. | `count_bombers_at_land()` | ✅ DONE | 95% | Air unit tracking |
| MATCH-060 | `countFightersAtSea()` | N/A | Returns fighters at sea zone. | `count_fighters_at_sea()` | ✅ DONE | 95% | Carrier fighters |
| MATCH-061 | `hasEnemyFightersInRange()` | N/A | Checks if enemy fighters can reach territory. | `has_enemy_fighters_in_range()` | ✅ DONE | 85% | Threat assessment |
| MATCH-062 | `getTerritoryValue()` | N/A | Returns base IPC value of territory. | `get_territory_value()` | ✅ DONE | 95% | Value lookup |
| MATCH-063 | `getTotalAdjacentLandValue()` | N/A | Returns sum of adjacent land IPC values. | `get_total_adjacent_land_value()` | ✅ DONE | 95% | Strategic value |
| MATCH-064 | `getTotalAdjacentSeaLandValue()` | N/A | Returns sum of land values touching sea. | `get_total_adjacent_sea_land_value()` | ✅ DONE | 95% | Sea value |
| MATCH-065 | `canLandMoveThrough()` | N/A | Checks if land unit can move through. | `can_land_move_through()` | ✅ DONE | 90% | Movement validation |
| MATCH-066 | `canSeaMoveThrough()` | N/A | Checks if sea unit can move through. | `can_sea_move_through()` | ✅ DONE | 85% | Movement validation |
| MATCH-067 | `isBlitzable()` | N/A | Checks if territory can be blitzed. | `is_blitzable()` | ✅ DONE | 90% | Tank movement |
| MATCH-068 | `hasAaThreat()` | N/A | Checks if territory has enemy AA. | `has_aa_threat()` | ✅ DONE | 95% | Air attack planning |
| MATCH-069 | `countAaGunsAt()` | N/A | Returns AA gun count at territory. | `count_aa_guns_at()` | ✅ DONE | 95% | AA defense |
| MATCH-070 | `getDefensePowerAtLand()` | N/A | Returns total defense power at territory. | `get_defense_power_at_land()` | ✅ DONE | 85% | Battle estimation |
| MATCH-071 | `getAttackPowerAtLand()` | N/A | Returns total attack power at territory. | `get_attack_power_at_land()` | ✅ DONE | 85% | Battle estimation |

---

### Summary Statistics

| Category | Total | ✅ DONE | 🔶 PARTIAL | ❌ MISSING | ⏭️ SKIP | 🔄 STUB |
|----------|-------|---------|------------|------------|---------|---------|
| AbstractProAi | 8 | 3 | 0 | 2 | 3 | 0 |
| ProPurchaseAi | 86 | 52 | 18 | 16 | 0 | 0 |
| ProCombatMoveAi | 50 | 38 | 5 | 5 | 0 | 2 |
| ProNonCombatMoveAi | 75 | 14 | 20 | 41 | 0 | 0 |
| ProTerritoryManager | 25 | 14 | 5 | 6 | 0 | 0 |
| ProTransportUtils | 20 | 4 | 2 | 14 | 0 | 0 |
| ProTerritoryValueUtils | 23 | 2 | 7 | 14 | 0 | 0 |
| **TOTAL** | **287** | **127 (44%)** | **57 (20%)** | **98 (34%)** | **3 (1%)** | **2 (1%)** |

### Critical Missing Items (Causing UK Infantry Pileup)

1. **PUR-061 to PUR-072**: `purchaseSeaAndAmphibUnits()` Phase 3 - Transport/Amphib purchase loop
2. **PUR-065**: `potentialUnitsToLoad` from territories with value <= 0.25 (islands like UK)
3. **TRN-005**: `getUnitsToTransportThatCantMoveToHigherValue()` - Identifies stranded units
4. ~~**NCM-014 to NCM-019**: Capital defense while loop with local superiority check~~ ✅ DONE
5. **NCM-030 to NCM-045**: Transport positioning blocks in `moveUnitsToBestTerritories()`

---

## Current Implementation Status Summary

### ✅ COMPLETE (or mostly complete)
| File | Status | Notes |
|------|--------|-------|
| `pro_turn.odin` | ✅ Complete | Turn orchestration working, proper unit counting |
| `pro_purchase.odin` | ✅ ~99% | 25+ methods, deferred placement, sequential battle sim, sea defense eval |
| `pro_purchase_ai.odin` | ✅ Complete | Alternative purchase flow entry point |
| `pro_my_attacks.odin` | ✅ Complete | Attack option generation |
| `pro_enemy_attacks.odin` | ✅ Complete | Per-enemy attack analysis with aggregation |
| `pro_move_execute.odin` | ✅ Complete | Movement execution layer |
| `pro_utils.odin` | ✅ Complete | Helper utilities |
| `pro_data.odin` | ✅ Complete | Data structures for Pro AI |
| `battle.odin` | ✅ Complete | Monte Carlo battle simulator |
| `pro_place.odin` | ✅ ~80% | Places purchased units at factories |

### 🔶 PARTIAL (needs completion)
| File | Status | Notes |
|------|--------|-------|
| `pro_combat_move_triplea_methods.odin` | 🔶 ~85% | Core algorithms exist, amphib assaults working, Unit_Info needs count-based refactor |
| `pro_noncombat_move.odin` | 🔶 ~60% | 3-pass algorithm exists, some air landing partial |
| `pro_territory_manager.odin` | 🔶 ~30% | Partial structure |
| `pro_transport.odin` | 🔶 ~40% | Planning structures defined |
| `pro_transport_execute.odin` | ✅ ~90% | Non-combat loading + amphib unloading implemented |
| `pro_land_value.odin` | 🔶 ~30% | Mostly commented out, strategic_value calc inlined in pro_purchase.odin |

### ❌ NOT IMPLEMENTED
| File | Status | Notes |
|------|--------|-------|
| `pro_matches.odin` | ❌ Empty | Predicates replaced with bitset operations (intentional) |
| Strategic Bombing Decision AI | ❌ Missing | When to bomb vs tactical attack |
| Naval Bombardment | ❌ Missing | Cruiser/Battleship support for amphib assaults |
| Multi-Transport Coordination | ❌ Missing | D-Day style large amphibious assaults |

### 🚫 INTENTIONALLY OMITTED
| Feature | Reason |
|---------|--------|
| Politics/Diplomacy | Not used in MCTS scenarios |
| Technology Research | Not used in MCTS scenarios |
| Scramble/Intercept | Not used in MCTS scenarios |
| FFA (Free-For-All) Mode | Not implemented |
| Bidding Logic | Not relevant for MCTS |
| Neutral Territories | Simplified to always false |

---

### Amphibious Assault System (✅ Working - December 2025)

Implemented complete amphibious assault planning and execution for combat moves.

**How it works**:

1. **Territory Evaluation** (Step 4b in `try_to_attack_territories_triplea`):
   - For each potential attack target, calculate win% with land/air only
   - If win% < 75%, check if adding amphib units would help
   - If amphib makes it winnable, mark `need_amphib_units = true`
   - Recalculate win% with all attackers (land + air + amphib)

2. **Amphib Attacker Population** (`update_amphib_attackers_only`):
   - Finds loaded transports in adjacent sea zones AND 1-move-away sea zones
   - Checks all 6 loaded transport types: TRANS_1I, TRANS_1T, TRANS_1A, TRANS_2I, TRANS_1I_1A, TRANS_1I_1T
   - Adds their cargo as `potential_amphib_attackers`

3. **Unit Assignment** (Step 10 `assign_amphibious_units`):
   - For attacks needing amphib units, assigns from `potential_amphib_attackers`
   - Resets `win_percentage = 0` to force battle recalculation with amphib units
   - Logs assignment: "Burma: 100.0% win, attackers=2 (land/air=0, amphib=2)"

4. **Route Execution** (`execute_amphibious_routes`):
   - Uses `gc.idle_ships` (not active_ships) to find loaded transports
   - Unloads infantry/artillery/tanks from transports to target territory
   - Updates transport state (e.g., TRANS_2I → TRANS_1I after unloading 1 inf)
   - Adds unloaded units to target as `active_armies` with 0 moves

**Key Functions**:
| Function | File | Description |
|----------|------|-------------|
| `evaluate_need_amphib_units_triplea` | pro_combat_move_triplea_methods.odin | Checks if territory needs amphib |
| `update_amphib_attackers_only` | pro_combat_move_triplea_methods.odin | Populates amphib attackers for existing Attack_Options |
| `assign_amphibious_units` | pro_combat_move_triplea_methods.odin | Assigns amphib units to attacks |
| `execute_amphibious_routes` | pro_combat_move_triplea_methods.odin | Unloads transports to targets |

**Example Output**:
```
Burma: Land+Air win=0.0%, WITH AMPHIB win=100.0% - NEED AMPHIB UNITS
[AMPHIB ASSIGN] Burma: Assigned 2 amphib attackers (from Sea_35)
Unloading Infantry from TRANS_1I (sea zone Sea_35) to Burma
Unloading Tank from TRANS_1T (sea zone Sea_35) to Burma
```

**Verified Working Targets**:
- Malaya: 100% win with 2 amphib attackers (pure amphib)
- Norway: 100% win with 2 amphib attackers
- Burma: 100% win with 2 amphib attackers  
- Buryatia_SSR: 100% win with 6 attackers (2 land/air + 4 amphib)
- French_Indo_China_Thailand: Multiple amphib assaults from Sea_35, Sea_61

---

### Sea Territory Defense Evaluation (Latest Work)

Implemented sea zone defense evaluation in `prioritize_territories_to_defend_triplea()`.

**How it works**:
1. For each sea zone, count our ships and calculate TUV (Total Unit Value) at risk
2. Check for enemy threat using `has_enemy_threat_sea()`
3. Calculate `hold_value = TUV / 8` (from Java ProPurchaseAi)
4. Run Monte Carlo sea battle simulation using `get_sea_battle_results()`
5. If `TUV_swing > hold_value`, mark zone as needing defense
6. Find adjacent coastal factory for purchasing naval defenders

**Helper functions added**:
- `Ship_Counts` struct - Quick ship counting with totals
- `count_our_ships()` - Count all allied ships in a sea zone
- `gather_sea_defenders()` - Build Sea_Defenders struct for battle sim
- `calculate_sea_tuv()` - Calculate total unit value of fleet
- `find_factory_for_sea_defense()` - Find coastal factory for purchases
- `Place_Sea_Territory_Defense` struct - Sea zone defense data

**Example output**:
```
Sea_4: TUV=31.0, holdValue=3.9, TUV_swing=21.6, win%=100.0%
  [SKIP] No adjacent factory for Sea_4
Sea_8: TUV=12.0, holdValue=1.5, TUV_swing=8.5, win%=100.0%
  [SKIP] No adjacent factory for Sea_8
```

---

### Transport Loading System

Transport loading has been implemented for non-combat moves, with combat loading identified as needing amphibious attack planning integration.

#### Non-Combat Transport Loading (✅ Working)
**Files**: `pro_turn.odin`, `pro_noncombat_move.odin`

The non-combat transport loading loads units onto transports for next-turn positioning:

1. **Entry Point**: `load_transports_noncombat()` in `pro_noncombat_move.odin`
   - Called after `move_land_units_noncombat()` in Step 8
   - Iterates through all sea zones looking for idle transports

2. **Loading Priority** (tank > artillery > infantry):
   - `load_noncombat_onto_empty_transport()` - Loads tank+inf or arty+inf or 2×inf
   - `load_noncombat_second_unit_onto_1i()` - Fills TRANS_1I with tank/arty/inf
   - `load_noncombat_infantry_onto_partial()` - Fills TRANS_1A/TRANS_1T with infantry

3. **Uses `idle_armies`** (not active) since these units haven't moved this turn

#### Combat Transport Loading (✅ Working via Amphibious Assault System)
**File**: `pro_combat_move_triplea_methods.odin`

The combat transport loading is now handled through the amphibious assault system:
- `assign_amphibious_units()` identifies which loaded transports to use
- `execute_amphibious_routes()` unloads transports directly to attack targets
- Uses `gc.idle_ships` to find available loaded transports
- Supports all 6 loaded transport types

**Note**: Transports get loaded during non-combat moves (previous turn) and are available for amphibious assaults on the current turn. On the very first turn, transports start EMPTY so amphibious assaults require at least one turn of loading.

#### Key Procedures Added

| Procedure | File | Description |
|-----------|------|-------------|
| `load_transports_noncombat` | pro_noncombat_move.odin | Entry point for noncombat loading |
| `load_transports_at_sea_noncombat` | pro_noncombat_move.odin | Loads transports at a sea zone |
| `load_noncombat_onto_empty_transport` | pro_noncombat_move.odin | Prioritized loading for empty |
| `load_noncombat_second_unit_onto_1i` | pro_noncombat_move.odin | Fill 1I transports |
| `load_noncombat_infantry_onto_partial` | pro_noncombat_move.odin | Fill 1A/1T transports |
| `proai_load_transports_for_combat` | pro_turn.odin | Combat loading (currently disabled) |
| `load_transports_at_sea` | pro_turn.odin | Combat loading helper |
| `load_best_units_onto_empty_transport` | pro_turn.odin | Combat loading helper |

---

### Purchase System Overhaul
The purchase system has been significantly improved with the following changes:

1. **Deferred Placement System** (`g_purchased_units`)
   - Units are tracked in `g_purchased_units` dynamic array during purchase
   - Placed during `place_defenders_triplea()` at placement phase
   - Prevents double-counting of units

2. **Sequential Battle Simulation** (`simulate_sequential_enemy_attacks`)
   - Each enemy attacks in turn order (Ger, then Jap for Russia)
   - Survivors from one battle defend against the next attacker
   - More realistic threat assessment than single aggregated attack

3. **Fodder % Algorithm** for offensive purchases
   - `fodder_percent = 80 - enemy_distance * 5`
   - Close to enemy (distance 1): 75% infantry, 25% attack units
   - Far from enemy (distance 5): 55% infantry, 45% attack units
   - Produces realistic mix of infantry, artillery, and tanks

4. **Strategic Value Calculation** (inlined in `prioritize_land_territories_triplea`)
   - `strategic_value = (production + territory_value) * distance_factor`
   - `distance_factor = 6 - min(enemy_distance, 5)` (closer = more strategic)

5. **Production Capacity Tracking** (`gc.builds_left[territory]`)
   - Respects factory production limits
   - Tracks remaining capacity per factory

### Key Procedures Added/Modified

| Procedure | File | Description |
|-----------|------|-------------|
| `simulate_sequential_enemy_attacks` | pro_purchase.odin | Sequential battle sim per enemy |
| `add_units_to_place_triplea` | pro_purchase.odin | Deferred land unit tracking |
| `add_naval_units_to_place_triplea` | pro_purchase.odin | Deferred naval unit tracking |
| `get_closest_enemy_land_distance` | pro_purchase.odin | Distance to nearest enemy (1-5) |
| `calculate_land_distance_factor` | pro_purchase.odin | Movement efficiency calculation |
| `find_upgrade_unit_efficiency_triplea` | pro_purchase.odin | Unit upgrade value calculation |
| `prioritize_land_territories_triplea` | pro_purchase.odin | Inline strategic value calc |
| `place_defenders_triplea` | pro_purchase.odin | Places units from g_purchased_units |

### Data Structures

#### Purchased_Units (pro_purchase.odin)
```odin
Purchased_Units :: struct {
    territory: Land_ID,   // Factory location
    inf:       u8,        // Infantry count
    arty:      u8,        // Artillery count
    tank:      u8,        // Tank count
    aa:        u8,        // AA gun count
    fighter:   u8,        // Fighter count
    bomber:    u8,        // Bomber count
    factory:   u8,        // Factory count
}
```

#### Purchased_Naval_Units (pro_purchase.odin)
```odin
Purchased_Naval_Units :: struct {
    factory:    Land_ID,   // Coastal factory
    sea_zone:   Sea_ID,    // Adjacent sea zone for placement
    destroyer:  u8,
    cruiser:    u8,
    battleship: u8,
    carrier:    u8,
    sub:        u8,
    transport:  u8,
}
```

#### Sequential_Battle_Result (pro_purchase.odin)
```odin
Sequential_Battle_Result :: struct {
    final_invaded_percent: f64,  // Probability territory is captured
    total_tuv_swing:       f64,  // Total expected TUV change
    num_battles:           int,  // Number of sequential battles simulated
}
```

---

## Phase 1: Critical Fixes & Core Infrastructure

### 1.1 Refactor Unit_Info to Count-Based System (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Problem**: Uses `[dynamic]Unit_Info` with individual unit tracking - poor performance and OOP-like.

**Current Code** (lines 56-78):
```odin
Unit_Info :: struct {
    unit_type:      Unit_Type,
    from_territory: Land_ID,
}

Attack_Option :: struct {
    territory:          Land_ID,
    attackers:          [dynamic]Unit_Info,
    ...
}
```

**Required Change**: Convert to count-based arrays:
```odin
// New structure - counts per source territory
Attack_Unit_Counts :: struct {
    infantry:  [Land_ID]u8,  // infantry counts by source
    artillery: [Land_ID]u8,
    tanks:     [Land_ID]u8,
    fighters:  [Air_ID]u8,   // Air_ID for sea-based fighters too
    bombers:   [Air_ID]u8,
}

Attack_Option :: struct {
    territory:        Air_ID,  // Changed from Land_ID to support sea attacks
    attacker_counts:  Attack_Unit_Counts,
    amphib_counts:    Attack_Unit_Counts,
    defender_counts:  Attack_Unit_Counts,
    // Battle metrics (existing)
    attack_value:     f64,
    win_percentage:   f64,
    tuv_swing:        f64,
    can_hold:         bool,
    is_amphib:        bool,
    is_strafing:      bool,
    avg_survivor_def_power: f64,
}
```

**Procedures to Update**:
- `prioritize_attack_options_triplea()` - lines 167-223
- `determine_territories_to_attack_triplea()` - lines 259-366
- `determine_territories_that_can_be_held_triplea()` - lines 395-492
- `try_to_attack_territories_triplea()` - lines 645-850

---

### 1.2 Change Attack_Option.territory to Air_ID (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current**: `territory: Land_ID` - Only supports land attacks

**Required**: `territory: Air_ID` - Supports both land and sea attacks in unified array

**Procedures to Update**:
- All procedures in `pro_combat_move_triplea_methods.odin` that reference `option.territory`
- `prioritize_my_attack_options()` in `pro_my_attacks.odin`

---

### 1.3 Implement Blitz Logic (Java-Style) (HIGH PRIORITY)
**File**: `army.odin`, `pro_combat_move_triplea_methods.odin`

**Current Problem**: Blitz implementation is partial/non-functional.

**Required Implementation**:

1. **New Procedure** in `army.odin`:
```odin
// Check if territory is blitzable
is_territory_blitzable :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
    // Territory must be:
    // 1. Enemy owned
    // 2. No enemy units present
    // 3. No factory
    if land in gc.friendly_owner do return false
    if gc.team_land_units[land][mm.enemy_team[gc.cur_player]] > 0 do return false
    if gc.factory_prod[land] > 0 do return false
    return true
}
```

2. **Update `add_valid_army_moves_2()`** to allow tank moves through blitzable territories

3. **Update Pro AI Combat Move** to plan blitz attacks

---

### ~~1.4 Add Strategic Territory Value (gc.strategic_value)~~ ✅ DONE (Inlined)
**Status**: Completed differently - strategic value is now calculated inline in `prioritize_land_territories_triplea()` instead of pre-computed in `gc.strategic_value`.

The calculation uses:
```odin
production := f64(gc.factory_prod[territory])
territory_value := f64(mm.value[territory])
enemy_distance := get_closest_enemy_land_distance(gc, territory)
distance_factor := 6.0 - f64(min(enemy_distance, 5))
strategic_value := (production + territory_value) * distance_factor
```

---

## Phase 2: Combat Move Completion

### 2.1 Complete populate_attack_options_triplea() (MEDIUM PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Currently Missing**:
1. Amphibious attack options - transports unloading
2. Bombardment options - cruisers/battleships
3. Multi-hop attack options for tanks (blitz paths)

---

### 2.2 Complete determine_units_to_attack_with_triplea() (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Status**: Partial implementation exists

**Required Implementation**:
1. Sort available units by attack efficiency (attack power / cost)
2. Assign minimum units needed to achieve win threshold (60%)
3. Reserve some units for defense
4. Handle multi-territory attacks (don't overcommit)

---

### 2.3 Execute Combat Moves (MEDIUM PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Status**: `execute_combat_moves_triplea()` called but may need refinement

**Required Sub-procedures**:
- `execute_land_combat_moves()`
- `execute_air_combat_moves()`
- `execute_amphib_combat_moves()`
- `execute_bombardment_moves()`
- `execute_bombing_runs()`

---

### 2.4 Strategic Bombing Decision Logic (LOW PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Status**: Stubs exist but no AI decision logic

**Decision Criteria** (from Java):
- `bombing_score = expected_damage * 2 - risk_of_losing_bomber`
- Must exceed `MIN_BOMBING_SCORE = 4`
- Avoid bombing low production factories with AA guns

---

## Phase 3: Non-Combat Move Completion

### 3.1 Complete proai_noncombat_move_phase() (MEDIUM PRIORITY)
**File**: `pro_noncombat_move.odin`

**Current Status**: ~60% complete with 3-pass algorithm

**Required Implementation Order**:
1. **`find_units_that_cant_move()`** - Identify AA guns placed this turn
2. **`move_one_defender_to_land_territories_bordering_enemy()`** - ✅ Exists
3. **`prioritize_defend_options()`** - Sort territories by defense priority
4. **`move_units_to_defend_territories()`** - Main defensive movement
5. **`move_units_to_best_territories()`** - Secondary positioning

---

### 3.2 Carrier Landing Detection (MEDIUM PRIORITY)
**File**: `pro_noncombat_move.odin`, `fighter.odin`

**Current Status**: `gc.has_carrier_space` exists but Pro AI doesn't fully utilize

**Required Implementation**:
```odin
find_best_fighter_landing :: proc(gc: ^Game_Cache, fighter_location: Air_ID, moves_remaining: int) -> Air_ID
can_carrier_reach_fighter :: proc(gc: ^Game_Cache, carrier_sea: Sea_ID, fighter_air: Air_ID, ...) -> bool
plan_carrier_rescue_moves :: proc(gc: ^Game_Cache) -> [dynamic]Carrier_Move
```

---

### 3.3 AA Gun Movement Logic (LOW PRIORITY)
**File**: `pro_noncombat_move.odin`

**Priority Order**:
1. Capital (if undefended by AA)
2. Major factories (production >= 3)
3. Territories under air threat
4. Minor factories

---

## Phase 4: Place Units Completion

### 4.1 Complete proai_place_units_phase() (✅ ~80% DONE)
**File**: `pro_place.odin`

**Current Status**: Basic implementation working with `place_defenders_triplea()`

**Remaining Work**:
- Factory placement at optimal locations
- Sea unit placement with carrier coordination

---

## Phase 5: Ship Purchase & Transport Logic

### 5.0 Complete Ship Purchase Logic (HIGH PRIORITY) ✅ DONE
**File**: `pro_purchase.odin`, `pro_enemy_attacks.odin`, `battle.odin`

**Status**: Implemented and working. Ships are now being purchased based on battle simulation.

**Implementation Summary**:
- ✅ Sea battle simulation in `battle.odin` (Monte Carlo, 1000 iterations)
- ✅ `simulate_sea_battle()` with submarine sneak attack logic
- ✅ `get_enemy_sea_attackers_from_threat()` - extracts attackers from threat analysis
- ✅ `get_my_sea_defenders()` - counts defenders + pending purchases
- ✅ `simulate_sea_defense()` - main simulation entry point
- ✅ `can_hold_sea_zone()` - decision: TUV swing < -1 OR win% < 5%
- ✅ `get_sea_defense_efficiency()` - defense_power/cost with bonuses
- ✅ Updated `is_sea_worth_defending()` to include factory-adjacent sea zones
- ✅ Moved sea purchase BEFORE land offense in `purchase_triplea()`
- ✅ All ship types purchasing: transports, destroyers, cruisers, battleships, subs

**Key Changes Made**:
1. Added `Sea_Combatants`, `Sea_Defenders`, `Sea_Attackers`, `Sea_Battle_Results` to `battle.odin`
2. Implemented submarine sneak attack (subs attack first if no enemy destroyer)
3. Casualty order: subs → destroyers → cruisers → carriers → BS_damaged → battleships → fighters → bombers/transports
4. Updated `is_sea_worth_defending()` in `pro_enemy_attacks.odin` to track threats to coastal factory sea zones
5. Reordered purchase flow in `purchase_triplea()` to buy ships BEFORE offensive land units

**Test Results**:
- 130+ ship purchases in typical game run
- Distribution: 51 transports, 40 battleships, 30 destroyers, 9 subs
- TUV swing and win percentage correctly calculated and used for decisions

**Remaining Work (Lower Priority)**:
    fighters:    u8,  // on carriers
    total_attack: f64,
    total_defense: f64,
}

Transport_Load_Info :: struct {
    sea_zone:   Sea_ID,
    capacity:   int,
    units_loaded: int,
}
```

---

### 5.1 Complete Transport Planning (MEDIUM PRIORITY)
**File**: `pro_transport.odin`

**Current Status**: Data structures defined, execution incomplete

**Required Procedures**:
```odin
plan_amphibious_assault :: proc(gc: ^Game_Cache, target_land: Land_ID) -> Maybe(Amphibious_Plan)
find_optimal_load :: proc(gc: ^Game_Cache, transport_sea: Sea_ID, capacity: int) -> [dynamic]Unit_Load_Info
execute_transport_load :: proc(gc: ^Game_Cache, plan: ^Amphibious_Plan) -> bool
execute_transport_move :: proc(gc: ^Game_Cache, plan: ^Amphibious_Plan) -> bool
```

---

## Phase 6: Code Quality & Cleanup

### 6.1 Variable Renames for Clarity

| Current Name | Suggested Name | Location | Reason |
|--------------|----------------|----------|--------|
| `gc.pro_value` | Remove or keep commented | game_cache.odin | Strategic value now inline |
| `win_percentage_needed` | `defense_threshold` | pro_purchase.odin | Clearer meaning (0.95) |
| `fodder_percent` | `infantry_ratio_target` | pro_purchase.odin | Clearer meaning |
| `tuv_swing` | `expected_tuv_change` | battle.odin | More descriptive |

### 6.2 Comments to Add

1. **pro_purchase.odin line ~760**: Document `simulate_sequential_enemy_attacks` algorithm
2. **pro_purchase.odin line ~2400**: Document upgrade efficiency formula
3. **pro_enemy_attacks.odin line ~1**: Document per-enemy vs aggregated attack options
4. **pro_turn.odin line ~85**: Document that `gs.cur_player` is starting player, `gc.cur_player` is next after turn

### 6.3 Dead Code Removal

| File | Lines | Description |
|------|-------|-------------|
| `pro_land_value.odin` | 10-37 | `build_map_production_value` commented out - can remove |
| `game_cache.odin` | ~160 | `build_map_production_value(gc)` call commented out |

---

## Implementation Priority Order

### Sprint 1 (Highest Priority - Blocking Issues)
1. ✅ Purchase system overhaul (DONE)
2. ✅ Deferred placement system (DONE)
3. ✅ Sequential battle simulation (DONE)
4. 🔲 1.1 - Refactor Unit_Info to count-based (partial)
5. 🔲 1.2 - Change Attack_Option.territory to Air_ID
6. 🔲 1.3 - Implement Blitz Logic (Java-style)

### Sprint 2 (High Priority - Core Functionality)
7. 🔲 2.2 - Complete determine_units_to_attack_with_triplea()
8. ✅ 3.1 - Complete proai_noncombat_move_phase() (non-combat loading done)
9. 🔲 3.2 - Carrier Landing Detection

### Sprint 3 (Medium Priority - Completion)
10. ✅ 2.1 - Complete populate_attack_options_triplea() (amphib planning DONE)
11. 🔲 2.3 - Execute Combat Moves refinement
12. ✅ 5.1 - Complete Transport Planning (non-combat + amphib DONE)

### Sprint 4 (Lower Priority - Polish)
13. 🔲 2.4 - Strategic Bombing Decision Logic
14. 🔲 3.3 - AA Gun Movement Logic
15. 🔲 6.1 - Variable Renames
16. 🔲 6.2 - Comment Updates
17. 🔲 6.3 - Dead Code Removal

### Future (Post-Core Completion)
18. 🔲 Retreat Logic (ProRetreatAi.java)
19. 🔲 Turn Simulation (ProSimulateTurnUtils.java)
20. 🔲 Alpha-Zero Integration

---

## Appendix A: Java to Odin Method Mapping

### ProPurchaseAi.java → pro_purchase.odin (✅ COMPLETE)

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `repair()` | `repair_factories_triplea()` | ✅ Done |
| `purchase()` | `purchase_triplea()` | ✅ Done |
| `prioritizeTerritoriesToDefend()` | `prioritize_territories_to_defend_triplea()` | ✅ Done + Sequential Sim |
| `purchaseDefenders()` | `purchase_defenders_triplea()` | ✅ Done |
| `prioritizeLandTerritories()` | `prioritize_land_territories_triplea()` | ✅ Done + Inline Strategic Value |
| `purchaseAaUnits()` | `purchase_aa_units_triplea()` | ✅ Done |
| `purchaseLandUnits()` | `purchase_land_units_triplea()` | ✅ Done + Fodder % |
| `purchaseFactory()` | `purchase_factory_triplea()` | ✅ Done |
| `prioritizeSeaTerritories()` | `prioritize_sea_territories_triplea()` | ✅ Done |
| `purchaseSeaAndAmphibUnits()` | `purchase_sea_and_amphib_units_triplea()` | ✅ Done |
| `purchaseUnitsWithRemainingProduction()` | `purchase_units_with_remaining_production_triplea()` | ✅ Done |
| `upgradeUnitsWithRemainingPUs()` | `upgrade_units_with_remaining_pus_triplea()` | ✅ Done |
| `findUpgradeUnitEfficiency()` | `find_upgrade_unit_efficiency_triplea()` | ✅ Done |
| `place()` | `place_defenders_triplea()` | ✅ Done |
| N/A | `simulate_sequential_enemy_attacks()` | ✅ New (OAAA improvement) |
| N/A | `get_closest_enemy_land_distance()` | ✅ New helper |
| N/A | `calculate_land_distance_factor()` | ✅ New helper |

### ProCombatMoveAi.java → pro_combat_move_triplea_methods.odin (🔶 ~85%)

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `doCombatMove()` | `proai_combat_move_phase()` | ✅ Done |
| `doMove()` | `execute_combat_moves_triplea()` | ✅ Done |
| `prioritizeAttackOptions()` | `prioritize_attack_options_triplea()` | ✅ Done |
| `determineTerritoriesToAttack()` | `determine_territories_to_attack_triplea()` | ✅ Done |
| `determineTerritoriesThatCanBeHeld()` | `determine_territories_that_can_be_held_triplea()` | ✅ Done |
| `removeTerritoriesThatArentWorthAttacking()` | `remove_territories_that_arent_worth_attacking_triplea()` | ✅ Done |
| `moveOneDefenderToLandTerritoriesBorderingEnemy()` | `move_one_defender_to_land_territories_bordering_enemy_triplea()` | ✅ Done |
| `removeTerritoriesWhereTransportsAreExposed()` | `remove_territories_where_transports_are_exposed_triplea()` | ✅ Done |
| `determineUnitsToAttackWith()` | `determine_units_to_attack_with_triplea()` | ✅ Done |
| `tryToAttackTerritories()` | `try_to_attack_territories_triplea()` | ✅ Done |
| `setNeedAmphibUnits()` | `evaluate_need_amphib_units_triplea()` | ✅ Done (New) |
| `assignAmphibUnits()` | `assign_amphibious_units()` | ✅ Done (New) |
| `executeAmphibRoutes()` | `execute_amphibious_routes()` | ✅ Done (New) |
| `determineTerritoriesThatCanBeBombed()` | Stub | ❌ Missing |
| `determineBestBombingAttackForBomber()` | Stub | ❌ Missing |
| `checkContestedSeaTerritories()` | `check_contested_sea_territories_triplea()` | 🔶 Stub |

### ProNonCombatMoveAi.java → pro_noncombat_move.odin (🔶 ~60%)

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `doNonCombatMove()` | `proai_noncombat_move_phase()` | 🔶 Partial |
| `findUnitsThatCantMove()` | N/A | ❌ Missing |
| `findInfraUnitsThatCanMove()` | N/A | ❌ Missing |
| `moveOneDefenderToLandTerritoriesBorderingEnemy()` | Exists in combat move | ✅ Done |
| `prioritizeDefendOptions()` | Partial | 🔶 Partial |
| `moveUnitsToDefendTerritories()` | Partial | 🔶 Partial |
| `moveUnitsToBestTerritories()` | Partial | 🔶 Partial |
| `moveInfraUnits()` | N/A | ❌ Missing |

---

## Appendix B: Key Data Structures Reference

### Global Variables (pro_purchase.odin)
```odin
g_purchased_units: [dynamic]Purchased_Units      // Land unit purchases
g_purchased_naval_units: [dynamic]Purchased_Naval_Units  // Naval purchases
```

### Existing (game_cache.odin)
```odin
// Unit tracking
idle_armies:               [Land_ID][Player_ID][Idle_Army]u8
active_armies:             [Land_ID][Active_Army]u8
idle_ships:                [Sea_ID][Player_ID][Idle_Ship]u8
active_ships:              [Sea_ID][Active_Ship]u8

// Territory analysis
team_land_units:           [Land_ID][Team_ID]u8
team_sea_units:            [Sea_ID][Team_ID]u8
friendly_owner:            Land_Bitset
has_enemy_armies:          Land_Bitset
has_enemy_ships:           Sea_Bitset
has_factory:               Land_Bitset
has_carrier_space:         Sea_Bitset
builds_left:               [Land_ID]u8  // Remaining factory production capacity
```

### Constants (pro_purchase.odin)
```odin
win_percentage_needed :: 0.95  // Defense threshold (95% = 5% invasion chance acceptable)
```

---

## Appendix C: Testing Notes

### Running Tests
```bash
odin build src/ -debug -out:debug_oaaa && ./debug_oaaa
```

### Key Debug Output to Check
1. `[RATIONALE] Found X threatened territories` - Defense system working
2. `Purchased: X infantry, Y artillery, Z tanks` - Offensive purchases working
3. `Units Added: N` - Should be positive for each player
4. `Money Spent: X IPCs` - Should use most/all available money

### Known Issues
1. Strategic bombing AI not implemented - bombers only used tactically
2. Blitz logic incomplete - tanks may not use optimal paths
3. ~Transport staging/unloading not implemented~ - **FIXED**: `stage_and_unload_transports_noncombat()` now moves loaded transports to high-value destinations and unloads cargo
4. ~Empty transport repositioning not implemented~ - **FIXED**: `move_empty_transports_to_loading()` moves transports toward factories

### Recently Completed
- **Empty Transport Positioning (NCM-038 to NCM-041)**: Empty transports now automatically move toward coastal territories with factories or units waiting to load. Uses Java's loadValue formula: `territoryValue + 0.5*numTurnsAway - 0.1*numUnitsToLoad - 0.1*factoryProduction`. Lower value = better destination (factories and units are attractive).
- **Circular Loading Bug Fix**: Fixed issue where Japan would load units from India onto transports at Sea_35, then immediately unload them back to India. Implemented Java's `landRoutesMap` filtering pattern from `ProTerritoryManager.java` - now excludes territories that can walk to the unload destination from valid loading sources.
- **Transport NCM Staging (NCM-030 to NCM-045)**: Loaded transports now automatically move to adjacent sea zones of high-value land territories and unload all cargo during non-combat phase. Uses `find_territory_values_triplea()` for destination selection.

---

*Document created: December 6, 2025*
*Last updated: December 9, 2025*
