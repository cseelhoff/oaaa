package oaaa

Bomber_After_Moves := [?]Active_Plane {
    /*
    AI NOTE: Bomber Movement State Transitions
    
    When a bomber moves, its state transitions to show remaining moves:
    - BOMBER_UNMOVED -> BOMBER_5_MOVES (after first move)
    - BOMBER_5_MOVES -> BOMBER_4_MOVES (and so on)
    - If no combat intended, transitions directly to BOMBER_0_MOVES
    
    After combat resolution:
    - Remaining moves can be used to reach friendly territory
    - If bomber doesn't/can't move after combat, stays at BOMBER_0_MOVES
    */
    .BOMBER_0_MOVES,  // No moves remaining
    .BOMBER_5_MOVES,  // After first move if combat intended
    .BOMBER_4_MOVES,  // After second move
    .BOMBER_3_MOVES,  // After third move
    .BOMBER_2_MOVES,  // After fourth move
    .BOMBER_1_MOVES,  // After fifth move
    .BOMBER_0_MOVES,  // After final move or if no combat
}

Unlanded_Bombers := [?]Active_Plane {
    .BOMBER_5_MOVES,
    .BOMBER_4_MOVES,
    .BOMBER_3_MOVES,
    .BOMBER_2_MOVES,
    .BOMBER_1_MOVES,
}

BOMBER_MAX_MOVES :: 6

move_unmoved_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
    gc.clear_history_needed = false
    for src_land in Land_ID {
        if gc.active_land_planes[src_land][.BOMBER_UNMOVED] == 0 do return true
        if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
        gc.valid_actions = {to_action(src_land)}
        add_valid_unmoved_bomber_moves(gc, src_land)
        for gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
            dst_air := get_move_plane_input(gc, .BOMBER_UNMOVED, to_air(src_land)) or_return
            if is_land(dst_air) {
                move_unmoved_bomber_to_land(gc, src_land, to_land(dst_air))
            } else {
                move_unmoved_bomber_to_sea(gc, src_land, to_sea(dst_air))
            }
        }
    }
    if gc.clear_history_needed do clear_move_history(gc)
    return true
}

add_valid_unmoved_bomber_moves :: #force_inline proc(gc: ^Game_Cache, src_land: Land_ID) {
    /*
    AI NOTE: Unmoved Bomber Move Validation
    
    Bombers can move in two ways:
    1. Simple Relocation (no combat):
       - Can move up to 6 spaces to friendly territory
       - Moves set to 0 after relocation
    
    2. Combat Mission:
       - Can move up to 3 spaces to attack enemies/factories
       - Can move up to 4 spaces if landing spot within 2 moves
       - Can move up to 5 spaces if landing spot within 1 move
       - Remaining moves saved for post-combat landing
    */
    gc.valid_actions += to_action_bitset(
        (~gc.rejected_moves_from[to_air(src_land)] &
            (mm.a2a_within_6_moves[to_air(src_land)] & to_air_bitset(gc.can_bomber_land_here) |
                    ((gc.air_has_enemies | to_air_bitset(gc.has_bombable_factory)) &
                            (mm.a2a_within_3_moves[to_air(src_land)] |
                                    (mm.a2a_within_4_moves[to_air(src_land)] &
                                            gc.can_bomber_land_in_2_moves) |
                                    (mm.a2a_within_5_moves[to_air(src_land)] &
                                            gc.can_bomber_land_in_1_moves))))),
    )
}

move_unmoved_bomber_to_land :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) {
    if skip_bomber(gc, src_land, dst_land) do return
    if dst_land in gc.can_bomber_land_here {
        gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
    } else {
        gc.more_land_combat_needed += {dst_land}
        gc.active_land_planes[dst_land][Bomber_After_Moves[mm.air_distances[to_air(src_land)][to_air(dst_land)]]] +=
        1
    }
    gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
    gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
    gc.active_land_planes[src_land][.BOMBER_UNMOVED] -= 1
    gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
    gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
    return
}

skip_bomber :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_land: Land_ID) -> (ok: bool) {
    if src_land != dst_land do return false
    gc.active_land_planes[src_land][.BOMBER_0_MOVES] +=
        gc.active_land_planes[src_land][.BOMBER_UNMOVED]
    gc.active_land_planes[src_land][.BOMBER_UNMOVED] = 0
    return true
}

move_unmoved_bomber_to_sea :: proc(gc: ^Game_Cache, src_land: Land_ID, dst_sea: Sea_ID) {
    gc.more_sea_combat_needed += {dst_sea}
    gc.active_sea_planes[dst_sea][Bomber_After_Moves[mm.air_distances[to_air(src_land)][to_air(dst_sea)]]] += 1
    add_my_bomber_to_sea(gc, dst_sea)
    gc.active_land_planes[src_land][.BOMBER_UNMOVED] -= 1
    gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
    gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
}

refresh_can_bomber_land_here :: proc(gc: ^Game_Cache) {
    gc.can_bomber_land_here = gc.friendly_owner & ~gc.land_combat_started
    gc.can_bomber_land_in_1_moves = {}
    gc.can_bomber_land_in_2_moves = {}
    for dst_land in gc.can_bomber_land_here {
        gc.can_bomber_land_in_1_moves += mm.a2a_within_1_moves[to_air(dst_land)]
        gc.can_bomber_land_in_2_moves += mm.a2a_within_2_moves[to_air(dst_land)]
    }
    gc.is_bomber_cache_current = true
}

refresh_can_bomber_land_here_directly :: proc(gc: ^Game_Cache) {
    gc.can_bomber_land_here = gc.friendly_owner & ~gc.land_combat_started
    gc.is_bomber_cache_current = true
}

land_remaining_bombers :: proc(gc: ^Game_Cache) -> (ok: bool) {
    for plane in Unlanded_Bombers {
        gc.clear_history_needed = false
        for src_land in Land_ID {
            land_bomber_from_land(gc, src_land, plane) or_return
        }
        for src_sea in Sea_ID {
            land_bomber_from_sea(gc, src_sea, plane) or_return
        }
        if gc.clear_history_needed do clear_move_history(gc)
    }
    return true
}

land_bomber_from_land :: proc(
    gc: ^Game_Cache,
    src_land: Land_ID,
    plane: Active_Plane,
) -> (
    ok: bool,
) {
    if gc.active_land_planes[src_land][plane] == 0 do return true
    if !gc.is_bomber_cache_current do refresh_can_bomber_land_here_directly(gc)
    gc.valid_actions = {}
    add_valid_landing_bomber_moves(gc, to_air(src_land), plane)
    for gc.active_land_planes[src_land][plane] > 0 {
        dst_air := get_move_plane_input(gc, plane, to_air(src_land)) or_return
        move_bomber_from_land_to_land(gc, to_land(dst_air), plane, src_land)
    }
    return true
}

move_bomber_from_land_to_land :: proc(
    gc: ^Game_Cache,
    dst_land: Land_ID,
    plane: Active_Plane,
    src_land: Land_ID,
) {
    gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
    gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
    gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
    gc.active_land_planes[src_land][plane] -= 1
    gc.idle_land_planes[src_land][gc.cur_player][.BOMBER] -= 1
    gc.team_land_units[src_land][mm.team[gc.cur_player]] -= 1
    return
}

land_bomber_from_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, plane: Active_Plane) -> (ok: bool) {
    if gc.active_sea_planes[src_sea][plane] == 0 do return true
    if ~gc.is_bomber_cache_current do refresh_can_bomber_land_here_directly(gc)
    gc.valid_actions = {}
    add_valid_landing_bomber_moves(gc, to_air(src_sea), plane)
    for gc.active_sea_planes[src_sea][plane] > 0 {
        dst_air := get_move_plane_input(gc, plane, to_air(src_sea)) or_return
        move_bomber_from_sea_to_land(gc, to_land(dst_air), plane, src_sea)
    }
    return true
}

move_bomber_from_sea_to_land :: proc(
    gc: ^Game_Cache,
    dst_land: Land_ID,
    plane: Active_Plane,
    src_sea: Sea_ID,
) {
    gc.active_land_planes[dst_land][.BOMBER_0_MOVES] += 1
    gc.idle_land_planes[dst_land][gc.cur_player][.BOMBER] += 1
    gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
    gc.active_sea_planes[src_sea][plane] -= 1
    remove_my_bomber_from_sea(gc, src_sea)
    return
}

add_valid_landing_bomber_moves :: proc(
    gc: ^Game_Cache,
    src_air: Air_ID,
    plane: Active_Plane,
) -> (
    valid_air_moves_bitset: Air_Bitset,
) {
    /*
    AI NOTE: Bomber Movement System
    
    Movement happens in phases:
    1. Initial Move Phase:
       - Bomber moves to target location
       - If no combat, remaining moves set to 0 (simple relocation)
       - If combat, remaining moves saved for landing
    
    2. Landing Phase (after combat):
       - Uses remaining moves to reach friendly territory
       - Cannot land on carriers (simpler than fighters)
       - Has up to 6 total moves (more than fighters' 4)
    
    Movement states track the bomber's remaining moves,
    from BOMBER_0_MOVES to BOMBER_6_MOVES
    */
    #partial switch plane {
    case .BOMBER_1_MOVES:
        gc.valid_actions = to_action_bitset(
            ~gc.rejected_moves_from[src_air] &
            to_air_bitset(gc.can_bomber_land_here) &
            mm.a2a_within_1_moves[src_air],
        )
    case .BOMBER_2_MOVES:
        gc.valid_actions = to_action_bitset(
            ~gc.rejected_moves_from[src_air] &
            to_air_bitset(gc.can_bomber_land_here) &
            mm.a2a_within_2_moves[src_air],
        )
    case .BOMBER_3_MOVES:
        gc.valid_actions = to_action_bitset(
            ~gc.rejected_moves_from[src_air] &
            to_air_bitset(gc.can_bomber_land_here) &
            mm.a2a_within_3_moves[src_air],
        )
    case .BOMBER_4_MOVES:
        gc.valid_actions = to_action_bitset(
            ~gc.rejected_moves_from[src_air] &
            to_air_bitset(gc.can_bomber_land_here) &
            mm.a2a_within_4_moves[src_air],
        )
    case .BOMBER_5_MOVES:
        gc.valid_actions = to_action_bitset(
            ~gc.rejected_moves_from[src_air] &
            to_air_bitset(gc.can_bomber_land_here) &
            mm.a2a_within_5_moves[src_air],
        )
    }
    return valid_air_moves_bitset
}

add_my_bomber_to_sea :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) {
    gc.idle_sea_planes[sea][gc.cur_player][.BOMBER] += 1
    gc.team_sea_units[sea][mm.team[gc.cur_player]] += 1
    gc.allied_antifighter_ships_total[sea] += 1
    gc.allied_sea_combatants_total[sea] += 1
}

remove_my_bomber_from_sea :: #force_inline proc(gc: ^Game_Cache, sea: Sea_ID) {
    gc.idle_sea_planes[sea][gc.cur_player][.BOMBER] -= 1
    gc.team_sea_units[sea][mm.team[gc.cur_player]] -= 1
    gc.allied_antifighter_ships_total[sea] -= 1
    gc.allied_sea_combatants_total[sea] -= 1
}
