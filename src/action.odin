package oaaa

to_action :: proc{air_to_action, land_to_action, sea_to_action, int_to_action}

to_action_bitset :: proc{land_to_action_bitset, sea_to_action_bitset, air_to_action_bitset}

air_to_action :: #force_inline proc(air: Air_ID) -> Action_ID {
	return Action_ID(air)
}

land_to_action :: #force_inline proc(land: Land_ID) -> Action_ID {
	return Action_ID(land)
}

sea_to_action :: #force_inline proc(sea: Sea_ID) -> Action_ID {
	return Action_ID(to_air(sea))
}

int_to_action :: #force_inline proc(i: int) -> Action_ID {
	assert(i >= 0 && i < len(Action_ID))
	return Action_ID(i)
}

land_to_action_bitset :: #force_inline proc(land: Land_Bitset) -> Action_Bitset {
	return transmute(Action_Bitset)(u128(transmute(u128)land))
}

sea_to_action_bitset :: #force_inline proc(sea: Sea_Bitset) -> Action_Bitset {
	return transmute(Action_Bitset)(u128(transmute(u128)sea) << len(Land_ID))
}

air_to_action_bitset :: #force_inline proc(air: Air_Bitset) -> Action_Bitset {
	return transmute(Action_Bitset)u128(transmute(u128)air)
}
