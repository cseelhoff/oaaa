package oaaa

import "base:intrinsics"

// For a 1024-bit integer represented as 16 x i64 chunks
Action_Bitset :: distinct [16]u64
load_dyn_arr_actions :: proc(gc: ^Game_Cache) {
    gc.dyn_arr_valid_actions = {}
    for i in 0..<len(gc.valid_actions) {
        chunk := gc.valid_actions[i]
        if chunk == 0 do continue        
        // Process each set bit in chunk
        // Calculate bit position: (chunk index * 64) + LSB position
        for chunk != 0 {
            append(&gc.dyn_arr_valid_actions, Action_ID(i * 64 + intrinsics.count_trailing_zeros(int(chunk))))
            chunk &= chunk - 1 // Clear least significant set bit
        }
    }
    // return positions
}

reset_valid_actions :: proc(gc: ^Game_Cache) {
    action := Action_ID.Skip_Action
    arr_pos:= uint(action) / 64
    remainder:= uint(action) % 64
    gc.valid_actions = {}
    gc.valid_actions[arr_pos] = 1 << remainder
}

add_valid_action :: #force_inline proc(gc: ^Game_Cache, action: Action_ID) {
    arr_pos:= uint(action) / 64
    remainder:= uint(action) % 64
    gc.valid_actions[arr_pos] |= 1 << remainder
}

remove_valid_action :: proc(gc: ^Game_Cache, action: Action_ID) {
    arr_pos:= uint(action) / 64
    remainder:= uint(action) % 64
    gc.valid_actions[arr_pos] &= ~(1 << remainder)
}

set_valid_actions :: proc(gc: ^Game_Cache, air_bitset: Air_Bitset) {
    gc.valid_actions = {}
    for air in air_bitset {
        add_valid_action(gc, Action_ID(air))
    }
    //todo: use a bit shift instead for better performance
}

remove_actions_above :: proc(gc: ^Game_Cache, action: Action_ID) {
    arr_pos:= uint(action) / 64
    remainder:= uint(action) % 64
    gc.valid_actions[arr_pos] &= ~(1 << remainder)
    for i in arr_pos..<len(gc.valid_actions) {
        gc.valid_actions[i] = 0
    }
}

add_lands_to_valid_actions :: proc(gc: ^Game_Cache, dst_lands: Land_Bitset, unit_count: u8) {
    //todo optimize with SIMD
    dst_lands_u128 := transmute(u128)dst_lands
    dst_lands_u64_0:u64 = u64(dst_lands_u128 >> 64)
    dst_lands_u64_1:u64 = u64(dst_lands_u128) 
    if unit_count >= 32 {
        gc.valid_actions[0] = dst_lands_u64_0
        gc.valid_actions[1] = dst_lands_u64_1
    }
    if unit_count >= 16 {
        offset := len(Action_ID) //144
        index_1 := offset / 64
        remainder := uint(offset % 64)
        dst_lands_u64_0:u64 = u64(dst_lands_u128 >> (remainder + 64))
        dst_lands_u64_1:u64 = u64(dst_lands_u128 >> remainder)
        dst_lands_u64_2:u64 = u64(dst_lands_u128 << (64 - remainder))
        gc.valid_actions[index_1] = dst_lands_u64_0
        gc.valid_actions[index_1 + 1] = dst_lands_u64_1
        gc.valid_actions[index_1 + 2] = dst_lands_u64_2
    }
    if unit_count >= 8 {
        offset := len(Action_ID) * 2 //288
        index_1 := offset / 64
        remainder := uint(offset % 64)
        dst_lands_u64_0:u64 = u64(dst_lands_u128 >> (remainder + 64))
        dst_lands_u64_1:u64 = u64(dst_lands_u128 >> remainder)
        dst_lands_u64_2:u64 = u64(dst_lands_u128 << (64 - remainder))
        gc.valid_actions[index_1] = dst_lands_u64_0
        gc.valid_actions[index_1 + 1] = dst_lands_u64_1
        gc.valid_actions[index_1 + 2] = dst_lands_u64_2
    }
    if unit_count >= 4 {
        offset := len(Action_ID) * 3 //432
        index_1 := offset / 64
        remainder := uint(offset % 64)
        dst_lands_u64_0:u64 = u64(dst_lands_u128 >> (remainder + 64))
        dst_lands_u64_1:u64 = u64(dst_lands_u128 >> remainder)
        dst_lands_u64_2:u64 = u64(dst_lands_u128 << (64 - remainder))
        gc.valid_actions[index_1] = dst_lands_u64_0
        gc.valid_actions[index_1 + 1] = dst_lands_u64_1
        gc.valid_actions[index_1 + 2] = dst_lands_u64_2
    }
    if unit_count >= 2 {
        offset := len(Action_ID) * 4 //576
        index_1 := offset / 64
        remainder := uint(offset % 64)
        dst_lands_u64_0:u64 = u64(dst_lands_u128 >> (remainder + 64))
        dst_lands_u64_1:u64 = u64(dst_lands_u128 >> remainder)
        // dst_lands_u64_2:u64 = u64(dst_lands_u128 << 64 - remainder)
        gc.valid_actions[index_1] = dst_lands_u64_0
        gc.valid_actions[index_1 + 1] = dst_lands_u64_1
        // gc.valid_actions[index_1 + 2] = dst_lands_u64_2
    }
    offset := len(Action_ID) * 5 //576
    index_1 := offset / 64
    remainder := uint(offset % 64)
    dst_lands_u64_0 = u64(dst_lands_u128 >> (remainder + 64))
    dst_lands_u64_1 = u64(dst_lands_u128 >> remainder)
    dst_lands_u64_2:u64 = u64(dst_lands_u128 << (64 - remainder))
    gc.valid_actions[index_1] = dst_lands_u64_0
    gc.valid_actions[index_1 + 1] = dst_lands_u64_1
    gc.valid_actions[index_1 + 2] = dst_lands_u64_2
}

remove_skipped_actions :: proc(gc: ^Game_Cache, src_air: Air_ID) {
    //todo optimize with SIMD
    a: = u16(gc.smallest_allowable_action[src_air])
    b: = a / 64
    remainder: = uint(a % 64)
    for i in b..<len(gc.valid_actions) {
        gc.valid_actions[i] = 0
    }
    gc.valid_actions[b] |= 1 << remainder
}

is_valid_actions_empty :: proc(gc: ^Game_Cache) -> (empty: bool) {
    //todo optimize with SIMD
    for i in 0..<len(gc.valid_actions) {
        if gc.valid_actions[i] != 0 do return false
    }
    return true
}

is_valid_actions_greater_than_one :: proc(gc: ^Game_Cache) -> (empty: bool) {
    //todo optimize with SIMD
    total_count := u8(0)
    for i in 0..<len(gc.valid_actions) {
        chunk := gc.valid_actions[i]
        if chunk == 0 do continue        
        // Process each set bit in chunk
        // Calculate bit position: (chunk index * 64) + LSB position
        for chunk != 0 {
            //append(&positions, Action_ID(i * 64 + intrinsics.count_trailing_zeros(int(chunk))))
            if total_count > 1 do return false
            total_count += 1
            chunk &= chunk - 1 // Clear least significant set bit
        }
    }
    return total_count > 1
}