# TripleA Pro AI Method Mapping

This document tracks the implementation status of all methods from TripleA's `ProCombatMoveAi.java` into the OAAA Pro AI system.

## Overview

TripleA's Pro AI combat move phase consists of 13 main methods that work together to:
1. Find and evaluate potential attack targets
2. Prioritize territories by value
3. Determine which can be held after conquest
4. Assign units to attacks
5. Ensure capital safety
6. Execute moves

## Method Mapping Table

| # | TripleA Method | Odin Implementation | Status | Lines (Java) | Notes |
|---|---|---|---|---|---|
| 1 | `prioritizeAttackOptions` | `prioritize_attack_options_triplea` | TODO | 192-299 | Calculate attack value using TUV swing, production, strategic factors |
| 2 | `determineTerritoriesToAttack` | `determine_territories_to_attack_triplea` | TODO | 301-393 | Iteratively add territories until success criteria met |
| 3 | `determineTerritoriesThatCanBeHeld` | `determine_territories_that_can_be_held_triplea` | TODO | 395-524 | Check if conquered territory survives enemy counter-attack |
| 4 | `removeTerritoriesThatArentWorthAttacking` | `remove_territories_that_arent_worth_attacking_triplea` | TODO | 526-634 | Filter convoy zones, low-value neutrals, exposed positions |
| 5 | `moveOneDefenderToLandTerritoriesBorderingEnemy` | `move_one_defender_to_land_territories_bordering_enemy_triplea` | TODO | 636-682 | Defensive positioning for border territories |
| 6 | `removeTerritoriesWhereTransportsAreExposed` | `remove_territories_where_transports_are_exposed_triplea` | TODO | 684-827 | Protect transports from enemy counter-attacks |
| 7 | `determineUnitsToAttackWith` | `determine_units_to_attack_with_triplea` | TODO | 847-1158 | Complex multi-phase unit assignment |
| 8 | `determineTerritoriesThatCanBeBombed` | `determine_territories_that_can_be_bombed_triplea` | TODO | 1160-1184 | Strategic bombing target selection |
| 9 | `determineBestBombingAttackForBomber` | `determine_best_bombing_attack_for_bomber_triplea` | TODO | 1186-1243 | Per-bomber factory targeting |
| 10 | `tryToAttackTerritories` | `try_to_attack_territories_triplea` | TODO | 1245-1778 | Attempt attacks with available units |
| 11 | `removeAttacksUntilCapitalCanBeHeld` | (Partially in `remove_attacks_until_capital_can_be_held`) | PARTIAL | 1780-1888 | Cancel attacks if capital threatened |
| 12 | `checkContestedSeaTerritories` | `check_contested_sea_territories_triplea` | TODO | 1890-1913 | Sub warfare in contested seas |
| 13 | `logAttackMoves` | `log_attack_moves_triplea` | TODO | 1915-2007 | Debug output for attack decisions |
| 14 | `canAirSafelyLandAfterAttack` | `can_air_safely_land_after_attack_triplea` | TODO | 2014-2031 | Check if air units can land safely |

## Current Implementation

### Completed/Partial
- **Capital Defense** (Method 11): Basic implementation exists but needs enhancement:
  - Currently calculates max purchasable defenders with remaining money
  - Needs full TripleA logic: `findMaxPurchaseDefenders` considers unit efficiency
  - Missing: Proper purchase tracking (units purchased vs units placed)

### Simplified Versions
Current `pro_combat_move.odin` has simplified versions of:
- `find_attack_options`: Basic territory scanning
- `prioritize_attack_options`: Simple TUV-based sorting
- `determine_units_for_attacks`: Basic unit assignment
- `remove_attacks_until_capital_can_be_held`: Partial capital defense

### Key Differences from TripleA

1. **Purchase Tracking**:
   - TripleA: Separate purchase/place phases, tracks `placeUnits` separately
   - OAAA: Currently adds purchased units directly to `idle_armies` (WRONG!)
   - Fix needed: Implement proper purchase tracking

2. **Territory Manager**:
   - TripleA: `ProTerritoryManager` handles complex attack/defense option population
   - OAAA: Simplified data structures
   - Consider: Creating similar manager for consistency

3. **Battle Calculation**:
   - TripleA: `ProOddsCalculator` with Monte Carlo simulation
   - OAAA: Simplified odds calculation
   - Acceptable: Monte Carlo too slow for MCTS rollouts

## Implementation Priority

### Phase 1: Critical Path (Capital Defense Bug)
1. Fix purchase phase to track units separately
2. Implement `findMaxPurchaseDefenders` logic
3. Update `removeAttacksUntilCapitalCanBeHeld` to match TripleA

### Phase 2: Core Attack Logic
1. `prioritizeAttackOptions` - Full TripleA formula
2. `determineTerritoriesToAttack` - Iterative selection
3. `determineTerritoriesThatCanBeHeld` - Counter-attack analysis
4. `tryToAttackTerritories` - Multi-phase unit assignment

### Phase 3: Enhancement
1. `determineUnitsToAttackWith` - Advanced unit assignment
2. `removeTerritoriesWhereTransportsAreExposed` - Naval safety
3. Strategic bombing methods
4. Contested sea territories

### Phase 4: Polish
1. Air unit safety checks
2. Defensive positioning
3. Debug logging

## Architecture Notes

### Data Structures Needed

```odin
// Track purchased units separately (not in idle_armies yet)
Purchased_Units :: struct {
    units: map[Land_ID][dynamic]Unit_Type,  // What was purchased where
    total_defense: f64,                      // Total defense value purchased
}

// Territory attack data (similar to ProTerritory)
Attack_Territory_Data :: struct {
    territory: Land_ID,
    max_attackers: [dynamic]Unit_Info,
    max_defenders: [dynamic]Unit_Info,
    assigned_attackers: [dynamic]Unit_Info,
    can_hold: bool,
    is_strafing: bool,
    win_percentage: f64,
    tuv_swing: f64,
    attack_value: f64,
}
```

### Key Algorithms

1. **Attack Value Formula** (from `prioritizeAttackOptions`):
```
territoryValue = (1 + isLand + isCanHold * (1 + 2.0 * isFfa * isLand))
                 * (1 + isEmptyLand)
                 * (1 + isFactory)
                 * (1 - 0.5 * isAmphib)
                 * production

attackValue = (tuvSwing + territoryValue)
              * (1 + 4.0 * isCapital)
              * (1 + 2.0 * isNotNeutralAdjacentToMyCapital)
              * (1 - 0.9 * isNeutral)
```

2. **Unit Assignment Phases** (from `tryToAttackTerritories`):
   - Phase 1: Destroyers vs subs
   - Phase 2: Land/sea units for minimum win chance
   - Phase 3: Non-air units for holdable territories
   - Phase 4: Air units for non-holdable territories
   - Phase 5: Remaining units as needed
   - Phase 6: Amphibious transports
   - Phase 7: Bombardment support

## Testing Strategy

1. **Unit Tests**: Each method independently
2. **Integration Tests**: Full combat move phase
3. **Comparison Tests**: OAAA vs TripleA decisions on same game state
4. **Regression Tests**: Ensure capital defense works correctly

## References

- `ProCombatMoveAi.java`: Main implementation (2031 lines)
- `ProPurchaseUtils.java`: Helper for `findMaxPurchaseDefenders`
- `ProTerritoryManager.java`: Attack/defense option population
- `ProOddsCalculator.java`: Battle probability calculation

## Current Bug Analysis

**Issue**: Russia can't attack because capital appears threatened

**Root Cause**: 
1. Purchase phase spends all 24 PUs on units
2. Units immediately added to `idle_armies[factory]` (wrong!)
3. Combat move phase: `money[cur_player] = 0`
4. `calculate_max_purchasable_defenders` returns 0 (no money left)
5. Capital defense calculation missing purchased units
6. All attacks canceled as "capital threatened"

**TripleA Approach**:
1. Purchase phase: Plan purchases, track separately
2. Combat move: Calculate `findMaxPurchaseDefenders(remaining_money, capital)`
3. Add `placeUnits` to capital defenders (line 1822)
4. Check if capital can be held WITH emergency purchases
5. Place phase: Actually place units

**Fix Required**:
- Separate purchase tracking OR
- Reserve money in purchase phase for capital defense OR
- Count purchased units in defense calculation
