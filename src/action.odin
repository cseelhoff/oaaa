package oaaa

to_action :: proc{region_to_action, land_to_action, sea_to_action, int_to_action, buy_to_action}

// to_action_bitset :: proc{land_to_action_bitset, sea_to_action_bitset, air_to_action_bitset}

region_to_action :: #force_inline proc(region: Region_ID) -> Action_ID {
	return Action_ID(int(region) + len(Region_ID) * 5)
}

land_to_action :: #force_inline proc(land: Land_ID) -> Action_ID {
	return Action_ID(int(land)+ len(Region_ID) * 5)
}

sea_to_action :: #force_inline proc(sea: Sea_ID) -> Action_ID {
	return Action_ID(int(to_region(sea))+ len(Region_ID) * 5)
}

int_to_action :: #force_inline proc(i: int) -> Action_ID {
	assert(i >= 0 && i < len(Action_ID))
	return Action_ID(i)
}

buy_to_action :: #force_inline proc(buy_action: Buy_Action) -> Action_ID {
	return Action_ID(len(Region_ID) * 6 + int(buy_action))
}

// land_to_action_bitset :: #force_inline proc(land: Land_Bitset) -> Action_Bitset {
// 	return transmute(Action_Bitset)(u128(transmute(u128)land))
// }

// sea_to_action_bitset :: #force_inline proc(sea: Sea_Bitset) -> Action_Bitset {
// 	return transmute(Action_Bitset)(u128(transmute(u128)sea) << len(Land_ID))
// }

// air_to_action_bitset :: #force_inline proc(region: Region_Bitset) -> Action_Bitset {
// 	return transmute(Action_Bitset)u128(transmute(u128)region)
// }
