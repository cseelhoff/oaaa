package oaaa

import "base:intrinsics"

Air_Bitset :: distinct [4]int
get_airs :: proc(num: Air_Bitset) -> (positions: [dynamic]Air_ID) {
    for i in 0..<len(num) {
        chunk := num[i]
        if chunk == 0 do continue        
        // Process each set bit in chunk
        // Calculate bit position: (chunk index * 64) + LSB position
        for chunk != 0 {
            append(&positions, Air_ID(i * 64 + intrinsics.count_trailing_zeros(chunk)))
            chunk &= chunk - 1 // Clear least significant set bit
        }
    }
    return positions
}

add_air :: #force_inline proc(air_bitset: ^Air_Bitset, air: Air_ID) {
    arr_pos:= uint(air) / 64
    remainder:= uint(air) % 64
    air_bitset[arr_pos] |= 1 << remainder
}