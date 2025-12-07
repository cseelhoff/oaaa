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
| `pro_turn.odin` | ✅ Complete | Turn orchestration working |
| `pro_purchase.odin` | ✅ ~90% | 25+ methods mapped, purchase logic working |
| `pro_my_attacks.odin` | ✅ Complete | Attack option generation |
| `pro_enemy_attacks.odin` | ✅ Complete | Enemy attack analysis |
| `pro_move_execute.odin` | ✅ Complete | Movement execution layer |
| `pro_utils.odin` | ✅ Complete | Helper utilities |
| `battle.odin` | ✅ Complete | Monte Carlo battle simulator |

### 🔶 PARTIAL (needs completion)
| File | Status | Notes |
|------|--------|-------|
| `pro_combat_move_triplea_methods.odin` | 🔶 ~70% | Core algorithms exist, needs cleanup |
| `pro_noncombat_move.odin` | 🔶 ~50% | 3-pass algorithm exists, air landing partial |
| `pro_place.odin` | 🔶 ~30% | Basic stubs, needs full implementation |
| `pro_territory_manager.odin` | 🔶 ~20% | Partial structure |
| `pro_transport.odin` | 🔶 ~40% | Planning structures defined, execution incomplete |
| `pro_land_value.odin` | 🔶 ~60% | Needs review and alignment with Java |

### ❌ NOT IMPLEMENTED
| File | Status | Notes |
|------|--------|-------|
| `pro_matches.odin` | ❌ Empty | Predicates need data-oriented replacement |
| Carrier Landing Logic | ❌ Missing | Critical for air unit survival |
| Strategic Bombing Decision AI | ❌ Missing | When to bomb vs tactical attack |
| Naval Bombardment | ❌ Missing | Separate from sea combat |
| Blitz Reimplementation | ❌ Missing | Needs Java-style approach |

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

## Phase 1: Critical Fixes & Core Infrastructure

### 1.1 Refactor Unit_Info to Count-Based System (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Problem**: Uses `[dynamic]Unit_Info` with individual unit tracking - poor performance and OOP-like.

**Current Code** (lines 56-68):
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
    // Battle metrics
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
- `count_non_infantry_defenders()` - refactor to use counts
- `calculate_total_attack_power()` - refactor to use counts
- `calculate_total_defense_power()` - refactor to use counts
- `try_to_attack_territories_triplea()` - lines 645-850

---

### 1.2 Change Attack_Option.territory to Air_ID (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current**: `territory: Land_ID` - Only supports land attacks

**Required**: `territory: Air_ID` - Supports both land and sea attacks in unified array

**Procedures to Update**:
- All procedures in `pro_combat_move_triplea_methods.odin` that reference `option.territory`
- `prioritize_my_attack_options()` in `pro_my_attacks.odin`
- Helper procedures: `get_production_and_is_capital_triplea()`, `has_factory()`, etc.

---

### 1.3 Implement Blitz Logic (Java-Style) (HIGH PRIORITY)
**File**: `army.odin`, `pro_combat_move_triplea_methods.odin`

**Current Problem**: Blitz implementation is non-functional. Current `blitz_checks()` is a partial stub.

**Java Approach** (from `ProMatches.territoryCanMoveLandUnitsThrough()`):
```java
if (isCombatMove && Matches.unitCanBlitz().test(u) && TerritoryEffectHelper.unitKeepsBlitz(u, startTerritory)) {
    // Can move through blitzable territories (empty enemy land with no factory)
    alliedOrBlitzableMatch = alliedWithNoEnemiesMatch.or(territoryIsBlitzable(player, u));
}
```

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

2. **Update `add_valid_army_moves_2()`** to only allow tank moves through blitzable territories:
```odin
add_valid_army_moves_2 :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    army := to_army(gc.current_active_unit)
    if army != .TANK_2_MOVES do return
    
    for dst_land in mm.l2l_2away_via_land_bitset[src_land] {
        // Check if any midland is passable (allied OR blitzable)
        midlands := mm.l2l_2away_via_midland_bitset[src_land][dst_land]
        has_valid_path := false
        for mid in midlands {
            if mid in gc.friendly_owner {
                has_valid_path = true
                break
            }
            if is_territory_blitzable(gc, mid) {
                has_valid_path = true
                break
            }
        }
        if has_valid_path {
            add_land_to_valid_actions(gc, dst_land, gc.active_armies[src_land][army])
        }
    }
}
```

3. **Update Pro AI Combat Move** to plan blitz attacks:
- Add `find_blitz_attack_options()` procedure
- Track which territories will be blitzed for capture

---

### 1.4 Add Strategic Territory Value (gc.strategic_value) (MEDIUM PRIORITY)
**File**: `game_cache.odin`, new `pro_territory_value.odin`

**Add to Game_Cache**:
```odin
Game_Cache :: struct {
    // ... existing fields ...
    strategic_value: [Land_ID]f64,  // Pre-computed once per turn
    sea_strategic_value: [Sea_ID]f64,
}
```

**New File**: `pro_territory_value.odin`

**Procedures to Implement** (from `ProTerritoryValueUtils.java`):

1. `calculate_strategic_values :: proc(gc: ^Game_Cache)` - Main entry, called once per turn start
2. `find_max_land_mass_size :: proc() -> int` - Can be pre-computed in map_data
3. `find_enemy_capitals_and_factories_value :: proc(gc: ^Game_Cache, ...) -> [Land_ID]f64`
4. `find_land_strategic_value :: proc(gc: ^Game_Cache, t: Land_ID, ...) -> f64`
5. `find_sea_strategic_value :: proc(gc: ^Game_Cache, sea: Sea_ID, ...) -> f64`

**Integration Points**:
- Call `calculate_strategic_values(gc)` at start of `play_full_proai_turn()`
- Use `gc.strategic_value[]` in `proai_noncombat_move_phase()` for positioning
- Use `gc.strategic_value[]` in `prioritize_territories_to_defend_triplea()`

---

## Phase 2: Combat Move Completion

### 2.1 Complete populate_attack_options_triplea() (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Java Source**: `ProTerritoryManager.populateAttackOptions()` (lines 100-250)

**Currently Missing**:
1. Amphibious attack options - transports unloading
2. Bombardment options - cruisers/battleships
3. Multi-hop attack options for tanks (blitz paths)

**Procedures to Add**:
```odin
// Populate all attack options including amphib
populate_attack_options_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option)

// Find amphibious attack options
populate_amphib_attack_options :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option)

// Find bombardment support for land attacks
find_bombardment_options :: proc(gc: ^Game_Cache, target_land: Land_ID) -> Bombardment_Info
```

---

### 2.2 Complete determine_units_to_attack_with_triplea() (HIGH PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Java Source**: `ProCombatMoveAi.determineUnitsToAttackWith()` (lines 600-900)

**Current Status**: Stub exists but doesn't actually assign units

**Required Implementation**:
1. Sort available units by attack efficiency (attack power / cost)
2. Assign minimum units needed to achieve win threshold (60%)
3. Reserve some units for defense
4. Handle multi-territory attacks (don't overcommit)

**Key Procedures**:
```odin
// Main unit assignment
determine_units_to_attack_with_triplea :: proc(
    gc: ^Game_Cache, 
    options: ^[dynamic]Attack_Option,
    border_moves: ^[dynamic]Border_Move,
)

// Calculate minimum units needed to win
calculate_min_units_for_attack :: proc(
    gc: ^Game_Cache,
    option: ^Attack_Option,
    available_units: ^Attack_Unit_Counts,
) -> Attack_Unit_Counts

// Check if we can spare units for this attack
can_spare_units_for_attack :: proc(
    gc: ^Game_Cache,
    needed: Attack_Unit_Counts,
    already_committed: Attack_Unit_Counts,
) -> bool
```

---

### 2.3 Execute Combat Moves (execute_combat_moves_triplea) (MEDIUM PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Current Status**: Called but may not be fully working

**Java Source**: `ProCombatMoveAi.doMove()` (lines 153-167)

**Required Sub-procedures**:
```odin
execute_combat_moves_triplea :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool

// Execute each type of move
execute_land_combat_moves :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool
execute_air_combat_moves :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool  
execute_amphib_combat_moves :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool
execute_bombardment_moves :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool
execute_bombing_runs :: proc(gc: ^Game_Cache, options: ^[dynamic]Attack_Option) -> bool
```

---

### 2.4 Strategic Bombing Decision Logic (MEDIUM PRIORITY)
**File**: `pro_combat_move_triplea_methods.odin`

**Java Source**: `ProCombatMoveAi.determineTerritoriesThatCanBeBombed()` (lines 1600-1700)

**Current Status**: Bombers can fly to bombable factories but no AI decision logic

**Required Implementation**:
```odin
// Decide whether to use bomber for bombing vs tactical attack
determine_territories_that_can_be_bombed :: proc(gc: ^Game_Cache) -> [dynamic]Bombing_Target

Bombing_Target :: struct {
    factory_location: Land_ID,
    expected_damage:  f64,
    bombing_score:    f64,  // Must exceed MIN_BOMBING_SCORE (4)
}

// For each bomber, decide best bombing target
determine_best_bombing_attack_for_bomber :: proc(
    gc: ^Game_Cache,
    bomber_location: Land_ID,
    targets: ^[dynamic]Bombing_Target,
) -> Maybe(Bombing_Target)
```

**Decision Criteria** (from Java):
- `bombing_score = expected_damage * 2 - risk_of_losing_bomber`
- Must exceed `MIN_BOMBING_SCORE = 4`
- Avoid bombing low production factories with AA guns

---

## Phase 3: Non-Combat Move Completion

### 3.1 Complete proai_noncombat_move_phase() (HIGH PRIORITY)
**File**: `pro_noncombat_move.odin`

**Java Source**: `ProNonCombatMoveAi.doNonCombatMove()` (lines 71-180)

**Current Status**: Large commented-out section with partial implementation

**Required Implementation Order**:

1. **`find_units_that_cant_move()`** - Identify AA guns placed this turn, etc.
2. **`find_infra_units_that_can_move()`** - Find AA guns that should be repositioned
3. **`move_one_defender_to_land_territories_bordering_enemy()`** - Exists, needs testing
4. **`determine_if_move_territories_can_be_held()`** - Calculate defense viability
5. **`prioritize_defend_options()`** - Sort territories by defense priority
6. **`move_units_to_defend_territories()`** - Main defensive movement
7. **`move_units_to_best_territories()`** - Secondary positioning
8. **`move_infra_units()`** - AA gun repositioning

---

### 3.2 Implement Carrier Landing Detection (HIGH PRIORITY)
**File**: `pro_noncombat_move.odin`, `fighter.odin`

**Current Status**: `gc.has_carrier_space` exists but Pro AI doesn't use it intelligently

**Required Implementation**:
```odin
// Find best landing option for a fighter
find_best_fighter_landing :: proc(
    gc: ^Game_Cache,
    fighter_location: Air_ID,
    moves_remaining: int,
) -> Air_ID

// Check if carrier can move to pick up fighter
can_carrier_reach_fighter :: proc(
    gc: ^Game_Cache,
    carrier_sea: Sea_ID,
    fighter_air: Air_ID,
    carrier_moves: int,
    fighter_moves: int,
) -> bool

// Plan carrier movements to save fighters
plan_carrier_rescue_moves :: proc(gc: ^Game_Cache) -> [dynamic]Carrier_Move

Carrier_Move :: struct {
    carrier_from: Sea_ID,
    carrier_to:   Sea_ID,
    fighters_rescued: u8,
}
```

---

### 3.3 AA Gun Movement Logic (MEDIUM PRIORITY)
**File**: `pro_noncombat_move.odin`

**Java Source**: `ProNonCombatMoveAi.moveInfraUnits()` (lines 1900-2000)

**Required Implementation**:
```odin
// Move AA guns to valuable territories
move_aa_guns_to_valuable_territories :: proc(gc: ^Game_Cache) -> bool

// Find best AA gun destination
find_best_aa_destination :: proc(
    gc: ^Game_Cache,
    current_location: Land_ID,
) -> Maybe(Land_ID)
```

**Priority Order**:
1. Capital (if undefended by AA)
2. Major factories (production >= 3)
3. Territories under air threat
4. Minor factories

---

## Phase 4: Place Units Completion

### 4.1 Complete proai_place_units_phase() (MEDIUM PRIORITY)
**File**: `pro_place.odin`

**Java Source**: `ProPurchaseAi.place()` (lines 400-500)

**Current Status**: Basic stubs exist

**Required Implementation**:
```odin
proai_place_units_phase :: proc(gc: ^Game_Cache) -> bool

// Place defenders at threatened territories first
place_defenders_triplea :: proc(gc: ^Game_Cache, purchased_units: ^Purchased_Units) -> bool

// Place remaining units at best strategic locations
place_remaining_units :: proc(gc: ^Game_Cache, purchased_units: ^Purchased_Units) -> bool

// Place naval units
place_sea_units :: proc(gc: ^Game_Cache, purchased_units: ^Purchased_Units) -> bool
```

**Placement Priority**:
1. Capital (if threatened)
2. Factories under attack
3. Strategic territories (high `gc.strategic_value[]`)
4. Factories for next-turn offense

---

## Phase 5: Transport & Amphibious Logic

### 5.1 Complete Transport Planning (MEDIUM PRIORITY)
**File**: `pro_transport.odin`

**Java Source**: `ProTransportUtils.java` (all), `ProMoveUtils.calculateAmphibRoutes()`

**Current Status**: Data structures defined, execution incomplete

**Required Procedures**:
```odin
// Plan complete amphibious assault
plan_amphibious_assault :: proc(
    gc: ^Game_Cache,
    target_land: Land_ID,
) -> Maybe(Amphibious_Plan)

Amphibious_Plan :: struct {
    target:          Land_ID,
    transports_used: [Sea_ID]u8,       // How many transports from each sea
    units_loaded:    Attack_Unit_Counts,
    unload_sea:      Sea_ID,
    escort_ships:    [Sea_ID]u8,       // Combat ships to escort
}

// Find optimal units to load
find_optimal_load :: proc(
    gc: ^Game_Cache,
    transport_sea: Sea_ID,
    capacity: int,
) -> [dynamic]Unit_Load_Info

// Execute transport loading
execute_transport_load :: proc(
    gc: ^Game_Cache,
    plan: ^Amphibious_Plan,
) -> bool

// Execute transport movement
execute_transport_move :: proc(
    gc: ^Game_Cache,
    plan: ^Amphibious_Plan,
) -> bool
```

---

### 5.2 Multi-Transport Coordination (LOW PRIORITY)
**File**: `pro_transport.odin`

**Required for**: Large-scale amphibious assaults (D-Day style)

```odin
// Coordinate multiple transports for single assault
plan_multi_transport_assault :: proc(
    gc: ^Game_Cache,
    target_land: Land_ID,
    min_attackers: Attack_Unit_Counts,
) -> [dynamic]Amphibious_Plan
```

---

## Phase 6: Data Structure Refinements

### 6.1 Eliminate Predicates (Replace with Data-Oriented Checks) (LOW PRIORITY)
**File**: `pro_matches.odin` (currently empty)

**Philosophy**: Instead of predicates like `territoryIsEnemyOrCantBeHeld(player)`, use bitset operations:

```odin
// Instead of: ProMatches.territoryIsEnemyOrCantBeHeld(player, cantBeHeld)
// Use: (~gc.friendly_owner | cant_be_held_bitset)

// Common computed bitsets to add to Game_Cache:
Game_Cache :: struct {
    // ... existing ...
    
    // Pre-computed territory classifications
    enemy_land:               Land_Bitset,  // Land owned by enemies
    threatened_land:          Land_Bitset,  // Land that could be attacked
    contested_sea:            Sea_Bitset,   // Sea zones with both sides' units
    safe_landing_zones:       Air_Bitset,   // Where planes can land
}

// Refresh these at turn start
refresh_territory_classifications :: proc(gc: ^Game_Cache)
```

---

### 6.2 Comment Updates (LOW PRIORITY)

**Files with outdated comments**:

1. **`army.odin`** lines 74-88 - Update to clarify blitz is handled separately via `blitz_checks()`

2. **`game_state.odin`** lines 1-36 - Add clarification about turn rotation repopulating active arrays

3. **`pro_combat_move_triplea_methods.odin`** line 3901 - Update strategic bombing status

---

## Phase 7: Testing & Validation

### 7.1 Unit Tests Required
**File**: New `tests/pro_ai_test.odin`

```odin
// Test attack option generation
test_generate_attack_options :: proc()

// Test battle simulation accuracy
test_battle_simulation :: proc()

// Test blitz path finding
test_blitz_paths :: proc()

// Test carrier landing detection
test_carrier_landing :: proc()

// Test full Pro AI turn execution
test_full_proai_turn :: proc()
```

### 7.2 Integration Tests
```odin
// Run multiple Pro AI turns and verify game state consistency
test_multi_turn_proai :: proc()

// Benchmark Pro AI turn time (target: < 1ms per turn)
benchmark_proai_turn :: proc()
```

---

## Implementation Priority Order

### Sprint 1 (Highest Priority - Blocking Issues)
1. ✅ Understand current state (DONE - this document)
2. 🔲 1.2 - Change Attack_Option.territory to Air_ID
3. 🔲 1.1 - Refactor Unit_Info to count-based (partial - just Attack_Option)
4. 🔲 1.3 - Implement Blitz Logic (Java-style)
5. 🔲 3.2 - Carrier Landing Detection

### Sprint 2 (High Priority - Core Functionality)
6. 🔲 2.1 - Complete populate_attack_options_triplea()
7. 🔲 2.2 - Complete determine_units_to_attack_with_triplea()
8. 🔲 2.3 - Execute Combat Moves
9. 🔲 3.1 - Complete proai_noncombat_move_phase()

### Sprint 3 (Medium Priority - Completion)
10. 🔲 1.4 - Add Strategic Territory Value
11. 🔲 2.4 - Strategic Bombing Decision Logic
12. 🔲 3.3 - AA Gun Movement Logic
13. 🔲 4.1 - Complete proai_place_units_phase()
14. 🔲 5.1 - Complete Transport Planning

### Sprint 4 (Lower Priority - Polish)
15. 🔲 5.2 - Multi-Transport Coordination
16. 🔲 6.1 - Eliminate Predicates
17. 🔲 6.2 - Comment Updates
18. 🔲 7.1 - Unit Tests
19. 🔲 7.2 - Integration Tests

### Future (Post-Core Completion)
20. 🔲 Retreat Logic (ProRetreatAi.java)
21. 🔲 Turn Simulation (ProSimulateTurnUtils.java)
22. 🔲 Alpha-Zero Integration

---

## Appendix A: Java to Odin Method Mapping

### ProCombatMoveAi.java → pro_combat_move_triplea_methods.odin

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `doCombatMove()` | `proai_combat_move_phase()` | 🔶 Partial |
| `doMove()` | `execute_combat_moves_triplea()` | 🔶 Stub |
| `prioritizeAttackOptions()` | `prioritize_attack_options_triplea()` | ✅ Done |
| `determineTerritoriesToAttack()` | `determine_territories_to_attack_triplea()` | ✅ Done |
| `determineTerritoriesThatCanBeHeld()` | `determine_territories_that_can_be_held_triplea()` | ✅ Done |
| `removeTerritoriesThatArentWorthAttacking()` | `remove_territories_that_arent_worth_attacking_triplea()` | ✅ Done |
| `moveOneDefenderToLandTerritoriesBorderingEnemy()` | `move_one_defender_to_land_territories_bordering_enemy_triplea()` | ✅ Done |
| `removeTerritoriesWhereTransportsAreExposed()` | `remove_territories_where_transports_are_exposed_triplea()` | ✅ Done |
| `determineUnitsToAttackWith()` | `determine_units_to_attack_with_triplea()` | ❌ Stub |
| `tryToAttackTerritories()` | `try_to_attack_territories_triplea()` | 🔶 Partial |
| `determineTerritoriesThatCanBeBombed()` | N/A | ❌ Missing |
| `determineBestBombingAttackForBomber()` | N/A | ❌ Missing |
| `checkContestedSeaTerritories()` | `check_contested_sea_territories_triplea()` | ❌ Stub |

### ProNonCombatMoveAi.java → pro_noncombat_move.odin

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `doNonCombatMove()` | `proai_noncombat_move_phase()` | 🔶 Partial |
| `simulateNonCombatMove()` | N/A | ❌ Missing |
| `findUnitsThatCantMove()` | N/A | ❌ Missing |
| `findInfraUnitsThatCanMove()` | N/A | ❌ Missing |
| `moveOneDefenderToLandTerritoriesBorderingEnemy()` | Exists | ✅ Done |
| `determineIfMoveTerritoriesCanBeHeld()` | N/A | ❌ Missing |
| `prioritizeDefendOptions()` | N/A | ❌ Missing |
| `moveUnitsToDefendTerritories()` | N/A | ❌ Missing |
| `moveUnitsToBestTerritories()` | N/A | ❌ Missing |
| `moveInfraUnits()` | N/A | ❌ Missing |

### ProPurchaseAi.java → pro_purchase.odin

| Java Method | Odin Procedure | Status |
|-------------|----------------|--------|
| `repair()` | `repair_factories_triplea()` | ✅ Done |
| `purchase()` | `purchase_triplea()` | ✅ Done |
| `prioritizeTerritoriesToDefend()` | `prioritize_territories_to_defend_triplea()` | ✅ Done |
| `purchaseDefenders()` | `purchase_defenders_triplea()` | ✅ Done |
| `prioritizeLandTerritories()` | `prioritize_land_territories_triplea()` | ✅ Done |
| `purchaseAaUnits()` | `purchase_aa_units_triplea()` | ✅ Done |
| `purchaseLandUnits()` | `purchase_land_units_triplea()` | ✅ Done |
| `purchaseFactory()` | `purchase_factory_triplea()` | ✅ Done |
| `prioritizeSeaTerritories()` | `prioritize_sea_territories_triplea()` | ✅ Done |
| `purchaseSeaAndAmphibUnits()` | `purchase_sea_and_amphib_units_triplea()` | ✅ Done |
| `place()` | `proai_place_units_phase()` | 🔶 Stub |

---

## Appendix B: Key Data Structures Reference

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

// Strategic values
pro_value:                 [Land_ID]f64  // To be renamed strategic_value
```

### To Add
```odin
// Strategic territory values
strategic_value:           [Land_ID]f64
sea_strategic_value:       [Sea_ID]f64

// Combat planning
enemy_land:                Land_Bitset
threatened_land:           Land_Bitset
safe_landing_zones:        Air_Bitset
```

---

## Appendix C: Low Priority Review Items

### pro_land_value.odin Review
The `find_land_value()` function needs review to align with Java's `ProTerritoryValueUtils.findLandValue()`. Current implementation appears to be a hybrid that doesn't match Java exactly. 

**Action**: Compare formulas line-by-line and document intentional differences vs bugs.

---

*Document created: December 6, 2025*
*Last updated: December 6, 2025*
