# Air_Bitset U256 Implementation

## Overview
Since Odin doesn't have a native `u256` type, we implement a 256-bit bitset using `distinct [4]u64`.

## Memory Layout
```
Air_Bitset :: distinct [4]u64
```
- `[0]` = bits 0-63
- `[1]` = bits 64-127  
- `[2]` = bits 128-191
- `[3]` = bits 192-255

This is a **little-endian** layout where lower indices store lower-order bits.

## Key Issues Fixed

### 1. **Indexing Logic**
Your original code used reversed indexing:
```odin
// WRONG - reversed indexing
arr_pos := len(Air_Bitset) - (uint(air) / 64) - 1
```

Correct approach:
```odin
// CORRECT - direct indexing
chunk_index := uint(air) / 64
bit_index := uint(air) % 64
air_bitset[chunk_index] |= 1 << bit_index
```

### 2. **get_airs Iteration**
Your original code reversed the chunk iteration, which would return air IDs in wrong order:
```odin
// WRONG
for i in 0 ..< len(air_bitset) {
    j := len(air_bitset) - i - 1
    chunk := air_bitset[j]  // Processes chunks backwards
```

Correct approach iterates forward:
```odin
// CORRECT
for i in 0 ..< len(air_bitset) {
    chunk := air_bitset[i]  // Process in order
    bit_offset := i * 64
```

### 3. **Conversion Functions**
Fixed the land/sea to air conversions:

**Land Bitset → Air Bitset:**
```odin
land_bitset_to_air_bitset :: proc(land_bitset: Land_Bitset) -> (result: Air_Bitset) {
    value := transmute(u128)land_bitset
    result[0] = u64(value)        // Lower 64 bits
    result[1] = u64(value >> 64)  // Upper 64 bits
    return result
}
```

**Sea Bitset → Air Bitset:**
Sea territories need to be shifted because they come after land territories in the Air_ID enum:
```odin
sea_bitset_to_air_bitset :: proc(sea_bitset: Sea_Bitset) -> (result: Air_Bitset) {
    value := transmute(u128)sea_bitset
    shift_amount := uint(len(Land_ID))  // Offset by number of land territories
    
    // Distribute the shifted bits across chunks
    result[0] = u64(value << shift_amount)
    result[1] = u64((value >> (64 - shift_amount)) | (value << (shift_amount - 64)))
    result[2] = u64(value >> (128 - shift_amount))
    return result
}
```

## Complete API

### Core Operations
- `add_air(air_bitset, air)` - Set a bit
- `remove_air(air_bitset, air)` - Clear a bit  
- `contains_air(air_bitset, air)` - Test a bit
- `get_airs(air_bitset, positions)` - Get all set bits
- `count_airs(air_bitset)` - Count set bits
- `is_empty(air_bitset)` - Check if empty
- `clear_air_bitset(air_bitset)` - Clear all bits

### Conversions
- `to_air_bitset(land_bitset)` - Convert Land_Bitset to Air_Bitset
- `to_air_bitset(sea_bitset)` - Convert Sea_Bitset to Air_Bitset

## Usage Example
```odin
// Create empty bitset
my_airs: Air_Bitset

// Add some air IDs
add_air(&my_airs, Air_ID(0))
add_air(&my_airs, Air_ID(100))
add_air(&my_airs, Air_ID(200))

// Check contents
if contains_air(my_airs, Air_ID(100)) {
    fmt.println("Contains air 100")
}

// Get all air IDs
positions := make([dynamic]Air_ID)
defer delete(positions)
get_airs(my_airs, &positions)
// positions now contains [0, 100, 200]

// Convert from land bitset
land_bits: Land_Bitset
// ... set some land bits ...
air_bits := to_air_bitset(land_bits)
```

## Why Little-Endian Layout?

Using `[0]` for lowest bits is more intuitive because:
1. Direct mapping: `Air_ID(N)` maps to `bitset[N/64]` bit `N%64`
2. Simpler arithmetic - no need for `len() - 1 - index`
3. Matches how arrays naturally grow
4. Easier to debug and visualize

## Performance Notes
- All basic operations are O(1)
- `get_airs()` is O(n) where n = number of set bits
- `count_airs()` is O(1) using intrinsics (4 × count_ones)
- Uses `#force_inline` for hot-path operations
