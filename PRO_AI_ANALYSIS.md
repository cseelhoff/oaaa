# Pro AI Implementation Analysis - Deep Dive

## Executive Summary

After thorough analysis of TripleA's Java Pro AI source code compared to our Odin implementation, I've identified several missing components and areas for refinement. This document categorizes findings into three priority levels.

---

## Part 1: Missing Critical Components

### 1.1 ProRetreatAi - **HIGH PRIORITY** ❌ NOT IMPLEMENTED
**Java File**: `ProRetreatAi.java`
**Status**: Completely missing from Odin implementation

**Purpose**: Makes tactical retreat decisions during combat
- Calculates TUV swing if battle continues vs retreats
- Evaluates whether territory value justifies staying
- Chooses optimal retreat path (prefer capital, then strongest defense)
- Handles submarine submerge decisions
- Manages amphibious assault retreat rules

**Impact**: Currently combat phase stub just resolves all battles. Pro AI should intelligently retreat from losing battles.

**Implementation Needed**:
```odin
// In pro_turn.odin
proai_combat_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
    // Resolve sea battles with retreat logic
    resolve_sea_battles_with_retreat_ai(gc) or_return
    
    // Unload surviving transports
    unload_transports(gc) or_return
    
    // Resolve land battles with retreat logic
    resolve_land_battles_with_retreat_ai(gc) or_return
    
    return true
}
```

**Key Algorithm** (from ProRetreatAi.java lines 45-142):
1. Calculate battle results if continue fighting
2. Estimate TUV swing + territory value
3. If battle value negative, retreat to:
   - Capital (if available)
   - Territory with highest defense strength
4. For submarine battles, calculate submerge vs retreat value

---

## Part 2: Missing Data Structures and Utilities

### 2.1 ProTerritoryManager - **HIGH PRIORITY** ⚠️ PARTIAL
**Java File**: `data/ProTerritoryManager.java`
**Current Status**: Basic Pro_Data exists, but missing manager logic

**Purpose**: Centralized territory analysis and caching
- Populates attack/defense options for all territories
- Caches battle calculations to avoid recomputation
- Manages enemy attack threat assessments
- Tracks unit movement options

**What's Missing**:
- `populateEnemyAttackOptions()` - Critical for defense planning
- `populateDefenseOptions()` - Used throughout noncombat move
- `populateAttackOptions()` - Used in combat move phase
- Caching layer for battle results

**Impact**: Current implementation recalculates everything repeatedly, very inefficient

---

### 2.2 ProBattleUtils - **HIGH PRIORITY** ⚠️ BASIC ONLY
**Java File**: `util/ProBattleUtils.java`
**Current Status**: Have `estimate_attack_power`, `estimate_defense_power` but missing many utilities

**Missing Functions**:
- `estimateStrengthDifference()` - Compare attacker vs defender strength
- `isNeutralized()` - Check if units are neutralized in battle
- `getAlliedUnits()` - Get allied units that can participate
- `getBombardingUnits()` - Naval bombardment support
- `getDefendersAfterRetreat()` - Post-retreat defensive strength

---

### 2.3 ProTransportUtils - **HIGH PRIORITY** ❌ NOT IMPLEMENTED
**Java File**: `util/ProTransportUtils.java`
**Status**: Completely missing

**Purpose**: Manages amphibious assault logistics
- Finds transports that can load units
- Calculates transport capacity and range
- Plans multi-turn transport routes
- Handles transport staging for future assaults

**Why Critical**: Combat move and noncombat move heavily rely on transport planning

**OAAA Integration Notes**:
- OAAA has sophisticated transport state machine (transport.odin)
- Need to adapt Java logic to work with OAAA's transport system
- States: TRANS_EMPTY, TRANS_1I_2_MOVES, TRANS_UNLOADED, etc.

---

### 2.4 ProMoveUtils - **MEDIUM PRIORITY** ⚠️ BASIC ONLY
**Java File**: `util/ProMoveUtils.java`
**Current Status**: Have basic adjacency checks, missing movement validation

**Missing Functions**:
- `calculateMovementRange()` - How far units can move
- `validateMove()` - Check if move is legal
- `findPath()` - Shortest path between territories
- `canReachTerritory()` - Comprehensive reachability check

**OAAA Integration**: Need to use existing `mm.l2l_1away_via_land`, `mm.s2s_1away_via_sea` structures

---

### 2.5 ProSortMoveOptionsUtils - **MEDIUM PRIORITY** ❌ NOT IMPLEMENTED
**Java File**: `util/ProSortMoveOptionsUtils.java`
**Status**: Missing

**Purpose**: Sophisticated unit prioritization and sorting
- Sort units by defensive value
- Sort territories by strategic importance
- Prioritize movement options

**Current Workaround**: Using simple `slice.sort_by` in Odin code

---

### 2.6 ProPurchaseValidationUtils - **LOW PRIORITY** ❌ NOT IMPLEMENTED
**Java File**: `util/ProPurchaseValidationUtils.java`
**Status**: Missing

**Purpose**: Validates purchase decisions before committing
- Checks production capacity
- Validates unit placement rules
- Ensures resource availability

**Current Status**: Basic validation in purchase phase, could be more robust

---

## Part 3: Algorithm Refinements Needed

### 3.1 Combat Move Phase - NEEDS REFINEMENT

**Current Implementation** (pro_combat_move.odin):
- ✅ Finds attack options
- ✅ Prioritizes by strategic value
- ⚠️ Unit assignment is stub/simplified
- ❌ No transport loading logic
- ❌ No bombardment support
- ❌ No airbase consideration

**Java Reference** (ProCombatMoveAi.java lines 849-1158):
```java
determineUnitsToAttackWith(prioritizedTerritories, alreadyMovedUnits) {
    // 1. Find max defenders in territories
    // 2. Add air units to attacks
    // 3. Add land units to attacks  
    // 4. Add sea units and transports
    // 5. Validate each attack has sufficient strength
    // 6. Remove units that don't have enough moves
}
```

**Recommended Additions**:
1. Implement proper unit assignment algorithm
2. Add transport loading for amphibious assaults
3. Include bombardment from battleships/cruisers
4. Check unit movement range constraints
5. Validate attacks before executing

---

### 3.2 Non-Combat Move Phase - NEEDS REFINEMENT

**Current Implementation** (pro_noncombat_move.odin):
- ✅ Finds defense targets
- ✅ Prioritizes by strategic value
- ⚠️ Move execution is placeholder
- ❌ No carrier landing logic
- ❌ No transport repositioning
- ❌ No unit consolidation

**Java Reference** (ProNonCombatMoveAi.java lines 709-1204):
```java
moveUnitsToDefendTerritories(isCombatMove, prioritizedTerritories, enemyDistance) {
    // For each territory needing defense:
    // 1. Find units that can move there
    // 2. Calculate movement cost
    // 3. Prefer units already nearby
    // 4. Move until territory can hold
}
```

**Key Missing Feature**: Unit movement execution
- Need to actually modify `gc.idle_armies`, `gc.active_armies`
- Track units that have moved (can't move twice)
- Handle multi-step movements

---

### 3.3 Place Phase - ADEQUATE BUT CAN IMPROVE

**Current Implementation** (pro_place.odin):
- ✅ Basic structure matches Java
- ⚠️ Calls existing `buy_units()` and `buy_factory()`
- ❌ Not using calculated priorities
- ❌ Not respecting `builds_left` properly

**Java Reference** (ProPurchaseAi.java lines 448-576):
```java
place(purchaseTerritories, placeDelegate) {
    // 1. Clear units to consume
    // 2. Place purchased land units (by territory priority)
    // 3. Place purchased sea units
    // 4. Find remaining place territories
    // 5. Place defenders at threatened locations
    // 6. Place remaining units at strategic locations
}
```

**Improvement Needed**:
- Actually use `Placement_Option` priorities
- Place defenders first at threatened factories
- Place remaining units by strategic value
- Don't just call generic `buy_units()`

---

## Part 4: Integration with OAAA Systems

### 4.1 Map Graph Integration - **CRITICAL**

**OAAA Has Rich Map Data**:
```odin
// From map_data.odin / land.odin / sea.odin
mm.l2l_1away_via_land[Land_ID] -> SA_Adjacent_L2L  // Adjacent land connections
mm.l2l_2away_via_midland_bitset[Land_ID][Land_ID] -> Land_Bitset  // 2-move paths
mm.s2s_1away_via_sea[Canal_States][Sea_ID] -> Sea_Bitset  // Sea connections
mm.l2s_1away_via_land[Land_ID] -> SA_Adjacent_L2S  // Coastal connections
mm.air_distances[Air_ID][Air_ID] -> u8  // Air movement costs
```

**Current Pro AI Usage**: Mostly placeholder comments like "// Simplified - would use map graph"

**Action Required**:
1. Replace all `is_adjacent_to_friendly()` stubs with actual map graph queries
2. Implement `find_units_in_range(from: Land_ID, range: int)` using bitsets
3. Use `mm.l2l_2away_via_midland_bitset` for 2-move unit pathfinding
4. Leverage `mm.air_distances` for fighter/bomber range calculations

---

### 4.2 Unit Movement Execution - **CRITICAL**

**OAAA Movement System**:
- `gc.idle_armies[Land_ID][Player_ID][Idle_Army]` -> idle units
- `gc.active_armies[Land_ID][Player_ID][Active_Army]` -> moved units
- State transitions via action execution

**Current Pro AI**: Calculates moves but doesn't execute them

**Action Required**:
1. Create `execute_land_move(gc, from: Land_ID, to: Land_ID, army_type: Idle_Army, count: u8)`
2. Create `execute_air_move(gc, from: Air_ID, to: Air_ID, plane_type: Idle_Plane, count: u8)`
3. Create `execute_sea_move(gc, from: Sea_ID, to: Sea_ID, ship_type: Idle_Ship, count: u8)`
4. Track moved units to prevent double-moving

---

### 4.3 Carrier Landing Logic - **HIGH PRIORITY**

**OAAA Carrier System** (from carrier.odin):
```odin
Active_Carrier :: enum {
    CARRIER_2_MOVES,
    CARRIER_0_MOVES,
}

Idle_Carrier :: enum {
    CARRIER,
}

// Carriers can hold fighters
gc.active_ships[Sea_ID][Active_Carrier]
```

**Pro AI Needs**:
1. Track carrier capacity when planning fighter moves
2. Ensure fighters can land on carriers after combat
3. Calculate carrier + fighter combined range
4. Prevent overloading carriers

**Java Reference**: ProTransportUtils and ProNonCombatMoveAi handle this extensively

---

### 4.4 Transport Loading/Unloading - **HIGH PRIORITY**

**OAAA Transport System** (from transport.odin):
```odin
Active_Ship :: enum {
    TRANS_EMPTY_2_MOVES,
    TRANS_1I_2_MOVES,  // 1 infantry, 2 moves left
    TRANS_1I_UNLOADED,  // Already unloaded
    // ... many more states
}

Trans_After_Loading[Idle_Army][Active_Ship] -> Active_Ship
```

**Pro AI Needs**:
1. Find transports with capacity
2. Load units for amphibious assaults
3. Move loaded transports to target
4. Unload at destination
5. Track transport states (can't unload twice)

**Current Status**: Combat move mentions transports but doesn't implement loading

---

## Part 5: Existing OAAA Functions to Leverage

### 5.1 Combat System ✅
```odin
// From combat.odin
resolve_sea_battles(gc) 
resolve_land_battles(gc)
unload_transports(gc)
```
**Pro AI Integration**: Can use these directly in combat phase

---

### 5.2 Air Movement ✅
```odin
// From air.odin / fighter.odin / bomber.odin
land_remaining_fighters(gc)
land_remaining_bombers(gc)
// Plus sophisticated air distance calculations
```
**Pro AI Integration**: Already using in non-combat phase

---

### 5.3 Purchase System ✅
```odin
// From purchase.odin
buy_units(gc)
buy_factory(gc)
```
**Pro AI Integration**: Using in purchase/place phases, but could be more sophisticated

---

### 5.4 Income Collection ✅
```odin
// From engine.odin
collect_money(gc)
reset_units_fully(gc)
rotate_turns(gc)
```
**Pro AI Integration**: Already using in end turn phase

---

## Part 6: Priority Action Plan

### Phase 1: Core Missing Components (Week 1-2)
1. ✅ **DONE**: Pro placement phase (pro_place.odin)
2. ⚠️ **IN PROGRESS**: Refine combat move unit assignment
3. ❌ **TODO**: Implement ProRetreatAi (pro_retreat.odin)
4. ❌ **TODO**: Add ProTransportUtils basics

### Phase 2: Movement Execution (Week 3)
5. ❌ **TODO**: Implement actual unit movement in combat_move
6. ❌ **TODO**: Implement actual unit movement in noncombat_move
7. ❌ **TODO**: Integrate with OAAA map graph for pathfinding
8. ❌ **TODO**: Add carrier landing logic

### Phase 3: Utilities and Refinement (Week 4)
9. ❌ **TODO**: Build ProTerritoryManager caching layer
10. ❌ **TODO**: Expand ProBattleUtils with missing functions
11. ❌ **TODO**: Add ProMoveUtils movement validation
12. ❌ **TODO**: Implement unit tracking to prevent double-moves

### Phase 4: Advanced Features (Future)
13. ❌ **TODO**: ProScrambleAi (if OAAA has scrambling)
14. ❌ **TODO**: ProPoliticsAi (if OAAA has politics)
15. ❌ **TODO**: ProTechAi (if OAAA has technology)
16. ❌ **TODO**: Sophisticated bid logic

---

## Part 7: Specific Code Examples Needed

### Example 1: Map Graph Integration
```odin
// CURRENT (pro_combat_move.odin line 190):
is_adjacent_to_friendly :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
    // TODO: Use actual map graph
    return false
}

// SHOULD BE:
is_adjacent_to_friendly :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
    // Check adjacent lands
    for adjacent in sa.slice(&mm.l2l_1away_via_land[territory]) {
        if gc.owner[adjacent] == gc.cur_player || 
           mm.team[gc.owner[adjacent]] == mm.team[gc.cur_player] {
            return true
        }
    }
    // Check adjacent seas with friendly ships
    for adjacent_sea in sa.slice(&mm.l2s_1away_via_land[territory]) {
        if has_friendly_ships(gc, adjacent_sea) {
            return true
        }
    }
    return false
}
```

### Example 2: Unit Movement Execution
```odin
// CURRENT (pro_noncombat_move.odin line 278):
move_units_to_defense :: proc(targets: ^[dynamic]Defense_Target, gc: ^Game_Cache, pro_data: ^Pro_Data) {
    // For each high-priority target
    // TODO: Implement actual unit movement
}

// SHOULD BE:
move_units_to_defense :: proc(targets: ^[dynamic]Defense_Target, gc: ^Game_Cache, pro_data: ^Pro_Data) {
    for &target in targets {
        if target.defense_needed <= 0 do continue
        
        // Find nearby friendly territories
        for land in Land_ID {
            if gc.owner[land] != gc.cur_player do continue
            if land == target.territory do continue
            
            // Check if adjacent or within 2 moves
            can_reach := land in mm.l2l_1away_via_land[target.territory] ||
                        target.territory in mm.l2l_2away_via_midland_bitset[land]
            if !can_reach do continue
            
            // Move infantry to defend
            inf_available := gc.idle_armies[land][gc.cur_player][.INF]
            inf_to_move := min(inf_available, u8(target.defense_needed / 2))
            if inf_to_move > 0 {
                gc.idle_armies[land][gc.cur_player][.INF] -= inf_to_move
                gc.idle_armies[target.territory][gc.cur_player][.INF] += inf_to_move
                target.defense_needed -= f64(inf_to_move) * 2
            }
        }
    }
}
```

### Example 3: Retreat Logic
```odin
// NEW FILE: pro_retreat.odin
proai_should_retreat :: proc(
    gc: ^Game_Cache,
    battle_territory: Land_ID,
    attackers: []Unit_Info,
    defenders: []Unit_Info,
) -> bool {
    // Calculate TUV of both sides
    attacker_tuv := calculate_unit_tuv(&attackers)
    defender_tuv := calculate_unit_tuv(&defenders)
    
    // Estimate battle outcome
    result := estimate_battle_result(gc, battle_territory, attackers, defenders)
    
    // Calculate TUV swing
    tuv_swing := result.attacker_losses - result.defender_losses
    
    // Add territory value
    territory_value := f64(0)
    if result.attacker_wins {
        prod := mm.production[battle_territory]
        territory_value = f64(prod) * 2.0
    }
    
    battle_value := tuv_swing + territory_value
    
    // Retreat if expected loss
    return battle_value < 0
}
```

---

## Part 8: Performance Considerations

### 8.1 Current Performance Characteristics
- Pro AI should be 10-100x faster than MCTS tree search
- Target: Complete Pro AI turn in <100ms
- Current: Likely slower due to missing caching

### 8.2 Optimization Opportunities
1. **Cache Battle Results**: ProTerritoryManager should cache calculations
2. **Use Bitsets**: OAAA has efficient bitset operations, use them
3. **Limit Search Depth**: Don't consider all possibilities, prune early
4. **Incremental Updates**: Update territory values incrementally, not full recalc

---

## Conclusion

**Implementation is 60% Complete**:
- ✅ Core data structures (Pro_Data, Pro_Territory)
- ✅ Purchase phase algorithm
- ✅ Combat move planning (without execution)
- ✅ Non-combat move planning (without execution)
- ✅ Place phase structure
- ✅ Basic utility functions

**Critical Gaps**:
1. Retreat AI (needed for combat phase)
2. Unit movement execution (both combat and noncombat)
3. Map graph integration (currently all stubs)
4. Transport/carrier logistics
5. Territory manager caching layer

**Next Steps**:
1. Implement retreat logic for combat phase
2. Add real unit movement execution
3. Integrate OAAA map graph throughout
4. Build transport planning utilities
5. Add comprehensive testing

The foundation is solid, but Pro AI needs movement execution and retreat logic to be functional for MCTS rollouts.
