# Purchase/Place Phase Separation Architecture

## Overview

The Pro AI now implements **separate purchase and place phases** matching TripleA's architecture, instead of the original OAAA approach of immediately placing units during purchase.

## Why This Matters

### Original OAAA Problem (Capital Defense Bug)
```odin
// BROKEN FLOW:
purchase() {
    buy 8 infantry (24 PUs)
    gc.idle_armies[factory][Rus][INF] += 8  // ← Units placed IMMEDIATELY
    gc.money[Rus] = 0                        // ← All money spent
}

combat_move() {
    max_defenders = gc.money[Rus] / 3 = 0 / 3 = 0  // ← Can't calculate!
    capital_defense = 20 + 0 = 20
    required = 34 * 1.3 = 44.2
    20 < 44.2 → Cancel ALL attacks  // ← BUG!
}
```

### New TripleA-Style Solution
```odin
// CORRECT FLOW:
purchase() {
    buy 8 infantry (24 PUs)
    add_units_to_place_triplea(factory, .Infantry, 8)  // ← Track, don't place
    gc.money[Rus] -= 24                                 // ← Money spent
    // Units NOT in idle_armies yet!
}

combat_move() {
    // Calculate defenders INCLUDING tracked purchases
    purchased_inf = count_purchased_units(factory, .Infantry) = 8
    capital_defense = 20 + 8 = 28
    required = 34 * 1.3 = 44.2
    28 < 44.2 → Still need defense, but can attack elsewhere  // ← Works!
}

place() {
    place_defenders_triplea(gc)  // ← NOW place all tracked units
    // Units moved from g_purchased_units → idle_armies
}
```

## Data Structures

### Purchased_Units
Tracks units bought during purchase phase but not yet placed:

```odin
Purchased_Units :: struct {
    territory: Land_ID,  // Where to place these units
    
    // Land units
    inf: u8,
    arty: u8,
    tank: u8,
    aa: u8,
    fighter: u8,
    bomber: u8,
    
    // Naval units (for coastal factories)
    sub: u8,
    destroyer: u8,
    cruiser: u8,
    carrier: u8,
    battleship: u8,
    transport: u8,
}
```

### Global Tracking
```odin
g_purchased_units: [dynamic]Purchased_Units
```

This global array stores all purchases until the place phase.

## Phase Flow

### 1. Purchase Phase
```odin
proai_purchase_phase(gc) {
    // Initialize tracking
    populate_production_rule_map_triplea(gc)  // Clears g_purchased_units
    
    // Buy units (tracked, not placed)
    purchase_defenders_triplea(...)
    purchase_land_units_triplea(...)
    purchase_sea_and_amphib_units_triplea(...)
    
    // Money is spent, but units NOT in idle_armies
}
```

### 2. Combat Move Phase
```odin
proai_combat_move_phase(gc) {
    // Can query g_purchased_units to see what was bought
    // Calculate emergency defenders including tracked purchases
    
    for territory in threatened_territories {
        current_defense = count_idle_units(territory)
        purchased_defense = count_purchased_units(territory)
        total_defense = current_defense + purchased_defense
        
        if total_defense >= required {
            // Safe to attack elsewhere
        }
    }
}
```

### 3. Place Phase
```odin
proai_place_phase(gc) {
    // Move all tracked purchases to idle_armies
    place_defenders_triplea(gc)  // or place_units_triplea(gc)
    
    // g_purchased_units cleared after placement
}
```

## Key Functions

### populate_production_rule_map_triplea
**Purpose**: Initialize purchase tracking at start of purchase phase

```odin
populate_production_rule_map_triplea :: proc(gc: ^Game_Cache) {
    if g_purchased_units == nil {
        g_purchased_units = make([dynamic]Purchased_Units)
    }
    clear(&g_purchased_units)  // Clear previous turn's purchases
}
```

### add_units_to_place_triplea
**Purpose**: Track unit purchase without placing

```odin
add_units_to_place_triplea :: proc(territory: Land_ID, unit_type: Unit_Type, count: u8) {
    // Find or create Purchased_Units entry for territory
    // Add units to tracking structure
    // Money already deducted, units NOT in idle_armies
}
```

**Naval variant**:
```odin
add_naval_units_to_place_triplea :: proc(territory: Land_ID, unit_type: Idle_Ship, count: u8) {
    // Same as above but for naval units
}
```

### place_defenders_triplea
**Purpose**: Actually place all tracked units during place phase

```odin
place_defenders_triplea :: proc(gc: ^Game_Cache) {
    for purchase in g_purchased_units {
        // Move units from tracking → idle_armies
        gc.idle_armies[purchase.territory][...] += purchase.inf
        gc.idle_armies[purchase.territory][...] += purchase.arty
        // etc for all unit types
        
        // Naval units placed in adjacent sea zones
    }
    
    clear(&g_purchased_units)  // Clear after placement
}
```

### place_units_triplea
**Purpose**: Alias for place_defenders_triplea (both place all units)

```odin
place_units_triplea :: proc(gc: ^Game_Cache) {
    place_defenders_triplea(gc)  // Same implementation
}
```

## Integration with Existing Code

### Updating Purchase Methods

**OLD** (immediate placement):
```odin
purchase_defenders_triplea :: proc(...) {
    if gc.money[gc.cur_player] >= 3 {
        gc.money[gc.cur_player] -= 3
        gc.idle_armies[factory][gc.cur_player][.INF] += 1  // ← Immediate
    }
}
```

**NEW** (deferred placement):
```odin
purchase_defenders_triplea :: proc(...) {
    if gc.money[gc.cur_player] >= 3 {
        gc.money[gc.cur_player] -= 3
        add_units_to_place_triplea(factory, .Infantry, 1)  // ← Track only
    }
}
```

### Querying Purchases During Combat Move

```odin
// Helper function (to be implemented)
count_purchased_units :: proc(territory: Land_ID, unit_type: Unit_Type) -> u8 {
    for purchase in g_purchased_units {
        if purchase.territory == territory {
            #partial switch unit_type {
            case .Infantry: return purchase.inf
            case .Artillery: return purchase.arty
            case .Tank: return purchase.tank
            case .Fighter: return purchase.fighter
            // etc
            }
        }
    }
    return 0
}

// Usage in capital defense calculation
calculate_capital_defense :: proc(gc: ^Game_Cache, capital: Land_ID) -> f64 {
    // Current defenders
    current_inf = gc.idle_armies[capital][gc.cur_player][.INF]
    
    // Add purchased defenders
    purchased_inf = count_purchased_units(capital, .Infantry)
    
    total_inf = current_inf + purchased_inf
    defense_power = f64(total_inf) * 2.0
    
    return defense_power
}
```

## Turn Flow

```
┌─────────────────────────────────────────────────────┐
│ START OF TURN                                       │
├─────────────────────────────────────────────────────┤
│ 1. PURCHASE PHASE                                   │
│    - populate_production_rule_map_triplea(gc)       │
│    - purchase_defenders_triplea(...)                │
│    - purchase_land_units_triplea(...)               │
│    - purchase_sea_and_amphib_units_triplea(...)     │
│                                                     │
│    State: g_purchased_units filled                  │
│           gc.money reduced                          │
│           idle_armies UNCHANGED                     │
├─────────────────────────────────────────────────────┤
│ 2. COMBAT MOVE PHASE                                │
│    - calculate_max_purchasable_defenders()          │
│      (includes g_purchased_units)                   │
│    - decide_attacks()                               │
│      (knows about tracked purchases)                │
│                                                     │
│    State: Can see purchased units via tracking      │
├─────────────────────────────────────────────────────┤
│ 3. COMBAT PHASE                                     │
│    - resolve_attacks()                              │
│                                                     │
│    State: g_purchased_units still tracked           │
├─────────────────────────────────────────────────────┤
│ 4. NON-COMBAT MOVE PHASE                            │
│    - move_remaining_units()                         │
│                                                     │
│    State: g_purchased_units still tracked           │
├─────────────────────────────────────────────────────┤
│ 5. PLACE PHASE                                      │
│    - place_defenders_triplea(gc)                    │
│      → Moves g_purchased_units → idle_armies        │
│      → Clears g_purchased_units                     │
│                                                     │
│    State: All units now in idle_armies              │
│           g_purchased_units empty                   │
└─────────────────────────────────────────────────────┘
```

## Benefits

1. **Fixes Capital Defense Bug**: Can calculate emergency defenders including purchases
2. **Matches TripleA Logic**: Pro AI behavior identical to reference implementation
3. **Enables Advanced Strategies**: 
   - Can reserve money for emergency purchases during combat
   - Can calculate hypothetical placements
   - Can optimize placement based on combat results
4. **Clean Separation of Concerns**:
   - Purchase = economic decision
   - Place = tactical decision based on combat results

## Testing Strategy

1. **Unit Test**: Verify tracking
   ```odin
   test_purchase_tracking :: proc(t: ^testing.T) {
       gc := create_test_game()
       populate_production_rule_map_triplea(gc)
       
       add_units_to_place_triplea(Moscow, .Infantry, 8)
       
       assert(len(g_purchased_units) == 1)
       assert(g_purchased_units[0].inf == 8)
       assert(gc.idle_armies[Moscow][Russia][.INF] == 0)  // Not placed yet!
   }
   ```

2. **Integration Test**: Full purchase/place cycle
   ```odin
   test_full_cycle :: proc(t: ^testing.T) {
       gc := create_test_game()
       initial_inf := gc.idle_armies[Moscow][Russia][.INF]
       
       // Purchase
       populate_production_rule_map_triplea(gc)
       add_units_to_place_triplea(Moscow, .Infantry, 5)
       assert(gc.idle_armies[Moscow][Russia][.INF] == initial_inf)
       
       // Place
       place_defenders_triplea(gc)
       assert(gc.idle_armies[Moscow][Russia][.INF] == initial_inf + 5)
       assert(len(g_purchased_units) == 0)
   }
   ```

3. **Regression Test**: Capital defense bug
   ```odin
   test_capital_defense_with_purchases :: proc(t: ^testing.T) {
       gc := setup_russia_scenario()  // 24 PUs, threatened capital
       
       // Purchase defenders
       proai_purchase_phase(gc)  // Buys 8 infantry
       
       // Verify can still attack
       proai_combat_move_phase(gc)
       assert(len(gc.attacks) > 0)  // Should not cancel all attacks!
   }
   ```

## Migration Path

### Phase 1: ✅ DONE
- [x] Create `Purchased_Units` structure
- [x] Create global `g_purchased_units` tracking
- [x] Implement `populate_production_rule_map_triplea`
- [x] Implement `add_units_to_place_triplea`
- [x] Implement `add_naval_units_to_place_triplea`
- [x] Implement `place_defenders_triplea`
- [x] Implement `place_units_triplea`
- [x] Update status comments

### Phase 2: TODO
- [ ] Update all purchase methods to use `add_units_to_place_triplea` instead of direct placement
- [ ] Implement `count_purchased_units` helper
- [ ] Update `calculate_max_purchasable_defenders` to include tracked purchases
- [ ] Create `proai_place_phase` function
- [ ] Add place phase to turn flow

### Phase 3: TODO  
- [ ] Add unit tests for purchase tracking
- [ ] Add integration tests for full cycle
- [ ] Test Russia capital defense scenario
- [ ] Verify all Pro AI phases work correctly

### Phase 4: TODO
- [ ] Performance optimization (reduce allocations)
- [ ] Add purchase tracking to game state persistence
- [ ] Document purchase strategies in Pro AI guide

## Notes

- The global `g_purchased_units` is cleared at start of purchase phase and after place phase
- Naval units are placed in the first adjacent sea zone to the factory
- Infrastructure (factories) should never be in purchased_units (bought and placed immediately)
- If combat results change territory ownership, placement logic must handle this edge case
