package oaaa

import "base:intrinsics"
import sa "core:container/small_array"

// air_positions: [dynamic]Air_ID

// Air_Bitset is a 256-bit bitset using [4]u64
// Layout: [0] = bits 0-63, [1] = bits 64-127, [2] = bits 128-191, [3] = bits 192-255
Air_Bitset :: distinct [4]u64
Air_ID_Array :: sa.Small_Array(len(Air_ID), Air_ID)

// Get all set bits from the bitset
get_airs :: proc(air_bitset: Air_Bitset, air_array: ^Air_ID_Array) {
	sa.clear(air_array)
	for i in 0 ..< len(air_bitset) {
		chunk := air_bitset[i]
		if chunk == 0 do continue
		
		// Process each set bit in this chunk
		bit_offset := i * 64
		temp_chunk := chunk
		for temp_chunk != 0 {
			trailing_zeros := intrinsics.count_trailing_zeros(temp_chunk)
			sa.append(air_array, Air_ID(bit_offset + int(trailing_zeros)))
			temp_chunk &= temp_chunk - 1 // Clear least significant set bit
		}
	}
}

// Add a single air to the bitset
add_air :: #force_inline proc(air_bitset: ^Air_Bitset, air: Air_ID) {
	chunk_index := uint(air) / 64
	bit_index := uint(air) % 64
	air_bitset[chunk_index] |= 1 << bit_index
}

// Remove a single air from the bitset
remove_air :: #force_inline proc(air_bitset: ^Air_Bitset, air: Air_ID) {
	chunk_index := uint(air) / 64
	bit_index := uint(air) % 64
	air_bitset[chunk_index] &~= 1 << bit_index
}

// Check if air is present in the bitset
contains_air :: #force_inline proc(air_bitset: Air_Bitset, air: Air_ID) -> bool {
	chunk_index := uint(air) / 64
	bit_index := uint(air) % 64
	return (air_bitset[chunk_index] & (1 << bit_index)) != 0
}

// Count number of set bits in the bitset
count_airs :: proc(air_bitset: Air_Bitset) -> int {
	count := 0
	for chunk in air_bitset {
		count += int(intrinsics.count_ones(chunk))
	}
	return count
}

// Check if bitset is empty
is_empty :: #force_inline proc(air_bitset: Air_Bitset) -> bool {
	return air_bitset[0] == 0 && air_bitset[1] == 0 && air_bitset[2] == 0 && air_bitset[3] == 0
}

// Clear all bits in the bitset
clear_air_bitset :: #force_inline proc(air_bitset: ^Air_Bitset) {
	air_bitset[0] = 0
	air_bitset[1] = 0
	air_bitset[2] = 0
	air_bitset[3] = 0
}

// Conversion functions
to_air_bitset :: proc {
	land_bitset_to_air_bitset,
	sea_bitset_to_air_bitset,
}

land_bitset_to_air_bitset :: proc(land_bitset: Land_Bitset) -> (result: Air_Bitset) {
	value := transmute(u128)land_bitset
	result[0] = u64(value)
	result[1] = u64(value >> 64)
	return result
}

sea_bitset_to_air_bitset :: proc(sea_bitset: Sea_Bitset) -> (result: Air_Bitset) {
	value := transmute(u128)sea_bitset
	// Sea territories start after land territories in the Air_ID enum
	// Shift left by number of land territories to place sea bits correctly
	shift_amount := uint(len(Land_ID))
	result[0] = u64(value << shift_amount)
	result[1] = u64((value >> (64 - shift_amount)) | (value << (shift_amount - 64)))
	result[2] = u64(value >> (128 - shift_amount))
	return result
}

air_bitset_to_action_bitset :: proc(air_bitset: Air_Bitset) -> (result: Action_Bitset) {
	// Each Air_ID maps to Action_ID at position (air + len(Air_ID) * 5)
	// We need to shift the entire bitset by len(Air_ID) * 5 bits
	shift_amount := uint(len(Air_ID) * 5)
	
	// Calculate which u64 chunks to start writing to
	chunk_offset := shift_amount / 64
	bit_offset := shift_amount % 64
	
	if bit_offset == 0 {
		// Aligned case: simply copy chunks with offset
		for i in 0 ..< len(air_bitset) {
			if chunk_offset + uint(i) < len(result) {
				result[chunk_offset + uint(i)] = air_bitset[i]
			}
		}
	} else {
		// Unaligned case: need to split bits across chunks
		for i in 0 ..< len(air_bitset) {
			if air_bitset[i] == 0 do continue
			
			// Lower bits go to current chunk
			if chunk_offset + uint(i) < len(result) {
				result[chunk_offset + uint(i)] |= air_bitset[i] << bit_offset
			}
			
			// Upper bits go to next chunk
			if chunk_offset + uint(i) + 1 < len(result) {
				result[chunk_offset + uint(i) + 1] |= air_bitset[i] >> (64 - bit_offset)
			}
		}
	}
	
	return result
}

// does_air_has_enemies :: proc(gc: ^Game_Cache, dst_action: Action_ID) -> bool {
// 	chunk_index := uint(dst_action) / 64
// 	bit_index := uint(dst_action) % 64
// 	return (gc.air_has_enemies[chunk_index] & (1 << bit_index)) != 0
// }
