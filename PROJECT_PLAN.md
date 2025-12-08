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
cd /home/nixos/aaa_merge/oaaa
nix-shell --run "odin build src/ -debug -out:debug_oaaa && ./debug_oaaa"
```

### Key Debug Output to Check
1. `[RATIONALE] Found X threatened territories` - Defense system working
2. `Purchased: X infantry, Y artillery, Z tanks` - Offensive purchases working
3. `Units Added: N` - Should be positive for each player
4. `Money Spent: X IPCs` - Should use most/all available money

### Known Issues
1. Strategic bombing AI not implemented - bombers only used tactically
2. Blitz logic incomplete - tanks may not use optimal paths
3. Multi-transport coordination not implemented

---

*Document created: December 6, 2025*
*Last updated: December 7, 2025*
