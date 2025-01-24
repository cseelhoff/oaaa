package oaaa

import "core:math/rand"

GLOBAL_RANDOM_SEED := 0
RANDOM_MAX :: 1024
RANDOM_NUMBERS: [RANDOM_MAX]u8

initialize_random_numbers :: proc() {
	rand.reset(1)
	for &value in RANDOM_NUMBERS {
		value = u8(rand.int_max(255))
	}
}
