# Pro AI Implementation - Quick Reference

## Question 1: Overlooked Java Components

### Missing Utility Classes
5. **ProTransportUtils.java** - Amphibious assault planning ✅ **IMPLEMENTED** (pro_transport.odin)
   - ✅ **NEW** High-level transport planning (`find_transports_for_target`, `create_transport_plan`)
   - ✅ **NEW** Unit loading optimization (`select_units_to_load` - by attack efficiency or cost)
   - ✅ **NEW** Multi-step path planning (`calculate_transport_path` - with blockade checking)
   - ✅ **NEW** Loadable unit collection (`find_loadable_units_near_sea` - infantry/artillery/tanks)
   - ✅ Transport reach detection (with 0/1/2 move range checking)
   - ✅ Transport safety validation (escort requirements, blockade checking)
   - ✅ Multi-move path validation (intermediate sea zone checking)
   - ✅ Basic transport detection (all cargo states)
   - ⏳ **Execution Layer Still Needed**:
     - State transition execution (loading units onto transports)
     - Movement execution (moving loaded transports)
     - Unloading execution (placing units on target territory)
   - **What We Now Have**:
     - Complete planning algorithm from Java ProTransportUtils + ProMoveUtils
     - Unit selection by attack value / transport cost
     - Path calculation with safety validation
     - Transport capacity management
   - **What's Next**: Execute the plans (modify game_cache to load/move/unload)
6. **ProSortMoveOptionsUtils.java** - Unit/territory prioritization ❌ 
7. **ProPurchaseValidationUtils.java** - Purchase validation ❌
8. **ProBattleUtils.java** - PARTIAL (missing many functions)
9. **ProMoveUtils.java** - PARTIAL (missing movement validation)

### Missing Data Structures
10. **ProTerritoryManager.java** - PARTIAL (missing caching & analysis)
11. **ProResourceTracker.java** - Not checked yet
12. **ProOtherMoveOptions.java** - Not checked yet

---

## Question 2: Functions Still Needed

### You Listed These 5:

#### 1. Map Graph Integration ✅ **NOW INTEGRATED**
**Status**: OAAA has excellent map graph system, Pro AI NOW USES IT

**OAAA Already Has** (in map_data.odin, land.odin, sea.odin):
```odin
mm.l2l_1away_via_land[Land_ID] -> SA_Adjacent_L2L  // 1-move land connections
mm.l2l_2away_via_midland_bitset[Land_ID][Land_ID] -> Land_Bitset  // 2-move land paths
mm.s2s_1away_via_sea[Canal_States][Sea_ID] -> Sea_Bitset  // Sea adjacency
mm.l2s_1away_via_land[Land_ID] -> SA_Adjacent_L2S  // Coast connections
mm.air_distances[Air_ID][Air_ID] -> u8  // Air movement costs
mm.a2a_within_4_moves[Air_ID] -> Air_Bitset  // 4-move air range
```

**✅ NOW IMPLEMENTED** (in pro_move_validate.odin):
```odin
// Land unit validation
can_land_units_move :: proc(gc: ^Game_Cache, src: Land_ID, dst: Land_ID, max_moves: int) -> bool
find_territories_within_range :: proc(gc: ^Game_Cache, src: Land_ID, max_moves: int) -> [dynamic]Land_ID

// Air unit validation
can_air_reach :: proc(gc: ^Game_Cache, src: Air_ID, dst: Air_ID, max_range: int) -> bool
can_air_reach_bitset :: proc(gc: ^Game_Cache, src: Air_ID, dst: Air_ID, max_range: int) -> bool
find_air_territories_within_range :: proc(gc: ^Game_Cache, src: Air_ID, max_range: int) -> [dynamic]Air_ID
can_fighter_land :: proc(gc: ^Game_Cache, dst: Air_ID) -> bool
can_bomber_land :: proc(gc: ^Game_Cache, dst: Air_ID) -> bool

// Sea unit validation
can_sea_reach :: proc(gc: ^Game_Cache, src: Sea_ID, dst: Sea_ID, max_moves: int, ship_type: Active_Ship) -> bool
can_transport_reach :: proc(gc: ^Game_Cache, src: Sea_ID, dst: Sea_ID, max_moves: int) -> bool
find_seas_within_range :: proc(gc: ^Game_Cache, src: Sea_ID, max_moves: int) -> [dynamic]Sea_ID
```

**✅ INTEGRATED** (in pro_move_execute.odin):
- `execute_land_move()` now calls `can_land_units_move()` before executing
- `execute_air_move()` now calls `can_air_reach()` before executing
- `execute_sea_move()` now calls `can_sea_reach()` or `can_transport_reach()` before executing

**Benefits**:
- ✅ Pro AI only attempts legal moves
- ✅ Validates paths aren't blocked (enemy territories, blockades)
- ✅ Respects canal states (open/closed canals affect movement)
- ✅ Enforces escort requirements (transports need combat ships)
- ✅ Clear debug messages when moves fail validation

**Files**:
- `src/pro_move_validate.odin` - Core validation layer (595 lines)
- `src/pro_move_execute.odin` - Updated to use validation (522 lines)

---

#### 1. Map Graph Integration ⚠️ **PARTIALLY EXISTS**
**Status**: OAAA has excellent map graph system, but Pro AI doesn't use it yet

**OAAA Already Has** (in map_data.odin, land.odin, sea.odin):
```odin
mm.l2l_1away_via_land[Land_ID] -> SA_Adjacent_L2L  // 1-move land connections
mm.l2l_2away_via_midland_bitset[Land_ID][Land_ID] -> Land_Bitset  // 2-move land paths
mm.s2s_1away_via_sea[Canal_States][Sea_ID] -> Sea_Bitset  // Sea adjacency
mm.l2s_1away_via_land[Land_ID] -> SA_Adjacent_L2S  // Coast connections
mm.air_distances[Air_ID][Air_ID] -> u8  // Air movement costs
mm.a2a_within_4_moves[Air_ID] -> Air_Bitset  // 4-move air range
```

**What Pro AI Needs to Do**: Replace placeholder adjacency functions with actual map graph queries

**Files to Update**:
- pro_combat_move.odin: `is_adjacent_to_friendly()`, `can_reach_territory()`
- pro_noncombat_move.odin: `find_best_noncombat_move()`
- pro_utils.odin: `count_adjacent_enemy_units()`
- pro_place.odin: `calculate_placement_threat()`

---

#### 2. Unit Movement Execution ❌ **DOES NOT EXIST**
**Status**: Pro AI plans moves but doesn't execute them

**OAAA Has Basic Actions** (in action.odin, army.odin):
- Actions for each unit type and destination
- State transitions via action bitsets
- But no "move N units from A to B" helper

**What's Needed**: Helper functions to modify game state
```odin
execute_infantry_move :: proc(gc: ^Game_Cache, from: Land_ID, to: Land_ID, count: u8) {
    gc.idle_armies[from][gc.cur_player][.INF] -= count
    // Check if adjacent (1 move) or need 2 moves
    if to in mm.l2l_1away_via_land[from] {
        gc.idle_armies[to][gc.cur_player][.INF] += count
    } else {
        // 2 moves - becomes active unit with moves=1
        // More complex...
    }
}
```

**Files to Create**:
- `pro_movement.odin` - Movement execution helpers
- Functions: `execute_land_move()`, `execute_air_move()`, `execute_sea_move()`

---

#### 3. Carrier Landing Logic ⚠️ **PARTIALLY EXISTS**
**Status**: OAAA has carrier system, Pro AI needs to track capacity

**OAAA Already Has** (in carrier.odin):
```odin
Active_Carrier :: enum {
    CARRIER_2_MOVES,  // Can move 2 more times
    CARRIER_0_MOVES,  // Used all moves
}

Idle_Carrier :: enum {
    CARRIER,  // Idle carrier
}

// Carriers tracked in:
gc.active_ships[Sea_ID][Active_Carrier] -> count
gc.idle_ships[Sea_ID][Idle_Carrier] -> count
```

**What Pro AI Needs**:
1. Track how many fighters each carrier can hold (capacity = 2)
2. When moving fighters, check if carrier has space
3. Calculate combined carrier+fighter range
4. Ensure fighters land on carriers or land after combat

**Similar Existing Code** (in fighter.odin, bomber.odin):
```odin
land_remaining_fighters(gc) -> already handles basic landing
land_remaining_bombers(gc) -> similar
```

**What's Missing**:
- Carrier capacity tracking: `get_carrier_capacity(gc, sea_zone: Sea_ID) -> int`
- Combined range calc: `can_fighter_reach_with_carrier(gc, from, to) -> bool`
- Smart landing: `land_fighters_on_carriers_or_land(gc, fighters, sea_zone)`

**Files to Update**:
- pro_utils.odin - Add carrier capacity functions
- pro_noncombat_move.odin - Use carrier logic in landing phase

---

#### 4. Transport Positioning ⚠️ **PARTIALLY IMPLEMENTED**
**Status**: OAAA has sophisticated transport system, Pro AI now has reach checking but not assault execution

**OAAA Already Has** (in transport.odin):
```odin
Active_Ship :: enum {
    TRANS_EMPTY_2_MOVES,     // Empty, 2 moves left
    TRANS_1I_2_MOVES,        // 1 infantry loaded, 2 moves left
    TRANS_1I_1_MOVES,        // 1 infantry loaded, 1 move left
    TRANS_1I_UNLOADED,       // Already unloaded this turn
    TRANS_1A_2_MOVES,        // 1 artillery loaded
    TRANS_1T_2_MOVES,        // 1 tank loaded
    TRANS_2I_2_MOVES,        // 2 infantry loaded
    // ... many more combinations
}

Trans_After_Loading[Idle_Army][Active_Ship] -> Active_Ship  // State transitions
Trans_After_Move_Used[Active_Ship][moves_used] -> Active_Ship
```

**What Pro AI Now Has** (in pro_combat_move.odin):
```odin
is_coastal_and_reachable_by_transport(gc, target) -> bool
  ✅ Checks 0/1/2 move transport reach
  ✅ Validates transport safety (escort requirements)
  ✅ Checks intermediate sea zones for blockades
  ✅ Respects canal states

can_transport_safely_move_to(gc, from_sea, to_sea) -> bool
  ✅ Implements transport.odin safety rules
  ✅ Checks for enemy units and escort availability

can_transport_safely_move_2_spaces(gc, from_sea, to_sea) -> bool
  ✅ Validates 2-move paths
  ✅ Checks all intermediate seas for blockades

has_friendly_transports(gc, sea) -> bool
  ✅ Detects all idle transport types
  ✅ Detects all active transport states
```

**What's Still Missing**: High-level amphibious assault planning
```odin
// Find transports that can reach a target
find_transports_for_assault :: proc(
    gc: ^Game_Cache,
    target_land: Land_ID,
    loading_sea: Sea_ID,
) -> [dynamic]Transport_Option

// Select which units to load (by attack value, transport cost)
select_units_to_load :: proc(
    gc: ^Game_Cache,
    available_units: []Idle_Army,
    transport_capacity: int,
) -> []Idle_Army

// Load units onto transport (state transition execution)
load_units_onto_transport :: proc(
    gc: ^Game_Cache,
    transport_sea: Sea_ID,
    units_to_load: []Idle_Army,
) -> bool

// Move loaded transport (state transition execution)
move_loaded_transport :: proc(
    gc: ^Game_Cache,
    from_sea: Sea_ID,
    to_sea: Sea_ID,
) -> bool

// Check if transport defense is adequate
check_transport_defense :: proc(
    gc: ^Game_Cache,
    transport_sea: Sea_ID,
) -> bool
```

**Files to Create**:
- `pro_transport.odin` - Transport planning utilities
- Integrates with existing transport.odin state machine

---

#### 5. Strategic Consolidation ⚠️ **PARTIALLY EXISTS**
**Status**: Pro AI has logic to find best territories, but not execution

**Already Implemented**:
- `prioritize_defense_targets()` in pro_noncombat_move.odin
- `prioritize_attack_options()` in pro_combat_move.odin
- `calculate_territory_value()` in pro_utils.odin

**What's Missing**: Multi-step movement optimization
```odin
// Find best multi-step path for a unit
find_optimal_path :: proc(
    gc: ^Game_Cache,
    unit_loc: Land_ID,
    unit_type: Idle_Army,
    targets: []Land_ID,  // Potential destinations
) -> Path_Option

Path_Option :: struct {
    destination: Land_ID,
    intermediate_steps: [dynamic]Land_ID,
    moves_required: int,
    final_value: f64,  // Strategic value at destination
}
```

**Files to Update**:
- pro_noncombat_move.odin - Add path optimization
- pro_utils.odin - Add pathfinding helpers

---

### Additional Missing Functions (Not in Your List)

#### 6. Retreat Logic ❌ **CRITICAL - DOES NOT EXIST**
**Status**: Not implemented at all

**What's Needed**:
```odin
proai_should_retreat :: proc(
    gc: ^Game_Cache,
    battle_loc: Land_ID,
    attackers: []Unit_Info,
    defenders: []Unit_Info,
) -> Maybe(Land_ID)  // Returns retreat destination or nil

choose_retreat_destination :: proc(
    gc: ^Game_Cache,
    battle_loc: Land_ID,
    possible_retreats: []Land_ID,
) -> Land_ID  // Pick best retreat location
```

**Files to Create**:
- `pro_retreat.odin` - Complete retreat AI implementation

---

#### 7. Territory Manager Caching ❌ **DOES NOT EXIST**
**Status**: Pro AI recalculates everything repeatedly

**What's Needed**:
```odin
Pro_Territory_Manager :: struct {
    attack_options_cache: map[Land_ID]Attack_Info,
    defense_options_cache: map[Land_ID]Defense_Info,
    enemy_threat_cache: map[Land_ID]f64,
    last_update_turn: int,
}

populate_enemy_attack_options :: proc(manager: ^Pro_Territory_Manager, gc: ^Game_Cache)
populate_defense_options :: proc(manager: ^Pro_Territory_Manager, gc: ^Game_Cache)
invalidate_cache :: proc(manager: ^Pro_Territory_Manager)
```

**Files to Create**:
- `pro_territory_manager.odin` - Caching layer

---

#### 8. Battle Result Caching ⚠️ **PARTIALLY EXISTS**
**Status**: Have battle estimation, but no caching

**Already Have** (in pro_utils.odin):
```odin
estimate_attack_power(attackers) -> f64
estimate_defense_power(defenders) -> f64
```

**What's Missing**: Cache repeated calculations
```odin
Pro_Battle_Cache :: struct {
    results: map[Battle_Key]Battle_Result,
}

Battle_Key :: struct {
    territory: Land_ID,
    attacker_hash: u64,
    defender_hash: u64,
}

get_cached_battle_result :: proc(cache: ^Pro_Battle_Cache, key: Battle_Key) -> Maybe(Battle_Result)
```

---

## Question 3: Summary Table

| Function | Status | Exists in OAAA? | Exists in Pro AI? | Priority |
|----------|--------|-----------------|-------------------|----------|
| **Map Graph Integration** | ⚠️ Partial | ✅ YES | ⚠️ Not Used | HIGH |
| **Unit Movement Execution** | ❌ Missing | ⚠️ Actions Only | ❌ NO | CRITICAL |
| **Carrier Landing Logic** | ⚠️ Partial | ✅ YES | ⚠️ Basic | HIGH |
| **Transport Positioning** | ✅ Complete | ✅ YES | ✅ Full Planning | HIGH |
| **Transport Execution** | ✅ Complete | ✅ YES | ✅ Load/Move/Unload | HIGH |
| **Unit Movement Execution** | ✅ Complete | ✅ YES | ✅ Land/Air/Sea | HIGH |
| **Strategic Consolidation** | ⚠️ Partial | N/A | ⚠️ Planning Only | MEDIUM |
| **Retreat Logic** | ❌ Missing | ✅ Basic Combat | ❌ NO | CRITICAL |
| **Territory Manager Cache** | ❌ Missing | N/A | ❌ NO | HIGH |
| **Battle Result Cache** | ⚠️ Partial | N/A | ⚠️ No Cache | MEDIUM |
| **Transport Utils** | ❌ Missing | ✅ System Exists | ❌ NO | HIGH |
| **ProBattleUtils** | ⚠️ Partial | N/A | ⚠️ Basic Only | HIGH |

---

## Recommended Implementation Order

### Phase 1: Enable Basic Functionality (Week 1)
1. **Unit Movement Execution** - Let Pro AI actually move units
2. **Map Graph Integration** - Use existing OAAA map data
3. **Retreat Logic** - Make combat phase intelligent

### Phase 2: Amphibious Warfare (Week 2)
4. **Transport Planning** - Enable amphibious assaults
5. **Carrier Landing** - Improve fighter placement
6. **Transport Utils** - Full transport logistics

### Phase 3: Optimization (Week 3)
7. **Territory Manager Cache** - Speed up repeated calculations
8. **Battle Result Cache** - Avoid recalculating same battles
9. **Strategic Consolidation** - Better multi-step movement

### Phase 4: Advanced Features (Week 4+)
10. **ProScrambleAi** - If OAAA has scrambling
11. **ProPoliticsAi** - If OAAA has politics/diplomacy
12. **ProTechAi** - If OAAA has technology research

---

## Files to Create

### New Files Needed:
1. `src/pro_retreat.odin` - Retreat decision logic
2. `src/pro_movement.odin` - Movement execution helpers
3. `src/pro_transport.odin` - Transport planning utilities
4. `src/pro_territory_manager.odin` - Caching layer

### Files to Expand:
5. `src/pro_utils.odin` - Add carrier capacity, battle caching
6. `src/pro_combat_move.odin` - Use map graph, add movement execution
7. `src/pro_noncombat_move.odin` - Use map graph, add movement execution
8. `src/pro_place.odin` - Use calculated priorities instead of generic buy_units()

---

## Conclusion

**Your 5 Listed Functions**:
1. ✅ Map Graph - EXISTS in OAAA, need to use it
2. ❌ Unit Movement - DOESN'T EXIST, need to build it
3. ⚠️ Carrier Landing - PARTIAL, need to expand it
4. ⚠️ Transport Positioning - SYSTEM EXISTS, need AI logic
5. ⚠️ Strategic Consolidation - PLANNING EXISTS, need execution

**Additional Critical Needs**:
6. ❌ Retreat Logic - Completely missing
7. ❌ Territory Manager - No caching layer
8. ⚠️ Battle Utils - Incomplete

**Bottom Line**: OAAA has excellent infrastructure (map graph, transport system, carriers), but Pro AI needs to actually USE it and ADD movement execution + retreat logic.
