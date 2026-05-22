package oaaa

import "core:mem"

Persp_State :: struct {
    active_armies:      Active_Armies,
    active_land_planes: Active_Land_Planes,
    active_ships:       Active_Ships,
    active_sea_planes:  Active_Sea_Planes,

    idle_armies:      [4]Idle_Armies,      // 4 enemy/ally slots; phantom ITA is zeroed
    idle_land_planes: [4]Idle_Land_Planes, // 4 enemy/ally slots; phantom ITA is zeroed
    idle_ships:       [4]Idle_Ships,       // 4 enemy/ally slots; phantom ITA is zeroed
    idle_sea_planes:  [4]Idle_Sea_Planes,  // 4 enemy/ally slots; phantom ITA is zeroed

    money:           [6]u8,               // 5 real player slots + 1 phantom (ITA)
    owner_slot:      [Land_ID]u8,        // per-land owner as canonical slot (0..5)

    factory_prod:    [Land_ID]u8,
    factory_dmg:     [Land_ID]u8,
    builds_left:     u8,
    more_land_combat_needed: bool,
    land_combat_started:     bool,
    more_sea_combat_needed:  bool,
    sea_combat_started:      bool,

    current_territory: Land_ID,
    phase:             u8,                // Phase_ID as u8 for easy switch-case in C
}

build_persp_state :: proc(gs: ^Game_State, out: ^Persp_State) {
    mover := gs.cur_player
    NP := len(Player_ID)

    // --- Slot 0 (mover) — active fields are mover-private; one memcpy each.
    mem.copy(&out.active_armies,      &gs.active_armies,      size_of(gs.active_armies))
    mem.copy(&out.active_land_planes, &gs.active_land_planes, size_of(gs.active_land_planes))
    mem.copy(&out.active_ships,       &gs.active_ships,       size_of(gs.active_ships))
    mem.copy(&out.active_sea_planes,  &gs.active_sea_planes,  size_of(gs.active_sea_planes))

    // --- Slots 1..4 — 4 enemy/ally idle slots come from real players.
    //     Slot 5 is phantom — we just leave it zero (struct was zero-inited
    //     by the caller, or do `mem.zero(out.idle_*[4])` defensively).
    for enemy_idx in 0..<4 {
        slot           := enemy_idx + 1                            // canonical slot 1..4
        src_player_idx :Player_ID= Player_ID((int(mover) + slot) % NP)                 // wraps in real-player ring
        // Each of these is one big contiguous memcpy: N_LANDS*4, N_LANDS*2, N_SEAS*13, N_SEAS*2 bytes.
        mem.copy(&out.idle_armies[enemy_idx],      &gs.idle_armies     [src_player_idx], size_of(gs.idle_armies     [0]))
        mem.copy(&out.idle_land_planes[enemy_idx], &gs.idle_land_planes[src_player_idx], size_of(gs.idle_land_planes[0]))
        mem.copy(&out.idle_ships[enemy_idx],       &gs.idle_ships      [src_player_idx], size_of(gs.idle_ships      [0]))
        mem.copy(&out.idle_sea_planes[enemy_idx],  &gs.idle_sea_planes [src_player_idx], size_of(gs.idle_sea_planes [0]))
    }
    // out.idle_*[4] (canonical slot 5) intentionally left zero (phantom ITA).

    // --- Money: 6 byte writes
    out.money[0] = gs.money[mover]
    for slot in 1..<NUM_SLOTS - 1 {
        src := Player_ID((int(mover) + slot) % NP)
        out.money[slot] = gs.money[src]
    }
    out.money[5] = 0   // phantom

    // --- Owner: scalar relabel per land (only field that's per-element).
    //     Build a small [Player_ID]u8 lookup once: player -> canonical slot.
    player_to_slot: [Player_ID]u8
    for slot in 0..<NUM_SLOTS - 1 {
        p := Player_ID((int(mover) + slot) % NP)
        player_to_slot[p] = u8(slot)
    }
    for land in Land_ID {
        out.owner_slot[land] = player_to_slot[gs.owner[land]]
    }

    // --- Cheap fields: bulk copy or trivial assigns.
    out.factory_prod            = gs.factory_prod
    out.factory_dmg             = gs.factory_dmg
    out.builds_left             = gs.builds_left
    out.more_land_combat_needed = gs.more_land_combat_needed
    out.land_combat_started     = gs.land_combat_started
    out.more_sea_combat_needed  = gs.more_sea_combat_needed
    out.sea_combat_started      = gs.sea_combat_started
    out.current_territory       = gs.current_territory
    out.phase                   = u8(current_phase(gs))
}