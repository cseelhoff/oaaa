package oaaa

import "base:intrinsics"

Air_Bitset :: distinct [4]u64
get_airs :: proc(air_bitset: Air_Bitset, positions: ^[dynamic]Air_ID) {
	clear(&air_positions)
    for i in 0..<len(air_bitset) {
        chunk := air_bitset[i]
        if chunk == 0 do continue        
        // Process each set bit in chunk
        // Calculate bit position: (chunk index * 64) + LSB position
        for chunk != 0 {
            append(positions, Air_ID(i * 64 + intrinsics.count_trailing_zeros(int(chunk))))
            chunk &= chunk - 1 // Clear least significant set bit
        }
    }
}

add_air :: #force_inline proc(air_bitset: ^Air_Bitset, air: Air_ID) {
    arr_pos:= uint(air) / 64
    remainder:= uint(air) % 64
    air_bitset[arr_pos] |= 1 << remainder
}

to_air_bitset :: proc {
    land_bitset_to_air_bitset,
    sea_bitset_to_air_bitset,
}

land_bitset_to_air_bitset :: proc(land_bitset: Land_Bitset) -> (result: Air_Bitset) {
    value := transmute(u128)land_bitset
    result[3] = u64(value)
    result[2] = u64(value >> 64)
    return result
}

sea_bitset_to_air_bitset :: proc(sea_bitset: Sea_Bitset) -> (result: Air_Bitset) {
    value := transmute(u128)sea_bitset
    // result[3] = u64(value)
    result[2] = u64(value << len(Land_ID) - 64)
    result[1] = u64(value >> 128 - len(Land_ID))
    return result
}

air_has_enemies :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> bool {
    chunk := gc.air_has_enemies[uint(dst_action) / 64]
    bool_index_in_chunk := uint(dst_action) % 64
    if (chunk & (1 << bool_index_in_chunk)) != 0 do return true
    return false
}