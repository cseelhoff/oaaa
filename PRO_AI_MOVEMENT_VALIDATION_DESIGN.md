# Pro AI Movement Validation Design

## Overview

This document synthesizes patterns discovered from examining OAAA's movement validation system and outlines the design for Pro AI's map graph validation layer.

## OAAA Movement Validation Patterns Discovered

### 1. Fighter Movement (fighter.odin)

**Pattern: Bitset Range Checking**
```odin
add_valid_unmoved_fighter_moves :: proc(gc: ^Game_Cache, unit_count: u8) {
    src_air := gc.current_territory
    
    // Combat moves: Limited by landing availability
    valid_destinations := 
        ((mm.a2a_within_4_moves[src_air] & gc.can_fighter_land_here) |
         (gc.air_has_enemies &
          (mm.a2a_within_2_moves[src_air] |
           (mm.a2a_within_3_moves[src_air] & gc.can_fighter_land_in_1_move))))
}
```

**Key Insights:**
- Uses bitset intersection for range validation: `mm.a2a_within_N_moves[src] & target_bitset`
- Combat range limited by landing availability (2-3 moves if can land in 1)
- `Fighter_After_Moves[]` maps distance to remaining move state
- Landing validation: `mm.a2a_within_4_moves[src] & gc.can_fighter_land_here`

**Landing Logic:**
```odin
land_remaining_fighters :: proc(gc: ^Game_Cache) -> (ok: bool) {
    for plane in Unlanded_Fighters {
        for src_land in Land_ID {
            land_fighter_from_land(gc) or_return
        }
        for src_sea in Sea_ID {
            land_fighter_from_sea(gc) or_return
        }
    }
}

add_valid_landing_fighter_moves :: proc(...) {
    // Can land within remaining range
    // Must be friendly territory or carrier
    // No-landing result: Remove fighters from game
}
```

---

### 2. Bomber Movement (bomber.odin)

**Pattern: Similar to fighters but 6-move range**
```odin
add_valid_unmoved_bomber_moves :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    
    // Simple relocation: 6 moves to friendly territory
    // Combat mission: 3-5 moves based on landing availability
    valid_bomber_destinations :=
        (mm.a2a_within_6_moves[to_air(src_land)] & to_air_bitset(gc.can_bomber_land_here)) |
        ((gc.air_has_enemies | to_air_bitset(gc.has_bombable_factory)) &
         (mm.a2a_within_3_moves[to_air(src_land)] |
          (mm.a2a_within_4_moves[to_air(src_land)] & gc.can_bomber_land_in_2_moves) |
          (mm.a2a_within_5_moves[to_air(src_land)] & gc.can_bomber_land_in_1_moves)))
}
```

**Key Insights:**
- 6-move range for non-combat
- 3-5 move range for combat (based on landing availability)
- `Bomber_After_Moves[]` maps distance to remaining moves
- Uses `mm.air_distances[src][dst]` to determine remaining moves

---

### 3. Army Movement (army.odin)

**Pattern: Adjacency Sets for 1-move, Bitsets for 2-move**
```odin
add_valid_army_moves_1 :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    
    // 1-move validation
    for dst in mm.l2l_1away_via_land[src_land] {
        // Can move if adjacent
        add_land_to_valid_actions(gc, dst, ...)
    }
}

add_valid_army_moves_2 :: proc(gc: ^Game_Cache) {
    src_land := to_land(gc.current_territory)
    
    // 2-move validation (tanks only)
    for dst in Land_ID {
        if !(dst in mm.l2l_2away_via_midland_bitset[src_land][dst]) {
            continue
        }
        
        // Validate path through midlands
        for midland in mm.l2l_2away_via_midland_bitset[src_land][dst] {
            // Check midland is passable
        }
        
        add_land_to_valid_actions(gc, dst, ...)
    }
}
```

**Blitz Logic (special case):**
```odin
blitz_checks :: proc(gc: ^Game_Cache, midland: Land_ID) -> Active_Army {
    // If tank conquers empty enemy territory
    if gc.owner[midland] == gc.cur_player {
        return .TANK_1_MOVES  // Tank can move again
    }
    return .TANK_0_MOVES  // Tank exhausted
}
```

**Key Insights:**
- 1-move: Uses adjacency set `dst in mm.l2l_1away_via_land[src]`
- 2-move: Uses bitset membership `dst in mm.l2l_2away_via_midland_bitset[src][dst]`
- Blitz returns `TANK_1_MOVES` for successful conquest (not `TANK_2_MOVES`)
- Tank ordering critical: `TANK_2_MOVES` before `TANK_1_MOVES` allows blitz→move
- Transport loading: Inline handling when destination is sea

---

### 4. Ship Movement (ship.odin)

**Pattern: Canal-Aware Adjacency with Blockade Checking**
```odin
add_valid_ship_moves :: proc(gc: ^Game_Cache) {
    src_sea := to_sea(gc.current_territory)
    ship := to_ship(gc.current_active_unit)
    canal_state := transmute(u8)gc.canals_open
    
    // 1-move: Direct adjacency
    add_seas_to_valid_actions(
        gc,
        mm.s2s_1away_via_sea[canal_state][src_sea],
        ...
    )
    
    // 2-move: Check intermediate seas for blockades
    for dst_sea_2_away in mm.s2s_2away_via_sea[canal_state][src_sea] {
        for mid_sea in mm.s2s_2away_via_midseas[canal_state][src_sea][dst_sea_2_away] {
            // Submarines ignore blockades
            if ship == .SUB_2_MOVES do continue
            
            // Other ships blocked by enemy blockades
            if gc.enemy_blockade_total[mid_sea] > 0 do continue
            
            // Destroyers block submarines
            if gc.enemy_destroyer_total[mid_sea] > 0 do continue
            
            add_sea_to_valid_actions(gc, dst_sea_2_away, ...)
            break  // Found valid path
        }
    }
}
```

**Key Insights:**
- Canal awareness: `transmute(u8)gc.canals_open` indexes movement arrays
- 1-move: `mm.s2s_1away_via_sea[canal_state][src_sea]`
- 2-move: `mm.s2s_2away_via_sea[canal_state][src_sea]`
- Intermediate validation: `mm.s2s_2away_via_midseas[canal_state][src][dst]`
- Blockade rules: All ships except subs blocked by enemy ships
- Destroyer rule: Blocks submarines in intermediate seas
- Carrier special: Updates `gc.has_carrier_space`, carries fighters

---

### 5. Transport Movement (transport.odin)

**Pattern: Escort Requirements + Blockade Checking**
```odin
add_valid_transport_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID, max_distance: int) {
    canal_state := transmute(u8)gc.canals_open
    
    // 1-move validation
    for dst_sea in mm.s2s_1away_via_sea[canal_state][src_sea] {
        // Transport needs combat ship escort in hostile waters
        if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 &&
           gc.allied_sea_combatants_total[dst_sea] == 0 {
            continue
        }
        add_valid_action(gc, to_action(dst_sea))
    }
    
    if max_distance == 1 do return
    
    // 2-move validation
    mid_seas := &mm.s2s_2away_via_midseas[canal_state][src_sea]
    for dst_sea_2_away in mm.s2s_2away_via_sea[canal_state][src_sea] {
        // Check escort requirement at destination
        if gc.team_sea_units[dst_sea_2_away][mm.enemy_team[gc.cur_player]] > 0 &&
           gc.allied_sea_combatants_total[dst_sea_2_away] == 0 {
            continue
        }
        
        // Check intermediate seas for blockades
        for mid_sea in sa.slice(&mid_seas[dst_sea_2_away]) {
            if gc.enemy_blockade_total[mid_sea] == 0 {
                add_valid_action(gc, to_action(dst_sea_2_away))
                break
            }
        }
    }
}
```

**Transport State Machine:**
```odin
Transports_Needing_Staging := [?]Active_Ship {
    .TRANS_EMPTY_2_MOVES,
    .TRANS_1I_2_MOVES,
    .TRANS_1A_2_MOVES,
    .TRANS_1T_2_MOVES,
    .TRANS_2I_2_MOVES,
    .TRANS_1I_1A_2_MOVES,
    .TRANS_1I_1T_2_MOVES,
}

Transports_With_Moves := [?]Active_Ship {
    .TRANS_EMPTY_1_MOVES,
    .TRANS_1I_1_MOVES,
    .TRANS_1A_1_MOVES,
    .TRANS_1T_1_MOVES,
    .TRANS_2I_1_MOVES,
    .TRANS_1I_1A_1_MOVES,
    .TRANS_1I_1T_1_MOVES,
}
```

**Key Insights:**
- Escort requirement: Transports need combat ships in hostile waters
- Same blockade rules as combat ships for 2-move paths
- Staging phase: Moves transports with 2 moves first
- Movement phase: Moves transports with 1 move remaining
- Unload phase: Only when transport has 0 moves left
- Rejection handling: `TRANS_*_UNLOADED` prevents re-prompting

---

## Common Validation Patterns

### Pattern 1: Bitset Membership for Range
```odin
// Air unit range checking
valid := (mm.a2a_within_N_moves[src] & target_bitset) != {}

// Land unit 2-move checking  
valid := dst in mm.l2l_2away_via_midland_bitset[src][dst]
```

### Pattern 2: Adjacency Set Membership
```odin
// Land 1-move
valid := dst in mm.l2l_1away_via_land[src]

// Sea 1-move (canal-aware)
valid := dst in mm.s2s_1away_via_sea[canal_state][src]
```

### Pattern 3: Intermediate Path Validation
```odin
// Find valid path through intermediate territories/seas
for mid in mm.intermediate_array[src][dst] {
    if is_passable(mid) {
        return true  // Found valid path
    }
}
return false  // All paths blocked
```

### Pattern 4: State Transition Arrays
```odin
// Maps current state + distance/action → resulting state
Fighter_After_Moves: [8]Active_Plane
Bomber_After_Moves: [8]Active_Plane
Armies_Moved: [Active_Army]Active_Army
Ships_Moved: [Active_Ship]Active_Ship
Trans_After_Move_Used: [Active_Ship][3]Active_Ship
```

### Pattern 5: Counter Update Pattern
```odin
// Always update three parallel structures
gc.active_units[dst][new_state] += count
gc.idle_units[dst][player][unit_type] += count
gc.team_units[dst][team] += count

gc.active_units[src][old_state] -= count
gc.idle_units[src][player][unit_type] -= count
gc.team_units[src][team] -= count
```

---

## Pro AI Validation Layer Design

### File: `pro_move_validate.odin`

### Core Validation Functions

#### Land Unit Validation
```odin
// Check if land units can move from src to dst
can_land_units_move :: proc(
    gc: ^Game_Cache,
    src: Land_ID,
    dst: Land_ID,
    max_moves: int,
) -> bool {
    if max_moves == 1 {
        return dst in mm.l2l_1away_via_land[src]
    } else if max_moves == 2 {
        // Check 2-move range
        if !(dst in mm.l2l_2away_via_midland_bitset[src][dst]) {
            return false
        }
        
        // Validate at least one passable path exists
        for midland in mm.l2l_2away_via_midland_bitset[src][dst] {
            // Allow movement through friendly/neutral/empty enemy territories
            // Disallow movement through occupied enemy territories
            if gc.owner[midland] == gc.cur_player {
                return true
            }
            if gc.owner[midland] == .NONE {
                return true
            }
            if gc.team_land_units[midland][mm.enemy_team[gc.cur_player]] == 0 {
                return true
            }
        }
        return false  // All paths blocked
    }
    return false
}

// Find all territories within max_moves range
find_territories_within_range :: proc(
    gc: ^Game_Cache,
    src: Land_ID,
    max_moves: int,
    allocator := context.allocator,
) -> [dynamic]Land_ID {
    territories := make([dynamic]Land_ID, allocator)
    
    if max_moves >= 1 {
        for adj in sa.slice(&mm.l2l_1away_via_land[src]) {
            append(&territories, adj)
        }
    }
    
    if max_moves >= 2 {
        for land in Land_ID {
            if can_land_units_move(gc, src, land, 2) {
                // Check not already added
                found := false
                for t in territories {
                    if t == land {
                        found = true
                        break
                    }
                }
                if !found {
                    append(&territories, land)
                }
            }
        }
    }
    
    return territories
}
```

#### Air Unit Validation
```odin
// Check if air unit can reach destination
can_air_reach :: proc(
    gc: ^Game_Cache,
    src: Air_ID,
    dst: Air_ID,
    max_range: int,
) -> bool {
    distance := mm.air_distances[src][dst]
    return distance <= u8(max_range)
}

// Alternative bitset-based approach (faster for many checks)
can_air_reach_bitset :: proc(
    gc: ^Game_Cache,
    src: Air_ID,
    dst: Air_ID,
    max_range: int,
) -> bool {
    dst_bitset: Air_Bitset
    add_air(&dst_bitset, dst)
    
    switch max_range {
    case 1: return (mm.a2a_within_1_moves[src] & dst_bitset) != {}
    case 2: return (mm.a2a_within_2_moves[src] & dst_bitset) != {}
    case 3: return (mm.a2a_within_3_moves[src] & dst_bitset) != {}
    case 4: return (mm.a2a_within_4_moves[src] & dst_bitset) != {}
    case 5: return (mm.a2a_within_5_moves[src] & dst_bitset) != {}
    case 6: return (mm.a2a_within_6_moves[src] & dst_bitset) != {}
    }
    return false
}

// Find all air territories within range
find_air_territories_within_range :: proc(
    gc: ^Game_Cache,
    src: Air_ID,
    max_range: int,
    allocator := context.allocator,
) -> [dynamic]Air_ID {
    territories := make([dynamic]Air_ID, allocator)
    
    range_bitset: Air_Bitset
    switch max_range {
    case 1: range_bitset = mm.a2a_within_1_moves[src]
    case 2: range_bitset = mm.a2a_within_2_moves[src]
    case 3: range_bitset = mm.a2a_within_3_moves[src]
    case 4: range_bitset = mm.a2a_within_4_moves[src]
    case 5: range_bitset = mm.a2a_within_5_moves[src]
    case 6: range_bitset = mm.a2a_within_6_moves[src]
    }
    
    for air in Air_ID {
        air_bit: Air_Bitset
        add_air(&air_bit, air)
        if (range_bitset & air_bit) != {} {
            append(&territories, air)
        }
    }
    
    return territories
}

// Check if fighter can land (considering carriers)
can_fighter_land :: proc(
    gc: ^Game_Cache,
    dst: Air_ID,
) -> bool {
    dst_bitset: Air_Bitset
    add_air(&dst_bitset, dst)
    return (to_air_bitset(gc.can_fighter_land_here) & dst_bitset) != {}
}

// Check if bomber can land
can_bomber_land :: proc(
    gc: ^Game_Cache,
    dst: Air_ID,
) -> bool {
    dst_bitset: Air_Bitset
    add_air(&dst_bitset, dst)
    return (to_air_bitset(gc.can_bomber_land_here) & dst_bitset) != {}
}
```

#### Sea Unit Validation
```odin
// Check if sea unit can reach destination
can_sea_reach :: proc(
    gc: ^Game_Cache,
    src: Sea_ID,
    dst: Sea_ID,
    max_moves: int,
    ship_type: Active_Ship = .EMPTY,  // For submarine special rules
) -> bool {
    canal_state := transmute(u8)gc.canals_open
    
    if max_moves == 1 {
        return dst in mm.s2s_1away_via_sea[canal_state][src]
    } else if max_moves == 2 {
        // Check 2-move range
        if !(dst in mm.s2s_2away_via_sea[canal_state][src]) {
            return false
        }
        
        // Validate at least one unblocked path exists
        for mid_sea in mm.s2s_2away_via_midseas[canal_state][src][dst] {
            // Submarines ignore blockades
            is_submarine := ship_type == .SUB_1_MOVES || ship_type == .SUB_2_MOVES
            
            if is_submarine {
                // Subs only blocked by destroyers
                if gc.enemy_destroyer_total[mid_sea] > 0 {
                    continue
                }
            } else {
                // Other ships blocked by any enemy blockade
                if gc.enemy_blockade_total[mid_sea] > 0 {
                    continue
                }
            }
            
            return true  // Found valid path
        }
        return false  // All paths blocked
    }
    return false
}

// Check if transport can reach destination (escort requirement)
can_transport_reach :: proc(
    gc: ^Game_Cache,
    src: Sea_ID,
    dst: Sea_ID,
    max_moves: int,
) -> bool {
    canal_state := transmute(u8)gc.canals_open
    
    if max_moves == 1 {
        if !(dst in mm.s2s_1away_via_sea[canal_state][src]) {
            return false
        }
        
        // Check escort requirement
        if gc.team_sea_units[dst][mm.enemy_team[gc.cur_player]] > 0 &&
           gc.allied_sea_combatants_total[dst] == 0 {
            return false
        }
        
        return true
    } else if max_moves == 2 {
        if !(dst in mm.s2s_2away_via_sea[canal_state][src]) {
            return false
        }
        
        // Check escort requirement at destination
        if gc.team_sea_units[dst][mm.enemy_team[gc.cur_player]] > 0 &&
           gc.allied_sea_combatants_total[dst] == 0 {
            return false
        }
        
        // Check intermediate seas for blockades
        for mid_sea in mm.s2s_2away_via_midseas[canal_state][src][dst] {
            if gc.enemy_blockade_total[mid_sea] == 0 {
                return true  // Found valid path
            }
        }
        return false  // All paths blocked
    }
    return false
}

// Find all seas within range
find_seas_within_range :: proc(
    gc: ^Game_Cache,
    src: Sea_ID,
    max_moves: int,
    allocator := context.allocator,
) -> [dynamic]Sea_ID {
    territories := make([dynamic]Sea_ID, allocator)
    canal_state := transmute(u8)gc.canals_open
    
    if max_moves >= 1 {
        for adj in sa.slice(&mm.s2s_1away_via_sea[canal_state][src]) {
            append(&territories, adj)
        }
    }
    
    if max_moves >= 2 {
        for sea in sa.slice(&mm.s2s_2away_via_sea[canal_state][src]) {
            // Check not already added
            found := false
            for t in territories {
                if t == sea {
                    found = true
                    break
                }
            }
            if !found {
                append(&territories, sea)
            }
        }
    }
    
    return territories
}
```

#### Helper Functions
```odin
// Get maximum moves for unit type
get_unit_max_moves :: proc(unit_type: Unit_Type) -> int {
    switch unit_type {
    case .INFANTRY, .ARTILLERY, .AAGUN, .FACTORY:
        return 1
    case .TANK:
        return 2
    case .FIGHTER:
        return 4
    case .BOMBER:
        return 6
    case .CARRIER, .BATTLESHIP, .SUB, .DESTROYER, .CRUISER:
        return 2
    case .TRANSPORT:
        return 2
    }
    return 0
}

// Convert unit type to active state for movement tracking
unit_type_to_active_army :: proc(unit_type: Unit_Type) -> (Active_Army, bool) #optional_ok {
    switch unit_type {
    case .INFANTRY: return .INF_1_MOVES, true
    case .ARTILLERY: return .ART_1_MOVES, true
    case .TANK: return .TANK_2_MOVES, true
    case .AAGUN: return .AAG_1_MOVES, true
    }
    return {}, false
}

unit_type_to_active_plane :: proc(unit_type: Unit_Type) -> (Active_Plane, bool) #optional_ok {
    switch unit_type {
    case .FIGHTER: return .FIGHTER_UNMOVED, true
    case .BOMBER: return .BOMBER_UNMOVED, true
    }
    return {}, false
}

unit_type_to_active_ship :: proc(unit_type: Unit_Type) -> (Active_Ship, bool) #optional_ok {
    switch unit_type {
    case .TRANSPORT: return .TRANS_EMPTY_2_MOVES, true
    case .CARRIER: return .CARRIER_2_MOVES, true
    case .BATTLESHIP: return .BATT_2_MOVES, true
    case .SUB: return .SUB_2_MOVES, true
    case .DESTROYER: return .DEST_2_MOVES, true
    case .CRUISER: return .CRUI_2_MOVES, true
    }
    return {}, false
}
```

---

## Integration with Movement Execution

### Update `pro_move_execute.odin`

```odin
execute_land_move :: proc(
    gc: ^Game_Cache,
    src: Land_ID,
    dst: Land_ID,
    unit_type: Unit_Type,
    count: u8,
    moved: ^Moved_Units,
) -> bool {
    if count == 0 do return false
    
    // Validate movement is legal
    max_moves := get_unit_max_moves(unit_type)
    if !can_land_units_move(gc, src, dst, max_moves) {
        when ODIN_DEBUG {
            fmt.eprintfln("[PRO-MOVE] Invalid land move: %v cannot reach %v from %v", 
                unit_type, dst, src)
        }
        return false
    }
    
    // Check unit availability (considering already moved units)
    available := get_available_unit_count(gc, src, unit_type, moved)
    if available == 0 {
        when ODIN_DEBUG {
            fmt.eprintfln("[PRO-MOVE] No available %v at %v", unit_type, src)
        }
        return false
    }
    
    // Limit to available count
    actual_count := min(count, available)
    
    // Convert to active army state
    active_army, ok := unit_type_to_active_army(unit_type)
    if !ok {
        when ODIN_DEBUG {
            fmt.eprintfln("[PRO-MOVE] Cannot convert %v to active army", unit_type)
        }
        return false
    }
    
    // Determine destination state (simplified - assumes all moves used)
    dst_active_army: Active_Army
    switch active_army {
    case .INF_1_MOVES: dst_active_army = .INF_0_MOVES
    case .ART_1_MOVES: dst_active_army = .ART_0_MOVES
    case .TANK_2_MOVES: dst_active_army = .TANK_0_MOVES
    case .TANK_1_MOVES: dst_active_army = .TANK_0_MOVES
    case .AAG_1_MOVES: dst_active_army = .AAG_0_MOVES
    case: return false
    }
    
    // Update game state (increment destination)
    gc.active_armies[dst][dst_active_army] += actual_count
    gc.idle_armies[dst][gc.cur_player][unit_type] += actual_count
    gc.team_land_units[dst][mm.team[gc.cur_player]] += actual_count
    
    // Update game state (decrement source)
    gc.active_armies[src][active_army] -= actual_count
    gc.idle_armies[src][gc.cur_player][unit_type] -= actual_count
    gc.team_land_units[src][mm.team[gc.cur_player]] -= actual_count
    
    // Track moved units
    if src not_in moved.land_units {
        moved.land_units[src] = make(map[Unit_Type]u8)
    }
    map_ptr := &moved.land_units[src]
    map_ptr[unit_type] = map_ptr[unit_type] + actual_count
    
    when ODIN_DEBUG {
        fmt.printfln("[PRO-MOVE] Moved %d %v from %v to %v", 
            actual_count, unit_type, src, dst)
    }
    
    return true
}

execute_air_move :: proc(
    gc: ^Game_Cache,
    src_air: Air_ID,
    dst_air: Air_ID,
    plane_type: Unit_Type,
    count: u8,
    moved: ^Moved_Units,
    is_land_src: bool,
    is_land_dst: bool,
) -> bool {
    if count == 0 do return false
    
    // Validate movement is legal
    max_range := get_unit_max_moves(plane_type)
    if !can_air_reach(gc, src_air, dst_air, max_range) {
        when ODIN_DEBUG {
            fmt.eprintfln("[PRO-MOVE] Invalid air move: %v cannot reach %v from %v",
                plane_type, dst_air, src_air)
        }
        return false
    }
    
    // Rest of execution logic...
}

execute_sea_move :: proc(
    gc: ^Game_Cache,
    src_sea: Sea_ID,
    dst_sea: Sea_ID,
    ship_type: Unit_Type,
    count: u8,
    moved: ^Moved_Units,
) -> bool {
    if count == 0 do return false
    
    // Convert to active ship state
    active_ship, ok := unit_type_to_active_ship(ship_type)
    if !ok {
        when ODIN_DEBUG {
            fmt.eprintfln("[PRO-MOVE] Cannot convert %v to active ship", ship_type)
        }
        return false
    }
    
    // Validate movement is legal
    max_moves := get_unit_max_moves(ship_type)
    
    // Special handling for transports (escort requirement)
    is_transport := ship_type == .TRANSPORT
    if is_transport {
        if !can_transport_reach(gc, src_sea, dst_sea, max_moves) {
            when ODIN_DEBUG {
                fmt.eprintfln("[PRO-MOVE] Invalid transport move: cannot reach %v from %v (escort/blockade)",
                    dst_sea, src_sea)
            }
            return false
        }
    } else {
        if !can_sea_reach(gc, src_sea, dst_sea, max_moves, active_ship) {
            when ODIN_DEBUG {
                fmt.eprintfln("[PRO-MOVE] Invalid sea move: %v cannot reach %v from %v",
                    ship_type, dst_sea, src_sea)
            }
            return false
        }
    }
    
    // Rest of execution logic...
}
```

---

## Integration with Combat Move Planning

### Update `pro_combat_move.odin`

```odin
determine_units_for_attacks :: proc(
    gc: ^Game_Cache,
    attack_options: ^[dynamic]Attack_Option,
) {
    for &attack_option in attack_options {
        // Find territories within 2-move range (max for ground units)
        nearby_lands := find_territories_within_range(
            gc,
            attack_option.territory,
            2,  // Max tank range
        )
        defer delete(nearby_lands)
        
        // Count available units that can reach target
        for src_land in nearby_lands {
            // Validate each unit type can actually move
            for unit_type in Unit_Type {
                max_moves := get_unit_max_moves(unit_type)
                if max_moves == 0 do continue
                
                if can_land_units_move(gc, src_land, attack_option.territory, max_moves) {
                    available_count := gc.idle_armies[src_land][gc.cur_player][unit_type]
                    if available_count > 0 {
                        // Assign units to attack
                        append(&attack_option.assigned_units, Assigned_Unit{
                            src = src_land,
                            unit_type = unit_type,
                            count = available_count,
                        })
                    }
                }
            }
        }
        
        // Find air units within range
        for air_id in Air_ID {
            // Check fighters (4-move range)
            if can_air_reach(gc, air_id, to_air(attack_option.territory), 4) {
                fighter_count := gc.idle_land_planes[to_land(air_id)][gc.cur_player][.FIGHTER]
                if fighter_count > 0 {
                    // Add to available fighters
                }
            }
            
            // Check bombers (6-move range)
            if can_air_reach(gc, air_id, to_air(attack_option.territory), 6) {
                bomber_count := gc.idle_land_planes[to_land(air_id)][gc.cur_player][.BOMBER]
                if bomber_count > 0 {
                    // Add to available bombers
                }
            }
        }
    }
}
```

---

## Testing Strategy

### Test Scenarios

1. **Land Movement Tests**
   - Infantry 1-move: Adjacent territories (should pass)
   - Infantry 2-move: Non-adjacent territories (should fail)
   - Tank 1-move: Adjacent territories (should pass)
   - Tank 2-move: Valid path exists (should pass)
   - Tank 2-move: All paths blocked (should fail)

2. **Air Movement Tests**
   - Fighter 4-move: Within range (should pass)
   - Fighter 5-move: Out of range (should fail)
   - Bomber 6-move: Within range (should pass)
   - Bomber 7-move: Out of range (should fail)
   - Landing validation: Friendly territory or carrier

3. **Sea Movement Tests**
   - Ship 1-move: Adjacent sea (should pass)
   - Ship 2-move: Valid path, no blockade (should pass)
   - Ship 2-move: All paths blocked (should fail)
   - Submarine: Ignores blockades (should pass)
   - Submarine: Blocked by destroyers (should fail)
   - Transport: Needs escort in hostile waters (should fail without escort)

4. **Canal Tests**
   - Ship movement: Uses correct canal state
   - Open canal: Additional paths available
   - Closed canal: Paths blocked

5. **Integration Tests**
   - Combat move: Only assigns units that can reach target
   - Movement execution: Rejects invalid moves
   - Double-move prevention: Moved units not moved again

### Test Implementation

Create `tests/pro_move_validate_test.odin`:
```odin
package tests

import "core:testing"
import sa "core:container/small_array"
import "../src"

@(test)
test_infantry_1_move_adjacent :: proc(t: ^testing.T) {
    // Setup game state
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Land_ID.GERMANY
    dst := Land_ID.POLAND
    
    // Poland should be adjacent to Germany
    result := can_land_units_move(gc, src, dst, 1)
    testing.expect(t, result, "Infantry should be able to move 1 space to adjacent territory")
}

@(test)
test_infantry_2_move_fails :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Land_ID.GERMANY
    dst := Land_ID.UKRAINE  // Not adjacent
    
    // Infantry cannot move 2 spaces
    result := can_land_units_move(gc, src, dst, 1)
    testing.expect(t, !result, "Infantry should not be able to move 2 spaces")
}

@(test)
test_tank_2_move_valid_path :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Land_ID.GERMANY
    dst := Land_ID.UKRAINE
    
    // Assuming valid 2-move path exists
    result := can_land_units_move(gc, src, dst, 2)
    testing.expect(t, result, "Tank should be able to move 2 spaces with valid path")
}

@(test)
test_fighter_within_range :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Air_ID(Land_ID.GERMANY)
    dst := Air_ID(Land_ID.POLAND)
    
    result := can_air_reach(gc, src, dst, 4)
    testing.expect(t, result, "Fighter should reach adjacent territory")
}

@(test)
test_ship_blocked_by_blockade :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Sea_ID.NORTH_SEA
    dst := Sea_ID.BALTIC_SEA
    
    // Add enemy blockade to intermediate sea
    // ... setup code ...
    
    result := can_sea_reach(gc, src, dst, 2, .BATT_2_MOVES)
    testing.expect(t, !result, "Battleship should be blocked by enemy blockade")
}

@(test)
test_submarine_ignores_blockade :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Sea_ID.NORTH_SEA
    dst := Sea_ID.BALTIC_SEA
    
    // Add enemy blockade (no destroyers)
    // ... setup code ...
    
    result := can_sea_reach(gc, src, dst, 2, .SUB_2_MOVES)
    testing.expect(t, result, "Submarine should ignore non-destroyer blockade")
}

@(test)
test_transport_needs_escort :: proc(t: ^testing.T) {
    gc := create_test_game_cache()
    defer destroy_test_game_cache(gc)
    
    src := Sea_ID.NORTH_SEA
    dst := Sea_ID.BALTIC_SEA
    
    // Add enemy ships at destination, no friendly combat ships
    // ... setup code ...
    
    result := can_transport_reach(gc, src, dst, 1)
    testing.expect(t, !result, "Transport should need escort in hostile waters")
}
```

---

## Implementation Priority

1. **Phase 1: Core Validation Functions**
   - `can_land_units_move()` ✓
   - `can_air_reach()` ✓
   - `can_sea_reach()` ✓
   - `can_transport_reach()` ✓

2. **Phase 2: Range Finding Functions**
   - `find_territories_within_range()` ✓
   - `find_air_territories_within_range()` ✓
   - `find_seas_within_range()` ✓

3. **Phase 3: Integration with Movement Execution**
   - Update `execute_land_move()` to validate
   - Update `execute_air_move()` to validate
   - Update `execute_sea_move()` to validate

4. **Phase 4: Integration with Combat Move Planning**
   - Update `determine_units_for_attacks()` to use validation
   - Update `select_units_for_attack()` to check reachability

5. **Phase 5: Testing**
   - Create test scenarios
   - Verify all validation functions
   - Integration testing with full MCTS rollouts

---

## Expected Benefits

1. **Correctness**: Pro AI will only make legal moves
2. **Performance**: Pre-validation prevents illegal move attempts
3. **Debugging**: Clear validation failures help identify issues
4. **Consistency**: Uses same patterns as OAAA codebase
5. **Maintainability**: Centralized validation logic

---

## Next Steps

1. Create `pro_move_validate.odin` with core validation functions
2. Add unit tests for validation logic
3. Integrate validation into movement execution
4. Update combat move planning to use validated reachability
5. Run full MCTS test to verify correctness
