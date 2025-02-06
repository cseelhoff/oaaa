package oaaa

import "core:math/rand"

GLOBAL_RANDOM_SEED := 0
RANDOM_MAX :: len(Action_ID)
RANDOM_NUMBERS: [RANDOM_MAX]u16

initialize_random_numbers :: proc() {
	rand.reset(1)
	for &value in RANDOM_NUMBERS {
		value = u16(rand.int_max(65535))
	}
}
