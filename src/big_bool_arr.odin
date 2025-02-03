package oaaa

import "base:intrinsics"

// For a 2048-bit integer represented as 32 x i64 chunks
Action_Bitset :: distinct [32]int
get_actions :: proc(num: Action_Bitset) -> (positions: [dynamic]Action_ID) {
    for i in 0..<len(num) {
        chunk := num[i]
        if chunk == 0 do continue        
        // Process each set bit in chunk
        // Calculate bit position: (chunk index * 64) + LSB position
        for chunk != 0 {
            append(&positions, Action_ID(i * 64 + intrinsics.count_trailing_zeros(chunk)))
            chunk &= chunk - 1 // Clear least significant set bit
        }
    }
    return positions
}

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
